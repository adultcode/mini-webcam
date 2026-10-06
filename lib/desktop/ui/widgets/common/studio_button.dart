import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

enum StudioButtonStyle { primary, danger, subtle }

/// Compact button in the studio look: filled accent, tinted danger, or subtle.
class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = StudioButtonStyle.subtle,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final StudioButtonStyle style;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      StudioButtonStyle.primary => (StudioColors.accent, const Color(0xFF020617), StudioColors.accent),
      StudioButtonStyle.danger => (
          StudioColors.danger.withValues(alpha: 0.1),
          const Color(0xFFFB7185),
          StudioColors.danger.withValues(alpha: 0.3),
        ),
      StudioButtonStyle.subtle => (StudioColors.surface, const Color(0xFFCBD5E1), StudioColors.border),
    };
    return TextButton(
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledForegroundColor: fg.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 14),
        if (busy || icon != null) const SizedBox(width: 6),
        Text(label),
      ]),
    );
  }
}
