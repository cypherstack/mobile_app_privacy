import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mobile_app_privacy_platform_interface.dart';

/// An implementation of [MobileAppPrivacyPlatform] that uses method channels.
class MethodChannelMobileAppPrivacy extends MobileAppPrivacyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mobile_app_privacy');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
