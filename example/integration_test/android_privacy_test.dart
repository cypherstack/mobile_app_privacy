import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';

import '../test_support/accessibility_checks.dart';
import '../test_support/host_control.dart';
import '../test_support/privacy_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) {
    testWidgets(
      'Android privacy requires an Android emulator',
      (_) async {},
      skip: true,
    );
    return;
  }
  final host = HostControl();
  tearDownAll(host.close);
  // Enable services before testWidgets records its semantics handles.
  setUpAll(() async {
    await host.command('ready');
    await waitNative(
      'accessibility services connected',
      (s) => s['toolConnected'] == true && s['nonToolConnected'] == true,
    );
    final timer = Stopwatch()..start();
    while (!binding.semanticsEnabled &&
        timer.elapsed < const Duration(seconds: 15)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(binding.semanticsEnabled, isTrue);
  });
  late int sdk;
  setUp(() async => sdk = await androidSdk());

  testWidgets('navigation, accessibility API, and version-based semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await openExample(tester);
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      await tester.tap(find.byKey(const ValueKey('open-accessibility')));
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      await waitFor(
        tester,
        find.bySemanticsLabel(
          sdk >= 34 ? 'fallback-probe' : 'Hidden from accessibility services',
        ),
      );

      void checkSemantics() {
        expect(find.bySemanticsLabel('public-probe'), findsOneWidget);
        expect(find.bySemanticsLabel('seed-probe'), findsOneWidget);
        expect(find.text('fallback-probe'), findsOneWidget);
        expect(
          find.bySemanticsLabel('fallback-probe'),
          sdk >= 34 ? findsOneWidget : findsNothing,
        );
        expect(
          find.bySemanticsLabel('Hidden from accessibility services'),
          sdk < 34 ? findsOneWidget : findsNothing,
        );
      }

      checkSemantics();
      await tester.tap(find.byKey(const ValueKey('disable-filtering')));
      await waitFor(tester, find.text('filtered=false'));
      expect(await privacy.isAccessibilityDataSensitive(), isFalse);
      checkSemantics();
      expect(await privacy.setAccessibilityDataSensitive(false), isFalse);
      await tester.tap(find.byKey(const ValueKey('enable-filtering')));
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      expect(await privacy.setAccessibilityDataSensitive(true), sdk >= 34);
      checkSemantics();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.byKey(const ValueKey('open-accessibility')));
      expect(find.text('seed-probe'), findsNothing);
    } finally {
      await cleanup(tester);
      semantics.dispose();
    }
  });

  testWidgets(
    'secure flag and native overlays including SVG, PNG, and missing assets',
    (tester) async {
      try {
        await openExample(tester);
        final initial = await snapshot();
        final children = initial['decorChildren'] as int;
        expect(initial['secure'], isFalse);
        await privacy.setFlagSecure(true);
        expect((await snapshot())['secure'], isTrue);
        await privacy.setFlagSecure(false);
        expect((await snapshot())['secure'], isFalse);

        const color = Color(0xff315577);
        await privacy.enableOverlay(color: color);
        await privacy.enableOverlay(color: Colors.red);
        var state = await snapshot();
        expect(
          state['decorChildren'],
          children + 1,
          reason: 'Repeated enables must not stack overlays',
        );
        expect((state['overlayColor'] as int) & 0xffffffff, color.toARGB32());
        // Exercise both integer widths used by the Android message codec,
        // including transparent black and the signed 32-bit boundary.
        for (final argb in [
          0x00000000,
          0x7f112233,
          0x7fffffff,
          0x80000000,
          0xffffffff,
        ]) {
          await privacy.disableOverlay();
          await privacy.enableOverlay(color: Color(argb));
          state = await snapshot();
          expect(state['decorChildren'], children + 1);
          expect(
            (state['overlayColor'] as int) & 0xffffffff,
            argb,
            reason: 'Preserve ARGB 0x${argb.toRadixString(16).padLeft(8, '0')}',
          );
        }
        for (final asset in [
          'assets/integration/icon.svg',
          'assets/integration/icon.png',
        ]) {
          await privacy.disableOverlay();
          await privacy.enableOverlay(
            color: color,
            iconAsset: IconAsset(assetPath: asset, width: 24, height: 16),
          );
          state = await snapshot();
          expect(
            state['overlayImages'],
            1,
            reason: 'The native plugin must decode $asset',
          );
          expect(
            state['imageWidth'],
            (24 * (state['density'] as double)).toInt(),
          );
          expect(
            state['imageHeight'],
            (16 * (state['density'] as double)).toInt(),
          );
        }
        await privacy.disableOverlay();
        await privacy.enableOverlay(
          iconAsset: IconAsset(assetPath: 'missing.png', width: 24, height: 16),
        );
        state = await snapshot();
        expect(state['decorChildren'], children + 1);
        expect(
          state['overlayImages'],
          0,
          reason: 'Missing icons must not prevent the privacy overlay',
        );
        await privacy.disableOverlay();
        await privacy.disableOverlay();
        expect((await snapshot())['decorChildren'], children);
      } finally {
        await cleanup(tester);
      }
    },
  );
  accessibilityTests(binding, host);
}
