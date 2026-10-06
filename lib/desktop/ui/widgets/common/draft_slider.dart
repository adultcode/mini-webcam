import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/studio_view_provider.dart';
import '../../theme/studio_theme.dart';

/// Labelled slider whose in-progress value lives in [StudioViewProvider], so
/// the phone only gets one request when the drag ends.
class DraftSlider extends StatelessWidget {
  const DraftSlider({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onCommit,
    this.icon,
    this.divisions,
    this.valueColor = StudioColors.textPrimary,
  });

  /// Unique key for the draft value.
  final String id;
  final String label;
  final IconData? icon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) format;
  final ValueChanged<double> onCommit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final draft = context.select<StudioViewProvider, double?>((v) => v.draft(id));
    final view = context.read<StudioViewProvider>();
    final shown = (draft ?? value).clamp(min, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: StudioColors.textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(label, style: StudioText.label)),
          Text(format(shown), style: StudioText.value.copyWith(color: valueColor)),
        ]),
        SizedBox(
          height: 28,
          child: Slider(
            value: shown,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => view.setDraft(id, v),
            onChangeEnd: (v) {
              onCommit(v);
              view.clearDraft(id);
            },
          ),
        ),
      ],
    );
  }
}
