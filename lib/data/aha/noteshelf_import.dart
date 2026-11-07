import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/aha/sqlite_reader.dart';
import 'package:saber/data/bookmarks/note_bookmarks.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

/// Aha! copy: imports a Noteshelf notebook (`.nsa`) as a Saber note, with
/// the handwriting as real, editable strokes.
///
/// An `.nsa` file is a zip holding `<name>.ns3_a/Document.plist` (the pages,
/// their size and bookmarks) and one SQLite file per page under
/// `Annotations/`, whose `annotation` table holds the strokes. Noteshelf
/// doesn't publish this format: it was worked out from a real notebook
/// exported on the tablet (Noteshelf 3, Android, document version 11.7).
abstract final class NoteshelfImport {
  static final log = Logger('NoteshelfImport');

  /// Saber pages are this wide; Noteshelf pages are scaled to fit.
  static const pageWidth = 1000.0;

  /// Noteshelf's widths, scaled to the page, look thinner in Saber's pens;
  /// these were matched by eye to the notebook's own cover picture.
  static const penWidthFactor = 1.15;
  static const highlighterWidthFactor = 5.5;

  /// Reads the notebook in [bytes] (an `.nsa` file).
  static NoteshelfNotebook parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? find(bool Function(String name) test) {
      for (final f in archive.files) {
        if (f.isFile && test(f.name)) return f;
      }
      return null;
    }

    final docFile = find((n) => n.endsWith('/Document.plist'));
    if (docFile == null) {
      throw const FormatException(
        'Not a Noteshelf notebook (no Document.plist)',
      );
    }
    final root = docFile.name.substring(0, docFile.name.lastIndexOf('/') + 1);
    final doc = Plist.parse(utf8.decode(docFile.content));
    if (doc is! Map) throw const FormatException('Unreadable Document.plist');

