import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/aha/noteshelf_import.dart';
import 'package:saber/data/aha/sqlite_reader.dart';
import 'package:saber/data/bookmarks/note_bookmarks.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "Is it possible to import files from the Noteshelf application?"
/// then "build it now - the notes are stored in google drive".
/// test/noteshelf/test_notebook.nsa is made up, laid out like a real
/// notebook exported from Noteshelf 3 on the tablet: two pages, the first
/// bookmarked, with pen strokes (one long enough to spill onto SQLite
/// overflow pages), a highlighter mark, a line, an oval and a typed text box.
void main() {
  final bytes = File('test/noteshelf/test_notebook.nsa').readAsBytesSync();

  test('Reads the pages, strokes, shapes and bookmark', () {
    final notebook = NoteshelfImport.parse(bytes);
    expect(notebook.name, 'Test notebook');
    expect(notebook.pages, hasLength(2));
    final first = notebook.pages.first;
    expect(first.size, const Size(1600, 2560));
    expect(first.isBookmarked, isTrue);
    expect(first.bookmarkTitle, 'Kick-off meeting');
    expect(first.marks, hasLength(5), reason: '3 strokes and 2 shapes');
    expect(notebook.skipped, 1, reason: 'the typed text box');
    expect(notebook.pages[1].marks, isEmpty);

    final letterL = first.marks[0];
    expect(letterL.points, const [
      Offset(200, 300),
      Offset(200, 400),
      Offset(260, 400),
    ]);
    expect(letterL.colour, const Color(0xFF050404));
    expect(first.marks[1].points, hasLength(500), reason: 'overflow pages');
    expect(first.marks[2].highlighter, isTrue);
    expect(first.marks[3].points, hasLength(2), reason: 'a straight line');
    expect(first.marks[4].points.length, greaterThan(40), reason: 'an oval');
  });

  test('A file that is not a notebook is refused, not half-read', () {
    expect(
      () => NoteshelfImport.parse(File('pubspec.yaml').readAsBytesSync()),
      throwsA(anything),
    );
    expect(
      () => SqliteReader(File('pubspec.yaml').readAsBytesSync()),
      throwsFormatException,
    );
  });

  test(
    'Imports as a Saber note with editable strokes and a bookmark',
    () async {
      FlavorConfig.setup();
      setupMockPathProvider();
      FileManager.documentsDirectory =
          '$tmpDir/noteshelf/${FileManager.appRootDirectoryPrefix}';
      final docs = Directory(FileManager.documentsDirectory);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
      docs.createSync(recursive: true);
      stows.recentFiles.value = [];

      final (path, skipped) = await NoteshelfImport.importBytes(
        bytes,
        fileName: 'Bayside Council.nsa',
        folder: '/Clients/',
      );
      expect(path, '/Clients/Bayside Council');
      expect(skipped, 1);
      expect(stows.recentFiles.value.first, '$path${Editor.extension}');

      final note = await EditorCoreInfo.loadFromFilePath(path);
      expect(note.readOnly, isFalse);
      expect(note.pages, hasLength(2));
      expect(note.pages.first.size.width, 1000);
      expect(note.pages.first.size.height, closeTo(1600, 0.01));
      expect(note.backgroundPattern, CanvasBackgroundPattern.lined);
      expect(note.lineHeight, 43, reason: '69 scaled to the page');

      final strokes = note.pages.first.strokes;
      expect(strokes, hasLength(5));
      final highlighter = strokes.where((s) => s.toolId == ToolId.highlighter);
      expect(highlighter, hasLength(1));
      expect(
        highlighter.single.color.a,
        closeTo(Highlighter.alpha / 255, 0.01),
      );
      // The letter L, scaled from a 1600-wide page to Saber's 1000.
      final pen = strokes.firstWhere(
        (s) => s.toolId == ToolId.ballpointPen && s.inputPoints.length == 3,
      );
      expect(pen.inputPoints.first, const Offset(125, 187.5));

      final bookmarks = await NoteBookmarks.load(path, note.pages);
      expect(bookmarks.single.name, 'Kick-off meeting');
      expect(bookmarks.single.page, note.pages.first);
      note.dispose();
    },
  );
}
