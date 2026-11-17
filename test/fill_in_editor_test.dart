import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/fill.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// The paint bucket, driven through the real editor: choose Fill, the
/// colour bar opens, a pen tap inside a drawn circle fills it under the ink.
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    stows.colourBarOpen.value = false;
    stows.penColourSlots.value = Stows.defaultPenColourSlots;
    stows.lastTool.value = ToolId.fountainPen;
    FillTool.currentFill = FillTool();
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

  /// Draws a circle outline (page units) on the first page.
  Stroke drawCircle(EditorState editor, {double gapDegrees = 0}) {
    final page = editor.coreInfo.pages[0];
    final stroke =
        Stroke(
          color: Colors.black,
          pressureEnabled: false,
          options: StrokeOptions(size: 4, isComplete: true),
          pageIndex: 0,
          page: page,
          toolId: ToolId.fountainPen,
        )..addPoints([
          for (var a = gapDegrees / 2; a <= 360 - gapDegrees / 2; a += 4)
            Offset(
              500 + 150 * cos(a * pi / 180),
              500 + 150 * sin(a * pi / 180),
            ),
        ]);
    page.insertStroke(stroke);
    return stroke;
  }

  /// Taps with the pen at page point [p] and waits for the fill.
  Future<void> penTap(WidgetTester tester, EditorState editor, Offset p) async {
    final box = editor.coreInfo.pages[0].renderBox!;
    await tester.tapAt(box.localToGlobal(p), kind: PointerDeviceKind.stylus);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Choose Fill, pick a colour, tap inside: it fills', (
    tester,
  ) async {
    final editor = await openEditor(tester, 'fillEditor');
    final outline = drawCircle(editor);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('fillTool')));
    await tester.pumpAndSettle();
    expect(editor.currentTool, isA<FillTool>());
    expect(
      find.byKey(const ValueKey('colourColumn')),
      findsOneWidget,
      reason: 'the colour bar opens with the bucket',
    );
    // Pick orange (the third colour).
    await tester.tap(find.byKey(const ValueKey('colourSlot2')));
    await tester.pumpAndSettle();

    await penTap(tester, editor, const Offset(500, 500));
    final page = editor.coreInfo.pages[0];
    final fill = page.strokes.where(FillTool.isFillStroke).toList();
    expect(fill, isNotEmpty);
    expect(fill.first.color, const Color(0xFFFF9800));
    expect(
      page.strokes.indexOf(fill.last),
      lessThan(page.strokes.indexOf(outline)),
      reason: 'under the ink',
    );

    // Undo takes the whole fill away in one step.
    editor.undo();
    await tester.pump();
    expect(page.strokes.where(FillTool.isFillStroke), isEmpty);
    expect(page.strokes, contains(outline));
  });

  testWidgets('A shape with a big gap says so and fills nothing', (
    tester,
  ) async {
    final editor = await openEditor(tester, 'fillOpen');
    drawCircle(editor, gapDegrees: 40);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fillTool')));
    await tester.pumpAndSettle();
    await penTap(tester, editor, const Offset(500, 500));
    expect(
      editor.coreInfo.pages[0].strokes.where(FillTool.isFillStroke),
      isEmpty,
    );
    expect(find.text(t.editor.fill.open), findsOneWidget);
  });
}
