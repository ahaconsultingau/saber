import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/home/new_note_dialog.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Chosen design: + then New note asks for a name, folder and line style.
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    FileManager.documentsDirectory =
        '$tmpDir/newNoteDialog/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    Directory('${FileManager.documentsDirectory}/Clients/Bayside')
        .createSync(recursive: true);
    stows.newNoteBackgroundPattern.value = CanvasBackgroundPattern.lined;
    EditorCoreInfo.nextNewNotePattern = null;
  });

  Future<String?> openAndCreate(
    WidgetTester tester, {
    String name = '',
    String? folder,
    String? pattern,
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<String>(
              context: context,
              builder: (_) => const NewNoteDialog(
                folders: ['/', '/Clients', '/Clients/Bayside'],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Let the folder list load from disk.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    if (name.isNotEmpty) {
      await tester.enterText(find.byKey(const ValueKey('newNoteName')), name);
    }
    if (folder != null) {
      await tester.tap(find.byKey(const ValueKey('newNoteFolder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(folder).last);
      await tester.pumpAndSettle();
    }
    if (pattern != null) {
      await tester.tap(find.byKey(const ValueKey('newNotePattern')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pattern).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(t.home.newNote.create));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Name and folder make the note\'s path', (tester) async {
    final path = await openAndCreate(
      tester,
      name: 'Steering group',
      folder: 'Clients/Bayside',
    );
    expect(path, '/Clients/Bayside/Steering group');
  });

  testWidgets('A blank name gets Saber\'s dated name', (tester) async {
    final path = await openAndCreate(tester);
    expect(path, startsWith('/'));
    expect(path, contains(t.editor.untitled));
  });

  testWidgets('The chosen line style applies to that note only', (
    tester,
  ) async {
    await openAndCreate(tester, name: 'Grid note', pattern: 'Grid');
    final first = EditorCoreInfo(filePath: '/Grid note');
    expect(first.backgroundPattern, CanvasBackgroundPattern.grid);
    final next = EditorCoreInfo(filePath: '/Another');
    expect(next.backgroundPattern, CanvasBackgroundPattern.lined);
  });

  testWidgets('A name with a slash is refused, with a reason', (tester) async {
    final path = await openAndCreate(tester, name: 'a/b');
    expect(path, isNull);
    expect(find.byKey(const ValueKey('newNoteName')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('newNoteName')))
          .decoration!
          .errorText,
      isNotNull,
    );
  });

  test('Every folder is offered, nested ones too', () async {
    expect(await NewNoteDialog.listFolders(), [
      '/',
      '/Clients',
      '/Clients/Bayside',
    ]);
  });
}
