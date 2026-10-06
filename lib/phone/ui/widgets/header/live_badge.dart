import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';

/// LIVE while streaming, OFF otherwise.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final live = context.select<PhoneProvider, bool>((p) => p.streaming);
    final color = live ? OledColors.emeraldLight : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: live ? OledColors.emerald.withValues(alpha: 0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: live ? OledColors.emerald.withValues(alpha: 0.5) : Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(live ? 'LIVE' : 'OFF',
            style: OledText.chip.copyWith(color: color, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ]),
    );
  }
}
