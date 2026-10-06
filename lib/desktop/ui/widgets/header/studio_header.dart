import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';
import 'link_status_pill.dart';

/// Top bar: logo and name on the left, link status in the middle.
class StudioHeader extends StatelessWidget {
  const StudioHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: StudioColors.surface.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/logo.png', height: 24),
            const SizedBox(width: 10),
            const Text('Mini Webcam',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0))),
          ]),
        ),
        const LinkStatusPill(),
      ]),
    );
  }
}
