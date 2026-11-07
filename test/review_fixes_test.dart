import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/bookmarks/note_bookmarks.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Fixes from the code review of 6 Nov (each test names the fault).
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    stows.penGuard.value = true;
    stows.penGuardHoldMs.value = 1000;
    stows.twoFingerScrollOnly.value = true;
    stows.lastSingleFingerPanLock.value = false;
    stows.editorFingerDrawing.value = false;
    stows.colourBarOpen.value = false;
    stows.colourBarEdge.value = AxisDirection.right;
    stows.lastTool.value = ToolId.fountainPen;
  });

  Future<EditorState> openEditor(WidgetTester tester, String name) async {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    return editor;
  }

  testWidgets(
    '1. A palm caught when the pen comes near no longer eats the next stroke',
    (tester) async {
      final editor = await openEditor(tester, 'palmThenPen');
      final centre = tester.getCenter(find.byType(InteractiveCanvasViewer));
      final before = editor.coreInfo.pages[0].strokes.length;

      // A palm (two touch points) moves while the pen is away...
      final a = await tester.startGesture(centre, pointer: 1);
      final b = await tester.startGesture(
        centre + const Offset(60, 0),
        pointer: 2,
      );
      for (var i = 0; i < 4; i++) {
        await a.moveBy(const Offset(0, -10));
        await b.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // ...then the pen comes near (hovering) while the palm is still down.
      final hover = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
        pointer: 3,
      );
      await hover.addPointer(location: centre + const Offset(0, 200));
      await hover.moveTo(centre + const Offset(5, 205));
      for (var i = 0; i < 3; i++) {
        await a.moveBy(const Offset(0, -10));
        await b.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await hover.removePointer();
      await tester.pump(const Duration(milliseconds: 50));

      // The next pen stroke draws.
      final pen = await tester.startGesture(
        centre + const Offset(-100, 100),
        kind: PointerDeviceKind.stylus,
        pointer: 4,
      );
      for (var i = 0; i < 8; i++) {
        await pen.moveBy(const Offset(15, 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await pen.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(editor.coreInfo.pages[0].strokes.length, before + 1);
    },
  );

  group('3. One damaged bookmark entry no longer loses the rest', () {
    test('the good entries are kept', () {
      final pages = [
        EditorPage(width: 1000, height: 1400),
        EditorPage(width: 1000, height: 1400),
      ];
      final marks = NoteBookmarks.decode(
        '{"v":1,"bookmarks":[null,'
        '{"name":"Kick-off","date":"2026-09-01","page":0},'
        '{"name":"Bad page","page":"x"},'
        '{"name":"Steering","date":"2026-10-21","page":1},'
        '"not a bookmark"]}',
        pages,
      );
      expect(marks.map((b) => b.name), ['Kick-off', 'Steering']);
      expect(marks[1].page, pages[1]);
    });
  });

  testWidgets(
    '4. The colour bar keeps clear of the Bookmarks panel on the right',
    (tester) async {
      await openEditor(tester, 'barAndPanel');
      await tester.tap(find.byTooltip(t.editor.bookmarks.title));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byKey(const ValueKey('colourColumn')));
      final panel = tester.getRect(
        find.byKey(const ValueKey('bookmarksPanel')),
      );
      expect(bar.right, lessThanOrEqualTo(panel.left));
    },
  );

  testWidgets(
    '5. With the bar at the bottom, it moves up when the toolbar grows',
    (tester) async {
      stows.colourBarEdge.value = AxisDirection.down;
      await openEditor(tester, 'barToolbarGrows');
      await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
      await tester.pumpAndSettle();
      final column = find.byKey(const ValueKey('colourColumn'));
      final bottomBefore = tester.getRect(column).bottom;

      // Tapping the pen in use opens its options row above the toolbar.
      await tester.tap(find.byTooltip(t.editor.pens.fountainPen));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      final bottomAfter = tester.getRect(column).bottom;
      expect(bottomAfter, lessThan(bottomBefore), reason: 'moved up');
      expect(
        bottomAfter,
        lessThanOrEqualTo(tester.getRect(find.byType(Toolbar)).top),
        reason: 'not over the grown toolbar',
      );
    },
  );

  test('9. A note that could not be read is not treated as a new one', () {
    EditorCoreInfo.nextNewNotePattern = CanvasBackgroundPattern.grid;
    final corrupt = EditorCoreInfo(
      filePath: '/Broken',
      readOnlyReason: .corrupted,
    );
    expect(corrupt.createdFresh, isFalse);
    expect(
      EditorCoreInfo.nextNewNotePattern,
      CanvasBackgroundPattern.grid,
      reason: 'the New note choice is kept for the real new note',
    );
    final fresh = EditorCoreInfo(filePath: '/New');
    expect(fresh.createdFresh, isTrue);
    expect(fresh.backgroundPattern, CanvasBackgroundPattern.grid);
  });

  test('10. A stored colour that cannot be read falls back', () {
    stows.penColourSlots.value = ['4278190080', 'not a colour', '4294940672'];
    final slots = ColorBar.slotsFor(highlighter: false);
    expect(slots, hasLength(6));
    expect(slots[1], Color(int.parse(Stows.defaultPenColourSlots[1])));
    expect(slots[5], Color(int.parse(Stows.defaultPenColourSlots[5])));
    stows.penColourSlots.value = Stows.defaultPenColourSlots;
  });
}
