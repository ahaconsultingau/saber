import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel, 16 Nov: Draw mode step 2: opacity, steadiness, pick colour,
/// drawing order, textured papers and a tracing image (drawings only).
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.editorFingerDrawing.value = false;
    stows.lastTool.value = ToolId.fountainPen;
    stows.lastPenIsBrush.value = false;
    stows.drawingOpacity.value = 1;
    Pen.currentPen = Pen.fountainPen();
    Pen.drawingMode = false;
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens [path] (made a drawing with [settings] first, unless null).
  Future<EditorState> open(
    WidgetTester tester,
    String name, {
    DrawingSettings? settings,
    bool newDrawing = false,
  }) async {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    if (newDrawing) {
      EditorCoreInfo.nextNewDrawing = settings ?? DrawingSettings();
    } else if (settings != null) {
      File('${docs.path}/Art${Editor.extension}').writeAsBytesSync(
        File('test/demo_notes/Golden ratio.sbn2').readAsBytesSync(),
      );
      await tester.runAsync(() => NoteDrawings.save('/Art', settings));
    }
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/Art')));
    await settle(tester, 8);
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    return editor;
  }

  Future<Stroke> drawWithPen(WidgetTester tester, EditorState editor) async {
    final page = editor.coreInfo.pages[0];
    final start = page.renderBox!.localToGlobal(const Offset(300, 300));
    final pen = await tester.startGesture(
      start,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 6; i++) {
      await pen.moveBy(const Offset(25, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pump();
    return page.strokes.last;
  }

  testWidgets('Opacity: see-through paint on drawings, solid on notes', (
    tester,
  ) async {
    final editor = await open(tester, 'opacity', settings: DrawingSettings());
    expect(Pen.drawingMode, isTrue);
    await tester.tap(find.byTooltip(Pen.currentPen.name).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('penOpacity')), findsOneWidget);
    expect(find.byKey(const ValueKey('penSteadiness')), findsOneWidget);
    Pen.drawingOpacity = 0.5;
    final stroke = await drawWithPen(tester, editor);
    expect(stroke.color.a, closeTo(0.5, 0.01));

    // The same pen in a note draws solid.
    Pen.drawingMode = false;
    final solid = await drawWithPen(tester, editor);
    expect(solid.color.a, 1);
  });

  testWidgets('Notes show no drawing options in the pen options', (
    tester,
  ) async {
    await open(tester, 'noteOptions');
    expect(Pen.drawingMode, isFalse);
    await tester.tap(find.byTooltip(Pen.currentPen.name).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('penOpacity')), findsNothing);
    expect(find.byKey(const ValueKey('penSteadiness')), findsNothing);
  });

  testWidgets('Drawing order: later paint stays on top after reopening', (
    tester,
  ) async {
    final editor = await open(tester, 'order', settings: DrawingSettings());
    final page = editor.coreInfo.pages[0];
    expect(page.keepDrawingOrder, isTrue);
    // A pen stroke, then a shape-pen stroke (Saber would put shape-pen
    // strokes first, under the pen).
    Stroke line(ToolId toolId, double y) => Stroke(
      color: Colors.black,
      pressureEnabled: false,
      options: StrokeOptions(size: 4, isComplete: true),
      pageIndex: 0,
      page: page,
      toolId: toolId,
    )..addPoints([Offset(100, y), Offset(400, y), Offset(400, y)]);
    final first = line(ToolId.fountainPen, 800);
    final second = line(ToolId.shapePen, 820);
    page.insertStroke(first);
    page.insertStroke(second);
    expect(page.strokes.last, same(second));

    editor.history.recordChange(
      HistoricAdd(strokes: [first, second], images: const []),
    );
    editor.savingState.value = .waitingToSave;
    final loaded = await tester.runAsync(() async {
      // Save as the editor does, then read it back.
      await editor.saveToFile();
      return EditorCoreInfo.loadFromFilePath('/Art');
    });
    final strokes = loaded!.pages[0].strokes;
    expect(strokes[strokes.length - 1].toolId, ToolId.shapePen);
    expect(strokes[strokes.length - 2].toolId, ToolId.fountainPen);
  });

  testWidgets('Pick colour takes the colour under the pen', (tester) async {
    final editor = await open(tester, 'pick', settings: DrawingSettings());
    Pen.currentPen = Pen.fountainPen()..color = const Color(0xFFE0703A);
    editor.currentTool = Pen.currentPen;
    final stroke = await drawWithPen(tester, editor);
    Pen.currentPen.color = Colors.black;

    await tester.tap(find.byKey(const ValueKey('drawPick')));
    await tester.pump();
    expect(editor.pickingColour, isTrue);
    final page = editor.coreInfo.pages[0];
    final onStroke = page.renderBox!.localToGlobal(
      stroke.inputPoints[stroke.inputPoints.length ~/ 2],
    );
    final before = page.strokes.length;
    await tester.tapAt(onStroke, kind: PointerDeviceKind.stylus);
    await tester.pump();
    expect(editor.pickingColour, isFalse);
    expect(Pen.currentPen.color.toARGB32(), 0xFFE0703A);
    expect(page.strokes.length, before, reason: 'picking draws nothing');
  });

  testWidgets('Textured paper goes behind each page and stays', (tester) async {
    final editor = await open(
      tester,
      'paper',
      settings: DrawingSettings(paper: .watercolour),
      newDrawing: true,
    );
    final first = editor.coreInfo.pages[0];
    expect(first.backgroundImage, isNotNull);
    expect(first.backgroundImage!.invertible, isFalse);
    expect(find.byKey(const ValueKey('drawGrid')), findsNothing);
    editor.insertPageAfter(0);
    expect(editor.coreInfo.pages[1].backgroundImage, isNotNull);

    await drawWithPen(tester, editor);
    editor.savingState.value = .waitingToSave;
    final loaded = await tester.runAsync(() async {
      await editor.saveToFile();
      return EditorCoreInfo.loadFromFilePath('/Art');
    });
    expect(loaded!.pages[0].backgroundImage, isNotNull);
    expect(
      (await tester.runAsync(() => NoteDrawings.load('/Art')))!.paper,
      DrawingPaper.watercolour,
    );
    editor.cancelAutosaveAndMarkSaved();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Tracing image: faded, can be hidden, removed and undone', (
    tester,
  ) async {
    final editor = await open(tester, 'tracing', settings: DrawingSettings());
    final bytes = File('assets/images/paper/sketch.jpg').readAsBytesSync();
    editor.addTracingImageBytes(bytes, '.jpg');
    await tester.pump();
    final page = editor.coreInfo.pages[editor.currentPageIndex];
    final image = page.backgroundImage!;
    expect(editor.drawing!.tracingIds, contains(image.id));
    expect(image.displayOpacity, DrawingSettings.tracingOpacity);

    await tester.runAsync(() => editor.setTracingHidden(true));
    await tester.pump();
    expect(image.displayOpacity, 0);
    await tester.runAsync(() => editor.setTracingHidden(false));
    await tester.pump();
    expect(image.displayOpacity, DrawingSettings.tracingOpacity);

    editor.removeTracingImage();
    await tester.pump();
    expect(page.backgroundImage, isNull);
    editor.undo();
    await tester.pump();
    expect(page.backgroundImage, same(image));
    expect(find.byKey(const ValueKey('drawTracing')), findsOneWidget);
    editor.cancelAutosaveAndMarkSaved();
    // Saber unloads page pictures 5 s after they leave the screen.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  test('A drawing keeps its paper and tracing in the companion file', () {
    final json = DrawingSettings(
      paper: .kraft,
      tracingIds: {3, 7},
      tracingHidden: true,
    ).toJson();
    final back = DrawingSettings.fromJson(json);
    expect(back.paper, DrawingPaper.kraft);
    expect(back.tracingIds, {3, 7});
    expect(back.tracingHidden, isTrue);
  });

  test('The shape pen still works as a pen', () {
    expect(ShapePen(), isA<Pen>());
  });
}
