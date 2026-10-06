import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../common/glass_chip.dart';

/// Right-aligned micro telemetry: codec, delivered fps and viewers.
class StreamChips extends StatelessWidget {
  const StreamChips({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    if (!phone.streaming) return const SizedBox.shrink();
    final s = phone.settings;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GlassChip(
        keyText: 'CODEC',
        text: s.codec == 'h264' ? 'H.264 ${(s.bitrate / 1000000).toStringAsFixed(0)}M' : 'MJPEG Q${s.jpegQuality}',
      ),
      const SizedBox(height: 6),
      GlassChip(keyText: 'FPS', text: phone.viewers > 0 ? phone.fps.toStringAsFixed(0) : '—'),
      const SizedBox(height: 6),
      GlassChip(keyText: 'VIEWERS', text: '${phone.viewers}'),
    ]);
  }
}
