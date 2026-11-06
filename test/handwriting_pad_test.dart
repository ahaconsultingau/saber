import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/bookmarks/bookmarks_panel.dart';
import 'package:saber/components/handwriting/handwriting_pad.dart';
import 'package:saber/components/home/new_note_dialog.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/handwriting/handwriting_recognizer.dart';
import 'package:saber/i18n/strings.g.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Joel: "Keyboard shows but want the option to write or skip".
/// The name boxes take the pen as well as the keyboard, and New note can
/// skip naming.
void main() {
  List<List<Offset>>? inkSeen;

  setUp(() {
    FlavorConfig.setup();
    setupMockPathProvider();
    FileManager.documentsDirectory =
        '$tmpDir/handwritingPad/${FileManager.appRootDirectoryPrefix}';
    final docs = Directory(FileManager.documentsDirectory);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
    docs.createSync(recursive: true);
    EditorCoreInfo.nextNewNotePattern = null;
    inkSeen = null;
    HandwritingRecognizer.debugIsSupported = true;
    HandwritingRecognizer.debugRecognizeInk = (strokes) async {
      inkSeen = strokes;
      return 'Bayside\nCouncil';
    };
  });

  tearDown(() {
    HandwritingRecognizer.debugIsSupported = null;
    HandwritingRecognizer.debugRecognizeInk = null;
  });

  Future<void> open(
    WidgetTester tester,
    Widget dialog,
    void Function(Object?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await showDialog<Object>(
                context: context,
                builder: (_) => dialog,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Writes a short stroke with the pen, then waits for it to be read.
  Future<void> writeInPad(WidgetTester tester) async {
    final pad = tester.getCenter(find.byKey(const ValueKey('handwritingPad')));
    final pen = await tester.startGesture(
      pad - const Offset(60, 0),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 6; i++) {
      await pen.moveBy(const Offset(20, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await tester.pump(
      HandwritingPad.readDelay + const Duration(milliseconds: 50),
    );
    await tester.pumpAndSettle();
  }

  String nameIn(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets('Writing in the New note pad fills in the name', (tester) async {
    await open(tester, const NewNoteDialog(folders: ['/']), (_) {});
    await writeInPad(tester);
    expect(inkSeen, hasLength(1));
    expect(inkSeen!.single.length, greaterThan(3));
    expect(nameIn(tester, 'newNoteName'), 'Bayside Council');
  });

  testWidgets('The written name can be created like a typed one', (
    tester,
  ) async {
    Object? result;
    await open(tester, const NewNoteDialog(folders: ['/']), (r) => result = r);
    await writeInPad(tester);
    await tester.tap(find.text(t.home.newNote.create));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(result, '/Bayside Council');
  });

  testWidgets('Skip gives the note Saber\'s dated name', (tester) async {
    Object? result;
    await open(tester, const NewNoteDialog(folders: ['/']), (r) => result = r);
    await tester.enterText(find.byKey(const ValueKey('newNoteName')), 'Draft');
    await tester.tap(find.text(t.home.newNote.skip));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(result, isA<String>());
    expect(result as String, contains(t.editor.untitled));
    expect(result as String, isNot(contains('Draft')));
  });

  testWidgets('Clear wipes the pad without touching the name', (tester) async {
    await open(tester, const NewNoteDialog(folders: ['/']), (_) {});
    await writeInPad(tester);
    await tester.tap(find.byTooltip(t.editor.handwritingPad.clear));
    await tester.pumpAndSettle();
    expect(find.text(t.editor.handwritingPad.hint), findsOneWidget);
    expect(nameIn(tester, 'newNoteName'), 'Bayside Council');
  });

  testWidgets('No pad where handwriting can\'t be read', (tester) async {
    HandwritingRecognizer.debugIsSupported = false;
    await open(tester, const NewNoteDialog(folders: ['/']), (_) {});
    expect(find.byKey(const ValueKey('handwritingPad')), findsNothing);
    expect(find.byKey(const ValueKey('newNoteName')), findsOneWidget);
  });

  testWidgets('The bookmark dialog takes a written name too', (tester) async {
    await open(
      tester,
      BookmarkDialog(
        initialName: '',
        initialDate: DateTime(2026, 11, 6),
        isNew: true,
      ),
      (_) {},
    );
    await writeInPad(tester);
    expect(nameIn(tester, 'bookmarkName'), 'Bayside Council');
  });

  testWidgets('A stroke Android cancels is still read', (tester) async {
    await open(tester, const NewNoteDialog(folders: ['/']), (_) {});
    final pad = tester.getCenter(find.byKey(const ValueKey('handwritingPad')));
    final pen = await tester.startGesture(
      pad - const Offset(60, 0),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 0; i < 6; i++) {
      await pen.moveBy(const Offset(20, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.cancel();
    await tester.pump(
      HandwritingPad.readDelay + const Duration(milliseconds: 50),
    );
    await tester.pumpAndSettle();
    expect(nameIn(tester, 'newNoteName'), 'Bayside Council');
  });

  testWidgets('When no words are found, it says so', (tester) async {
    HandwritingRecognizer.debugRecognizeInk = (_) async => '';
    await open(tester, const NewNoteDialog(folders: ['/']), (_) {});
    await writeInPad(tester);
    expect(find.text(t.editor.handwritingPad.noText), findsOneWidget);
    expect(nameIn(tester, 'newNoteName'), '');
  });
}
