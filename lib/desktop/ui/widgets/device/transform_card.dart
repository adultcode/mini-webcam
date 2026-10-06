import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/inset_panel.dart';
import '../common/pill_selector.dart';
import '../common/studio_card.dart';
import '../common/toggle_row.dart';
import 'aspect_selector.dart';

/// Rotation, mirror and preview options applied on the PC, plus decoder state.
class TransformCard extends StatelessWidget {
  const TransformCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final decoding = c.status.isStreaming;
    final decoder = c.status.codec == 'mjpeg' ? 'WIC JPEG decoder' : 'Media Foundation H.264';

    return StudioCard(
      icon: Icons.tune,
      title: 'Orientation & Transform',
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Stream Rotation', style: StudioText.caption),
          const SizedBox(height: 6),
          PillSelector<int>(
            options: const [
              PillOption(0, '0°'),
              PillOption(90, '90°'),
              PillOption(180, '180°'),
              PillOption(270, '270°'),
            ],
            selected: c.rotation,
            onChanged: (v) => c.setTransform(rotation: v),
          ),
        ]),
        const AspectSelector(),
        ToggleRow(
          title: 'Mirror Video Feed',
          subtitle: 'Flip horizontally, applied to the virtual camera too',
          value: c.mirror,
          onChanged: (v) => c.setTransform(mirror: v),
        ),
        ToggleRow(
          title: 'Live Preview',
          subtitle: 'Turn off to save CPU',
          value: c.preview,
          onChanged: c.setPreview,
        ),
        InsetPanel(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            const Icon(Icons.memory, size: 14, color: StudioColors.accent),
            const SizedBox(width: 6),
            Expanded(child: Text(decoder, style: StudioText.caption)),
            Text(decoding ? 'Active' : 'Idle',
                style: TextStyle(
                    fontFamily: StudioText.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: decoding ? StudioColors.success : StudioColors.textMuted)),
          ]),
        ),
      ],
    );
  }
}
