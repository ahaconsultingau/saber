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

/// Joel: "User can drag the colour tool bar to the top, left, right,
/// bottom and it snaps into place... default is to open on the right".
void main() {
  final column = find.byKey(const ValueKey('colourColumn'));
  const screen = Size(800, 1280);

  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    stows.colourBarEdge.value = AxisDirection.right;
  });

  Future<void> openColours(WidgetTester tester) async {
    FileManager.documentsDirectory =
        '$tmpDir/colourBarDrag/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    await tester.tap(find.byTooltip(t.editor.toolbar.toggleColors));
    await tester.pumpAndSettle();
  }

  /// Drags the bar's handle to [target] in small steps.
  Future<void> dragTo(WidgetTester tester, Offset target) async {
    final handle = find.byTooltip(t.editor.toolbar.moveColours);
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(start);
    const steps = 20;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(start, target, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('Opens upright on the right by default', (tester) async {
    await openColours(tester);
    final rect = tester.getRect(column);
    expect(rect.right, greaterThan(screen.width - 20));
    expect(rect.height, greaterThan(rect.width));
  });

  testWidgets('Dragged to the top, it snaps there across the screen', (
    tester,
  ) async {
    await openColours(tester);
    await dragTo(tester, const Offset(400, 90));
    final rect = tester.getRect(column);
    expect(stows.colourBarEdge.value, AxisDirection.up);
    expect(rect.width, greaterThan(rect.height), reason: 'across');
    expect(rect.top, lessThan(200), reason: 'at the top');
    expect(rect.top, greaterThan(kToolbarHeight), reason: 'below the app bar');
  });

  testWidgets('Dragged to the left, it snaps there upright', (tester) async {
    await openColours(tester);
    await dragTo(tester, const Offset(20, 640));
    final rect = tester.getRect(column);
    expect(stows.colourBarEdge.value, AxisDirection.left);
    expect(rect.left, lessThan(20));
    expect(rect.height, greaterThan(rect.width));
  });

  testWidgets('Dragged to the bottom, it sits above the toolbar', (
    tester,
  ) async {
    await openColours(tester);
    await dragTo(tester, const Offset(400, 1200));
    expect(stows.colourBarEdge.value, AxisDirection.down);
    final rect = tester.getRect(column);
    expect(rect.width, greaterThan(rect.height), reason: 'across');
    final toolbarTop = tester
        .getRect(find.byTooltip(t.editor.toolbar.toggleColors))
        .top;
    expect(rect.bottom, lessThanOrEqualTo(toolbarTop), reason: 'not over it');
  });

  testWidgets('It opens where it was last left, and colours still pick', (
    tester,
  ) async {
    stows.colourBarEdge.value = AxisDirection.up;
    await openColours(tester);
    final rect = tester.getRect(column);
    expect(rect.width, greaterThan(rect.height));
    expect(rect.top, lessThan(200));
    final preset = ColorBar.slotsFor(highlighter: false)[1];
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
}
