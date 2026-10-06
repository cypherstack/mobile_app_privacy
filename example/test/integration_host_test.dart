import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/integration_host.dart';
import '../tool/support/android_host.dart';

class FakeAdb extends Adb {
  FakeAdb() : super('unused', 'emulator-test');

  final settings = <String, String>{
    'enabled_accessibility_services': 'other/.Reader',
    'accessibility_enabled': '1',
  };
  final replies = <Map<String, dynamic>>[];
  final ready = Completer<void>();
  Map<String, dynamic>? request = {
    'session': 'test-session',
    'id': 1,
    'command': 'ready',
  };
  bool alive = true;
  bool pidofThrows = false;
  bool failReady = false;

  @override
  Future<String> shell(List<String> arguments) async {
    switch (arguments.first) {
      case 'getprop':
        if (arguments[1] == 'ro.kernel.qemu') return failReady ? '0' : '1';
        return '34';
      case 'pidof':
        if (pidofThrows) {
          throw ProcessException('adb', arguments, 'no process', 1);
        }
        return alive ? '1234' : '';
      case 'settings':
        final key = arguments[3];
        switch (arguments[1]) {
          case 'get':
            return settings[key] ?? 'null';
          case 'put':
            settings[key] = arguments[4];
          case 'delete':
            settings.remove(key);
        }
        return '';
      case 'run-as':
        if (arguments[2] == 'cat') return jsonEncode(request);
        final encoded = RegExp(
          r'printf %s ([A-Za-z0-9+/=]+)',
        ).firstMatch(arguments.last)![1]!;
        final reply = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
        replies.add(reply.cast<String, dynamic>());
        if (reply['id'] == 1 && !ready.isCompleted) ready.complete();
        return '';
      default:
        throw StateError('Unexpected ADB command: $arguments');
    }
  }
}

