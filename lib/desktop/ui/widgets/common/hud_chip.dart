import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Translucent label floating over the video, e.g. "1080p • 30 FPS".
class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.text,
    this.color = StudioColors.textPrimary,
    this.icon,
    this.dotColor,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: StudioColors.hud,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x99334155)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dotColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(text, style: TextStyle(fontFamily: StudioText.mono, fontSize: 12, color: color)),
      ]),
    );
  }
}
