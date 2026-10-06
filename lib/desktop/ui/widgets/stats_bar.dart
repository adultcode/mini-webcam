import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';

/// Live stream statistics under the preview.
class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DesktopProvider>().status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Stat('Device', s.device.isEmpty ? '—' : s.device),
            _Stat('Codec', s.codec.isEmpty ? '—' : s.codec.toUpperCase()),
            _Stat('Resolution', s.width > 0 ? '${s.width}×${s.height}' : '—'),
            _Stat('FPS', s.fps.toStringAsFixed(1)),
            _Stat('Bitrate', '${(s.kbps / 1000).toStringAsFixed(2)} Mbps'),
            _Stat('Decode', '${s.decodeMs.toStringAsFixed(1)} ms'),
            if (s.decodeErrors > 0) _Stat('Decode errors', '${s.decodeErrors}'),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
