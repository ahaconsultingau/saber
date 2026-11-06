import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Reported on the tablet: "palm or jacket movements move the page".
/// Drives real pointer gestures (touch and stylus) at the editor.
void main() {
  late Offset centre;

  Future<EditorState> openEditor(WidgetTester tester, String name) async {
    FlavorConfig.setup();
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    stows.editorFingerDrawing.value = false;
    await tester.pumpWidget(MaterialApp(home: Editor()));
    await tester.pumpAndSettle();
    final state = tester.state<EditorState>(find.byType(Editor));
    addTearDown(state.cancelAutosaveAndMarkSaved);
    centre = tester.getCenter(find.byType(InteractiveCanvasViewer));
    return state;
  }

  Matrix4 transform(WidgetTester tester) => tester
      .widget<InteractiveCanvasViewer>(find.byType(InteractiveCanvasViewer))
      .transformationController!
      .value
      .clone();

  Future<void> drag(
    WidgetTester tester, {
    required int fingers,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final gestures = [
      for (var i = 0; i < fingers; i++)
        await tester.startGesture(
          centre + Offset(i * 60.0, 0),
          kind: kind,
          pointer: 100 + i,
        ),
    ];
    for (var step = 0; step < 10; step++) {
      for (final g in gestures) {
        await g.moveBy(const Offset(0, -30));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (final g in gestures) {
      await g.up();
    }
    await tester.pumpAndSettle();
    // Let the editor's timers (pointer count, hint, zoom indicator) finish.
    await tester.pump(const Duration(seconds: 6));
  }

  setUp(() {
    FlavorConfig.setup();
    stows.penGuard.value = true;
    stows.penGuardHoldMs.value = 1000;
    stows.twoFingerScrollOnly.value = true;
  });

  testWidgets('One finger or a sleeve does not move the page', (tester) async {
    await openEditor(tester, 'guardOneFinger');
    final before = transform(tester);
    await drag(tester, fingers: 1);
    expect(transform(tester), before);
  });

  testWidgets('One finger scrolls when two-finger scrolling is off', (
    tester,
  ) async {
    stows.twoFingerScrollOnly.value = false;
    await openEditor(tester, 'guardOneFingerOff');
    final before = transform(tester);
    await drag(tester, fingers: 1);
    expect(transform(tester), isNot(before));
  });

  testWidgets('Two fingers scroll the page', (tester) async {
    await openEditor(tester, 'guardTwoFingers');
    final before = transform(tester);
    await drag(tester, fingers: 2);
    expect(transform(tester), isNot(before));
  });

  testWidgets('Right after the pen lifts, a palm does not move the page', (
    tester,
  ) async {
    stows.penGuardHoldMs.value = 60000; // so the test's own timing can't lapse
    final editor = await openEditor(tester, 'guardPalm');

    // Write a stroke with the pen.
    final strokesBefore = editor.coreInfo.pages[0].strokes.length;
    await drag(tester, fingers: 1, kind: PointerDeviceKind.stylus);
    expect(editor.coreInfo.pages[0].strokes.length, strokesBefore + 1);

    // A palm (several touch points) straight after: ignored.
    final before = transform(tester);
    await drag(tester, fingers: 2);
    expect(transform(tester), before);
    expect(editor.coreInfo.pages[0].strokes.length, strokesBefore + 1);
  });

  testWidgets('Once the hold time has passed, two fingers scroll again', (
    tester,
  ) async {
    stows.penGuardHoldMs.value = 1;
    await openEditor(tester, 'guardHoldOver');
    await drag(tester, fingers: 1, kind: PointerDeviceKind.stylus);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 20)),
    );
    final before = transform(tester);
    await drag(tester, fingers: 2);
    expect(transform(tester), isNot(before));
  });

  testWidgets('With the pen guard off, a palm right after the pen scrolls', (
    tester,
  ) async {
    stows.penGuard.value = false;
    await openEditor(tester, 'guardOff');
    await drag(tester, fingers: 1, kind: PointerDeviceKind.stylus);
    final before = transform(tester);
    await drag(tester, fingers: 2);
    expect(transform(tester), isNot(before));
  });
}
