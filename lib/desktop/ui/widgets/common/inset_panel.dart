import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Darker recessed box used inside cards for details and status text.
class InsetPanel extends StatelessWidget {
  const InsetPanel({super.key, required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: StudioColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioColors.divider),
      ),
      child: child,
    );
  }
}
