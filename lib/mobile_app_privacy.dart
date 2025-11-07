
import 'mobile_app_privacy_platform_interface.dart';

class MobileAppPrivacy {
  Future<String?> getPlatformVersion() {
    return MobileAppPrivacyPlatform.instance.getPlatformVersion();
  }
}
