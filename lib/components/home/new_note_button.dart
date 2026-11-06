import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/home/new_note_dialog.dart';
import 'package:saber/data/editor/editor_core_info.dart';
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

  /// Aha! copy: opens a new note straight away, with no questions: Saber's
  /// dated name, the default page design, in [folder]. Rename it later with
  /// the pencil beside its name.
  static Future<void> createQuickNote(
    BuildContext context, {
    String? folder,
  }) async {
    EditorCoreInfo.nextNewNotePattern = null;
    final path = await NewNoteDialog.pathFor(
      folder == null || folder.isEmpty ? '/' : folder,
      '',
    );
    if (!context.mounted) return;
    context.push(RoutePaths.editFilePath(path));
  }

  @override
  State<NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<NewNoteButton> {
  /// Aha! copy: one solid "+ New note" button that opens the New note sheet
  /// straight away (it was a pale, see-through + with a menu), a Quick note
  /// button that skips the sheet, and a small Import button.
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
        // Aha! copy: skip the New note sheet altogether. Just the icon on
        // narrow (phone) screens, where the words don't fit.
        FloatingActionButton.extended(
          key: const ValueKey('quickNote'),
          heroTag: null,
          tooltip: t.home.create.quickNoteTooltip,
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          onPressed: () =>
              NewNoteButton.createQuickNote(context, folder: widget.path),
          isExtended: MediaQuery.sizeOf(context).width >= 600,
          icon: const Icon(Icons.bolt),
          label: Text(t.home.create.quickNote),
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
