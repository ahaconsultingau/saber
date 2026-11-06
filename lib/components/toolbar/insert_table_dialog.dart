import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/tools/table_lines.dart';
import 'package:saber/i18n/strings.g.dart';

/// Asks how many rows and columns the new table should have.
/// Pops with `(rows, columns)`, or null if cancelled.
class InsertTableDialog extends StatefulWidget {
  const new({super.key});

  static Future<(int, int)?> show(BuildContext context) =>
      showDialog<(int, int)>(
        context: context,
        builder: (context) => const InsertTableDialog(),
      );

  @override
  State<InsertTableDialog> createState() => _InsertTableDialogState();
}

class _InsertTableDialogState extends State<InsertTableDialog> {
  var rows = 3;
  var columns = 3;

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: Text(t.editor.insertTable.title),
      content: Column(
        mainAxisSize: .min,
        children: [
          _Stepper(
            key: const ValueKey('rows'),
            label: t.editor.insertTable.rows,
            value: rows,
            min: TableLines.minRows,
            max: TableLines.maxRows,
            onChanged: (value) => setState(() => rows = value),
          ),
          _Stepper(
            key: const ValueKey('columns'),
            label: t.editor.insertTable.columns,
            value: columns,
            min: TableLines.minColumns,
            max: TableLines.maxColumns,
            onChanged: (value) => setState(() => columns = value),
          ),
          const SizedBox(height: 8),
          Text(
            t.editor.insertTable.hint,
            style: TextTheme.of(context).bodySmall,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop((rows, columns)),
          child: Text(t.editor.insertTable.insert),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const new({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '−',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: .center)),
        IconButton(
          tooltip: '+',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
