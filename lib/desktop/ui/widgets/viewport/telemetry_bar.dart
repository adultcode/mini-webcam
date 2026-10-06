import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import 'telemetry_item.dart';

/// Stream statistics under the viewport.
class TelemetryBar extends StatelessWidget {
  const TelemetryBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DesktopProvider>().status;
    final items = [
      TelemetryItem(label: 'Active Target', value: s.device.isEmpty ? '—' : s.device),
      TelemetryItem(
          label: 'Codec',
          value: s.codec.isEmpty ? '—' : (s.codec == 'mjpeg' ? 'MJPEG (WIC)' : 'H.264 (MF)'),
          color: StudioColors.accent),
      TelemetryItem(label: 'Resolution', value: s.width > 0 ? '${s.width} × ${s.height}' : '—'),
      TelemetryItem(
          label: 'Delivery FPS', value: '${s.fps.toStringAsFixed(1)} fps', color: StudioColors.success),
      TelemetryItem(
          label: 'Throughput',
          value: '${(s.kbps / 1000).toStringAsFixed(2)} Mbps',
          color: StudioColors.warning),
      TelemetryItem(label: 'Decode Time', value: '${s.decodeMs.toStringAsFixed(1)} ms'),
      if (s.decodeErrors > 0)
        TelemetryItem(label: 'Decode Errors', value: '${s.decodeErrors}', color: StudioColors.danger),
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: StudioColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioColors.border),
      ),
      child: Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(width: 1, height: 24, color: StudioColors.divider),
          Expanded(child: Center(child: items[i])),
        ],
      ]),
    );
  }
}
