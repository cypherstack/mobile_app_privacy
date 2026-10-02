import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Example-only fallback that hides a subtree from accessibility on Android <14.
///
/// This also prevents screen readers from accessing the subtree. Android 14+
/// keeps its semantics, independently of whether native filtering is enabled.
class AccessibilitySensitive extends StatefulWidget {
  const AccessibilitySensitive({
    super.key,
    required this.child,
    this.hiddenLabel = 'Hidden from accessibility services',
  });

  final Widget child;
  final String hiddenLabel;

  @override
  State<AccessibilitySensitive> createState() => _AccessibilitySensitiveState();
}

class _AccessibilitySensitiveState extends State<AccessibilitySensitive> {
  static const _platform = MethodChannel('mobile_app_privacy_example/platform');

  late final Future<int?> _sdkInt;

  @override
  void initState() {
    super.initState();
    _sdkInt = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? _platform.invokeMethod<int>('getAndroidSdkInt')
        : Future<int?>.value();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return widget.child;
    }
    return FutureBuilder<int?>(
      future: _sdkInt,
      builder: (context, snapshot) {
        // Avoid exposing content while the version is loading or unavailable.
        final exclude = snapshot.data == null || snapshot.data! < 34;
        // Keep the child mounted when the version lookup completes.
        return Semantics(
          container: exclude,
          label: exclude ? widget.hiddenLabel : null,
          child: ExcludeSemantics(excluding: exclude, child: widget.child),
        );
      },
    );
  }
}
