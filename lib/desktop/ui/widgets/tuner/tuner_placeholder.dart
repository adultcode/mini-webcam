import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';
import '../common/studio_card.dart';

/// Shown in the right column until a phone is connected.
class TunerPlaceholder extends StatelessWidget {
  const TunerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudioCard(
      icon: Icons.camera_outlined,
      title: 'Camera Controls',
      children: [
        Text(
          'Connect a phone to change its camera, resolution, bitrate, zoom, exposure and focus from here.',
          style: StudioText.caption,
        ),
      ],
    );
  }
}
