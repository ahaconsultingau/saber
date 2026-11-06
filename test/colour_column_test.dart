import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Requested: tapping the colour circle shows the colours as a small
/// vertical column on the right, not a row across the top.
void main() {
  Future<EditorState> openEditor(WidgetTester tester) async {
    FlavorConfig.setup();
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

  testWidgets('Colours open as a column on the right and close on pick', (
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

    // Pick a preset: the pen takes it and the column closes.
    final preset = ColorBar.slotsFor(highlighter: false)[3];
    await tester.tap(
      find.descendant(
        of: column,
        matching: find.byTooltip(ColorBar.findColorName(preset)),
      ),
    );
    await tester.pumpAndSettle();
    expect(column, findsNothing);
    expect(Pen.currentPen.color.withAlpha(255), preset);
  });

  testWidgets('Tapping elsewhere closes the colours', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 700));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('colourColumn')), findsNothing);
  });
}
