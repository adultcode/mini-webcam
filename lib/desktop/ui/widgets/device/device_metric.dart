import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Icon + monospace value in the device card metrics row.
class DeviceMetric extends StatelessWidget {
  const DeviceMetric({super.key, required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: StudioText.mono, fontSize: 11, color: StudioColors.textSecondary)),
      ),
    ]);
  }
}
