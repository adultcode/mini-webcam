import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Rounded panel with an icon + title header, used for every studio section.
class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioColors.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: StudioColors.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: StudioText.title)),
            ?trailing,
          ]),
          const SizedBox(height: 12),
          ..._spaced(children),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          items[i],
        ],
      ];
}
