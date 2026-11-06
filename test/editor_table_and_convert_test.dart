import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/handwriting/handwriting_recognizer.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

Future<EditorState> openEditor(WidgetTester tester, String name) async {
  FlavorConfig.setup();
  FileManager.documentsDirectory =
      '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
  // A tablet-sized screen, so every toolbar button fits.
  tester.view.physicalSize = const Size(1600, 2560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Editor()));
  await tester.pumpAndSettle();
  final state = tester.state<EditorState>(find.byType(Editor));
  addTearDown(state.cancelAutosaveAndMarkSaved);
  return state;
}

Stroke handwriting(EditorState state, double y) => Stroke(
  color: Colors.black,
  pressureEnabled: false,
  options: StrokeOptions(size: 5, isComplete: true),
  pageIndex: 0,
  page: state.coreInfo.pages[0],
  toolId: .ballpointPen,
)..addPoints([Offset(100, y), Offset(120, y + 30), Offset(140, y)]);

/// Draws a lasso around [rect] (page coordinates) with the select tool,
/// through the editor's real drawing handlers.
Future<void> lasso(WidgetTester tester, EditorState state, Rect rect) async {
  final box = state.coreInfo.pages[0].renderBox!;
  Offset global(Offset local) => box.localToGlobal(local);
  state.dragPageIndex = 0;
  state.onDrawStart(ScaleStartDetails(focalPoint: global(rect.topLeft)));
  for (final corner in [rect.topRight, rect.bottomRight, rect.bottomLeft]) {
    state.onDrawUpdate(ScaleUpdateDetails(focalPoint: global(corner)));
  }
  state.onDrawEnd(ScaleEndDetails());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    HandwritingRecognizer.debugIsSupported = null;
    HandwritingRecognizer.debugRecognize = null;
    // The select tool is shared, so clear any selection a previous test left.
    Select.currentSelect.unselect();
  });

  testWidgets('Insert table draws a selected grid on the page', (tester) async {
    final state = await openEditor(tester, 'insertTable');
    final page = state.coreInfo.pages[0];
    final strokesBefore = page.strokes.length;

    await tester.tap(find.byTooltip(t.editor.toolbar.table));
    await tester.pumpAndSettle();
    expect(find.text(t.editor.insertTable.title), findsWidgets);

    // 3 × 3 by default: make it 4 rows × 2 columns.
    final rows = find.byKey(const ValueKey('rows'));
    final columns = find.byKey(const ValueKey('columns'));
    await tester.tap(
      find.descendant(of: rows, matching: find.byIcon(Icons.add)),
    );
    await tester.tap(
      find.descendant(of: columns, matching: find.byIcon(Icons.remove)),
    );
    await tester.pump();
    await tester.tap(find.text(t.editor.insertTable.insert));
    await tester.pumpAndSettle();

    final added = page.strokes.skip(strokesBefore).toList();
    expect(added, hasLength((4 + 1) + (2 + 1)));
    for (final stroke in added) {
      final points = stroke.inputPoints;
      final start = points.first, end = points.last;
      expect(
        start.dx == end.dx || start.dy == end.dy,
        isTrue,
        reason: 'every table line is straight',
      );
      // Saved like a shape-pen line, so standard Saber apps read it.
      final json = stroke.toJson();
      expect(json['shape'], isNull);
      final reloaded = Stroke.fromJson(
        json,
        fileVersion: EditorCoreInfo.sbnVersion,
        pageIndex: 0,
        page: page,
      );
      expect(reloaded.inputPoints, stroke.inputPoints);
      expect(reloaded.toolId, stroke.toolId);
    }

    expect(state.currentTool, isA<Select>());
    final select = state.currentTool as Select;
    expect(select.doneSelecting, isTrue);
    expect(select.selectResult.strokes, added);

    // One undo removes the whole table.
    state.undo();
    await tester.pump();
    expect(page.strokes, hasLength(strokesBefore));
  });

  testWidgets('Convert to text is hidden where recognition is unavailable', (
    tester,
  ) async {
    HandwritingRecognizer.debugIsSupported = false;
    final state = await openEditor(tester, 'convertHidden');
    state.coreInfo.pages[0].strokes.add(handwriting(state, 100));
    await tester.tap(find.byTooltip(t.editor.toolbar.select));
    await tester.pumpAndSettle();
    await lasso(tester, state, const Rect.fromLTWH(50, 50, 200, 200));
    expect(find.byTooltip(t.editor.selectionBar.delete), findsOneWidget);
    expect(find.byTooltip(t.editor.selectionBar.convertToText), findsNothing);
  });

  testWidgets('Convert to text adds the text and can remove the ink', (
    tester,
  ) async {
    HandwritingRecognizer.debugIsSupported = true;
    List<Stroke>? recognised;
    HandwritingRecognizer.debugRecognize = (strokes) async {
      recognised = strokes;
      return 'Hello world';
    };

    final state = await openEditor(tester, 'convertToText');
    final page = state.coreInfo.pages[0];
    final ink = [handwriting(state, 100), handwriting(state, 200)];
    page.strokes.addAll(ink);

    await tester.tap(find.byTooltip(t.editor.toolbar.select));
    await tester.pumpAndSettle();
    await lasso(tester, state, const Rect.fromLTWH(50, 50, 200, 250));
    expect((state.currentTool as Select).selectResult.strokes, ink);

    await tester.tap(find.byTooltip(t.editor.selectionBar.convertToText));
    await tester.pumpAndSettle();
    expect(recognised, ink);

    final field = find.byKey(const ValueKey('convertedText'));
    expect(tester.widget<TextField>(field).controller!.text, 'Hello world');
    await tester.enterText(field, 'Hello there');
    await tester.tap(find.text(t.editor.convertToText.removeHandwriting));
    await tester.pump();
    await tester.tap(find.text(t.editor.convertToText.addToPage));
    await tester.pumpAndSettle();

    expect(page.quill.controller.document.toPlainText().trim(), 'Hello there');
    for (final stroke in ink) {
      expect(page.strokes, isNot(contains(stroke)));
    }

    // Two undos: the first takes the text away, the second puts the
    // handwriting back.
    state.undo();
    await tester.pump();
    expect(page.quill.controller.document.isEmpty(), isTrue);
    state.undo();
    await tester.pump();
    for (final stroke in ink) {
      expect(page.strokes, contains(stroke));
    }
  });

  testWidgets('Cancel leaves the page unchanged', (tester) async {
    HandwritingRecognizer.debugIsSupported = true;
    HandwritingRecognizer.debugRecognize = (_) async => 'Hello';

    final state = await openEditor(tester, 'convertCancel');
    final page = state.coreInfo.pages[0];
    final ink = [handwriting(state, 100)];
    page.strokes.addAll(ink);
    state.currentTool = Select.currentSelect
      ..selectResult = SelectResult(
        pageIndex: 0,
        strokes: List.of(ink),
        images: [],
        path: Path(),
        pageIndexStart: 0,
      )
      ..doneSelecting = true;

    final done = state.convertSelectionToText();
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    await done;

    expect(page.quill.controller.document.isEmpty(), isTrue);
    expect(page.strokes, contains(ink.single));
  });
}
