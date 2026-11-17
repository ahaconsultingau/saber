import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/interactive_canvas.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel, 16 Nov: "each time I go to write the whole program closes - files
/// are still there". A wrist resting on the edge of the screen reads as
/// Android's swipe back: one closed the note, a second closed the app.
void main() {
  testWidgets('Back is ignored while writing, and works after', (tester) async {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.editorFingerDrawing.value = false;
    FileManager.documentsDirectory =
        '$tmpDir/backWhileWriting/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => Editor())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);

    Future<void> settle() async {
      for (var j = 0; j < 10; j++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Write with the pen.
    final centre = tester.getCenter(find.byType(InteractiveCanvasViewer));
    final pen = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 8; i++) {
      await pen.moveBy(const Offset(15, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pump();
    expect(editor.coreInfo.pages[0].strokes, isNotEmpty);

    // The wrist swipes back straight away: the note stays open.
    await tester.binding.handlePopRoute();
    await settle();
    expect(find.byType(Editor), findsOneWidget);
    expect(find.text(t.editor.penGuard.backPaused), findsOneWidget);

    // A moment later, back saves and leaves as usual.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 3; i++) {
      await settle();
    }
    expect(find.byType(Editor), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
