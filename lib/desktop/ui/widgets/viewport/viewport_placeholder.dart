import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';

/// Shown in the viewport when there is no video to display.
class ViewportPlaceholder extends StatelessWidget {
  const ViewportPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<DesktopProvider, ({String state, String message})>(
        (c) => (state: c.status.state, message: c.status.message));
    final (icon, title, detail) = switch (s.state) {
      'streaming' => (Icons.visibility_off_outlined, 'Preview hidden',
          'Video still reaches the virtual camera.'),
      'connecting' || 'reconnecting' => (Icons.hourglass_top, 'Connecting...', s.message),
      'error' => (Icons.error_outline, 'Connection error', s.message),
      _ => (Icons.videocam_outlined, 'No video yet', 'Connect your phone from the left panel.'),
    };

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xCC1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xCC334155)),
        ),
        child: Icon(icon, size: 36, color: StudioColors.accent),
      ),
      const SizedBox(height: 12),
      Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1))),
      const SizedBox(height: 4),
      SizedBox(
        width: 320,
        child: Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: StudioColors.textMuted)),
      ),
    ]);
  }
}
