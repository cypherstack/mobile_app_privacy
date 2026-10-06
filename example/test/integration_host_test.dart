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
}
