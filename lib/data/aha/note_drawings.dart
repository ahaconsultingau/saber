import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// Aha! copy: the shape of a drawing's pages.
enum DrawingShape {
  portrait(EditorPage.defaultSize),
  landscape(Size(EditorPage.defaultHeight, EditorPage.defaultWidth)),
  square(Size(EditorPage.defaultWidth, EditorPage.defaultWidth));

  new(this.pageSize);

  /// The size of each page, in page units.
  final Size pageSize;

  static DrawingShape fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? portrait;
}

/// Aha! copy: what makes a note a drawing, and its drawing settings.
class DrawingSettings {
  new({this.shape = .portrait, this.grid = .none});

  DrawingShape shape;

  /// The guide grid chosen for the drawing ([CanvasBackgroundPattern.none]
  /// for plain paper). The note's own pattern is what shows; this remembers
  /// it so the Grid button can bring it back after hiding it.
  CanvasBackgroundPattern grid;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'shape': shape.name,
    'grid': grid.name,
  };

  factory fromJson(Map<String, dynamic> json) => DrawingSettings(
    shape: DrawingShape.fromName(json['shape'] as String?),
    grid: CanvasBackgroundPattern.fromName(json['grid'] as String?),
  );
}

/// Aha! copy: marks notes as drawings.
///
/// A drawing is an ordinary Saber note with a small companion file beside
/// it (`<note>.sbn2.dw`), like the bookmarks file. Keeping the marker out of
/// the note itself means the standard Saber apps (the Mac) can open and save
/// a drawing without turning it back into a note. Saber's sync carries the
/// companion file like any other file in the notes folder, and moving or
/// deleting the note moves or deletes it too (see [FileManager]).
abstract final class NoteDrawings {
  static final log = Logger('NoteDrawings');

  /// The companion file's extension, after the note's own (`.sbn2`).
  static const suffix = '.dw';

  static String pathFor(String notePath) =>
      '$notePath${Editor.extension}$suffix';

  /// Whether the note at [notePath] (no extension) is a drawing.
  static bool isDrawing(String notePath) =>
      FileManager.doesFileExist(pathFor(notePath));

  /// The note's drawing settings, or null if it's not a drawing.
  static Future<DrawingSettings?> load(String notePath) async {
    final bytes = await FileManager.readFile(pathFor(notePath));
    if (bytes == null) return null;
    try {
      return DrawingSettings.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } catch (e, st) {
      // Still a drawing, with the usual settings.
      log.warning('Could not read drawing settings for $notePath: $e', e, st);
      return DrawingSettings();
    }
  }

  /// Makes the note a drawing (or saves its new settings).
  static Future<void> save(String notePath, DrawingSettings settings) =>
      FileManager.writeFile(
        pathFor(notePath),
        utf8.encode(jsonEncode(settings.toJson())),
        awaitWrite: true,
      );

  /// Makes the note an ordinary note again (its strokes are untouched).
  static Future<void> remove(String notePath) =>
      FileManager.deleteFile(pathFor(notePath), alsoDeleteAssets: false);
}
