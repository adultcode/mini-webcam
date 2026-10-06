import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';

/// "PC SYNC" when a computer is receiving the stream, otherwise "NO PC".
class PcSyncChip extends StatelessWidget {
  const PcSyncChip({super.key});

  @override
  Widget build(BuildContext context) {
    final viewers = context.select<PhoneProvider, int>((p) => p.viewers);
    final synced = viewers > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: synced ? OledColors.emeraldLight : Colors.white38,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          synced ? (viewers > 1 ? 'PC SYNC · $viewers' : 'PC SYNC') : 'NO PC',
          style: OledText.chip.copyWith(color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.6),
        ),
      ]),
    );
  }
}
