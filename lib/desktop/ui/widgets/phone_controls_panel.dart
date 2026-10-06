import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/camera_models.dart';
import '../../providers/desktop_provider.dart';
import 'live_slider.dart';

/// Remote controls for the phone camera, sent over the phone's control API.
class PhoneControlsPanel extends StatelessWidget {
  const PhoneControlsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final phone = c.phone;
    if (phone == null) return const SizedBox.shrink();
    final st = phone.settings;
    final f = phone.features;
    final resolutions =
        f.resolutions.contains(st.resolution) ? f.resolutions : [...f.resolutions, st.resolution];

    return Card(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('Phone camera', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(children: [
            if (f.cameras.length > 1)
              IconButton.filledTonal(
                tooltip: 'Switch camera',
                onPressed: () =>
                    c.updatePhone({'camera': st.camera == 'back' ? 'front' : 'back'}),
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
            const SizedBox(width: 8),
            if (f.hasFlash)
              IconButton.filledTonal(
                tooltip: 'Torch',
                isSelected: st.torch,
                onPressed: () => c.updatePhone({'torch': !st.torch}),
                icon: Icon(st.torch ? Icons.flashlight_on : Icons.flashlight_off_outlined),
              ),
            const SizedBox(width: 8),
            Text(st.camera == 'back' ? 'Back camera' : 'Front camera'),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('res-${st.resolution}'),
            initialValue: st.resolution,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Resolution', isDense: true),
            items: [
              for (final r in resolutions)
                DropdownMenuItem(value: r, child: Text(resolutionLabel(r))),
            ],
            onChanged: (v) => c.updatePhone({'resolution': v}),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('fps-${st.fps}'),
                initialValue: f.fps.contains(st.fps) ? st.fps : null,
                isDense: true,
                decoration: const InputDecoration(labelText: 'FPS', isDense: true),
                items: [for (final v in f.fps) DropdownMenuItem(value: v, child: Text('$v'))],
                onChanged: (v) => c.updatePhone({'fps': v}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('codec-${st.codec}'),
                initialValue: st.codec,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Codec', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'h264', child: Text('H.264')),
                  DropdownMenuItem(value: 'mjpeg', child: Text('MJPEG')),
                ],
                onChanged: (v) => c.updatePhone({'codec': v}),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (st.codec == 'h264')
            DropdownButtonFormField<int>(
              key: ValueKey('br-${st.bitrate}'),
              initialValue: bitrateOptions.contains(st.bitrate) ? st.bitrate : null,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Bitrate', isDense: true),
              items: [
                for (final b in bitrateOptions)
                  DropdownMenuItem(value: b, child: Text(formatBitrate(b))),
              ],
              onChanged: (v) => c.updatePhone({'bitrate': v}),
            ),
          if (f.zoomMax > f.zoomMin) ...[
            const SizedBox(height: 8),
            Text('Zoom ${st.zoom.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12)),
            LiveSlider(
              value: st.zoom.clamp(f.zoomMin, f.zoomMax),
              min: f.zoomMin,
              max: f.zoomMax,
              onChanged: (v) => c.updatePhone({'zoom': v}),
            ),
          ],
          if (f.exposureMax > f.exposureMin) ...[
            Text('Exposure ${(st.exposure * f.exposureStep).toStringAsFixed(1)} EV',
                style: const TextStyle(fontSize: 12)),
            LiveSlider(
              value: st.exposure
                  .toDouble()
                  .clamp(f.exposureMin.toDouble(), f.exposureMax.toDouble()),
              min: f.exposureMin.toDouble(),
              max: f.exposureMax.toDouble(),
              divisions: f.exposureMax - f.exposureMin,
              onChanged: (v) => c.updatePhone({'exposure': v.round()}),
            ),
          ],
          if (f.manualFocus) ...[
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Manual focus'),
              value: st.focusMode == 'manual',
              onChanged: (v) => c.updatePhone({'focusMode': v ? 'manual' : 'auto'}),
            ),
            if (st.focusMode == 'manual')
              LiveSlider(
                value: st.focusDistance,
                min: 0,
                max: 1,
                onChanged: (v) => c.updatePhone({'focusDistance': v}),
              ),
          ],
        ],
      ),
    );
  }
}
