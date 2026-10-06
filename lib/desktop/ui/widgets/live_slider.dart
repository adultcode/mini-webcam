import 'package:flutter/material.dart';

/// Slider that only reports the value when the drag ends, so dragging doesn't
/// flood the phone with HTTP requests.
class LiveSlider extends StatefulWidget {
  const LiveSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  State<LiveSlider> createState() => _LiveSliderState();
}

class _LiveSliderState extends State<LiveSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: (_dragging ?? widget.value).clamp(widget.min, widget.max),
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      onChanged: (v) => setState(() => _dragging = v),
      onChangeEnd: (v) {
        widget.onChanged(v);
        setState(() => _dragging = null);
      },
    );
  }
}
