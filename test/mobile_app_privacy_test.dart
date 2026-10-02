import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';
import 'package:mobile_app_privacy/mobile_app_privacy_method_channel.dart';
import 'package:mobile_app_privacy/mobile_app_privacy_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMobileAppPrivacyPlatform
    with MockPlatformInterfaceMixin
    implements MobileAppPrivacyPlatform {
  @override
  Future<bool> setAccessibilityDataSensitive(bool enable) async =>
      throw StateError('Unexpected platform call');

  @override
  Future<bool> isAccessibilityDataSensitive() async =>
      throw StateError('Unexpected platform call');

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> disableOverlay() {
    // TODO: implement disableOverlay
    throw UnimplementedError();
  }

  @override
  Future<void> enableOverlay({
    Color? color,
    IconAsset? iconAsset,
    bool? blurInsteadOfColor,
  }) {
    // TODO: implement enableOverlay
    throw UnimplementedError();
  }

  @override
  Future<void> setFlagSecure(bool enable) {
    // TODO: implement setFlagSecure
    throw UnimplementedError();
  }
}

void main() {
  final MobileAppPrivacyPlatform initialPlatform =
      MobileAppPrivacyPlatform.instance;

  tearDown(() => MobileAppPrivacyPlatform.instance = initialPlatform);

  test('$MethodChannelMobileAppPrivacy is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMobileAppPrivacy>());
  });

  test('getPlatformVersion', () async {
    MobileAppPrivacy mobileAppPrivacyPlugin = MobileAppPrivacy();
    MockMobileAppPrivacyPlatform fakePlatform = MockMobileAppPrivacyPlatform();
    MobileAppPrivacyPlatform.instance = fakePlatform;

    expect(await mobileAppPrivacyPlugin.getPlatformVersion(), '42');
  });
  test(
    'unsupported platforms do not invoke the native accessibility methods',
    () async {
      if (Platform.isAndroid) return;
      MobileAppPrivacyPlatform.instance = MockMobileAppPrivacyPlatform();
      expect(
        await MobileAppPrivacy().setAccessibilityDataSensitive(true),
        isFalse,
      );
      expect(await MobileAppPrivacy().isAccessibilityDataSensitive(), isFalse);
    },
  );
}
