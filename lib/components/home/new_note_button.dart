import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/home/new_note_dialog.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

class NewNoteButton extends StatefulWidget {
  const new({super.key, required this.cupertino, this.path});

  final bool cupertino;
  final String? path;

  /// Aha! copy: asks for the new note's name, folder and line style, then
  /// opens it. Used by this button and by the side bar's New note.
  static Future<void> createNote(BuildContext context, {String? folder}) async {
    final newFilePath = await NewNoteDialog.show(
      context,
      folder: folder == null || folder.isEmpty ? '/' : folder,
    );
    if (newFilePath == null || !context.mounted) return;
    context.push(RoutePaths.editFilePath(newFilePath));
  }

  @override
  State<NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<NewNoteButton> {
  /// Aha! copy: one solid "+ New note" button that opens the New note sheet
  /// straight away (it was a pale, see-through + with a menu), with a small
  /// Import button beside it.
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Row(
      mainAxisSize: .min,
      spacing: 12,
      children: [
        IconButton.filledTonal(
          tooltip: t.home.create.importNote,
          onPressed: _import,
          icon: const Icon(Icons.file_upload_outlined),
        ),
        FloatingActionButton.extended(
          heroTag: null,
          tooltip: t.home.tooltips.newNote,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: () =>
              NewNoteButton.createNote(context, folder: widget.path),
          icon: const Icon(Icons.add),
          label: Text(t.home.create.newNote),
        ),
      ],
    );
  }

  Future<void> _import() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;

    final filePath = file.path;
    final fileName = file.name;
    if (filePath == null) return;

    if (filePath.toLowerCase().endsWith('.sbn') ||
        filePath.toLowerCase().endsWith('.sbn2') ||
        filePath.toLowerCase().endsWith('.sba')) {
      final path = await FileManager.importFile(
        filePath,
        '${widget.path ?? ''}/',
      );
      if (path == null) return;
      if (!mounted) return;

      context.push(RoutePaths.editFilePath(path));
    } else if (filePath.toLowerCase().endsWith('.pdf')) {
      if (!Editor.canRasterPdf) return;
      if (!mounted) return;

      final fileNameWithoutExtension = fileName.substring(
        0,
        fileName.length - '.pdf'.length,
      );
      final sbnFilePath = await FileManager.suffixFilePathToMakeItUnique(
        '${widget.path ?? ''}/$fileNameWithoutExtension',
      );
      if (!mounted) return;

      context.push(RoutePaths.editImportPdf(sbnFilePath, filePath));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.home.invalidFormat)));
      }
      throw 'Invalid file type';
    }
  }
}
