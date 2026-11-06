import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/handwriting/handwriting_pad.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/i18n/strings.g.dart';

/// Aha! copy: renames an open note, by keyboard or by writing with the pen.
/// Opens when the pen touches the note's name at the top of the page.
/// Pops with the new name, or null.
class RenameNoteDialog extends StatefulWidget {
  const new({super.key, required this.currentName});

  final String currentName;

  static Future<String?> show(BuildContext context, String currentName) =>
      showDialog<String>(
        context: context,
        builder: (context) => RenameNoteDialog(currentName: currentName),
      );

  @override
  State<RenameNoteDialog> createState() => _RenameNoteDialogState();
}

class _RenameNoteDialogState extends State<RenameNoteDialog> {
  late final name = TextEditingController(text: widget.currentName);
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty || trimmed == widget.currentName) {
      return Navigator.of(context).pop();
    }
    final problem = FileManager.validateFilename(trimmed);
    if (problem != null) return setState(() => error = problem);
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.editor.renameNote;
    return AdaptiveAlertDialog(
      title: Text(strings.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 14,
          children: [
            TextField(
              key: const ValueKey('renameNoteName'),
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              // The pen writes in the box below instead.
              stylusHandwritingEnabled: false,
              decoration: InputDecoration(
                labelText: t.home.newNote.name,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            HandwritingPad(
              onText: (text) => setState(() {
                name.text = text;
                name.selection = TextSelection.collapsed(offset: text.length);
                error = null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _save,
          child: Text(strings.save),
        ),
      ],
    );
  }
}
