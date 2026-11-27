import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "Keep the colour bar small and unobtrusive. 6 colours showing max.
/// Click into the colour and there is an RGB picker to create the colour
/// you want, which gets remembered. Starting colours black, blue, orange,
/// green, red, grey. Highlighter colours yellow, green, pink, blue, orange,
/// purple."
void main() {
  final column = find.byKey(const ValueKey('colourColumn'));
  Finder slot(int i) => find.byKey(ValueKey('colourSlot$i'));

  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    stows.colourBarEdge.value = AxisDirection.right;
    stows.colourBarOpen.value = false;
    stows.penColourSlots.value = Stows.defaultPenColourSlots;
    stows.highlighterColourSlots.value = Stows.defaultHighlighterColourSlots;
    // The editor reopens with the last tool used; start each test on a pen.
    stows.lastTool.value = ToolId.fountainPen;
  });

  Future<EditorState> openEditor(WidgetTester tester) async {
    FileManager.documentsDirectory =
        '$tmpDir/colourSlots/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    return state;
  }

  Future<void> openColours(WidgetTester tester) async {
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
  }

  String names(bool highlighter) =>
      ColorBar.slotsFor(highlighter: highlighter)
          .map(ColorBar.findColorName)
          .join(', ');

  test('The starting colours', () {
    expect(names(false), 'Black, Blue, Orange, Green, Red, Grey');
    expect(names(true), 'Yellow, Green, Pink, Blue, Orange, Purple');
  });

  testWidgets('Six colours only, in a small bar', (tester) async {
    await openEditor(tester);
    await openColours(tester);
    for (var i = 0; i < 6; i++) {
      expect(slot(i), findsOneWidget);
    }
    expect(slot(6), findsNothing);
    final rect = tester.getRect(column);
    expect(rect.width, lessThanOrEqualTo(48));
    expect(rect.height, lessThan(320), reason: 'short: six colours');
  });

  testWidgets('The highlighter shows its own six colours', (tester) async {
    final editor = await openEditor(tester);
    editor.currentTool = Highlighter.currentHighlighter;
    // ignore: invalid_use_of_protected_member
    editor.setState(() {});
    await tester.pumpAndSettle();
    await openColours(tester);
    final pink = ColorBar.slotsFor(highlighter: true)[2];
    await tester.tap(slot(2));
    await tester.pumpAndSettle();
    expect(
      Highlighter.currentHighlighter.color,
      pink.withAlpha(Highlighter.alpha),
    );
  });

  testWidgets('Tap the colour in use to change it; it is remembered', (
    tester,
  ) async {
    await openEditor(tester);
    // Use blue.
    await openColours(tester);
    await tester.tap(slot(1));
    await tester.pumpAndSettle();
    expect(column, findsOneWidget, reason: 'the bar stays open');

    // Tap blue again: the picker opens on it.
    await tester.tap(slot(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('colourSlotPicker')), findsOneWidget);

    // Type a colour's code (a teal) and save.
    final code = find.descendant(
      of: find.byKey(const ValueKey('colourSlotPicker')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(code).readOnly, isFalse);
    await tester.enterText(code, '008080');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    const teal = Color(0xFF008080);
    expect(ColorBar.slotsFor(highlighter: false)[1], teal);
    expect(stows.penColourSlots.value[1], teal.toARGB32().toString());
    expect(Pen.currentPen.color.withAlpha(255), teal, reason: 'and used');
    expect(names(false), startsWith('Black, Custom'));
  });

  testWidgets('Cancel leaves the colour as it was', (tester) async {
    await openEditor(tester);
    await openColours(tester);
    await tester.longPress(slot(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(stows.penColourSlots.value, Stows.defaultPenColourSlots);
  });
}
