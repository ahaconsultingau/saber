import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/aha/whiteboard_migration.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/main.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/pages/home/whiteboard.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Reported: writing on the Whiteboard didn't make a note, and the + was
/// hard to find. Chosen: the side bar's pen icon becomes New note, the
/// Whiteboard's writing moves into a named note, and the + is a solid
/// "+ New note" button.
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.sentryConsent.value = .granted;
    stows.layoutSize.value = .tablet;
    WhiteboardMigration.resetForTesting();
  });

  void freshFolder(String name) {
    FileManager.documentsDirectory =
        '$tmpDir/$name/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    stows.recentFiles.value = [];
  }

  Future<void> writeWhiteboard() async {
    final info = EditorCoreInfo(filePath: Whiteboard.filePath);
    final page = EditorPage();
    info.pages.add(page);
    page.strokes.add(
      Stroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 5, isComplete: true),
        pageIndex: 0,
        page: page,
        toolId: .ballpointPen,
      )..addPoints(const [Offset(10, 10), Offset(50, 50)]),
    );
    final (bson, _) = info.saveToBinary(currentPageIndex: 0);
    await FileManager.writeFile(
      Whiteboard.filePath + Editor.extension,
      bson,
      awaitWrite: true,
    );
    stows.recentFiles.value = [];
  }

  test(
    'The Whiteboard\'s writing becomes a named note in Recent notes',
    () async {
      freshFolder('whiteboardMigration');
      await writeWhiteboard();
      final path = await WhiteboardMigration.run(now: DateTime(2026, 11, 6));
      expect(path, '/Whiteboard 6 Nov 2026');
      expect(
        FileManager.doesFileExist('/Whiteboard 6 Nov 2026${Editor.extension}'),
        isTrue,
      );
      expect(
        FileManager.doesFileExist(Whiteboard.filePath + Editor.extension),
        isFalse,
      );
      expect(stows.recentFiles.value.first, '/Whiteboard 6 Nov 2026.sbn2');
      final moved = await EditorCoreInfo.loadFromFilePath(path!);
      expect(moved.pages.first.strokes, hasLength(1));
    },
  );

  test('An empty or missing Whiteboard makes no note', () async {
    freshFolder('whiteboardMigrationEmpty');
    expect(await WhiteboardMigration.run(), isNull);
    expect(stows.recentFiles.value, isEmpty);
  });

  testWidgets('The side bar\'s New note and the + both open the sheet', (
    tester,
  ) async {
    freshFolder('sideBarNewNote');
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: App.initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => HomePage(
            subpage: state.pathParameters['subpage'] ?? HomePage.recentSubpage,
            path: state.uri.queryParameters['path'],
          ),
        ),
        GoRoute(
          path: RoutePaths.edit,
          builder: (context, state) =>
              Editor(path: state.uri.queryParameters['path']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // The + is a solid, labelled button.
    final fab = find.widgetWithText(
      FloatingActionButton,
      t.home.create.newNote,
    );
    expect(fab, findsOneWidget);

    // Side bar: the old Whiteboard icon is now New note.
    await tester.tap(find.byIcon(Icons.note_add_outlined));
    await tester.pumpAndSettle();
    expect(find.text(t.home.newNote.create), findsOneWidget);
    expect(find.byType(Whiteboard), findsNothing);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();

    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text(t.home.newNote.create), findsOneWidget);
  });
}
