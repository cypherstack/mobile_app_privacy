import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_privacy/mobile_app_privacy_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMobileAppPrivacy platform = MethodChannelMobileAppPrivacy();
  const MethodChannel channel = MethodChannel('mobile_app_privacy');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
  test(
    'accessibility methods return effective state and send boolean arguments',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'isAccessibilityDataSensitive' ||
                call.arguments['enable'] == true;
          });
      expect(await platform.setAccessibilityDataSensitive(true), isTrue);
      expect(await platform.setAccessibilityDataSensitive(false), isFalse);
      expect(await platform.isAccessibilityDataSensitive(), isTrue);
      expect(calls.map((call) => call.method), [
        'setAccessibilityDataSensitive',
        'setAccessibilityDataSensitive',
        'isAccessibilityDataSensitive',
      ]);
      expect(calls[0].arguments, {'enable': true});
      expect(calls[1].arguments, {'enable': false});
      expect(calls[2].arguments, isNull);
    },
  );

  test('absent native state is never reported as protected', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await platform.setAccessibilityDataSensitive(true), isFalse);
    expect(await platform.isAccessibilityDataSensitive(), isFalse);
  });

  test('native errors propagate instead of claiming protection', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    await expectLater(
      platform.setAccessibilityDataSensitive(true),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      platform.isAccessibilityDataSensitive(),
      throwsA(isA<PlatformException>()),
    );
  });
}