    final pages = <NoteshelfPage>[];
    var skipped = 0;
    for (final p in (doc['pages'] as List? ?? const [])) {
      if (p is! Map) continue;
      final size =
          _parseSize(p['pdfKitPageRect'] as String?) ?? const Size(1600, 2560);
      final annotations = find((n) => n == '${root}Annotations/${p['uuid']}');
      final page = NoteshelfPage(
        size: size,
        lineHeight: _toDouble(p['lineHeight']) ?? 0,
        isBookmarked: p['isBookmarked'] == true,
        bookmarkTitle: (p['bookmarkTitle'] as String? ?? '').trim(),
        date: _unixDate(p['lastUpdated'] ?? p['creationDate']),
        marks: [],
      );
      if (annotations != null) {
        try {
          final rows = SqliteReader(annotations.content)
              .readTable('annotation');
          for (final row in rows) {
            final mark = _markFrom(row);
            if (mark == null) {
              skipped++;
            } else {
              page.marks.add(mark);
            }
          }
        } catch (e, st) {
          log.warning('Could not read a page of the notebook: $e', e, st);
          skipped++;
        }
      }
      pages.add(page);
    }
    final name = root.split('/').where((s) => s.isNotEmpty).firstOrNull;
    return NoteshelfNotebook(
      name: name?.replaceAll(RegExp(r'\.ns\d*_a$'), '') ?? 'Noteshelf',
      pages: pages,
      skipped: skipped,
    );
  }

  /// A mark from one row of a page's `annotation` table, or null for kinds
  /// that aren't brought across (typed text, images, stickers).
  static NoteshelfMark? _markFrom(Map<String, Object?> row) {
    final type = row['annotationType'];
    final width = _toDouble(row['strokeWidth']) ?? 3;
    final colour = Color(
      0xFF000000 | ((row['strokeColor'] as int? ?? 0) & 0xFFFFFF),
    );
    final highlighter = row['penType'] == 5;
    if (type == 0) {
      final blob = row['stroke_segments_v3'];
      if (blob is! Uint8List || blob.length < 16) return null;
      final data = ByteData.sublistView(blob);
      final points = [
        for (var i = 0; i + 16 <= blob.length; i += 16)
          Offset(
            data.getFloat32(i, Endian.little),
            data.getFloat32(i + 4, Endian.little),
          ),
      ];
      return NoteshelfMark(points, width, colour, highlighter: highlighter);
    }
    if (type == 5) {
      // A shape: base64 JSON with its control points and type.
      final raw = row['shape_data'];
      if (raw is! Uint8List) return null;
      try {
        final outer = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
        final shape = jsonDecode(
          utf8.decode(base64Decode(outer['shapeData'] as String)),
        ) as Map<String, dynamic>;
        final pts = [
          for (final p in shape['controlPoints'] as List)
            Offset(
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ];
        final thickness =
            ((shape['properties'] as Map?)?['strokeThickness'] as num?)
                ?.toDouble() ??
            width;
        final kind = shape['shapeType'];
        final List<Offset> outline;
        if (kind == 6 && pts.length >= 2) {
          // An oval in the box between the two points.
          final box = Rect.fromPoints(pts[0], pts[1]);
          outline = [
            for (var a = 0; a <= 360; a += 6)
              box.center +
                  Offset(
                    box.width / 2 * cos(a * pi / 180),
                    box.height / 2 * sin(a * pi / 180),
                  ),
          ];
        } else if ((shape['numberOfSides'] as int? ?? 0) > 2) {
          outline = [...pts, pts.first];
        } else {
          outline = pts;
        }
        if (outline.length < 2) return null;
        return NoteshelfMark(outline, thickness / 2, colour, straight: true);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Turns [notebook] into a Saber note at [notePath] (no extension), saves
  /// it, with its bookmarks, and adds it to Recent notes.
  static Future<void> save(NoteshelfNotebook notebook, String notePath) async {
    // The file doesn't exist yet, so this gives a fresh, empty note.
    final info = await EditorCoreInfo.loadFromFilePath(notePath);
    info.pages.clear();
    final lineHeights = <double>[];
    for (final p in notebook.pages) {
      final scale = pageWidth / p.size.width;
      final page = EditorPage(width: pageWidth, height: p.size.height * scale);
      final index = info.pages.length;
      for (final mark in p.marks) {
        page.insertStroke(
          mark.toStroke(page: page, pageIndex: index, scale: scale),
        );
      }
      info.pages.add(page);
      if (p.lineHeight > 0) lineHeights.add(p.lineHeight * scale);
    }
    if (info.pages.isEmpty) info.pages.add(EditorPage());
    // Noteshelf pages are white; the lines come from its template.
    info.backgroundColor = null;
    info.backgroundPattern = CanvasBackgroundPattern.none;
    if (lineHeights.isNotEmpty) {
      info
        ..backgroundPattern = CanvasBackgroundPattern.lined
        ..lineHeight = lineHeights.first.round();
    }

    final (bson, _) = info.saveToBinary(currentPageIndex: 0);
    await FileManager.writeFile(
      notePath + Editor.extension,
      bson,
      awaitWrite: true,
    );

    final bookmarks = [
      for (final (i, p) in notebook.pages.indexed)
        if (p.isBookmarked)
          NoteBookmark(
            name: p.bookmarkTitle.isEmpty ? 'Page ${i + 1}' : p.bookmarkTitle,
            date: p.date ?? DateTime.now(),
            page: info.pages[i],
          ),
    ];
    if (bookmarks.isNotEmpty) {
      await NoteBookmarks.save(notePath, bookmarks, info.pages);
    }

    final recent = notePath + Editor.extension;
    stows.recentFiles.value
      ..remove(recent)
      ..insert(0, recent);
    stows.recentFiles.notifyListeners();
    info.dispose();
  }

  /// Imports the `.nsa` file at [bytes] (named [fileName]) into [folder];
  /// returns the new note's path (no extension) and how many marks were
  /// left out.
  static Future<(String, int)> importBytes(
    Uint8List bytes, {
    required String fileName,
    String folder = '/',
  }) async {
    final notebook = parse(bytes);
    final parent = folder.endsWith('/') ? folder : '$folder/';
    var name = fileName.replaceAll(RegExp(r'\.nsa$', caseSensitive: false), '');
    if (name.trim().isEmpty) name = notebook.name;
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    final path = await FileManager.suffixFilePathToMakeItUnique('$parent$name');
    await save(notebook, path);
    return (path, notebook.skipped);
  }

  static Size? _parseSize(String? rect) {
    if (rect == null) return null;
    final nums = RegExp(r'-?\d+(\.\d+)?')
        .allMatches(rect)
        .map((m) => double.parse(m.group(0)!))
        .toList();
    if (nums.length < 4 || nums[2] <= 0 || nums[3] <= 0) return null;
    return Size(nums[2], nums[3]);
  }

  static double? _toDouble(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static DateTime? _unixDate(Object? v) {
    final seconds = _toDouble(v);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }
}

class NoteshelfNotebook {
  const new({required this.name, required this.pages, required this.skipped});

  final String name;
  final List<NoteshelfPage> pages;

  /// Marks that couldn't be brought across (typed text, images, stickers).
  final int skipped;
}

class NoteshelfPage {
  const new({
    required this.size,
    required this.lineHeight,
    required this.isBookmarked,
    required this.bookmarkTitle,
    required this.date,
    required this.marks,
  });

  final Size size;
  final double lineHeight;
  final bool isBookmarked;
  final String bookmarkTitle;
  final DateTime? date;
  final List<NoteshelfMark> marks;
}

class NoteshelfMark {
  const new(
    this.points,
    this.width,
    this.colour, {
    this.highlighter = false,
    this.straight = false,
  });

  /// In Noteshelf page coordinates.
  final List<Offset> points;
  final double width;
  final Color colour;
  final bool highlighter;

  /// A drawn shape's outline (no smoothing).
  final bool straight;

  Stroke toStroke({
    required EditorPage page,
    required int pageIndex,
    required double scale,
  }) {
    final size =
        width *
        scale *
        (highlighter
            ? NoteshelfImport.highlighterWidthFactor
            : NoteshelfImport.penWidthFactor);
    return Stroke(
      color: highlighter ? colour.withAlpha(Highlighter.alpha) : colour,
      pressureEnabled: false,
      options: StrokeOptions(
        size: size,
        thinning: 0,
        smoothing: straight ? 0 : 0.5,
        streamline: straight ? 0 : 0.5,
        simulatePressure: false,
        isComplete: true,
      ),
      pageIndex: pageIndex,
      page: page,
      toolId: highlighter
          ? ToolId.highlighter
          : straight
          ? ToolId.shapePen
          : ToolId.ballpointPen,
    )..addPoints([for (final p in points) p * scale]);
  }
}

/// A small reader for Apple's XML property lists: dict, array, string,
/// integer, real, true, false, date and data.
abstract final class Plist {
  static Object? parse(String xml) {
    final tokens = RegExp(r'<(/?)([a-zA-Z]+)\s*(/?)>|([^<]+)')
        .allMatches(xml.replaceAll(RegExp(r'<\?[^>]*\?>|<!DOCTYPE[^>]*>'), ''));
    final it = tokens.iterator;
    Object? value(String tag) {
      switch (tag) {
        case 'dict':
          final map = <String, Object?>{};
          String? key;
          while (it.moveNext()) {
            final m = it.current;
            if (m.group(4) != null) continue;
            if (m.group(1) == '/') return map;
            final t = m.group(2)!;
            if (m.group(3) == '/') {
              final v = t == 'true'
                  ? true
                  : t == 'false'
                  ? false
                  : t == 'dict'
                  ? <String, Object?>{}
                  : t == 'array'
                  ? <Object?>[]
                  : '';
              if (key != null) map[key] = v;
              key = null;
              continue;
            }
            if (t == 'key') {
              key = _text(it);
            } else {
              final v = value(t);
              if (key != null) map[key] = v;
              key = null;
            }
          }
          return map;
        case 'array':
          final list = <Object?>[];
          while (it.moveNext()) {
            final m = it.current;
            if (m.group(4) != null) continue;
            if (m.group(1) == '/') return list;
            final t = m.group(2)!;
            if (m.group(3) == '/') {
              list.add(
                t == 'true'
                    ? true
                    : t == 'false'
                    ? false
                    : '',
              );
              continue;
            }
            list.add(value(t));
          }
          return list;
        case 'true':
          _close(it);
          return true;
        case 'false':
          _close(it);
          return false;
        case 'integer':
          return int.tryParse(_text(it).trim());
        case 'real':
          return double.tryParse(_text(it).trim());
        default: // string, date, data
          return _unescape(_text(it));
      }
    }

    while (it.moveNext()) {
      final m = it.current;
      if (m.group(2) == 'plist' || m.group(4) != null) continue;
      return value(m.group(2)!);
    }
    return null;
  }

  /// The text up to the next closing tag.
  static String _text(Iterator<RegExpMatch> it) {
    final buf = StringBuffer();
    while (it.moveNext()) {
      final m = it.current;
      if (m.group(4) != null) {
        buf.write(m.group(4));
      } else {
        break; // the closing tag
      }
    }
    return buf.toString();
  }

  static void _close(Iterator<RegExpMatch> it) {
    while (it.moveNext()) {
      if (it.current.group(4) == null) return;
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
