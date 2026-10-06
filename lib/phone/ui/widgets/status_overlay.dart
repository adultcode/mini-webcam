import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/status_pill.dart';
import '../../providers/phone_provider.dart';

/// Top card: streaming state, viewer count, throughput, addresses and errors.
class StatusOverlay extends StatelessWidget {
  const StatusOverlay({super.key});

  static const _small = TextStyle(fontSize: 12, color: Colors.white70);

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final viewers = phone.viewers;
    final (label, color) = switch ((phone.streaming, viewers)) {
      (false, _) => ('Not streaming', Colors.grey),
      (true, 0) => ('Waiting for PC', Colors.amber),
      _ => ('Live · $viewers ${viewers == 1 ? 'viewer' : 'viewers'}', Colors.greenAccent),
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                StatusPill(label: label, color: color),
                const Spacer(),
                if (phone.streaming && viewers > 0)
                  Text(
                    '${phone.fps.toStringAsFixed(0)} fps · '
                    '${(phone.kbps / 1000).toStringAsFixed(1)} Mbps',
                    style: _small,
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                phone.addresses.isEmpty
                    ? 'No network · use USB mode on the PC'
                    : 'Wi-Fi: ${phone.addresses.join(', ')}  ·  USB: plug in + enable USB debugging',
                style: _small,
              ),
              if (phone.error != null) ...[
                const SizedBox(height: 6),
                Text(phone.error!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
