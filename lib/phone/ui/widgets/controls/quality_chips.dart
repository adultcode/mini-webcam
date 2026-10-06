import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../common/glass_chip.dart';

/// One-tap stream quality: the standard resolutions this camera supports.
class QualityChips extends StatelessWidget {
  const QualityChips({super.key});

  static const _labels = {360: '360p', 480: '480p', 540: '540p', 720: '720p', 1080: '1080p', 1440: '1440p', 2160: '4K'};

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final current = phone.settings.resolution;
    // Prefer the common 16:9 sizes; fall back to whatever the camera offers.
    final options = phone.features.resolutions
        .where((r) => const ['1280x720', '1920x1080', '3840x2160'].contains(r))
        .toList();
    final shown = options.isNotEmpty ? options : phone.features.resolutions.take(3).toList();
    if (shown.length < 2) return const SizedBox.shrink();

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        GlassChip(
          text: _label(shown[i]),
          dotColor: shown[i] == current ? const Color(0xFF60CDFF) : null,
          selected: shown[i] == current,
          onTap: () => phone.applyChanges({'resolution': shown[i]}),
        ),
      ],
    ]);
  }

  static String _label(String res) {
    final h = int.tryParse(res.split('x').last) ?? 0;
    return _labels[h] ?? res;
  }
}
