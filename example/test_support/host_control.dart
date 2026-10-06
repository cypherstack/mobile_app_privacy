import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'privacy_app.dart';

class HostControl {
  String? _session;
  late String _directory;
  int _sequence = 0;
  bool _pending = false;

  Future<Map<String, dynamic>> command(String command) async {
    if (_pending) throw StateError('A host command is already pending');
    if (_session == null) {
      final session = (await probe.invokeMapMethod<String, dynamic>(
        'session',
      ))!;
      _session = session['id'] as String;
      _directory = session['directory'] as String;
    }
    if (_session == null || _session!.isEmpty) {
      throw StateError(
        'Run flutter test integration_test on an Android emulator.',
      );
    }
    _pending = true;
    final id = ++_sequence;
    try {
      final path = '$_directory/privacy-request.json';
      await File('$path.tmp').writeAsString(
        jsonEncode({'session': _session, 'id': id, 'command': command}),
        flush: true,
      );
      await File('$path.tmp').rename(path);
      final timer = Stopwatch()..start();
      while (timer.elapsed < const Duration(seconds: 60)) {
        final reply = File('$_directory/privacy-reply.json');
        if (await reply.exists()) {
          final data =
              jsonDecode(await reply.readAsString()) as Map<String, dynamic>;
          if (data['session'] == _session && data['id'] == id) {
            if (data['error'] != null) throw StateError('${data['error']}');
            return (data['data'] as Map).cast<String, dynamic>();
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      throw TimeoutException(
        'Android host command $command timed out; inspect build/app/privacy-host-$_session.log',
      );
    } finally {
      _pending = false;
    }
  }

  Future<void> close() async {
    if (_sequence > 0) await command('finish');
  }
}
