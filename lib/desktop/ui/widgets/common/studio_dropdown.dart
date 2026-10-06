import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

/// Labelled dropdown. Rebuilds from [value] whenever the phone reports a change.
class StudioDropdown<T> extends StatelessWidget {
  const StudioDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: StudioText.label)),
          if (hint != null)
            Text(hint!,
                style: const TextStyle(
                    fontFamily: StudioText.mono, fontSize: 11, color: StudioColors.accent)),
        ]),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: items.containsKey(value) ? value : null,
          isDense: true,
          isExpanded: true,
          dropdownColor: StudioColors.surface,
          style: StudioText.body,
          iconSize: 18,
          items: [
            for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: onChanged == null ? null : (v) => v == null ? null : onChanged!(v),
        ),
      ],
    );
  }
}
