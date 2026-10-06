import 'package:flutter/material.dart';

import '../../theme/oled_theme.dart';
import 'glass_container.dart';

/// Small glass pill: optional dot or icon, optional accent key, then a value.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.text,
    this.keyText,
    this.dotColor,
    this.icon,
    this.iconColor = OledColors.cyan,
    this.selected = false,
    this.onTap,
  });

  final String text;
  final String? keyText;
  final Color? dotColor;
  final IconData? icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = GlassContainer(
      color: selected ? OledColors.cyan.withValues(alpha: 0.12) : OledColors.glassPill,
      borderColor: selected ? OledColors.cyan.withValues(alpha: 0.5) : OledColors.border,
      padding: onTap == null
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dotColor != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
        ],
        if (keyText != null) ...[
          Text(keyText!, style: OledText.chip.copyWith(color: OledColors.cyan)),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: onTap == null
              ? OledText.chip
              : TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? OledColors.cyan : Colors.white.withValues(alpha: 0.7)),
        ),
      ]),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
