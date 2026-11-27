import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/pages/editor/editor.dart';

/// Aha! copy: a named, dated bookmark on one page of a note.
///
/// While a note is open, a bookmark holds its [EditorPage] itself, so it
/// follows the page when pages are added, moved, deleted or undone. The page
/// number is worked out when saving.
class NoteBookmark {
  new({required this.name, required this.date, required this.page});

  String name;
  DateTime date;
  EditorPage page;
}

/// Reads and writes a note's bookmarks.
///
/// They live in a companion file beside the note (`<note>.sbn2.bm`), not in
/// the note itself, so the standard Saber apps (which don't know about
/// bookmarks) can open and save the note without losing them. Saber's sync
/// carries the companion file like any other file in the notes folder.
abstract final class NoteBookmarks {
  static final log = Logger('NoteBookmarks');

  /// The companion file's extension, after the note's own (`.sbn2`).
  static const suffix = '.bm';

  static String pathFor(String notePath) =>
      '$notePath${Editor.extension}$suffix';

  /// Loads [notePath]'s bookmarks, matched to [pages]. Bookmarks whose page
  /// no longer exists are left out.
  static Future<List<NoteBookmark>> load(
    String notePath,
    List<EditorPage> pages,
  ) async {
    final bytes = await FileManager.readFile(pathFor(notePath));
    if (bytes == null) return [];
    try {
      return decode(utf8.decode(bytes), pages);
    } catch (e, st) {
      log.warning('Could not read bookmarks for $notePath: $e', e, st);
      return [];
    }
  }

  static List<NoteBookmark> decode(String json, List<EditorPage> pages) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final list = map['bookmarks'] as List<dynamic>? ?? const [];
    // Read each entry on its own: one damaged entry (e.g. from a sync
    // merge) is skipped rather than losing every bookmark.
    return [
      for (final item in list)
        if (item is Map &&
            item['page'] is int &&
            (item['page'] as int) >= 0 &&
            (item['page'] as int) < pages.length)
          NoteBookmark(
            name: item['name'] is String ? item['name'] as String : '',
            date:
                DateTime.tryParse(
                  item['date'] is String ? item['date'] as String : '',
                ) ??
                DateTime.now(),
            page: pages[item['page'] as int],
          ),
    ];
  }

  /// The bookmarks as JSON, newest date first. Bookmarks whose page has
  /// been deleted are dropped.
  static String encode(List<NoteBookmark> bookmarks, List<EditorPage> pages) {
    final kept = [
      for (final b in bookmarks)
        if (pages.indexOf(b.page) case final int index when index >= 0)
          (b, index),
    ]..sort((a, b) => b.$1.date.compareTo(a.$1.date));
    return jsonEncode({
      'v': 1,
      'bookmarks': [
        for (final (b, index) in kept)
          {'name': b.name, 'date': _dateOnly(b.date), 'page': index},
      ],
    });
  }

  /// Writes the bookmarks, or removes the file when there are none.
  static Future<void> save(
    String notePath,
    List<NoteBookmark> bookmarks,
    List<EditorPage> pages,
  ) async {
    final path = pathFor(notePath);
    final live = bookmarks.where((b) => pages.contains(b.page));
    if (live.isEmpty) {
      if (FileManager.doesFileExist(path)) {
        await FileManager.deleteFile(path, alsoDeleteAssets: false);
      }
      return;
    }
    await FileManager.writeFile(
      path,
      utf8.encode(encode(bookmarks, pages)),
      awaitWrite: true,
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
