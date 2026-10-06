import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/hud_chip.dart';

/// LIVE / format / codec chips on the left, throughput on the right.
class HudTopBar extends StatelessWidget {
  const HudTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DesktopProvider>().status;
    final short = s.width < s.height ? s.width : s.height;
    return Row(children: [
      const HudChip(text: 'LIVE', color: StudioColors.success, dotColor: Colors.red),
      const SizedBox(width: 8),
      HudChip(text: '${short}p • ${s.fps.toStringAsFixed(0)} FPS'),
      const SizedBox(width: 8),
      HudChip(text: s.codec == 'mjpeg' ? 'MJPEG' : 'H.264', color: StudioColors.accent),
      const Spacer(),
      HudChip(
        text: '${(s.kbps / 1000).toStringAsFixed(2)} Mbps',
        color: const Color(0xFFFCD34D),
        icon: Icons.speed,
      ),
    ]);
  }
}
