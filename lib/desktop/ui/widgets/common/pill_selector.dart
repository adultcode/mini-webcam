import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';

class PillOption<T> {
  const PillOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control: equal-width options in a recessed track, the selected
/// one filled with the accent colour.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StudioColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioColors.border),
      ),
      child: Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _Pill(option: options[i], selected: options[i].value == selected, onTap: onChanged)),
        ],
      ]),
    );
  }
}

class _Pill<T> extends StatelessWidget {
  const _Pill({required this.option, required this.selected, required this.onTap});

  final PillOption<T> option;
  final bool selected;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF020617) : StudioColors.textSecondary;
    return Material(
      color: selected ? StudioColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap == null ? null : () => onTap!(option.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(option.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}
