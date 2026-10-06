import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/oled_theme.dart';

/// Frosted dark glass surface used for every floating control.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.radius = 999,
    this.color = OledColors.glass,
    this.borderColor = OledColors.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: shape,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
