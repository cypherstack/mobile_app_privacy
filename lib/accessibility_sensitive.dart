import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Android: excludes screen readers unless [hostFiltered].
class AccessibilitySensitive extends StatelessWidget {
  const AccessibilitySensitive({
    super.key,
    required this.child,
    this.sensitive = true,
    this.hostFiltered = false,
    this.hiddenLabel = 'Hidden from accessibility services',
  });

  final Widget child;
  final bool sensitive;

  final bool hostFiltered;

  final String hiddenLabel;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return child;
    final exclude = sensitive && !hostFiltered;
    return Semantics(
      container: exclude,
      label: exclude ? hiddenLabel : null,
      child: ExcludeSemantics(excluding: exclude, child: child),
    );
  }
}
