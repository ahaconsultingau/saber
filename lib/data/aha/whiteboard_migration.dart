import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/whiteboard.dart';

/// Aha! copy: the side bar's Whiteboard (one scratch page that never
/// became a named note) is replaced by New note. Anything still on the
/// Whiteboard is moved, once, into a named note ("Whiteboard 6 Nov 2026")
/// at the top of Recent notes, so nothing is lost.
abstract final class WhiteboardMigration {
  static final log = Logger('WhiteboardMigration');
  static var _ran = false;

  /// Moves the Whiteboard into a named note if it has anything on it.
  /// Returns the new note's path (no extension), or null if there was
  /// nothing to move. Runs at most once per app start.
  static Future<String?> run({DateTime? now}) async {
    if (_ran) return null;
    _ran = true;
    try {
      return await _move(now ?? DateTime.now());
    } catch (e, st) {
      // Never let this break the home page; the Whiteboard file stays put.
      log.warning('Could not move the Whiteboard into a note: $e', e, st);
      return null;
    }
  }

  static Future<String?> _move(DateTime now) async {
    const whiteboardFile = Whiteboard.filePath + Editor.extension;
    if (!FileManager.doesFileExist(whiteboardFile)) return null;

    final info = await EditorCoreInfo.loadFromFilePath(Whiteboard.filePath);
    final isEmpty = info.isEmpty;
    info.dispose();
    if (isEmpty) return null;

    final date = DateFormat('d MMM y').format(now);
    final notePath = await FileManager.suffixFilePathToMakeItUnique(
      '/Whiteboard $date',
    );
    await FileManager.moveFile(whiteboardFile, notePath + Editor.extension);

    final recent = notePath + Editor.extension;
    stows.recentFiles.value
      ..remove(recent)
      ..insert(0, recent);
    stows.recentFiles.notifyListeners();
    log.info('Moved the Whiteboard into $notePath');
    return notePath;
  }

  static void resetForTesting() => _ran = false;
}
