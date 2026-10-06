import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'support/android_host.dart';

Future<void> main(List<String> args) async {
  final session = args[0];
  final executable = args[1];
  await runPrivacyHost(
    session,
    discoverDevices: () async {
      final devices = await runProcess(executable, ['devices']);
      if (devices.exitCode != 0) throw StateError('${devices.stderr}');
      return [
        for (final line in '${devices.stdout}'.split('\n'))
          if (RegExp(r'^(\S+)\s+device$').firstMatch(line.trim())
              case final match?)
            Adb(executable, match[1]!),
      ];
    },
  );
}

Future<void> runPrivacyHost(
  String session, {
  required Future<List<Adb>> Function() discoverDevices,
  Duration startupTimeout = const Duration(minutes: 2),
  Duration maxLifetime = const Duration(minutes: 20),
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  Adb? device;
  AccessibilitySettings? settings;
  var enabled = false;
  var lastId = 0;
  var finished = false;
  final startup = Stopwatch()..start();

  Future<Map<String, dynamic>?> request(Adb adb) async {
    try {
      final data =
          jsonDecode(
                await adb.shell([
                  'run-as',
                  examplePackage,
                  'cat',
                  'cache/privacy-request.json',
                ]),
              )
              as Map<String, dynamic>;
      return data['session'] == session ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> reply(Adb adb, Map<String, dynamic> value) async {
    final encoded = base64Encode(utf8.encode(jsonEncode(value)));
    await adb.shell([
      'run-as',
      examplePackage,
      'sh',
      '-c',
      'printf %s $encoded | base64 -d > cache/privacy-reply.tmp && '
          'mv cache/privacy-reply.tmp cache/privacy-reply.json',
    ]);
  }

  try {
    // Once probes are enabled, app liveness owns the session lifetime. Widget
    // tests and debugger pauses need not send host commands to keep it alive.
    // The lifetime cap bounds an interrupted run whose app never exits.
    while (!finished &&
        startup.elapsed < maxLifetime &&
        (enabled || startup.elapsed < startupTimeout)) {
      if (device == null) {
        for (final candidate in await discoverDevices()) {
          if (await request(candidate) != null) {
            device = candidate;
            settings = AccessibilitySettings(candidate.shell);
            break;
          }
        }
      }
      final adb = device;
      if (adb != null) {
        final data = await request(adb);
        if (data != null && data['id'] != lastId) {
          lastId = data['id'] as int;
          final response = <String, dynamic>{'session': session, 'id': lastId};
          try {
            if (await adb.shell(['getprop', 'ro.kernel.qemu']) != '1') {
              throw StateError(
                'Privacy integration tests require an emulator.',
              );
            }
            switch (data['command']) {
              case 'ready':
                if (!enabled) {
                  await settings!.enableProbes();
                  enabled = true;
                }
                response['data'] = {
                  'sdkInt': int.parse(
                    await adb.shell(['getprop', 'ro.build.version.sdk']),
                  ),
                  'device': adb.serial,
                };
              case 'background':
                await adb.shell(['input', 'keyevent', 'KEYCODE_HOME']);
                response['data'] = <String, dynamic>{};
              case 'resume':
                await adb.shell([
                  'am',
                  'start',
                  '-n',
                  '$examplePackage/.MainActivity',
                ]);
                response['data'] = <String, dynamic>{};
              case 'finish':
                await settings!.restore();
                response['data'] = <String, dynamic>{};
                finished = true;
              default:
                throw StateError('Unknown command: ${data['command']}');
            }
          } catch (error, stack) {
            stderr.writeln('$error\n$stack');
            response['error'] = '$error';
            if (data['command'] == 'ready') finished = true;
          }
          await reply(adb, response);
        }
        if (enabled) {
          try {
            if ((await adb.shell(['pidof', examplePackage])).isEmpty) break;
          } on ProcessException {
            break;
          }
        }
      }
      if (!finished) {
        await Future<void>.delayed(pollInterval);
      }
    }
  } finally {
    await settings?.restore();
    if (!finished && startup.elapsed >= maxLifetime) {
      stderr.writeln(
        'Host session $session ran for ${maxLifetime.inMinutes} minutes '
        'without a finish command.',
      );
    }
    stdout.writeln(
      'Accessibility settings restored; host session $session closed.',
    );
  }
}
