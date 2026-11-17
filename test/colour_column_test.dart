import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Requested: tapping the colour circle shows the colours as a small
/// vertical column on the right, not a row across the top. Then: "not
/// persistent - one click and it disappears... it should be turned on and
/// off by the colour button".
void main() {
  Future<EditorState> openEditor(WidgetTester tester) async {
    FlavorConfig.setup();
    stows.colourBarOpen.value = false;
    setupMockPathProvider();
    FileManager.documentsDirectory =
        '$tmpDir/colourColumn/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    return state;
  }

  testWidgets('Colours open as a column on the right and stay open', (
    tester,
  ) async {
    await openEditor(tester);
    final column = find.byKey(const ValueKey('colourColumn'));
    expect(column, findsNothing);

    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
    expect(column, findsOneWidget);
    final rect = tester.getRect(column);
    expect(rect.right, greaterThan(760), reason: 'on the right edge');
    expect(rect.width, lessThanOrEqualTo(48), reason: 'a slim column');
    expect(rect.height, greaterThan(rect.width), reason: 'vertical');

    // Pick a colour: the pen takes it and the column stays open.
    final preset = ColorBar.slotsFor(highlighter: false)[3];
    await tester.tap(
      find.descendant(
        of: column,
        matching: find.byTooltip(ColorBar.findColorName(preset)),
      ),
    );
    await tester.pumpAndSettle();
    expect(column, findsOneWidget);
    expect(Pen.currentPen.color.withAlpha(255), preset);

    // The colour button in the toolbar turns it off.
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
    expect(column, findsNothing);
  });

  testWidgets('Writing on the page leaves the colours open', (tester) async {
    final editor = await openEditor(tester);
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
    final before = editor.coreInfo.pages[0].strokes.length;

    // A pen stroke beside the bar goes onto the page, not to the bar.
    final pen = await tester.startGesture(
      const Offset(200, 700),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 8; i++) {
      await pen.moveBy(const Offset(15, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    expect(editor.coreInfo.pages[0].strokes.length, before + 1);
    expect(find.byKey(const ValueKey('colourColumn')), findsOneWidget);
  });

  testWidgets('Left open, it is open in the next note too', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
    expect(stows.colourBarOpen.value, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final next = tester.state<EditorState>(find.byType(Editor));
    addTearDown(next.cancelAutosaveAndMarkSaved);
    expect(find.byKey(const ValueKey('colourColumn')), findsOneWidget);
  });
}
