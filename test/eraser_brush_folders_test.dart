import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/browse.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "Give adjustment ability to the eraser. Add the ability to drag
/// and drop notes to arrange them into folders. Add feathering option for
/// the brushes and width".
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.eraserSize.value = 10;
    stows.lastBrushFeather.value = 0;
    stows.lastTool.value = ToolId.fountainPen;
    stows.lastPenIsBrush.value = false;
    Pen.currentPen = Pen.fountainPen();
  });

  group('Eraser size', () {
    Stroke line(EditorPage page, double y) => Stroke(
      color: Colors.black,
      pressureEnabled: false,
      options: StrokeOptions(size: 3, isComplete: true),
      pageIndex: 0,
      page: page,
      toolId: ToolId.fountainPen,
    )..addPoints([Offset(100, y), Offset(400, y), Offset(400, y)]);

    test('A bigger eraser reaches strokes further away', () {
      final page = EditorPage(width: 1000, height: 1400);
      final stroke = line(page, 500);
      // 30 units above the end of the line.
      expect(
        Eraser(size: 10)
            .checkForOverlappingStrokes(const Offset(400, 470), [stroke]),
        isEmpty,
      );
      expect(
        Eraser(size: 40)
            .checkForOverlappingStrokes(const Offset(400, 470), [stroke]),
        [stroke],
      );
    });

    test('The eraser starts at the last size used', () {
      stows.eraserSize.value = 33;
      expect(Eraser().size, 33);
    });

    testWidgets('Choosing the eraser shows its size slider', (tester) async {
      FileManager.documentsDirectory =
          '$tmpDir/eraserSize/${FileManager.appRootDirectoryPrefix}';
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Editor()));
      await tester.pumpAndSettle();
      final editor = tester.state<EditorState>(find.byType(Editor));
      addTearDown(editor.cancelAutosaveAndMarkSaved);

      final slider = find.byKey(const ValueKey('eraserSize'));
      expect(slider, findsNothing);
      await tester.tap(find.byTooltip(t.editor.toolbar.toggleEraser));
      await tester.pumpAndSettle();
      expect(slider, findsOneWidget);

      // Drag the slider to the far end: biggest eraser.
      final s = find.descendant(of: slider, matching: find.byType(Slider));
      await tester.drag(s, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(stows.eraserSize.value, Eraser.maxSize);
      expect((editor.currentTool as Eraser).size, Eraser.maxSize);
    });
  });

  group('Brush feathering', () {
    test('Feathering is saved with the stroke, and read back', () {
      final page = EditorPage(width: 1000, height: 1400);
      final stroke =
          Stroke(
              color: Colors.black,
              pressureEnabled: true,
              options: Pen.brushOptions,
              pageIndex: 0,
              page: page,
              toolId: ToolId.fountainPen,
              feather: 0.6,
            )
            ..addPoint(const Offset(10, 10), 0.5)
            ..addPoint(const Offset(60, 20), 0.8);
      final json = stroke.toJson();
      expect(json['aF'], 0.6);
      final back = Stroke.fromJson(
        json,
        fileVersion: 20,
        pageIndex: 0,
        page: page,
      );
      expect(back.feather, 0.6);
      expect(stroke.copy().feather, 0.6);
      // A crisp stroke doesn't write the key.
      expect((stroke..feather = 0).toJson().containsKey('aF'), isFalse);
    });

    test('The brush starts with the last feathering used', () {
      stows.lastBrushFeather.value = 0.4;
      expect(Pen.brush().feather, 0.4);
      expect(Pen.fountainPen().feather, 0);
    });

    testWidgets('The brush options show width and feathering', (tester) async {
      FileManager.documentsDirectory =
          '$tmpDir/brushFeather/${FileManager.appRootDirectoryPrefix}';
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      stows.lastPenIsBrush.value = true;
      Pen.currentPen = Pen.brush();
      await tester.pumpWidget(MaterialApp(home: Editor()));
      await tester.pumpAndSettle();
      final editor = tester.state<EditorState>(find.byType(Editor));
      addTearDown(editor.cancelAutosaveAndMarkSaved);

      await tester.tap(find.byTooltip(t.editor.pens.brush).first);
      await tester.pumpAndSettle();
      final feather = find.byKey(const ValueKey('brushFeather'));
      expect(feather, findsOneWidget);
      await tester.drag(
        find.descendant(of: feather, matching: find.byType(Slider)),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(stows.lastBrushFeather.value, 1);
      expect(Pen.currentPen.feather, 1);
    });
  });

  group('Drag notes into folders', () {
    Future<void> openBrowse(WidgetTester tester, String name) async {
      FileManager.documentsDirectory =
          '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
      final docs = Directory(FileManager.documentsDirectory);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
      Directory('${docs.path}/Clients').createSync(recursive: true);
      File('${docs.path}/Meeting${Editor.extension}').writeAsBytesSync([0]);
      BrowsePage.overrideChildren = null;
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: HomeRoutes.browseFilePath('/'),
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (_, _) => const BrowsePage(),
              ),
            ],
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('Long-press a note and drop it on a folder to move it', (
      tester,
    ) async {
      await openBrowse(tester, 'dragToFolder');
      final card = find.byType(PreviewCard);
      expect(card, findsOneWidget);
      final folder = find.byKey(const ValueKey('folderDrop-Clients'));
      expect(folder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 600)); // long-press
      final to = tester.getCenter(folder);
      final from = tester.getCenter(card);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      for (
        var i = 0;
        i < 40 && find.byType(PreviewCard).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        FileManager.doesFileExist('/Clients/Meeting${Editor.extension}'),
        isTrue,
      );
      expect(FileManager.doesFileExist('/Meeting${Editor.extension}'), isFalse);
      expect(find.byType(PreviewCard), findsNothing, reason: 'moved away');
    });

    testWidgets('A long-press without dragging still selects the note', (
      tester,
    ) async {
      await openBrowse(tester, 'longPressSelects');
      await tester.longPress(find.byType(PreviewCard));
      await tester.pumpAndSettle();
      expect(find.byTooltip(t.home.deleteNote), findsOneWidget);
      expect(FileManager.doesFileExist('/Meeting${Editor.extension}'), isTrue);
    });
  });
}
