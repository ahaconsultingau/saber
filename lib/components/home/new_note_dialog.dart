import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/handwriting/handwriting_pad.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// Aha! copy: asks for a new note's name, folder and line style before it
/// opens. Pops with the new note's file path (no extension), or null.
class NewNoteDialog extends StatefulWidget {
  const new({super.key, this.initialFolder = '/', this.folders});

  /// The folder the note goes in unless changed, e.g. '/Clients'.
  final String initialFolder;

  /// Folders to offer; null lists them from the notes folder.
  final List<String>? folders;

  static Future<String?> show(BuildContext context, {String? folder}) =>
      showDialog<String>(
        context: context,
        builder: (context) => NewNoteDialog(initialFolder: folder ?? '/'),
      );

  /// Every folder under the notes folder, '/' first.
  static Future<List<String>> listFolders() async {
    final folders = <String>['/'];
    Future<void> walk(String dir, int depth) async {
      if (depth > 4) return;
      final children = await FileManager.getChildrenOfDirectory(dir);
      if (children == null) return;
      for (final name in children.directories) {
        final path = dir == '/' ? '/$name' : '$dir/$name';
        folders.add(path);
        await walk(path, depth + 1);
      }
    }

    await walk('/', 0);
    return folders;
  }

  /// The file path a new note gets: [name] (or Saber's dated default) in
  /// [folder], made unique.
  static Future<String> pathFor(String folder, String name) async {
    final parent = folder.endsWith('/') ? folder : '$folder/';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return FileManager.newFilePath(parent);
    return FileManager.suffixFilePathToMakeItUnique('$parent$trimmed');
  }

  @override
  State<NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<NewNoteDialog> {
  final name = TextEditingController();
  late String folder = widget.initialFolder;
  late var pattern = stows.newNoteBackgroundPattern.value;
  late List<String> folders = widget.folders ?? [widget.initialFolder];
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.folders == null) {
      NewNoteDialog.listFolders().then((list) {
        if (!mounted) return;
        setState(() {
          folders = {...list, widget.initialFolder}.toList();
        });
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final trimmed = name.text.trim();
    if (trimmed.isNotEmpty) {
      final problem = FileManager.validateFilename(trimmed);
      if (problem != null) return setState(() => error = problem);
    }
    final path = await NewNoteDialog.pathFor(folder, trimmed);
    // The editor creates the note with the default design; this note
    // takes the line style chosen here.
    EditorCoreInfo.nextNewNotePattern = pattern;
    if (mounted) Navigator.of(context).pop(path);
  }

  String _folderLabel(String path) =>
      path == '/' ? t.home.newNote.topFolder : path.substring(1);

  @override
  Widget build(BuildContext context) {
    final strings = t.home.newNote;
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
              key: const ValueKey('newNoteName'),
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.name,
                hintText: strings.nameHint,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _create(),
            ),
            // Aha! copy: or write the name with the pen.
            HandwritingPad(
              onText: (text) => setState(() {
                name.text = text;
                name.selection = TextSelection.collapsed(offset: text.length);
                error = null;
              }),
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('newNoteFolder'),
              initialValue: folder,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.folder,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final f in folders)
                  DropdownMenuItem(
                    value: f,
                    child: Text(
                      _folderLabel(f),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (f) => setState(() => folder = f ?? folder),
            ),
            DropdownButtonFormField<CanvasBackgroundPattern>(
              key: const ValueKey('newNotePattern'),
              initialValue: pattern,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: strings.lineStyle,
                helperText: strings.lineStyleHelp,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final p in CanvasBackgroundPattern.values)
                  DropdownMenuItem(value: p, child: Text(p.localizedName)),
              ],
              onChanged: (p) => setState(() => pattern = p ?? pattern),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        // Aha! copy: skip naming; the note gets Saber's dated name.
        CupertinoDialogAction(
          onPressed: () {
            name.clear();
            _create();
          },
          child: Text(strings.skip),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _create,
          child: Text(strings.create),
        ),
      ],
    );
  }
}
