import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/aha/note_locks.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "add the ability to lock a note or folder with a password".
/// Chosen: a lock inside Saber Aha (the files themselves aren't encrypted).
void main() {
  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    setupMockWindowManager();
    NoteLocks.resetForTesting();
  });

  group('Locks', () {
    test('A note locks, opens only with its password, and unlocks', () {
      NoteLocks.setLock('/Clients/Bayside', 'kangaroo');
      expect(NoteLocks.isNoteLocked('/Clients/Bayside'), isTrue);
      expect(NoteLocks.isNoteLocked('/Clients/Other'), isFalse);
      expect(NoteLocks.unlock('/Clients/Bayside', 'wrong'), isFalse);
      expect(NoteLocks.isNoteLocked('/Clients/Bayside'), isTrue);
      expect(NoteLocks.unlock('/Clients/Bayside', 'kangaroo'), isTrue);
      expect(NoteLocks.isNoteLocked('/Clients/Bayside'), isFalse);
      NoteLocks.lockAll();
      expect(NoteLocks.isNoteLocked('/Clients/Bayside'), isTrue);
    });

    test('The password is never stored as typed', () {
      NoteLocks.setLock('/Secret', 'kangaroo');
      final stored = stows.noteLocks.value.join();
      expect(stored, isNot(contains('kangaroo')));
      expect(stored, contains('pbkdf2-sha256'));
    });

    test('A locked folder covers every note and folder inside it', () {
      NoteLocks.setLock(NoteLocks.folderKey('/Clients'), 'wombat');
      expect(NoteLocks.isNoteLocked('/Clients/Bayside'), isTrue);
      expect(NoteLocks.isNoteLocked('/Clients/Sub/Deep note'), isTrue);
      expect(NoteLocks.isFolderLocked('/Clients/Sub'), isTrue);
      expect(NoteLocks.isNoteLocked('/Clientsfile'), isFalse);
      expect(NoteLocks.unlock('/Clients/', 'wombat'), isTrue);
      expect(NoteLocks.isNoteLocked('/Clients/Sub/Deep note'), isFalse);
    });

    test('Removing a lock needs the password', () {
      NoteLocks.setLock('/A', 'one1');
      expect(NoteLocks.removeLock('/A', 'nope'), isFalse);
      expect(NoteLocks.hasLock('/A'), isTrue);
      expect(NoteLocks.removeLock('/A', 'one1'), isTrue);
      expect(NoteLocks.hasLock('/A'), isFalse);
    });

    test('Locks follow renames and moves, and go with deletes', () async {
      FileManager.documentsDirectory =
          '$tmpDir/locksMove/${FileManager.appRootDirectoryPrefix}';
      final docs = Directory(FileManager.documentsDirectory);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
      docs.createSync(recursive: true);
      await FileManager.writeFile('/Old${Editor.extension}', [1, 2, 3]);
      NoteLocks.setLock('/Old', 'pass1');
      await FileManager.moveFile(
        '/Old${Editor.extension}',
        '/Clients/New${Editor.extension}',
      );
      expect(NoteLocks.hasLock('/Old'), isFalse);
      expect(NoteLocks.hasLock('/Clients/New'), isTrue);

      NoteLocks.setLock('/Clients/', 'pass2');
      await FileManager.renameDirectory('/Clients', 'Customers');
      expect(NoteLocks.hasLock('/Customers/'), isTrue);
      expect(NoteLocks.hasLock('/Customers/New'), isTrue);

      await FileManager.deleteDirectory('/Customers');
      expect(stows.noteLocks.value, isEmpty);
    });
  });

  testWidgets('A locked note asks for its password before it opens', (
    tester,
  ) async {
    FileManager.documentsDirectory =
        '$tmpDir/locksEditor/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    NoteLocks.setLock('/Private', 'echidna');

    await tester.pumpWidget(MaterialApp(home: Editor(path: '/Private')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);

    expect(find.byKey(const ValueKey('lockPrompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('noteTitle')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('lockPassword')), 'nope');
    await tester.tap(find.byKey(const ValueKey('lockUnlock')));
    await tester.pumpAndSettle();
    expect(find.text(t.locks.wrongPassword), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('lockPassword')),
      'echidna',
    );
    await tester.tap(find.byKey(const ValueKey('lockUnlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lockPrompt')), findsNothing);
    expect(find.byKey(const ValueKey('noteTitle')), findsOneWidget);

    // Left for a while, it locks again over the open note, and unlocks
    // back to the same note (nothing it held was thrown away).
    NoteLocks.lockAll();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lockPrompt')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('lockPassword')),
      'echidna',
    );
    await tester.tap(find.byKey(const ValueKey('lockUnlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('noteTitle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A locked note\'s preview is hidden', (tester) async {
    FileManager.documentsDirectory =
        '$tmpDir/locksPreview/${FileManager.appRootDirectoryPrefix}';
    NoteLocks.setLock('/Private', 'echidna');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: PreviewCard(
              filePath: '/Private',
              toggleSelection: (_, _) {},
              selected: false,
              isAnythingSelected: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('lockedThumbnail')), findsOneWidget);
    NoteLocks.unlock('/Private', 'echidna');
    await tester.pump();
    expect(find.byKey(const ValueKey('lockedThumbnail')), findsNothing);
  });
}
