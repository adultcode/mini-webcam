import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Square icon button for the viewport toolbars; accent coloured when [active].
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 16,
          onPressed: onPressed,
          color: active ? StudioColors.accent : const Color(0xFFCBD5E1),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}
