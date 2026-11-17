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

/// Aha! copy: textured papers for drawings. Each page gets the texture as
/// its background picture, so the standard Saber apps show it too.
enum DrawingPaper {
  sketch('sketch'),
  watercolour('watercolour'),
  canvas('canvas'),
  kraft('kraft'),
  tonedGrey('toned_grey');

  new(this._file);
  final String _file;

  String get asset => 'assets/images/paper/$_file.jpg';

  static DrawingPaper? fromName(String? name) =>
      values.where((p) => p.name == name).firstOrNull;
}

/// Aha! copy: one layer of a drawing. Strokes carry its [id].
class DrawingLayer {
  new({
    required this.id,
    required this.name,
    this.opacity = 1,
    this.hidden = false,
  });

  final int id;
  String name;

  /// How strongly the layer shows, 0.05 to 1.
  double opacity;
  bool hidden;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (opacity != 1) 'opacity': opacity,
    if (hidden) 'hidden': true,
  };

  factory fromJson(Map<String, dynamic> json) => DrawingLayer(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    opacity: ((json['opacity'] as num?)?.toDouble() ?? 1).clamp(0.05, 1),
    hidden: json['hidden'] == true,
  );
}

/// Aha! copy: what makes a note a drawing, and its drawing settings.
class DrawingSettings {
  new({
    this.shape = .portrait,
    this.grid = .none,
    this.paper,
    Set<int>? tracingIds,
    this.tracingHidden = false,
    List<DrawingLayer>? layers,
    this.activeLayer = 0,
    this.fillLinesLayer,
  }) : tracingIds = tracingIds ?? {},
       layers = layers == null || layers.isEmpty
           ? [DrawingLayer(id: 0, name: 'Layer 1')]
           : layers;

  /// The layers, bottom first. Strokes on a layer that isn't listed (e.g.
  /// one deleted elsewhere) show on the bottom layer.
  final List<DrawingLayer> layers;

  /// The layer new strokes go on; the eraser and lasso only touch it.
  int activeLayer;

  /// The layer whose lines paint fill uses as edges, or null for every
  /// visible layer.
  int? fillLinesLayer;

  static const maxLayers = 10;

  /// The layer [id] belongs to as shown: itself, or the bottom layer.
  int shownLayerOf(int id) =>
      layers.any((l) => l.id == id) ? id : layers.first.id;

  DrawingLayer? layerWithId(int id) =>
      layers.where((l) => l.id == id).firstOrNull;

  DrawingShape shape;

  /// The textured paper new pages get, or null for plain paper (with
  /// [grid]).
  DrawingPaper? paper;

  /// The ids of page pictures that are tracing images: shown faded (or
  /// hidden) on the tablet. The standard Saber apps show them as ordinary
  /// page pictures.
  final Set<int> tracingIds;
  bool tracingHidden;

  /// How strongly a tracing image shows.
  static const tracingOpacity = 0.3;

  /// The guide grid chosen for the drawing ([CanvasBackgroundPattern.none]
  /// for plain paper). The note's own pattern is what shows; this remembers
  /// it so the Grid button can bring it back after hiding it.
  CanvasBackgroundPattern grid;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'shape': shape.name,
    'grid': grid.name,
    if (paper != null) 'paper': paper!.name,
    if (tracingIds.isNotEmpty) 'tracing': tracingIds.toList(),
    if (tracingHidden) 'tracingHidden': true,
    'layers': [for (final layer in layers) layer.toJson()],
    'activeLayer': activeLayer,
    if (fillLinesLayer != null) 'fillLinesLayer': fillLinesLayer,
  };

  factory fromJson(Map<String, dynamic> json) => DrawingSettings(
    shape: DrawingShape.fromName(json['shape'] as String?),
    grid: CanvasBackgroundPattern.fromName(json['grid'] as String?),
    paper: DrawingPaper.fromName(json['paper'] as String?),
    tracingIds: {
      for (final id in json['tracing'] as List? ?? const [])
        if (id is int) id,
    },
    tracingHidden: json['tracingHidden'] == true,
    layers: [
      for (final layer in json['layers'] as List? ?? const [])
        if (layer is Map<String, dynamic>) DrawingLayer.fromJson(layer),
    ],
    activeLayer: (json['activeLayer'] as num?)?.toInt() ?? 0,
    fillLinesLayer: (json['fillLinesLayer'] as num?)?.toInt(),
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
