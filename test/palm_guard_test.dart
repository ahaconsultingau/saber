import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel, 17 Nov: "I just lost notes because of my palm closing the
/// program. Can you create a palm guard of the lower ⅛ … it responds to a
/// pen touch but not a big thing".
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.lastTool.value = ToolId.fountainPen;
    stows.lastPenIsBrush.value = false;
    stows.palmZone.value = 0.125;
    stows.palmSizeGuard.value = true;
    // Finger drawing on, so an accepted touch would draw: a palm mustn't.
    stows.editorFingerDrawing.value = true;
    stows.hideFingerDrawingToggle.value = true;
    stows.penGuard.value = false;
    Pen.currentPen = Pen.fountainPen();
  });
  tearDown(() {
    stows.editorFingerDrawing.value = false;
    stows.hideFingerDrawingToggle.value = false;
    stows.penGuard.value = true;
  });

  Future<EditorState> open(WidgetTester tester, String name) async {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/Palm')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    return editor;
  }

  /// A touch dragged across the page, starting [atFraction] of the way
  /// down the canvas, with contact [radius]. Returns strokes added.
  Future<int> touch(
    WidgetTester tester,
    EditorState editor, {
    required double atFraction,
    double radius = 5,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final page = editor.coreInfo.pages[0];
    final before = page.strokes.length;
    final canvas = tester.getRect(find.byType(InteractiveCanvasViewer));
    var at = Offset(canvas.left + 300, canvas.top + canvas.height * atFraction);
    await tester.sendEventToBinding(
      PointerDownEvent(
        pointer: 7,
        kind: kind,
        position: at,
        radiusMajor: radius,
        radiusMinor: radius,
      ),
    );
    for (var i = 0; i < 8; i++) {
      at += const Offset(20, -4);
      await tester.sendEventToBinding(
        PointerMoveEvent(
          pointer: 7,
          kind: kind,
          position: at,
          delta: const Offset(20, -4),
          radiusMajor: radius,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendEventToBinding(
      PointerUpEvent(pointer: 7, kind: kind, position: at),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return page.strokes.length - before;
  }

  testWidgets('Touch in the bottom eighth is ignored; above it works', (
    tester,
  ) async {
    final editor = await open(tester, 'palmZone');
    expect(await touch(tester, editor, atFraction: 0.95), 0);
    expect(await touch(tester, editor, atFraction: 0.5), 1);
    // The pen still writes in the palm zone.
    expect(
      await touch(
        tester,
        editor,
        atFraction: 0.95,
        kind: PointerDeviceKind.stylus,
      ),
      1,
    );
  });

  testWidgets('A palm-sized touch is ignored anywhere', (tester) async {
    final editor = await open(tester, 'palmSize');
    expect(await touch(tester, editor, atFraction: 0.4, radius: 40), 0);
    expect(await touch(tester, editor, atFraction: 0.4, radius: 6), 1);
  });

  testWidgets('With the guards off, those touches work again', (tester) async {
    stows.palmZone.value = 0;
    stows.palmSizeGuard.value = false;
    final editor = await open(tester, 'palmOff');
    expect(await touch(tester, editor, atFraction: 0.95), 1);
    expect(await touch(tester, editor, atFraction: 0.4, radius: 40), 1);
  });

  testWidgets('Leaving the app saves the note at once', (tester) async {
    final editor = await open(tester, 'saveOnLeave');
    expect(await touch(tester, editor, atFraction: 0.4), 1);
    expect(editor.savingState.value, isNot(SavingState.saved));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(FileManager.doesFileExist('/Palm${Editor.extension}'), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
