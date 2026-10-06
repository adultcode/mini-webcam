import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';
import '../common/glass_container.dart';

/// Phone address (to type on the PC) and live throughput.
class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final address = phone.addresses.isEmpty ? 'USB only' : phone.addresses.first;
    final sending = phone.streaming && phone.viewers > 0;

    return GlassContainer(
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: OledColors.cyan,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: OledColors.cyan.withValues(alpha: 0.8), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // The PC needs this address for Wi-Fi; resolution is shown by the quality chips.
          child: Text(address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: OledText.mono, fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: sending ? const Color(0x99022C22) : Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sending ? OledColors.emerald.withValues(alpha: 0.3) : Colors.white12),
          ),
          child: Text(
            sending ? '${(phone.kbps / 1000).toStringAsFixed(1)} Mb/s' : 'Idle',
            style: OledText.chip.copyWith(color: sending ? OledColors.emeraldLight : Colors.white54),
          ),
        ),
      ]),
    );
  }
}
