import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';
import '../common/glass_container.dart';

/// Lens stops (ultra-wide / 1× / tele, when supported), zoom slider and readout.
class ZoomPill extends StatelessWidget {
  const ZoomPill({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final f = phone.features;
    if (f.zoomMax <= f.zoomMin) return const SizedBox.shrink();
    final zoom = phone.settings.zoom.clamp(f.zoomMin, f.zoomMax);
    final stops = <double>{
      if (f.zoomMin < 0.95) double.parse(f.zoomMin.toStringAsFixed(1)),
      1.0,
      if (f.zoomMax >= 2) 2.0,
      if (f.zoomMax >= 5) 5.0,
    }.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassContainer(
        padding: const EdgeInsets.fromLTRB(10, 4, 14, 4),
        child: Row(children: [
          for (final stop in stops)
            _ZoomStop(
              value: stop,
              selected: (zoom - stop).abs() < 0.05,
              onTap: () => phone.applyChanges({'zoom': stop}),
            ),
          Expanded(
            child: Slider(
              value: zoom,
              min: f.zoomMin,
              max: f.zoomMax,
              onChanged: (v) => phone.applyChanges({'zoom': v}),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text('${zoom.toStringAsFixed(1)}x',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: OledText.mono, fontSize: 12, fontWeight: FontWeight.w600, color: OledColors.cyan)),
          ),
        ]),
      ),
    );
  }
}

class _ZoomStop extends StatelessWidget {
  const _ZoomStop({required this.value, required this.selected, required this.onTap});

  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = value < 1 ? value.toStringAsFixed(1).substring(1) : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? OledColors.cyan.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(color: selected ? OledColors.cyan.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? OledColors.cyan : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }
}
