import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/fill.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel, 16 Nov: Draw mode step 3, layers, and "with the paint can colour
/// fill, there should be an option to fill to the lines of another layer -
/// so one layer is the fill but the next is the master sketch or outline".
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
  });

  Stroke line(EditorPage page, Offset a, Offset b, {int layer = 0}) => Stroke(
    color: Colors.black,
    pressureEnabled: false,
    options: StrokeOptions(size: 5, isComplete: true),
    pageIndex: 0,
    page: page,
    toolId: ToolId.fountainPen,
    layer: layer,
  )..addPoints([a, b, b]);

  List<Stroke> square(EditorPage page, Rect r, {required int layer}) => [
    line(page, r.topLeft, r.topRight, layer: layer),
    line(page, r.topRight, r.bottomRight, layer: layer),
    line(page, r.bottomRight, r.bottomLeft, layer: layer),
    line(page, r.bottomLeft, r.topLeft, layer: layer),
  ];

  Future<EditorState> open(WidgetTester tester, String name) async {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    EditorCoreInfo.nextNewDrawing = DrawingSettings(
      layers: [
        DrawingLayer(id: 0, name: 'Colour'),
        DrawingLayer(id: 1, name: 'Outline'),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/Art')));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    return editor;
  }

  test('Layers and strokes keep their layer in the files', () {
    final settings = DrawingSettings(
      layers: [
        DrawingLayer(id: 0, name: 'Colour', opacity: 0.4),
        DrawingLayer(id: 3, name: 'Ink', hidden: true),
      ],
      activeLayer: 3,
      fillLinesLayer: 3,
    );
    final back = DrawingSettings.fromJson(settings.toJson());
    expect(back.layers.map((l) => l.name), ['Colour', 'Ink']);
    expect(back.layers[0].opacity, 0.4);
    expect(back.layers[1].hidden, isTrue);
    expect(back.activeLayer, 3);
    expect(back.fillLinesLayer, 3);
    // A stroke on a layer that no longer exists shows on the bottom one.
    expect(back.shownLayerOf(9), 0);

    final page = EditorPage();
    final stroke = line(page, Offset.zero, const Offset(10, 10), layer: 3);
    final json = stroke.toJson();
    expect(json['aL'], 3);
    expect(
      Stroke.fromJson(json, fileVersion: 20, pageIndex: 0, page: page).layer,
      3,
    );
    expect(line(page, Offset.zero, Offset.zero).toJson()['aL'], isNull);
  });

  testWidgets('New strokes go on the layer in use; the eraser and lasso '
      'only touch that layer', (tester) async {
    final editor = await open(tester, 'layersTouch');
    final drawing = editor.drawing!;
    final page = editor.coreInfo.pages[0];
    expect(page.drawing, same(drawing));
    drawing.activeLayer = 1;

    final onColour = line(page, const Offset(100, 300), const Offset(400, 300));
    final onOutline = line(
      page,
      const Offset(100, 302),
      const Offset(400, 302),
      layer: 1,
    );
    page.strokes.addAll([onColour, onOutline]);

    // Erase across both with the pen: only the outline stroke goes.
    editor.currentTool = Eraser(size: 20);
    final from = page.renderBox!.localToGlobal(const Offset(250, 280));
    final g = await tester.startGesture(from, kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    expect(page.strokes, contains(onColour));
    expect(page.strokes, isNot(contains(onOutline)));
    page.strokes.add(onOutline);

    // The lasso, through the editor, sees only the layer in use.
    final select = Select.currentSelect..unselect();
    select.onDragStart(const Offset(50, 250), 0);
    for (final p in const [
      Offset(450, 250),
      Offset(450, 350),
      Offset(50, 350),
      Offset(50, 250),
    ]) {
      select.onDragUpdate(p);
    }
    editor.currentTool = select;
    select.onDragEnd(
      page.strokes.where((s) => drawing.shownLayerOf(s.layer) == 1).toList(),
      page.images,
    );
    expect(select.selectResult.strokes, [onOutline]);
    select.unselect();
  });

  testWidgets('Fill uses the outline layer\'s lines; the colour goes on '
      'the layer in use', (tester) async {
    final editor = await open(tester, 'layersFill');
    final drawing = editor.drawing!;
    final page = editor.coreInfo.pages[0];
    page.strokes.addAll(
      square(page, const Rect.fromLTWH(200, 200, 300, 300), layer: 1),
    );
    drawing
      ..activeLayer = 0
      ..fillLinesLayer = 1;

    final result = (await tester.runAsync(
      () => FillTool.fill(
        page: page,
        pageIndex: 0,
        tap: const Offset(350, 350),
        color: Colors.orange,
        edges: page.strokes.where((s) => drawing.shownLayerOf(s.layer) == 1),
        replaceable: (s) => drawing.shownLayerOf(s.layer) == 0,
      ),
    ))!;
    expect(result.outcome, FillOutcome.filled);

    // Through the editor: the rows land on the Colour layer.
    editor.currentTool = FillTool.currentFill..color = Colors.orange;
    final before = page.strokes.length;
    await tester.runAsync(
      () => editor.fillAtForTesting(const Offset(350, 350), 0),
    );
    await tester.pump();
    final rows = page.strokes.skip(0).where(FillTool.isFillStroke).toList();
    expect(page.strokes.length, greaterThan(before));
    expect(rows, isNotEmpty);
    expect(rows.every((s) => s.layer == 0), isTrue);
  });

  testWidgets('Merge down and delete a layer; undo puts it all back', (
    tester,
  ) async {
    final editor = await open(tester, 'layersMerge');
    final drawing = editor.drawing!;
    final page = editor.coreInfo.pages[0];
    final ink = line(
      page,
      const Offset(100, 600),
      const Offset(400, 600),
      layer: 1,
    );
    page.strokes.add(ink);

    final outline = drawing.layerWithId(1)!;
    editor.mergeLayerDown(outline);
    await tester.pump();
    expect(drawing.layers.map((l) => l.id), [0]);
    expect(ink.layer, 0);
    editor.undo();
    await tester.pump();
    expect(drawing.layers.map((l) => l.id), [0, 1]);
    expect(ink.layer, 1);

    editor.deleteLayer(drawing.layerWithId(1)!);
    await tester.pump();
    expect(page.strokes, isNot(contains(ink)));
    expect(drawing.layers.map((l) => l.id), [0]);
    editor.undo(); // the layer
    editor.undo(); // its strokes
    await tester.pump();
    expect(drawing.layers.map((l) => l.id), [0, 1]);
    expect(page.strokes, contains(ink));
    expect(ink.layer, 1);
  });

  testWidgets('The Layers panel: add, choose, hide', (tester) async {
    final editor = await open(tester, 'layersPanel');
    final drawing = editor.drawing!;
    await tester.tap(find.byKey(const ValueKey('drawLayers')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('layersPanel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('addLayer')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(drawing.layers, hasLength(3));
    final added = drawing.layers.last;
    expect(drawing.activeLayer, added.id);

    await tester.tap(find.text('Colour'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(drawing.activeLayer, 0);

    await tester.tap(find.byKey(ValueKey('layerEye-${added.id}')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(added.hidden, isTrue);

    // A new stroke goes on the Colour layer.
    final pen = Pen.currentPen;
    editor.currentTool = pen;
    final page = editor.coreInfo.pages[0];
    final start = page.renderBox!.localToGlobal(const Offset(300, 900));
    final g = await tester.startGesture(start, kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(20, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    expect(page.strokes.last.layer, 0);
  });
}
