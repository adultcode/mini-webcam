import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Upper-case caption with a monospace value below.
class TelemetryItem extends StatelessWidget {
  const TelemetryItem({
    super.key,
    required this.label,
    required this.value,
    this.color = const Color(0xFFE2E8F0),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10, letterSpacing: 0.8, color: StudioColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: StudioText.mono, fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
