import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/camera_models.dart';
import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/draft_slider.dart';
import '../common/studio_card.dart';
import '../common/studio_dropdown.dart';
import 'bitrate_presets.dart';

/// Resolution, frame rate, codec and bitrate / JPEG quality of the phone stream.
class EncodingCard extends StatelessWidget {
  const EncodingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.phone!.settings;
    final f = c.phone!.features;
    final resolutions = {...f.resolutions, s.resolution};
    final fps = {...f.fps, s.fps}.toList()..sort();

    return StudioCard(
      icon: Icons.movie_outlined,
      title: 'Stream Encoding',
      children: [
        StudioDropdown<String>(
          label: 'Output Resolution',
          hint: _aspect(s.resolution),
          value: s.resolution,
          items: {for (final r in resolutions) r: resolutionLabel(r)},
          onChanged: (v) => c.updatePhone({'resolution': v}),
        ),
        Row(children: [
          Expanded(
            child: StudioDropdown<int>(
              label: 'Framerate',
              value: s.fps,
              items: {for (final v in fps) v: '$v FPS'},
              onChanged: (v) => c.updatePhone({'fps': v}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StudioDropdown<String>(
              label: 'Codec',
              value: s.codec,
              items: const {'h264': 'H.264 (AVC)', 'mjpeg': 'MJPEG'},
              onChanged: (v) => c.updatePhone({'codec': v}),
            ),
          ),
        ]),
        if (s.codec == 'h264') ...[
          DraftSlider(
            id: 'bitrate',
            label: 'Target Bitrate',
            value: s.bitrate / 1000000,
            min: 1,
            max: 20,
            divisions: 19,
            valueColor: StudioColors.accent,
            format: (v) => '${v.toStringAsFixed(1)} Mbps',
            onCommit: (v) => c.updatePhone({'bitrate': (v.round() * 1000000)}),
          ),
          BitratePresets(
            current: s.bitrate,
            onSelected: (bps) => c.updatePhone({'bitrate': bps}),
          ),
        ] else
          DraftSlider(
            id: 'jpegQuality',
            label: 'JPEG Quality',
            value: s.jpegQuality.toDouble(),
            min: 30,
            max: 95,
            divisions: 13,
            valueColor: StudioColors.accent,
            format: (v) => '${v.round()}',
            onCommit: (v) => c.updatePhone({'jpegQuality': v.round()}),
          ),
      ],
    );
  }

  static String _aspect(String resolution) {
    final parts = resolution.split('x');
    final w = int.tryParse(parts.first) ?? 0;
    final h = int.tryParse(parts.last) ?? 0;
    if (w == 0 || h == 0) return '';
    final ratio = w / h;
    if ((ratio - 16 / 9).abs() < 0.02) return '16:9';
    if ((ratio - 4 / 3).abs() < 0.02) return '4:3';
    return ratio.toStringAsFixed(2);
  }
}
