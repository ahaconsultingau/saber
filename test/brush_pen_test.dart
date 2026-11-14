import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "add a brush tool" (a paintbrush pen).
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.lastTool.value = ToolId.fountainPen;
    stows.lastPenIsBrush.value = false;
    Pen.currentPen = Pen.fountainPen();
  });

  test('The brush is thick-and-thin with tapered ends', () {
    final brush = Pen.brush();
    expect(brush.isBrush, isTrue);
    expect(Pen.fountainPen().isBrush, isFalse);
    expect(brush.pressureEnabled, isTrue);
    expect(brush.options.thinning, greaterThan(0.5));
    expect(brush.options.start.taperEnabled, isTrue);
    expect(brush.options.end.taperEnabled, isTrue);
    // Saved as a fountain-pen stroke, which the standard apps can draw.
    expect(brush.toolId, ToolId.fountainPen);
  });

  testWidgets('Choose the brush from the pens, and it draws brush strokes', (
    tester,
  ) async {
    FileManager.documentsDirectory =
        '$tmpDir/brush/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);

    // Tapping the pen in use opens its options, with the pen choices.
    await tester.tap(find.byTooltip(Pen.currentPen.name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('brushPen')));
    await tester.pumpAndSettle();
    expect((editor.currentTool as Pen).isBrush, isTrue);
    expect(stows.lastPenIsBrush.value, isTrue, reason: 'remembered');

    final centre = tester.getCenter(find.byType(InteractiveCanvasViewer));
    final pen = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 10; i++) {
      await pen.moveBy(const Offset(15, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));

    final stroke = editor.coreInfo.pages[0].strokes.last;
    expect(stroke.toolId, ToolId.fountainPen);
    expect(stroke.options.thinning, Pen.brushOptions.thinning);
    expect(stroke.options.size, Pen.brushOptions.size);
  });
}
