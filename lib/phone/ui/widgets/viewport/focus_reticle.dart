import 'package:flutter/material.dart';

import '../../theme/oled_theme.dart';

/// Glowing ring shown where the user tapped to focus.
class FocusReticle extends StatelessWidget {
  const FocusReticle({super.key, required this.center, this.scale = 1});

  final Offset center;

  /// The viewport is drawn at sensor size and scaled to the screen, so the
  /// reticle is scaled the same way to look ~96 px on screen.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = 96 * scale;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: OledColors.cyan.withValues(alpha: 0.85), width: 1.5 * scale),
            boxShadow: [BoxShadow(color: OledColors.cyan.withValues(alpha: 0.35), blurRadius: 16 * scale)],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: const BoxDecoration(color: OledColors.cyan, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
