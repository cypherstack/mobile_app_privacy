import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mobile_app_privacy_method_channel.dart';

abstract class MobileAppPrivacyPlatform extends PlatformInterface {
  /// Constructs a MobileAppPrivacyPlatform.
  MobileAppPrivacyPlatform() : super(token: _token);

  static final Object _token = Object();

  static MobileAppPrivacyPlatform _instance = MethodChannelMobileAppPrivacy();

  /// The default instance of [MobileAppPrivacyPlatform] to use.
  ///
  /// Defaults to [MethodChannelMobileAppPrivacy].
  static MobileAppPrivacyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MobileAppPrivacyPlatform] when
  /// they register themselves.
  static set instance(MobileAppPrivacyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
