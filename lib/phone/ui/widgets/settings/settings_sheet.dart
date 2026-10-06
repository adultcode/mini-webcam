import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/camera_models.dart';
import '../../../../core/protocol.dart';
import '../../../providers/blackout_provider.dart';
import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';
import 'settings_section.dart';

/// Stream, image and power settings in a draggable bottom sheet.
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

  static const _caption = TextStyle(fontSize: 12, color: OledColors.dimText);

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final blackout = context.watch<BlackoutProvider>();
    final s = phone.settings;
    final f = phone.features;
    final resolutions = {...f.resolutions, s.resolution}.toList();
    final fps = ({...f.fps, s.fps}.toList()..sort());

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SettingsSection(icon: Icons.movie_outlined, title: 'Stream', children: [
          DropdownButtonFormField<String>(
            key: ValueKey('res-${s.resolution}'),
            initialValue: s.resolution,
            dropdownColor: OledColors.sheet,
            decoration: const InputDecoration(labelText: 'Resolution', border: OutlineInputBorder()),
            items: [for (final r in resolutions) DropdownMenuItem(value: r, child: Text(resolutionLabel(r)))],
            onChanged: (v) => phone.applyChanges({'resolution': v}),
          ),
          const SizedBox(height: 14),
          const Text('Frame rate', style: _caption),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: [for (final v in fps) ButtonSegment(value: v, label: Text('$v'))],
            selected: {s.fps},
            onSelectionChanged: (v) => phone.applyChanges({'fps': v.first}),
          ),
          const SizedBox(height: 14),
          const Text('Codec', style: _caption),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'h264', label: Text('H.264'), icon: Icon(Icons.bolt_outlined)),
              ButtonSegment(value: 'mjpeg', label: Text('MJPEG'), icon: Icon(Icons.public)),
            ],
            selected: {s.codec},
            onSelectionChanged: (v) => phone.applyChanges({'codec': v.first}),
          ),
          const SizedBox(height: 6),
          Text(
            s.codec == 'h264'
                ? 'Hardware encoder. Lowest bandwidth and latency. Best for the PC app.'
                : 'Works in a browser or OBS at http://<phone-ip>:${FcamPorts.mjpegPort}/video. Uses more bandwidth.',
            style: _caption,
          ),
          const SizedBox(height: 10),
          if (s.codec == 'h264') ...[
            Text('Bitrate: ${formatBitrate(s.bitrate)}', style: OledText.label),
            Slider(
              value: (s.bitrate / 1000000).clamp(1, 20).toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: formatBitrate(s.bitrate),
              onChanged: (v) => phone.applyChanges({'bitrate': v.round() * 1000000}),
            ),
          ] else ...[
            Text('JPEG quality: ${s.jpegQuality}', style: OledText.label),
            Slider(
              value: s.jpegQuality.toDouble(),
              min: 30,
              max: 95,
              divisions: 13,
              label: '${s.jpegQuality}',
              onChanged: (v) => phone.applyChanges({'jpegQuality': v.round()}),
            ),
          ],
        ]),
        SettingsSection(icon: Icons.wb_sunny_outlined, title: 'Image', children: [
          if (f.exposureMax > f.exposureMin) ...[
            Text('Exposure: ${(s.exposure * f.exposureStep).toStringAsFixed(1)} EV', style: OledText.label),
            Slider(
              value: s.exposure.toDouble().clamp(f.exposureMin.toDouble(), f.exposureMax.toDouble()),
              min: f.exposureMin.toDouble(),
              max: f.exposureMax.toDouble(),
              divisions: f.exposureMax - f.exposureMin,
              onChanged: (v) => phone.applyChanges({'exposure': v.round()}),
            ),
          ],
          if (f.manualFocus) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Manual focus', style: OledText.label),
              subtitle: const Text('Tap the preview for one-shot autofocus', style: _caption),
              value: s.focusMode == 'manual',
              onChanged: (v) => phone.applyChanges({'focusMode': v ? 'manual' : 'auto'}),
            ),
            if (s.focusMode == 'manual')
              Row(children: [
                const Icon(Icons.landscape_outlined, size: 18, color: OledColors.dimText),
                Expanded(
                  child: Slider(
                    value: s.focusDistance,
                    onChanged: (v) => phone.applyChanges({'focusDistance': v}),
                  ),
                ),
                const Icon(Icons.local_florist_outlined, size: 18, color: OledColors.dimText),
              ]),
          ] else
            const Text('Autofocus only on this camera. Tap the preview to focus.', style: _caption),
        ]),
        SettingsSection(icon: Icons.battery_saver_outlined, title: 'Power', children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto OLED Sleep while streaming', style: OledText.label),
            subtitle: const Text('Blacks the screen after 30 s to save battery and heat', style: _caption),
            value: blackout.auto,
            onChanged: blackout.setAuto,
          ),
        ]),
      ],
    );
  }
}
