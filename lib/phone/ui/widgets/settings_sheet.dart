import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/camera_models.dart';
import '../../../core/protocol.dart';
import '../../providers/blackout_provider.dart';
import '../../providers/phone_provider.dart';

/// Stream and image settings, shown as a draggable bottom sheet.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, scroll) => SettingsSheet(scrollController: scroll),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final blackout = context.watch<BlackoutProvider>();
    final s = phone.settings;
    final f = phone.features;
    final theme = Theme.of(context);
    final resolutions =
        f.resolutions.contains(s.resolution) ? f.resolutions : [...f.resolutions, s.resolution];
    final fpsOptions = f.fps.contains(s.fps) ? f.fps : ([...f.fps, s.fps]..sort());

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('Stream', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('res-${s.resolution}'),
          initialValue: s.resolution,
          decoration: const InputDecoration(labelText: 'Resolution'),
          items: [
            for (final r in resolutions) DropdownMenuItem(value: r, child: Text(resolutionLabel(r))),
          ],
          onChanged: (v) => phone.applyChanges({'resolution': v}),
        ),
        const SizedBox(height: 16),
        const Text('Frame rate'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [for (final v in fpsOptions) ButtonSegment(value: v, label: Text('$v'))],
          selected: {s.fps},
          onSelectionChanged: (v) => phone.applyChanges({'fps': v.first}),
        ),
        const SizedBox(height: 16),
        const Text('Codec'),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'h264', label: Text('H.264'), icon: Icon(Icons.bolt_outlined)),
            ButtonSegment(value: 'mjpeg', label: Text('MJPEG'), icon: Icon(Icons.public)),
          ],
          selected: {s.codec},
          onSelectionChanged: (v) => phone.applyChanges({'codec': v.first}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            s.codec == 'h264'
                ? 'Hardware encoder. Lowest bandwidth and latency. Recommended for the PC app.'
                : 'Works in any browser/OBS at http://<phone-ip>:${FcamPorts.mjpegPort}/video. '
                    'Uses more bandwidth and CPU.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        if (s.codec == 'h264')
          DropdownButtonFormField<int>(
            key: ValueKey('br-${s.bitrate}'),
            initialValue: bitrateOptions.contains(s.bitrate) ? s.bitrate : null,
            decoration: const InputDecoration(labelText: 'Bitrate'),
            items: [
              for (final b in bitrateOptions) DropdownMenuItem(value: b, child: Text(formatBitrate(b))),
            ],
            onChanged: (v) => phone.applyChanges({'bitrate': v}),
          )
        else ...[
          Text('JPEG quality: ${s.jpegQuality}'),
          Slider(
            value: s.jpegQuality.toDouble(),
            min: 30,
            max: 95,
            divisions: 13,
            label: '${s.jpegQuality}',
            onChanged: (v) => phone.applyChanges({'jpegQuality': v.round()}),
          ),
        ],
        const Divider(height: 32),
        Text('Image', style: theme.textTheme.titleMedium),
        if (f.manualFocus) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manual focus'),
            subtitle: const Text('Tap the preview for one-shot autofocus'),
            value: s.focusMode == 'manual',
            onChanged: (v) => phone.applyChanges({'focusMode': v ? 'manual' : 'auto'}),
          ),
          if (s.focusMode == 'manual')
            Row(children: [
              const Icon(Icons.landscape_outlined, size: 18),
              Expanded(
                child: Slider(
                  value: s.focusDistance,
                  onChanged: (v) => phone.applyChanges({'focusDistance': v}),
                ),
              ),
              const Icon(Icons.local_florist_outlined, size: 18),
            ]),
        ],
        if (f.exposureMax > f.exposureMin) ...[
          const SizedBox(height: 8),
          Text('Exposure: ${(s.exposure * f.exposureStep).toStringAsFixed(1)} EV'),
          Slider(
            value: s.exposure.toDouble().clamp(f.exposureMin.toDouble(), f.exposureMax.toDouble()),
            min: f.exposureMin.toDouble(),
            max: f.exposureMax.toDouble(),
            divisions: f.exposureMax - f.exposureMin,
            onChanged: (v) => phone.applyChanges({'exposure': v.round()}),
          ),
        ],
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto screen-off while streaming'),
          subtitle: const Text('Blacks the screen after 30 s to save battery'),
          value: blackout.auto,
          onChanged: blackout.setAuto,
        ),
      ],
    );
  }
}
