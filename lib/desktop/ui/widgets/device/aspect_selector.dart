import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/pill_selector.dart';

/// Output aspect ratio (Original / 16:9 / 4:3 / 1:1) and Fit vs Fill.
class AspectSelector extends StatelessWidget {
  const AspectSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final reframing = c.aspect != OutputAspect.original;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Output Aspect', style: StudioText.caption),
      const SizedBox(height: 6),
      PillSelector<OutputAspect>(
        options: [for (final a in OutputAspect.values) PillOption(a, a.label)],
        selected: c.aspect,
        onChanged: (a) => c.setAspect(aspect: a),
      ),
      if (reframing) ...[
        const SizedBox(height: 8),
        PillSelector<bool>(
          options: const [
            PillOption(false, 'Fit', icon: Icons.fit_screen_outlined),
            PillOption(true, 'Fill', icon: Icons.crop),
          ],
          selected: c.aspectFill,
          onChanged: (fill) => c.setAspect(fill: fill),
        ),
        const SizedBox(height: 6),
        Text(
          c.aspectFill
              ? 'Crops the picture to fill ${c.aspect.label}.'
              : 'Shows the whole picture with black bars.',
          style: StudioText.caption,
        ),
      ],
    ]);
  }
}
