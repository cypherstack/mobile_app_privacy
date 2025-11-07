import 'dart:io';
import 'dart:ui';

import 'mobile_app_privacy_platform_interface.dart';

class IconAsset {
  final String assetPath;
  final double width, height;

  IconAsset({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() => {
    "assetPath": assetPath,
    "width": width,
    "height": height,
  };

  @override
  String toString() => toMap().toString();
}

class MobileAppPrivacy {
  Future<String?> getPlatformVersion() {
    return MobileAppPrivacyPlatform.instance.getPlatformVersion();
  }

  /// [blurInsteadOfColor] is currently ignored on android
  Future<void> enableOverlay({
    Color color = const Color(0xFFFFFFFF),
    IconAsset? iconAsset,
    bool? blurInsteadOfColor,
  }) => MobileAppPrivacyPlatform.instance.enableOverlay(
    color: color,
    iconAsset: iconAsset,
    blurInsteadOfColor: blurInsteadOfColor,
  );

  Future<void> disableOverlay() =>
      MobileAppPrivacyPlatform.instance.disableOverlay();

  /// Does nothing on iOS
  Future<void> setFlagSecure(bool enable) => Platform.isAndroid
      ? MobileAppPrivacyPlatform.instance.setFlagSecure(enable)
      : Future.value();
}