void main() {
  test(
    'active session survives startup timeout and restores on finish',
    () async {
      final adb = FakeAdb();
      final original = Map<String, String>.of(adb.settings);
      var closed = false;
      final host = runPrivacyHost(
        'test-session',
        discoverDevices: () async => [adb],
        startupTimeout: const Duration(milliseconds: 50),
        pollInterval: const Duration(milliseconds: 1),
      ).whenComplete(() => closed = true);
      try {
        await adb.ready.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(closed, isFalse);
        expect(
          adb.settings['enabled_accessibility_services'],
          contains('.ToolProbeService'),
        );
        adb.request = {'session': 'test-session', 'id': 2, 'command': 'finish'};
        await host.timeout(const Duration(seconds: 5));
        expect(adb.replies.last, {
          'session': 'test-session',
          'id': 2,
          'data': <String, dynamic>{},
        });
        expect(adb.settings, original);
      } finally {
        adb.alive = false;
        await host;
      }
    },
  );

  for (final pidofThrows in [false, true]) {
    test('app exit restores probes (pidof throws: $pidofThrows)', () async {
      final adb = FakeAdb();
      final original = Map<String, String>.of(adb.settings);
      final host = runPrivacyHost(
        'test-session',
        discoverDevices: () async => [adb],
        pollInterval: const Duration(milliseconds: 1),
      );
      try {
        await adb.ready.future.timeout(const Duration(seconds: 5));
        adb.alive = false;
        adb.pidofThrows = pidofThrows;
        await host.timeout(const Duration(seconds: 5));
        expect(adb.settings, original);
      } finally {
        adb.alive = false;
        await host;
      }
    });
  }

  test(
    'startup expires without changing settings if no session arrives',
    () async {
      final adb = FakeAdb()..request = null;
      final original = Map<String, String>.of(adb.settings);
      await runPrivacyHost(
        'test-session',
        discoverDevices: () async => [adb],
        startupTimeout: const Duration(milliseconds: 20),
        pollInterval: const Duration(milliseconds: 1),
      ).timeout(const Duration(seconds: 5));
      expect(adb.settings, original);
      expect(adb.replies, isEmpty);
    },
  );

  test('lifetime cap restores probes when the app never exits', () async {
    final adb = FakeAdb();
    final original = Map<String, String>.of(adb.settings);
    await runPrivacyHost(
      'test-session',
      discoverDevices: () async => [adb],
      maxLifetime: const Duration(milliseconds: 100),
      pollInterval: const Duration(milliseconds: 1),
    ).timeout(const Duration(seconds: 5));
    expect(adb.replies, isNotEmpty);
    expect(adb.settings, original);
  });

  test('a failed ready command closes the host', () async {
    final adb = FakeAdb()..failReady = true;
    final original = Map<String, String>.of(adb.settings);
    await runPrivacyHost(
      'test-session',
      discoverDevices: () async => [adb],
      pollInterval: const Duration(milliseconds: 1),
    ).timeout(const Duration(seconds: 5));
    expect(adb.replies.single['error'], contains('emulator'));
    expect(adb.settings, original);
  });

  test('stop request restores probes while the app is alive', () async {
    final adb = FakeAdb();
    final original = Map<String, String>.of(adb.settings);
    final stop = Completer<void>();
    final host = runPrivacyHost(
      'test-session',
      discoverDevices: () async => [adb],
      pollInterval: const Duration(milliseconds: 1),
      stop: stop.future,
    );
    await adb.ready.future.timeout(const Duration(seconds: 5));
    expect(
      adb.settings['enabled_accessibility_services'],
      contains('.ToolProbeService'),
    );
    stop.complete();
    await host.timeout(const Duration(seconds: 5));
    expect(adb.settings, original);
  });

  test(
    'SIGTERM to the host process restores probes',
    () async {
      final state = await Directory.systemTemp.createTemp('privacy-host-');
      addTearDown(() => state.delete(recursive: true));
      final adb = File('${state.path}/adb');
      await adb.writeAsString(_fakeAdb);
      await Process.run('chmod', ['+x', adb.path]);
      await Directory('${state.path}/cache').create();
      await File(
        '${state.path}/enabled_accessibility_services',
      ).writeAsString('other/.Reader');
      await File('${state.path}/accessibility_enabled').writeAsString('1');
      await File('${state.path}/cache/privacy-request.json').writeAsString(
        jsonEncode({'session': 'signal-session', 'id': 1, 'command': 'ready'}),
      );
      final dart =
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart';
      final host = await Process.start(dart, [
        'run',
        'tool/integration_host.dart',
        'signal-session',
        adb.path,
      ]);
      final output = StringBuffer();
      host.stdout.transform(utf8.decoder).listen(output.write);
      host.stderr.transform(utf8.decoder).listen(output.write);
      final reply = File('${state.path}/cache/privacy-reply.json');
      final timer = Stopwatch()..start();
      while (!await reply.exists()) {
        if (timer.elapsed > const Duration(seconds: 60)) {
          host.kill(ProcessSignal.sigkill);
          fail('The host never replied to ready: $output');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(jsonDecode(await reply.readAsString()), containsPair('id', 1));
      expect(
        await File(
          '${state.path}/enabled_accessibility_services',
        ).readAsString(),
        contains('.ToolProbeService'),
      );

      host.kill(ProcessSignal.sigterm);
      expect(
        await host.exitCode.timeout(const Duration(seconds: 30)),
        0,
        reason: '$output',
      );
      expect(
        await File(
          '${state.path}/enabled_accessibility_services',
        ).readAsString(),
        'other/.Reader',
      );
      expect(
        await File('${state.path}/accessibility_enabled').readAsString(),
        '1',
      );
    },
    skip: Platform.isWindows ? 'Windows has no SIGTERM' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

// Stands in for adb when a test runs the host as a real process. State lives
// beside the script: one file per secure setting, plus cache/ for the request
// and reply files the app would hold.
const _fakeAdb = r'''
#!/bin/sh
state=$(dirname "$0")
if [ "$1" = devices ]; then
  printf 'List of devices attached\nemulator-5554\tdevice\n'
  exit 0
fi
# The host runs `adb -s <serial> shell '<quoted command>'`.
eval "set -- $4"
case "$1" in
  getprop) if [ "$2" = ro.kernel.qemu ]; then echo 1; else echo 34; fi ;;
  pidof) echo 1234 ;;
  settings)
    case "$2" in
      get) cat "$state/$4" 2>/dev/null || echo null ;;
      put) printf %s "$5" > "$state/$4" ;;
      delete) rm -f "$state/$4" ;;
    esac ;;
  run-as)
    if [ "$3" = cat ]; then cat "$state/$4"; else cd "$state" && sh -c "$5"; fi ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac
''';
