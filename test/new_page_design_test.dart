import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/settings/new_page_design.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Requested: "set a default/template page design" with line style,
/// spacing and thickness (sliders, as in Saber's page menu), page colour
/// (presets plus any colour) and starting pen (including the highlighter).
void main() {
  setUp(() {
    FlavorConfig.setup();
    stows.newNoteBackgroundPattern.value = CanvasBackgroundPattern.none;
    stows.newNoteLineHeight.value = Stows.defaultLineHeight;
    stows.newNoteLineThickness.value = Stows.defaultLineThickness;
    stows.newNoteBackgroundColor.value = 0;
    stows.newNoteStartingTool.value = '';
  });

  test('A new note starts with the default design, not the last one used', () {
    stows.lastBackgroundPattern.value = CanvasBackgroundPattern.grid;
    stows.lastLineHeight.value = 100;
    stows.newNoteBackgroundPattern.value = CanvasBackgroundPattern.dots;
    stows.newNoteLineHeight.value = 30;
    stows.newNoteLineThickness.value = 2;
    stows.newNoteBackgroundColor.value = 0xFFFBF6E9;

    final info = EditorCoreInfo(filePath: '/new note');
    expect(info.createdFresh, isTrue);
    expect(info.backgroundPattern, CanvasBackgroundPattern.dots);
    expect(info.lineHeight, 30);
    expect(info.lineThickness, 2);
    expect(info.backgroundColor, const Color(0xFFFBF6E9));
  });

  test("Saber's usual page colour is stored as no colour", () {
    expect(EditorCoreInfo(filePath: '/x').backgroundColor, isNull);
  });

  testWidgets('Settings › New pages sets every part of the design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NewPageDesignSettings()),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Grid'));
    await tester.pump();
    expect(stows.newNoteBackgroundPattern.value, CanvasBackgroundPattern.grid);

    // Spacing slider: drag to the right end (100).
    final spacing = find.byType(Slider).at(0);
    await tester.drag(spacing, const Offset(600, 0));
    await tester.pump();
    expect(stows.newNoteLineHeight.value, 100);

    // Thickness slider: drag to the left end (1).
    final thickness = find.byType(Slider).at(1);
    await tester.drag(thickness, const Offset(-600, 0));
    await tester.pump();
    expect(stows.newNoteLineThickness.value, 1);

    await tester.tap(find.text(t.settings.newPages.colours.cream));
    await tester.pump();
    expect(stows.newNoteBackgroundColor.value, 0xFFFBF6E9);

    // Any colour opens the colour picker; Save keeps a colour.
    await tester.tap(find.text(t.settings.newPages.colours.anyColour));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.accentColorPicker.pickAColor), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(stows.newNoteBackgroundColor.value, isNot(0));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Highlighter'));
    await tester.pump();
    expect(stows.newNoteStartingTool.value, ToolId.highlighter.name);
  });

  testWidgets('A new note opens with the chosen starting pen', (tester) async {
    FileManager.documentsDirectory =
        '$tmpDir/startingPen/${FileManager.appRootDirectoryPrefix}';
    stows.lastTool.value = ToolId.fountainPen;
    stows.newNoteStartingTool.value = ToolId.highlighter.name;
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    expect(state.currentTool, isA<Highlighter>());
  });

  testWidgets('With "the pen I last used", a new note keeps the last pen', (
    tester,
  ) async {
    FileManager.documentsDirectory =
        '$tmpDir/startingPenLast/${FileManager.appRootDirectoryPrefix}';
    stows.lastTool.value = ToolId.ballpointPen;
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    expect(state.currentTool, isA<Pen>());
    expect((state.currentTool as Pen).toolId, ToolId.ballpointPen);
  });

  testWidgets("A note's page menu can make its design the default", (
    tester,
  ) async {
    FileManager.documentsDirectory =
        '$tmpDir/makeDefault/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    state.coreInfo
      ..backgroundPattern = CanvasBackgroundPattern.cornell
      ..lineHeight = 60
      ..lineThickness = 4
      ..backgroundColor = const Color(0xFFEEF5FB);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final button = find.text(t.editor.menu.makeDefault);
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      stows.newNoteBackgroundPattern.value,
      CanvasBackgroundPattern.cornell,
    );
    expect(stows.newNoteLineHeight.value, 60);
    expect(stows.newNoteLineThickness.value, 4);
    expect(stows.newNoteBackgroundColor.value, 0xFFEEF5FB);
    await tester.pump(const Duration(seconds: 5)); // let the snack bar go
  });
}
