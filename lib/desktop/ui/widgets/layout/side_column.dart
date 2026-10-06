import 'package:flutter/material.dart';

/// Scrollable column of cards with consistent spacing.
class SideColumn extends StatelessWidget {
  const SideColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}
