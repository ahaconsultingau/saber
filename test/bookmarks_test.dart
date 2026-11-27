import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/bookmarks/bookmarks_panel.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/data/bookmarks/note_bookmarks.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Requested: "one 'note' for one client/project - where I can bookmark a
/// page, that bookmark gets a date and I can name it - then there is a
/// simple way to jump to that page". Chosen: a floating Bookmarks panel,
/// its button beside Pages (not replacing it).
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
  });

  void freshFolder(String name) {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
  }

  group('Saved form', () {
    test('Round trip keeps names, dates and pages; newest first', () {
      final pages = [EditorPage(), EditorPage(), EditorPage()];
      final json = NoteBookmarks.encode([
        NoteBookmark(
          name: 'Kick-off',
          date: DateTime(2026, 9, 1),
          page: pages[0],
        ),
        NoteBookmark(
          name: 'Workshop',
          date: DateTime(2026, 11, 6),
          page: pages[2],
        ),
      ], pages);
      final map = jsonDecode(json) as Map<String, dynamic>;
      expect(map['bookmarks'], [
        {'name': 'Workshop', 'date': '2026-11-06', 'page': 2},
        {'name': 'Kick-off', 'date': '2026-09-01', 'page': 0},
      ]);
      final back = NoteBookmarks.decode(json, pages);
      expect(back.map((b) => b.name), ['Workshop', 'Kick-off']);
      expect(back.first.page, same(pages[2]));
    });

    test('A bookmark follows its page when pages move', () {
      final pages = [EditorPage(), EditorPage(), EditorPage()];
      final b = NoteBookmark(name: 'B', date: DateTime(2026), page: pages[1]);
      pages.insert(0, EditorPage()); // a page added before it
      final map = jsonDecode(NoteBookmarks.encode([b], pages));
      expect(map['bookmarks'][0]['page'], 2);
    });

    test('A bookmark on a deleted page is dropped', () {
      final pages = [EditorPage(), EditorPage()];
      final b = NoteBookmark(
        name: 'Gone',
        date: DateTime(2026),
        page: pages[1],
      );
      pages.removeAt(1);
      expect(jsonDecode(NoteBookmarks.encode([b], pages))['bookmarks'], []);
    });

    test('Out-of-range pages in a file are ignored', () {
      const json =
          '{"v":1,"bookmarks":[{"name":"X","date":"2026-01-01","page":9}]}';
      expect(NoteBookmarks.decode(json, [EditorPage()]), isEmpty);
    });
  });

  group('The companion file', () {
    test('moves with its note and goes when the note is deleted', () async {
      freshFolder('bookmarksFiles');
      await FileManager.writeFile('/Client${Editor.extension}', [1, 2]);
      await FileManager.writeFile(
        NoteBookmarks.pathFor('/Client'),
        utf8.encode('{}'),
        awaitWrite: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(stows.recentFiles.value, isNot(contains('/Client.sbn2.bm')));
      final listed = await FileManager.getChildrenOfDirectory('/');
      expect(listed!.files, ['Client']);

      await FileManager.moveFile(
        '/Client${Editor.extension}',
        '/Bayside${Editor.extension}',
      );
      expect(
        FileManager.doesFileExist(NoteBookmarks.pathFor('/Bayside')),
        isTrue,
      );
      expect(
        FileManager.doesFileExist(NoteBookmarks.pathFor('/Client')),
        isFalse,
      );

      await FileManager.deleteFile('/Bayside${Editor.extension}');
      expect(
        FileManager.doesFileExist(NoteBookmarks.pathFor('/Bayside')),
        isFalse,
      );
    });
  });

  group('In the editor', () {
    Future<EditorState> openNote(WidgetTester tester, String path) async {
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Editor(path: path)));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      final state = tester.state<EditorState>(find.byType(Editor));
      addTearDown(state.cancelAutosaveAndMarkSaved);
      return state;
    }

    Future<void> settleIo(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('Bookmark a page, start a meeting, jump, edit, reopen', (
      tester,
    ) async {
      freshFolder('bookmarksEditor');
      final editor = await openNote(tester, '/Bayside Council');

      // The Bookmarks button sits beside Pages; Pages is still there.
      expect(find.byTooltip(t.editor.pages), findsOneWidget);
      await tester.tap(find.byTooltip(t.editor.bookmarks.title));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bookmarksPanel')), findsOneWidget);
      expect(find.text(t.editor.bookmarks.empty), findsOneWidget);
      final panelWidth = tester
          .getSize(find.byKey(const ValueKey('bookmarksPanel')))
          .width;
      expect(panelWidth, lessThanOrEqualTo(320));

      // Bookmark the first page, keeping the heading on.
      await tester.tap(find.text(t.editor.bookmarks.bookmarkThisPage));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bookmarkName')),
        'Kick-off meeting',
      );
      await tester.tap(find.text(t.editor.bookmarks.save));
      await settleIo(tester);
      expect(editor.bookmarks.single.name, 'Kick-off meeting');
      expect(
        editor.coreInfo.pages[0].quill.controller.document.toPlainText(),
        startsWith('Kick-off meeting · '),
        reason: 'the heading shows on the Mac too',
      );
      expect(
        find.text(t.editor.bookmarks.thisPageIsBookmarked),
        findsOneWidget,
      );

      // New meeting: a page at the end, bookmarked, and we jump to it.
      final transformBefore = tester
          .widget<InteractiveCanvasViewer>(find.byType(InteractiveCanvasViewer))
          .transformationController!
          .value
          .clone();
      await tester.tap(find.text(t.editor.bookmarks.newMeeting));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bookmarkName')),
        'Steering group',
      );
      await tester.tap(find.text(t.editor.bookmarks.save));
      await settleIo(tester);
      expect(editor.bookmarks.map((b) => b.name), [
        'Kick-off meeting',
        'Steering group',
      ]);
      final meetingPage = editor.coreInfo.pages.indexOf(
        editor.bookmarks.last.page,
      );
      expect(meetingPage, greaterThan(0));
      expect(
        editor.coreInfo.pages.last.isEmpty,
        isTrue,
        reason: 'a blank page stays at the end',
      );
      final transformAfter = tester
          .widget<InteractiveCanvasViewer>(find.byType(InteractiveCanvasViewer))
          .transformationController!
          .value;
      expect(transformAfter, isNot(transformBefore), reason: 'jumped to it');

      // Both listed, with their page numbers.
      expect(find.text('Steering group'), findsOneWidget);
      expect(find.textContaining('page ${meetingPage + 1}'), findsOneWidget);

      // Tap the first one: jumps back towards the top.
      await tester.tap(find.text('Kick-off meeting'));
      await tester.pumpAndSettle();

      // Edit: rename the meeting.
      await tester.longPress(find.text('Steering group'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bookmarkName')),
        'Steering group #1',
      );
      await tester.tap(find.text(t.editor.bookmarks.save));
      await settleIo(tester);
      expect(find.text('Steering group #1'), findsOneWidget);

      // Saved beside the note.
      final saved = File(
        FileManager.getFile(NoteBookmarks.pathFor('/Bayside Council')).path,
      ).readAsStringSync();
      expect(saved, contains('Steering group #1'));
      expect(saved, contains('Kick-off meeting'));

      // Remove one.
      await tester.longPress(find.text('Kick-off meeting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.bookmarks.remove));
      await settleIo(tester);
      expect(editor.bookmarks.map((b) => b.name), ['Steering group #1']);

      // Save the note, close it and reopen: the bookmark is still there,
      // on the same page.
      await tester.runAsync(editor.saveToFile);
      await tester.pumpWidget(const SizedBox());
      await settleIo(tester);
      final reopened = await openNote(tester, '/Bayside Council');
      expect(reopened.bookmarks.single.name, 'Steering group #1');
      expect(
        reopened.coreInfo.pages.indexOf(reopened.bookmarks.single.page),
        meetingPage,
      );
    });

    testWidgets('Pages opens in the same spot as Bookmarks, one at a time', (
      tester,
    ) async {
      freshFolder('pagesPanel');
      await openNote(tester, '/Pages panel');
      const pages = ValueKey('pagesPanel');
      const marks = ValueKey('bookmarksPanel');

      await tester.tap(find.byTooltip(t.editor.pages));
      await tester.pumpAndSettle();
      expect(find.byKey(pages), findsOneWidget);
      expect(find.byType(Dialog), findsNothing, reason: 'no longer a dialog');
      final pagesRect = tester.getRect(find.byKey(pages));

      await tester.tap(find.byTooltip(t.editor.bookmarks.title));
      await tester.pumpAndSettle();
      expect(find.byKey(pages), findsNothing);
      expect(find.byKey(marks), findsOneWidget);
      expect(tester.getRect(find.byKey(marks)), pagesRect);

      await tester.tap(find.byTooltip(t.editor.pages));
      await tester.pumpAndSettle();
      expect(find.byKey(marks), findsNothing);
      await tester.tap(find.byTooltip(t.editor.pages));
      await tester.pumpAndSettle();
      expect(find.byKey(pages), findsNothing, reason: 'the button toggles it');
    });

    testWidgets('The date can be changed', (tester) async {
      freshFolder('bookmarksDate');
      final editor = await openNote(tester, '/Dated');
      await tester.tap(find.byTooltip(t.editor.bookmarks.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.editor.bookmarks.bookmarkThisPage));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bookmarkDate')));
      await tester.pumpAndSettle();
      // Pick the 1st of the shown month in the date picker.
      await tester.tap(find.text('1').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bookmarkWriteHeading')));
      await tester.tap(find.text(t.editor.bookmarks.save));
      await settleIo(tester);
      expect(editor.bookmarks.single.date.day, 1);
      expect(
        editor.coreInfo.pages[0].quill.controller.document.isEmpty(),
        isTrue,
        reason: 'heading left off when unticked',
      );
      expect(
        find.textContaining(formatBookmarkDate(editor.bookmarks.single.date)),
        findsOneWidget,
      );
    });
  });
}
