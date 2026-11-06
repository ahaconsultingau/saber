import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/main.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/home.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Reported on the tablet: "made a note, clicked back and it didn't show".
/// Drives the real flow: Recent notes → New note → write → back.
void main() {
  testWidgets('A new note shows in Recent notes after going back', (
    tester,
  ) async {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.sentryConsent.value = .granted;
    stows.layoutSize.value = .tablet;
    FileManager.documentsDirectory =
        '$tmpDir/newNoteRecents/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    stows.recentFiles.value = [];

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
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(PreviewCard), findsNothing);

    // New note
    await tester.tap(find.byTooltip(t.home.tooltips.newNote));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.home.create.newNote));
    await tester.pumpAndSettle();
    // The New note sheet asks for a name first.
    expect(find.text(t.home.newNote.title), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('newNoteName')),
      'Bayside Council',
    );
    await tester.tap(find.text(t.home.newNote.create));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    expect(editor.coreInfo.filePath, '/Bayside Council');

    // Write a stroke with the pen, through the real drawing handlers.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final box = editor.coreInfo.pages[0].renderBox!;
    editor.dragPageIndex = 0;
    editor.onDrawStart(
      ScaleStartDetails(focalPoint: box.localToGlobal(const Offset(100, 100))),
    );
    editor.onDrawUpdate(
      ScaleUpdateDetails(focalPoint: box.localToGlobal(const Offset(200, 150))),
    );
    editor.onDrawEnd(ScaleEndDetails());
    await tester.pump();
    expect(editor.coreInfo.pages[0].strokes, isNotEmpty);

    // Back, like the system back button. Before the fix, the first press only
    // started the save and showed "still saving", so a second was needed.
    var backPresses = 0;
    for (var i = 0; i < 3 && find.byType(Editor).evaluate().isNotEmpty; i++) {
      backPresses++;
      await tester.binding.handlePopRoute();
      for (var j = 0; j < 30; j++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(backPresses, 1, reason: 'one tap on back saves and leaves');

    for (var j = 0; j < 10; j++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Editor), findsNothing);
    expect(find.byType(PreviewCard), findsOneWidget);
    expect(find.text('Bayside Council'), findsOneWidget);
  });

  testWidgets('The back arrow saves and leaves in one tap', (tester) async {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    stows.sentryConsent.value = .granted;
    stows.layoutSize.value = .tablet;
    FileManager.documentsDirectory =
        '$tmpDir/backArrow/${FileManager.appRootDirectoryPrefix}';
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
    router.push(RoutePaths.editFilePath('/Back arrow note'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    final box = editor.coreInfo.pages[0].renderBox!;
    editor.dragPageIndex = 0;
    editor.onDrawStart(
      ScaleStartDetails(focalPoint: box.localToGlobal(const Offset(100, 100))),
    );
    editor.onDrawUpdate(
      ScaleUpdateDetails(focalPoint: box.localToGlobal(const Offset(200, 150))),
    );
    editor.onDrawEnd(ScaleEndDetails());
    await tester.pump();
    expect(find.text(t.editor.saveState.notSaved), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    for (var j = 0; j < 30; j++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Editor), findsNothing);
    expect(
      FileManager.doesFileExist('/Back arrow note${Editor.extension}'),
      isTrue,
    );
  });
}
