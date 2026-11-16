import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/components/home/new_note_dialog.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/toolbar/draw_row.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// Aha! copy: asks for a new drawing's name, folder, paper and shape, then
/// pops with its file path (no extension), or null. The next note the
/// editor creates becomes the drawing.
class NewDrawingDialog extends StatefulWidget {
  const new({super.key, this.initialFolder = '/', this.folders});

  final String initialFolder;
  final List<String>? folders;

  static Future<String?> show(BuildContext context, {String? folder}) =>
      showDialog<String>(
        context: context,
        builder: (context) => NewDrawingDialog(initialFolder: folder ?? '/'),
      );

  @override
  State<NewDrawingDialog> createState() => _NewDrawingDialogState();
}

class _NewDrawingDialogState extends State<NewDrawingDialog> {
  final name = TextEditingController();
  late String folder = widget.initialFolder;
  late var grid = DrawRow.grids.contains(stows.newDrawingGrid.value)
      ? stows.newDrawingGrid.value
      : CanvasBackgroundPattern.none;
  late var shape = DrawingShape.fromName(stows.newDrawingShape.value);
  late DrawingPaper? paper = DrawingPaper.fromName(stows.newDrawingPaper.value);
  late List<String> folders = widget.folders ?? [widget.initialFolder];
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.folders == null) {
      NewNoteDialog.listFolders().then((list) {
        if (!mounted) return;
        setState(() => folders = {...list, widget.initialFolder}.toList());
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _create({bool skipName = false}) async {
    final trimmed = skipName ? '' : name.text.trim();
    if (trimmed.isNotEmpty) {
      final problem = FileManager.validateFilename(trimmed);
      if (problem != null) return setState(() => error = problem);
    }
    final path = await NewNoteDialog.pathFor(folder, trimmed);
    stows.newDrawingGrid.value = grid;
    stows.newDrawingShape.value = shape.name;
    stows.newDrawingPaper.value = paper?.name ?? '';
    EditorCoreInfo.nextNewNotePattern = null;
    EditorCoreInfo.nextNewDrawing = DrawingSettings(
      shape: shape,
      grid: paper == null ? grid : .none,
      paper: paper,
    );
    if (mounted) Navigator.of(context).pop(path);
  }

  String _folderLabel(String path) =>
      path == '/' ? t.home.newNote.topFolder : path.substring(1);

  String _paperLabel(DrawingPaper paper) => switch (paper) {
    .sketch => t.home.newDrawing.papers.sketch,
    .watercolour => t.home.newDrawing.papers.watercolour,
    .canvas => t.home.newDrawing.papers.canvas,
    .kraft => t.home.newDrawing.papers.kraft,
    .tonedGrey => t.home.newDrawing.papers.tonedGrey,
  };

  Widget _swatch({
    required Key key,
    required bool selected,
    required VoidCallback onTap,
    required Widget preview,
    required String label,
  }) {
    final colorScheme = ColorScheme.of(context);
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
          Text(label, style: TextTheme.of(context).bodySmall),
        ],
      ),
    );
  }

  String _shapeLabel(DrawingShape shape) => switch (shape) {
    .portrait => t.home.newDrawing.portrait,
    .landscape => t.home.newDrawing.landscape,
    .square => t.home.newDrawing.square,
  };

  @override
  Widget build(BuildContext context) {
    final strings = t.home.newDrawing;
    final textTheme = TextTheme.of(context);
    return AdaptiveAlertDialog(
      title: Text(strings.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 14,
            children: [
              TextField(
                key: const ValueKey('newDrawingName'),
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.home.newNote.name,
                  hintText: strings.nameHint,
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _create(),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('newDrawingFolder'),
                initialValue: folder,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t.home.newNote.folder,
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
              Text(strings.paper, style: textTheme.titleSmall),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final pattern in DrawRow.grids)
                    _swatch(
                      key: ValueKey('newDrawingPaper-${pattern.name}'),
                      selected: paper == null && pattern == grid,
                      onTap: () => setState(() {
                        grid = pattern;
                        paper = null;
                      }),
                      preview: FittedBox(
                        child: CanvasBackgroundPreview(
                          selected: false,
                          invert: false,
                          backgroundColor: Colors.white,
                          backgroundPattern: pattern,
                          backgroundImage: null,
                          pageSize: const Size(1000, 1000),
                          lineHeight: 50,
                          lineThickness: 3,
                        ),
                      ),
                      label: pattern == .none
                          ? strings.plain
                          : pattern.localizedName,
                    ),
                  // Aha! copy: textured papers.
                  for (final texture in DrawingPaper.values)
                    _swatch(
                      key: ValueKey('newDrawingPaper-${texture.name}'),
                      selected: paper == texture,
                      onTap: () => setState(() => paper = texture),
                      preview: Image.asset(
                        texture.asset,
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                      ),
                      label: _paperLabel(texture),
                    ),
                ],
              ),
              Text(strings.shape, style: textTheme.titleSmall),
              SegmentedButton<DrawingShape>(
                key: const ValueKey('newDrawingShape'),
                segments: [
                  for (final s in DrawingShape.values)
                    ButtonSegment(value: s, label: Text(_shapeLabel(s))),
                ],
                selected: {shape},
                showSelectedIcon: false,
                onSelectionChanged: (set) => setState(() => shape = set.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          onPressed: () => _create(skipName: true),
          child: Text(t.home.newNote.skip),
        ),
        CupertinoDialogAction(
          key: const ValueKey('newDrawingCreate'),
          isDefaultAction: true,
          onPressed: _create,
          child: Text(t.home.newNote.create),
        ),
      ],
    );
  }
}
