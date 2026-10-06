import 'package:flutter/material.dart';

import '../../theme/oled_theme.dart';

/// Circular dark button in the bottom action deck.
class DeckButton extends StatelessWidget {
  const DeckButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Highlighted state, e.g. torch on.
  final bool active;

  /// Accent-coloured icon, e.g. the settings button.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? Colors.white24
        : active
            ? OledColors.onCyan
            : accent
                ? OledColors.cyan
                : Colors.white.withValues(alpha: 0.9);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? OledColors.cyan : Colors.black.withValues(alpha: 0.7),
        shape: CircleBorder(
          side: BorderSide(color: active ? OledColors.cyan : Colors.white.withValues(alpha: 0.15)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 20, color: color)),
        ),
      ),
    );
  }
}
