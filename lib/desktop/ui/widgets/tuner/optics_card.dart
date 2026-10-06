import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/draft_slider.dart';
import '../common/pill_selector.dart';
import '../common/studio_card.dart';

/// Zoom, exposure and focus of the phone camera.
class OpticsCard extends StatelessWidget {
  const OpticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.phone!.settings;
    final f = c.phone!.features;

    return StudioCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Optics & Sensors',
      trailing: TextButton(
        onPressed: c.resetOptics,
        style: TextButton.styleFrom(
          foregroundColor: StudioColors.textSecondary,
          textStyle: const TextStyle(fontSize: 11),
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Reset'),
      ),
      children: [
        if (f.zoomMax > f.zoomMin)
          DraftSlider(
            id: 'zoom',
            label: 'Zoom',
            icon: Icons.zoom_in,
            value: s.zoom,
            min: f.zoomMin,
            max: f.zoomMax,
            format: (v) => '${v.toStringAsFixed(1)}×',
            onCommit: (v) => c.updatePhone({'zoom': v}),
          ),
        if (f.exposureMax > f.exposureMin)
          DraftSlider(
            id: 'exposure',
            label: 'Exposure (EV)',
            icon: Icons.exposure,
            value: s.exposure.toDouble(),
            min: f.exposureMin.toDouble(),
            max: f.exposureMax.toDouble(),
            divisions: f.exposureMax - f.exposureMin,
            valueColor: StudioColors.accent,
            format: (v) {
              final ev = v.round() * f.exposureStep;
              return '${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)} EV';
            },
            onCommit: (v) => c.updatePhone({'exposure': v.round()}),
          ),
        const Divider(height: 1),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Focus Mode', style: StudioText.label),
          const SizedBox(height: 6),
          PillSelector<String>(
            options: const [
              PillOption('auto', 'Continuous'),
              PillOption('manual', 'Manual'),
            ],
            selected: s.focusMode,
            onChanged: f.manualFocus ? (v) => c.updatePhone({'focusMode': v}) : null,
          ),
          if (!f.manualFocus)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('This camera only supports autofocus.', style: StudioText.caption),
            ),
        ]),
        if (f.manualFocus && s.focusMode == 'manual')
          DraftSlider(
            id: 'focus',
            label: 'Focus Distance',
            icon: Icons.center_focus_strong_outlined,
            value: s.focusDistance,
            min: 0,
            max: 1,
            format: (v) => v < 0.02 ? 'Far' : (v > 0.98 ? 'Near' : '${(v * 100).round()}%'),
            onCommit: (v) => c.updatePhone({'focusDistance': v}),
          ),
      ],
    );
  }
}
