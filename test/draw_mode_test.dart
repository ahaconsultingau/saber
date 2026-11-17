import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/_canvas_background_painter.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/main.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/home.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel, 16 Nov: "both for note taking and drawing … a third button -
/// quick note, note, draw and the extra functions only show on the draw
/// pages". Step 1: drawings, the Draw button and sheet, the Draw row.
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.sentryConsent.value = .granted;
    stows.layoutSize.value = .tablet;
    stows.editorFingerDrawing.value = false;
    stows.lastTool.value = ToolId.fountainPen;
    stows.lastPenIsBrush.value = false;
    stows.newDrawingGrid.value = CanvasBackgroundPattern.none;
    stows.newDrawingShape.value = 'portrait';
    Pen.currentPen = Pen.fountainPen();
  });

  Future<Directory> freshDocs(String name) async {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    stows.recentFiles.value = [];
    return docs;
  }

  Future<void> settle(WidgetTester tester, [int rounds = 5]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('Drawing companion file', () {
    test('It goes with its note when moved, and is deleted with it', () async {
      final docs = await freshDocs('drawingFile');
      File('${docs.path}/Logo${Editor.extension}').writeAsBytesSync([0]);
      await NoteDrawings.save(
        '/Logo',
        DrawingSettings(shape: .landscape, grid: .isometric),
      );
      expect(NoteDrawings.isDrawing('/Logo'), isTrue);
      final read = await NoteDrawings.load('/Logo');
      expect(read!.shape, DrawingShape.landscape);
      expect(read.grid, CanvasBackgroundPattern.isometric);

      await FileManager.moveFile(
        '/Logo${Editor.extension}',
        '/Art/Logo${Editor.extension}',
      );
      expect(NoteDrawings.isDrawing('/Logo'), isFalse);
      expect(NoteDrawings.isDrawing('/Art/Logo'), isTrue);

      await FileManager.deleteFile('/Art/Logo${Editor.extension}');
      expect(NoteDrawings.isDrawing('/Art/Logo'), isFalse);
      expect(
        File('${docs.path}/Art/Logo${Editor.extension}.dw').existsSync(),
        isFalse,
      );
    });

    test('A note without the file is an ordinary note', () async {
      await freshDocs('noDrawingFile');
      expect(NoteDrawings.isDrawing('/Plain'), isFalse);
      expect(await NoteDrawings.load('/Plain'), isNull);
    });

    test('The isometric grid draws lines three ways', () {
      final lines = CanvasBackgroundPainter.getPatternElements(
        pattern: .isometric,
        size: EditorPage.defaultSize,
        lineHeight: 40,
      ).toList();
      expect(lines, isNotEmpty);
      final rising = lines.where((l) => l.end.dy > l.start.dy + 1);
      final falling = lines.where((l) => l.end.dy < l.start.dy - 1);
      final upright = lines.where((l) => l.start.dx == l.end.dx);
      expect(rising, isNotEmpty);
      expect(falling, isNotEmpty);
      expect(upright, isNotEmpty);
    });
  });

  Future<GoRouter> openHome(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: App.initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => HomePage(
            subpage: state.pathParameters['subpage'] ?? HomePage.recentSubpage,
            path: state.uri.queryParameters['path'],
          ),
        ),
        GoRoute(
          path: RoutePaths.edit,
          builder: (context, state) =>
              Editor(path: state.uri.queryParameters['path']),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  testWidgets('Draw: the sheet makes a landscape drawing with a grid, '
      'the brush in hand and the Draw row', (tester) async {
    await freshDocs('newDrawing');
    await openHome(tester);

    // Quick note · Draw · New note
    final quick = tester.getCenter(find.byKey(const ValueKey('quickNote')));
    final draw = tester.getCenter(find.byKey(const ValueKey('drawButton')));
    final newNote = tester.getCenter(find.byTooltip(t.home.tooltips.newNote));
    expect(quick.dx < draw.dx && draw.dx < newNote.dx, isTrue);

    await tester.tap(find.byKey(const ValueKey('drawButton')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(t.home.newDrawing.title), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('newDrawingName')),
      'Logo ideas',
    );
    await tester.tap(
      find.byKey(const ValueKey('newDrawingPaper-aha-isometric')),
    );
    await tester.tap(find.text(t.home.newDrawing.landscape));
    await tester.pump();
    await tester.tap(find.text(t.home.newNote.create));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    final editor = tester.state<EditorState>(find.byType(Editor));
    expect(editor.coreInfo.filePath, '/Logo ideas');
    expect(editor.drawing, isNotNull);
    expect(editor.coreInfo.pages.first.size, DrawingShape.landscape.pageSize);
    expect(
      editor.coreInfo.backgroundPattern,
      CanvasBackgroundPattern.isometric,
    );
    expect((editor.currentTool as Pen).isBrush, isTrue);
    expect(find.byKey(const ValueKey('drawRow')), findsOneWidget);
    expect(stows.newDrawingShape.value, 'landscape', reason: 'remembered');

    // Draw, and it saves as a drawing.
    final centre = tester.getCenter(find.byType(InteractiveCanvasViewer));
    final pen = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 6; i++) {
      await pen.moveBy(const Offset(20, 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pump();
    await tester.runAsync(editor.saveToFile);
    await settle(tester);
    expect(NoteDrawings.isDrawing('/Logo ideas'), isTrue);
    // New pages keep the drawing's shape.
    editor.insertPageAfter(0);
    expect(editor.coreInfo.pages[1].size, DrawingShape.landscape.pageSize);
  });

  testWidgets('Notes keep their toolbar: no Draw row', (tester) async {
    await freshDocs('noteNoRow');
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    expect(editor.drawing, isNull);
    expect(find.byKey(const ValueKey('drawRow')), findsNothing);
    expect(find.byKey(const ValueKey('drawButton')), findsNothing);
  });

  Future<EditorState> openDrawing(WidgetTester tester, String name) async {
    final docs = await freshDocs(name);
    File('${docs.path}/Sketch${Editor.extension}').writeAsBytesSync(
      File('test/demo_notes/Golden ratio.sbn2').readAsBytesSync(),
    );
    await tester.runAsync(
      () => NoteDrawings.save('/Sketch', DrawingSettings(grid: .dots)),
    );
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/Sketch')));
    await settle(tester, 8);
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    return editor;
  }

  testWidgets('Grid: pick a guide grid; undo puts it back', (tester) async {
    final editor = await openDrawing(tester, 'drawGrid');
    expect(editor.drawing, isNotNull);
    final before = editor.coreInfo.backgroundPattern;
    await tester.tap(find.byKey(const ValueKey('drawGrid')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('drawGrid-aha-isometric')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      editor.coreInfo.backgroundPattern,
      CanvasBackgroundPattern.isometric,
    );
    editor.undo();
    await tester.pump();
    expect(editor.coreInfo.backgroundPattern, before);
  });

  testWidgets('Flip view mirrors the page, and the pen still lands under '
      'it', (tester) async {
    final editor = await openDrawing(tester, 'drawFlip');
    Pen.currentPen = Pen.brush();
    editor.currentTool = Pen.currentPen;
    await tester.tap(find.byKey(const ValueKey('drawFlip')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(editor.flipView, isTrue);
    final flip = tester.widget<Transform>(
      find.byKey(const ValueKey('pageFlip0')),
    );
    expect(flip.transform.storage[0], -1);

    // Touch the left side of the screen: the stroke is on the page's
    // right side (the page is shown mirrored).
    final page = editor.coreInfo.pages[0];
    final box = page.renderBox!;
    final screenLeft = box.localToGlobal(
      Offset(page.size.width * 0.8, page.size.height * 0.3),
    );
    expect(
      screenLeft.dx < tester.getCenter(find.byType(Editor)).dx,
      isTrue,
      reason: 'the right of the page now shows on the left',
    );
    final before = page.strokes.length;
    final pen = await tester.startGesture(
      screenLeft,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 5; i++) {
      await pen.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pump();
    expect(page.strokes.length, before + 1);
    final stroke = page.strokes.last;
    expect(stroke.inputPoints.first.dx, closeTo(page.size.width * 0.8, 5));

    // Flip back.
    await tester.tap(find.byKey(const ValueKey('drawFlip')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(editor.flipView, isFalse);
  });

  testWidgets('A note can become a drawing, and back', (tester) async {
    final editor = await openDrawing(tester, 'toggleDrawing');
    await tester.runAsync(() => editor.setIsDrawing(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(NoteDrawings.isDrawing('/Sketch'), isFalse);
    expect(find.byKey(const ValueKey('drawRow')), findsNothing);
    await tester.runAsync(() => editor.setIsDrawing(true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(NoteDrawings.isDrawing('/Sketch'), isTrue);
    expect(find.byKey(const ValueKey('drawRow')), findsOneWidget);
  });

  testWidgets('A drawing shows a brush badge in Recent notes', (tester) async {
    final docs = await freshDocs('badge');
    File('${docs.path}/Sketch${Editor.extension}').writeAsBytesSync(
      File('test/demo_notes/Golden ratio.sbn2').readAsBytesSync(),
    );
    File('${docs.path}/Notes${Editor.extension}').writeAsBytesSync(
      File('test/demo_notes/Golden ratio.sbn2').readAsBytesSync(),
    );
    await tester.runAsync(
      () => NoteDrawings.save('/Sketch', DrawingSettings()),
    );
    stows.recentFiles.value = ['/Sketch.sbn2', '/Notes.sbn2'];
    await openHome(tester);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PreviewCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('drawingBadge')), findsOneWidget);
  });
}
