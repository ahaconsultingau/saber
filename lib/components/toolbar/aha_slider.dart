import 'package:material_ui/material_ui.dart';

/// Aha! copy: a small labelled slider for the toolbar's option rows (the
/// eraser's size, the brush's feathering). Turns upright when the toolbar
/// is on the side.
class AhaToolSlider extends StatelessWidget {
  const new({
    super.key,
    required this.axis,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabel,
  });

  final Axis axis;
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  /// Shown beside the label, e.g. "40%".
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: .min,
        children: [
          Text(
            valueLabel == null ? label : '$label $valueLabel',
            style: TextTheme.of(context).labelMedium,
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
    return axis == Axis.vertical
        ? RotatedBox(quarterTurns: 3, child: row)
        : row;
  }
}
