import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Title + description on the left, switch on the right.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0))),
          const SizedBox(height: 2),
          Text(subtitle, style: StudioText.caption),
        ]),
      ),
      Transform.scale(scale: 0.8, child: Switch(value: value, onChanged: onChanged)),
    ]);
  }
}
