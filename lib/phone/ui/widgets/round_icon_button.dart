import 'package:flutter/material.dart';

/// Translucent circular button used in the phone control bar.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? Colors.amber.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
