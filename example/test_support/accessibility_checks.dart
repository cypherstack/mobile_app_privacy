import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'host_control.dart';
import 'privacy_app.dart';

void accessibilityTests(
  IntegrationTestWidgetsFlutterBinding binding,
  HostControl host,
) {
  late int sdk;

  bool secret(String text) =>
      text.contains('seed-probe') || text.contains('private-probe');

  // Native uptime. Probe events record theirs, so a phase can examine every
  // event since its transition started rather than clearing the buffers.
  Future<int> mark() async => (await probe.invokeMethod<int>('uptime'))!;

  String events(Map<String, dynamic> state, String key, int since) => [
    for (final entry in (state[key] as List).cast<String>())
      if (int.parse(entry.substring(0, entry.indexOf(' '))) >= since)
        entry.substring(entry.indexOf(' ') + 1),
  ].join('\n');

  Future<void> checkAccessibility(
    WidgetTester tester,
    String phase,
    bool protected,
    int since,
  ) async {
    // While protected, every snapshot taken here must be free of secrets, not
    // only the samples taken once the phase has settled.
    final leaks = <String>{};
    bool watch(Map<String, dynamic> s, bool done) {
      if (protected) {
        final tree = s['nonToolTree'] as String;
        final log = events(s, 'nonToolEvents', since);
        if (secret(tree)) leaks.add('$phase: non-tool node leak: $tree');
        if (secret(log)) leaks.add('$phase: event leak: $log');
      }
      return done;
    }

    await waitNative(
      '$phase: tool reads the real Flutter view tree',
      (s) => watch(
        s,
        (s['toolTree'] as String).contains('public-probe') &&
            (s['toolTree'] as String).contains('seed-probe') &&
            (s['toolTree'] as String).contains('private-probe') &&
            ((s['toolTree'] as String).contains('fallback-probe') ==
                (sdk >= 34)),
      ),
      tester: tester,
    );
    await waitNative(
      '$phase: tool receives input events',
      (s) => watch(s, events(s, 'toolEvents', since).contains('private-probe')),
      tester: tester,
    );
    if (!protected) {
      await waitNative(
        '$phase: non-tool positive control',
        (s) =>
            secret(s['nonToolTree'] as String) &&
            events(s, 'nonToolEvents', since).contains('private-probe'),
        tester: tester,
      );
    }
    Map<String, dynamic> state = {};
    for (var sample = 0; sample < 10; sample++) {
      state = await snapshot();
      watch(state, true);
      final toolTree = state['toolTree'] as String;
      final otherTree = state['nonToolTree'] as String;
      expect(toolTree, contains('seed-probe'), reason: phase);
      expect(toolTree.contains('fallback-probe'), sdk >= 34, reason: phase);
      expect(
        otherTree.contains('fallback-probe'),
        sdk >= 34 && !protected,
        reason: phase,
      );
      if (protected) {
        expect(
          events(state, 'nonToolEvents', since),
          isNot(contains('fallback-probe')),
          reason: phase,
        );
      } else {
        expect(otherTree, contains('public-probe'), reason: phase);
        expect(otherTree, contains('seed-probe'), reason: phase);
        expect(otherTree, contains('private-probe'), reason: phase);
      }
      if (sdk < 34) {
        expect(
          events(state, 'toolEvents', since),
          isNot(contains('fallback-probe')),
        );
        expect(
          events(state, 'nonToolEvents', since),
          isNot(contains('fallback-probe')),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(leaks, isEmpty);
    (binding.reportData!['phases'] as List).add({
      'phase': phase,
      'protected': protected,
      ...state,
    });
  }

  Future<void> prepare() async {
    final info = await host.command('ready');
    sdk = (await snapshot())['sdkInt'] as int;
    expect(sdk, info['sdkInt']);
    binding.reportData ??= {
      'device': info['device'],
      'sdkInt': sdk,
      'phases': <Object>[],
    };
  }

  void privacyTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await prepare();
        await body(tester);
      } finally {
        await cleanup(tester);
      }
    });
  }

  privacyTest(
    'real app navigation, native filtering, and legacy semantics fallback',
    (tester) async {
      await openExample(tester);
      await waitNative(
        'both real accessibility services connected',
        (s) => s['toolConnected'] == true && s['nonToolConnected'] == true,
        tester: tester,
      );

      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      // Protection is already in effect, so the page's first render counts.
      final startup = await mark();
      await tester.tap(find.byKey(const ValueKey('open-accessibility')));
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      await checkAccessibility(tester, 'startup', sdk >= 34, startup);

      final disabled = await mark();
      await tester.tap(find.byKey(const ValueKey('disable-filtering')));
      await waitFor(tester, find.text('filtered=false'));
      expect(await privacy.isAccessibilityDataSensitive(), isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('sensitive-input')),
        'private-probe-entered',
      );
      await checkAccessibility(tester, 'disabled', false, disabled);

      // The tap sends the plugin call before this mark reaches the platform
      // thread, so the mark follows the switch with no frame in between.
      // Events the page sent while still unprotected precede it.
      await tester.tap(find.byKey(const ValueKey('enable-filtering')));
      final reenabled = await mark();
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      await checkAccessibility(tester, 're-enabled', sdk >= 34, reenabled);
      await tester.pageBack();
      await waitFor(tester, find.byKey(const ValueKey('open-accessibility')));
    },
  );

  privacyTest(
    'ADB background and resume exercise the real app lifecycle overlay',
    (tester) async {
      await openExample(tester);
      final children = (await snapshot())['decorChildren'] as int;
      try {
        await host.command('background');
        await waitNative(
          'background lifecycle installed the native overlay',
          (s) => s['decorChildren'] == children + 1,
        );
      } finally {
        await host.command('resume');
      }
      await waitNative(
        'resume removed the native overlay',
        (s) => s['decorChildren'] == children,
        tester: tester,
      );
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
    },
  );
}
