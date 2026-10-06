import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/pill_selector.dart';
import '../common/studio_card.dart';
import '../common/toggle_row.dart';

/// Phone camera selection and torch.
class LensCard extends StatelessWidget {
  const LensCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final phone = c.phone!;
    final s = phone.settings;
    final f = phone.features;
    final zoomRange = f.zoomMax > f.zoomMin
        ? '${f.zoomMin.toStringAsFixed(1)}–${f.zoomMax.toStringAsFixed(1)}×'
        : 'Fixed';

    return StudioCard(
      icon: Icons.camera_outlined,
      title: 'Lens',
      trailing: Text(zoomRange,
          style: const TextStyle(fontFamily: StudioText.mono, fontSize: 11, color: StudioColors.accent)),
      children: [
        PillSelector<String>(
          options: [
            if (f.cameras.contains('back'))
              const PillOption('back', 'Back Camera', icon: Icons.photo_camera_outlined),
            if (f.cameras.contains('front'))
              const PillOption('front', 'Front Selfie', icon: Icons.person_outline),
          ],
          selected: s.camera,
          onChanged: f.cameras.length > 1 ? (v) => c.updatePhone({'camera': v}) : null,
        ),
        if (f.hasFlash)
          ToggleRow(
            title: 'Torch',
            subtitle: 'Phone flashlight as a fill light',
            value: s.torch,
            onChanged: (v) => c.updatePhone({'torch': v}),
          ),
      ],
    );
  }
}
