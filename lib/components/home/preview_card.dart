import 'dart:async';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/components/canvas/invert_widget.dart';
import 'package:saber/components/home/sync_indicator.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/data/aha/note_locks.dart';
import 'package:saber/data/constants.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

class PreviewCard extends StatefulWidget {
  new({
    required this.filePath,
    required this.toggleSelection,
    required this.selected,
    required this.isAnythingSelected,
    this.dragPaths,
  }) : super(key: ValueKey('PreviewCard$filePath'));

  /// Aha! copy: the notes a long-press drag of this card carries (all the
  /// selected notes if this one is selected). Null turns dragging off.
  final List<String> Function()? dragPaths;

  final String filePath;
  final bool selected;
  final bool isAnythingSelected;
  final void Function(String, bool) toggleSelection;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  final expanded = ValueNotifier(false);
  final thumbnail = _ThumbnailState();

  @override
  void initState() {
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );

    expanded.value = widget.selected;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final imageFile = FileManager.getFile(
      '${widget.filePath}${Editor.extension}.p',
    );
    if (isThisATest) {
      // Avoid FileImages in tests
      thumbnail.image = imageFile.existsSync()
          ? MemoryImage(imageFile.readAsBytesSync())
          : null;
    } else {
      thumbnail.image = FileImage(imageFile);
    }
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (event.filePath != widget.filePath) return;
    if (event.type == .delete) {
      thumbnail.image = null;
    } else if (event.type == .write) {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
    } else {
      throw Exception('Unknown file operation type: ${event.type}');
    }
  }

  /// Aha! copy: how far the finger moved since it went down, so a
  /// long-press that isn't a drag still selects the card.
  Offset? _downAt;
  var _moved = 0.0;

  void _toggleCardSelection() {
    expanded.value = !expanded.value;
    widget.toggleSelection(widget.filePath, expanded.value);
  }

  Timer? _refreshThumbnailTimer;
  void _refreshThumbnailAfterDelay() {
    _refreshThumbnailTimer?.cancel();
    _refreshThumbnailTimer = Timer(const Duration(milliseconds: 500), () {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = Duration(
      milliseconds: disableAnimations ? 0 : 300,
    );
    final invert = theme.brightness == .dark && stows.editorAutoInvert.value;

    final borderWidth = MediaQuery.highContrastOf(context)
        ? kSaberBorderWidthAccessible
        : kSaberBorderWidthInaccessible;

    final Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isAnythingSelected ? _toggleCardSelection : null,
        onSecondaryTap: _toggleCardSelection,
        // With dragging on, the drag's long-press selects (see below).
        onLongPress: widget.dragPaths == null ? _toggleCardSelection : null,
        child: Column(
          mainAxisSize: stows.homeLayout.value.fillVertical ? .max : .min,
          children: [
            Flexible(
              fit: stows.homeLayout.value.fillVertical ? .tight : .loose,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: kSaberCardRadius,
                    left: borderWidth,
                    right: borderWidth,
                    child: ColoredBox(
                      color: InnerCanvas.defaultBackgroundColor.withInversion(
                        invert,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      thumbnail,
                      NoteLocks.changes,
                    ]),
                    builder: (context, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ConstrainedBox(
                        key: ValueKey(thumbnail.updateCount),
                        constraints: const BoxConstraints(
                          minWidth: double.infinity,
                          minHeight: 100,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: borderWidth,
                            left: borderWidth,
                            right: borderWidth,
                          ),
                          child: ClipRRect(
                            borderRadius: .only(
                              topLeft: .circular(
                                kSaberCardRadius - borderWidth,
                              ),
                              topRight: .circular(
                                kSaberCardRadius - borderWidth,
                              ),
                            ),
                            child: InvertWidget(
                              invert: invert,
                              // Aha! copy: a locked note's preview is hidden.
                              child: NoteLocks.isNoteLocked(widget.filePath)
                                  ? const _LockedThumbnail()
                                  : thumbnail.doesImageExist
                                  ? Image(
                                      image: thumbnail.image!,
                                      alignment: .topCenter,
                                      fit: .cover,
                                    )
                                  : const _FallbackThumbnail(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Aha! copy: a small brush marks a drawing.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ListenableBuilder(
                      listenable: thumbnail,
                      builder: (context, _) =>
                          NoteDrawings.isDrawing(widget.filePath)
                          ? const _DrawingBadge()
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    left: -1,
                    top: -1,
                    right: -1,
                    bottom: -1,
                    child: ValueListenableBuilder(
                      valueListenable: expanded,
                      builder: (context, expanded, child) => AnimatedOpacity(
                        opacity: expanded ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !expanded,
                          child: child!,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: _toggleCardSelection,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: .topCenter,
                              end: .bottomCenter,
                              colors: [
                                colorScheme.surface.withValues(alpha: 0.2),
                                colorScheme.surface.withValues(alpha: 0.8),
                                colorScheme.surface.withValues(alpha: 1),
                              ],
                            ),
                          ),
                          child: ColoredBox(
                            color: colorScheme.primary.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SyncIndicator(filePath: widget.filePath),
                ],
              ),
            ),
            Padding(
              padding: const .all(8),
              child: Text(
                widget.filePath.substring(widget.filePath.lastIndexOf('/') + 1),
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    final Widget openable = ValueListenableBuilder(
      valueListenable: expanded,
      builder: (context, expanded, _) {
        return OpenContainer(
          clipBehavior: Clip.none,
          closedColor: colorScheme.surface,
          closedShape: RoundedRectangleBorder(
            side: BorderSide(
              color: expanded
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.12),
              width: borderWidth,
            ),
            borderRadius: const .all(.circular(kSaberCardRadius)),
          ),
          closedElevation: 0,
          closedBuilder: (context, action) => card,
          openColor: colorScheme.surface,
          openBuilder: (context, action) => Editor(path: widget.filePath),
          transitionDuration: transitionDuration,
          routeSettings: RouteSettings(
            name: RoutePaths.editFilePath(widget.filePath),
          ),
          onClosed: (_) => _refreshThumbnailAfterDelay(),
        );
      },
    );
    final dragPaths = widget.dragPaths;
    if (dragPaths == null) return openable;
    // Aha! copy: long-press and drag onto a folder to move the note there.
    return Listener(
      onPointerDown: (e) {
        _downAt = e.position;
        _moved = 0;
      },
      onPointerMove: (e) {
        final down = _downAt;
        if (down != null) _moved = max(_moved, (e.position - down).distance);
      },
      child: LongPressDraggable<NoteDrag>(
        data: NoteDrag(dragPaths),
        hapticFeedbackOnStart: true,
        feedback: _DragFeedback(paths: dragPaths()),
        childWhenDragging: Opacity(opacity: 0.4, child: openable),
        onDragEnd: (details) {
          if (!details.wasAccepted && _moved < 12) _toggleCardSelection();
        },
        child: openable,
      ),
    );
  }

  @override
  void dispose() {
    _refreshThumbnailTimer?.cancel();
    fileWriteSubscription?.cancel();
    super.dispose();
  }
}

/// Aha! copy: the notes being dragged onto a folder. Read when dropped,
/// so a selection made before the drag is included.
class NoteDrag {
  new(this._paths);
  final List<String> Function() _paths;
  List<String> get paths => _paths();
}

/// Aha! copy: what follows the finger while notes are dragged.
class const _DragFeedback({required final List<String> paths})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final name = paths.first.substring(paths.first.lastIndexOf('/') + 1);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const .symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            const Icon(Icons.description_outlined),
            Text(paths.length == 1 ? name : '$name + ${paths.length - 1}'),
          ],
        ),
      ),
    );
  }
}

/// Aha! copy: shown in place of a locked note's preview.
class const _LockedThumbnail() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('lockedThumbnail'),
    height: 140,
    child: Center(
      child: Icon(
        Icons.lock_outline,
        size: 40,
        color: ColorScheme.of(context).onSurfaceVariant,
      ),
    ),
  );
}

class const _FallbackThumbnail() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InnerCanvas.defaultBackgroundColor,
      child: Center(
        child: Text(
          t.home.noPreviewAvailable,
          style: TextTheme.of(context).bodyMedium?.copyWith(
            color: Stroke.defaultColor.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
          textAlign: .center,
        ),
      ),
    );
  }
}

class _ThumbnailState extends ChangeNotifier {
  var updateCount = 0;
  ImageProvider? _image;

  void markAsChanged() {
    ++updateCount;
    notifyListeners();
  }

  ImageProvider? get image => _image;
  set image(ImageProvider? image) {
    _image = image;
    markAsChanged();
  }

  bool get doesImageExist => switch (image) {
    (final FileImage fileImage) => fileImage.file.existsSync(),
    null => false,
    _ => true,
  };
}

/// Aha! copy: the brush badge on a drawing's preview.
class _DrawingBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Tooltip(
      message: t.home.newDrawing.drawingBadge,
      child: DecoratedBox(
        key: const ValueKey('drawingBadge'),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Padding(
          padding: const .all(6),
          child: Icon(
            Icons.brush,
            size: 16,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
