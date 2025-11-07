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
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> disableOverlay() {
    // TODO: implement disableOverlay
    throw UnimplementedError();
  }

  @override
  Future<void> enableOverlay({Color? color, IconAsset? iconAsset}) {
    // TODO: implement enableOverlay
    throw UnimplementedError();
  }
}

void main() {
  final MobileAppPrivacyPlatform initialPlatform =
      MobileAppPrivacyPlatform.instance;

  test('$MethodChannelMobileAppPrivacy is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMobileAppPrivacy>());
  });

  test('getPlatformVersion', () async {
    MobileAppPrivacy mobileAppPrivacyPlugin = MobileAppPrivacy();
    MockMobileAppPrivacyPlatform fakePlatform = MockMobileAppPrivacyPlatform();
    MobileAppPrivacyPlatform.instance = fakePlatform;

    expect(await mobileAppPrivacyPlugin.getPlatformVersion(), '42');
  });
}
