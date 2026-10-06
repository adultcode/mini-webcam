import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Quick bitrate buttons under the bitrate slider.
class BitratePresets extends StatelessWidget {
  const BitratePresets({super.key, required this.current, required this.onSelected});

  static const presets = [4000000, 6000000, 12000000, 20000000];

  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < presets.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(child: _Preset(bps: presets[i], selected: presets[i] == current, onTap: onSelected)),
      ],
    ]);
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.bps, required this.selected, required this.onTap});

  final int bps;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xCC083344) : StudioColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? const Color(0x990E7490) : StudioColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onTap(bps),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Center(
            child: Text('${bps ~/ 1000000}M',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? const Color(0xFF67E8F9) : StudioColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}
