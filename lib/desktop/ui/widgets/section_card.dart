import 'package:flutter/material.dart';

/// Card with a title row (and optional trailing widget) used in the side panel.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
