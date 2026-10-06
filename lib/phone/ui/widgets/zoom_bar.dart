import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/phone_provider.dart';

/// Zoom slider shown above the control bar when the camera can zoom.
class ZoomBar extends StatelessWidget {
  const ZoomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final f = phone.features;
    if (f.zoomMax <= f.zoomMin) return const SizedBox.shrink();
    final zoom = phone.settings.zoom.clamp(f.zoomMin, f.zoomMax);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        const Icon(Icons.zoom_in, size: 18, color: Colors.white70),
        Expanded(
          child: Slider(
            value: zoom,
            min: f.zoomMin,
            max: f.zoomMax,
            label: '${zoom.toStringAsFixed(1)}x',
            onChanged: (v) => phone.applyChanges({'zoom': v}),
          ),
        ),
        Text('${zoom.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
