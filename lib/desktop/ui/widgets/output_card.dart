import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';
import 'section_card.dart';

/// Rotation, mirror and preview toggles applied on the PC.
class OutputCard extends StatelessWidget {
  const OutputCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    return SectionCard(
      title: 'Output',
      children: [
        const Text('Rotation', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('0°')),
            ButtonSegment(value: 90, label: Text('90°')),
            ButtonSegment(value: 180, label: Text('180°')),
            ButtonSegment(value: 270, label: Text('270°')),
          ],
          selected: {c.rotation},
          onSelectionChanged: (v) => c.setTransform(rotation: v.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Mirror'),
          value: c.mirror,
          onChanged: (v) => c.setTransform(mirror: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Show preview'),
          subtitle: const Text('Turn off to save CPU'),
          value: c.preview,
          onChanged: c.setPreview,
        ),
      ],
    );
  }
}
