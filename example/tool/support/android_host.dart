import 'dart:async';
import 'dart:convert';
import 'dart:io';

const examplePackage = 'com.cypherstack.mobile_app_privacy_example';
typedef Shell = Future<String> Function(List<String> arguments);

Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  bool binary = false,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final process = await Process.start(executable, arguments);
  final output = process.stdout.fold<List<int>>(
    [],
    (all, chunk) => all..addAll(chunk),
  );
  final errors = process.stderr.transform(utf8.decoder).join();
  int code;
  try {
    code = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    await output;
    await errors;
    rethrow;
  }
  final bytes = await output;
  return ProcessResult(
    process.pid,
    code,
    binary ? bytes : utf8.decode(bytes, allowMalformed: true),
    await errors,
  );
}

class Adb {
  Adb(this.executable, this.serial);
  final String executable;
  final String serial;

  Future<ProcessResult> run(
    List<String> arguments, {
    bool binary = false,
  }) async {
    final args = ['-s', serial, ...arguments];
    final result = await runProcess(executable, args, binary: binary);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        args,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return result;
  }

  Future<String> shell(List<String> arguments) async {
    final command = arguments
        .map((s) => "'${s.replaceAll("'", "'\\''")}'")
        .join(' ');
    return '${(await run(['shell', command])).stdout}'.trim();
  }
}

class AccessibilitySettings {
  AccessibilitySettings(this.shell);
  final Shell shell;
  final _previous = <String, String>{};
  static const keys = [
    'enabled_accessibility_services',
    'accessibility_enabled',
  ];

  static const probes = [
    '$examplePackage/.ToolProbeService',
    '$examplePackage/.NonToolProbeService',
  ];

  Future<void> enableProbes() async {
    if (_previous.isNotEmpty) throw StateError('Settings already captured');
    final snapshot = <String, String>{};
    for (final key in keys) {
      snapshot[key] = await shell(['settings', 'get', 'secure', key]);
    }
    // A helper that was killed, or one still running beside this one, may
    // have left the probes enabled. They are never part of the original, so
    // this helper's restore removes them either way.
    final current = snapshot[keys.first]!;
    final enabled = [
      if (current != 'null' && current.isNotEmpty) ...current.split(':'),
    ];
    final others = [
      for (final service in enabled)
        if (!probes.contains(service)) service,
    ];
    if (others.length != enabled.length) {
      snapshot[keys.first] = others.isEmpty ? 'null' : others.join(':');
      if (others.isEmpty) snapshot[keys.last] = '0';
    }
    _previous.addAll(snapshot);
    final services = {...others, ...probes};
    await shell(['settings', 'put', 'secure', keys.first, services.join(':')]);
    await shell(['settings', 'put', 'secure', keys.last, '1']);
  }

  Future<void> restore() async {
    final errors = <Object>[];
    for (final entry in _previous.entries.toList()) {
      try {
        await shell(
          entry.value == 'null'
              ? ['settings', 'delete', 'secure', entry.key]
              : ['settings', 'put', 'secure', entry.key, entry.value],
        );
        _previous.remove(entry.key);
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) {
      throw StateError('Could not restore emulator settings: $errors');
    }
  }
}
