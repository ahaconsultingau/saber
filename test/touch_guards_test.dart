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
    stows.lastSingleFingerPanLock.value = false;
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

  double zoomOf(WidgetTester tester) => transform(tester).getMaxScaleOnAxis();

  /// Two fingers moving up together, drifting apart by [spreadPerStep] px
  /// each step (fingers' spacing changes as people scroll).
  Future<void> twoFingerMove(
    WidgetTester tester, {
    required Offset step,
    double spreadPerStep = 0,
    int steps = 12,
  }) async {
    final a = await tester.startGesture(
      centre + const Offset(-60, 0),
      pointer: 200,
    );
    final b = await tester.startGesture(
      centre + const Offset(60, 0),
      pointer: 201,
    );
    for (var i = 0; i < steps; i++) {
      await a.moveBy(step + Offset(-spreadPerStep, 0));
      await b.moveBy(step + Offset(spreadPerStep, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('Two fingers scrolling with a little drift only scroll', (
    tester,
  ) async {
    await openEditor(tester, 'scrollNoZoom');
    final zoomBefore = zoomOf(tester);
    final before = transform(tester);
    // About 7% spread over the scroll: the kind of drift that used to zoom.
    await twoFingerMove(
      tester,
      step: const Offset(0, -25),
      spreadPerStep: 0.35,
    );
    expect(zoomOf(tester), closeTo(zoomBefore, 0.001));
    expect(transform(tester), isNot(before), reason: 'it did scroll');
  });

  testWidgets('A clear pinch still zooms', (tester) async {
    await openEditor(tester, 'pinchZooms');
    final zoomBefore = zoomOf(tester);
    await twoFingerMove(tester, step: Offset.zero, spreadPerStep: 6);
    expect(zoomOf(tester), greaterThan(zoomBefore * 1.2));
  });

  testWidgets('A long scroll keeps scrolling even as the fingers drift', (
    tester,
  ) async {
    await openEditor(tester, 'longScroll');
    final zoomBefore = zoomOf(tester);
    final before = transform(tester);
    // 30 steps, drifting ~25% apart overall: once it's a scroll, it stays one.
    await twoFingerMove(
      tester,
      step: const Offset(0, -20),
      spreadPerStep: 0.5,
      steps: 30,
    );
    expect(zoomOf(tester), closeTo(zoomBefore, 0.001));
    final moved =
        (transform(tester).getTranslation() - before.getTranslation()).length;
    expect(moved, greaterThan(400), reason: 'scrolled the whole way');
  });

  testWidgets('Two fingers scroll even with the page lock button on', (
    tester,
  ) async {
    // Reported: "it locks, and a slight pinch unlocks it". Saber's
    // single-finger pan lock (a button at the top left of the page) stopped
    // all panning, so only a pinch moved the page.
    stows.lastSingleFingerPanLock.value = true;
    await openEditor(tester, 'panLockOn');
    final zoomBefore = zoomOf(tester);
    final before = transform(tester);
    await drag(tester, fingers: 1);
    // Scroll one way, then the other (the page may already be at an end).
    await twoFingerMove(tester, step: const Offset(0, -20));
    final afterUp = transform(tester);
    await twoFingerMove(tester, step: const Offset(0, 20));
    final afterDown = transform(tester);
    expect(
      afterUp != before || afterDown != afterUp,
      isTrue,
      reason: 'two fingers scroll',
    );
    expect(zoomOf(tester), closeTo(zoomBefore, 0.001), reason: 'no zoom');
  });

  testWidgets('The page lock button is hidden with two-finger scrolling', (
    tester,
  ) async {
    await openEditor(tester, 'panLockHidden');
    await twoFingerMove(tester, step: const Offset(0, -20));
    // The HUD shows for a few seconds after the page moves.
    await twoFingerMove(tester, step: const Offset(0, 10), steps: 2);
    expect(find.byIcon(Icons.swipe_up), findsNothing);
    expect(find.byIcon(Icons.pinch), findsNothing);
  });
}
