import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/prefs.dart';

/// Aha! copy: password locks on notes and folders, inside this app.
///
/// A locked note (or any note in a locked folder) asks for its password
/// before it opens, and its preview is hidden. The files themselves are
/// not encrypted: the Mac's standard Saber, and anyone with the files, can
/// still read them. Passwords are stored only as salted PBKDF2 hashes, on
/// this tablet (not synced).
///
/// A lock's key is a note's path without its extension (`/Clients/Bayside`)
/// or a folder's path with a trailing slash (`/Clients/`).
abstract final class NoteLocks {
  /// Notifies when a lock is added, removed, unlocked or locked again.
  static final changes = _Changes();

  /// Locks unlocked since the app was last left for a while.
  static final _unlocked = <String>{};

  /// How long the app can be left before everything locks again.
  static const relockAfter = Duration(minutes: 2);

  static AppLifecycleListener? _lifecycle;
  static DateTime? _leftAt;

  /// Starts relocking when the app is left (call once the app is running).
  static void watchAppLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onHide: () => _leftAt = DateTime.now(),
      onShow: () {
        final left = _leftAt;
        _leftAt = null;
        if (left != null && DateTime.now().difference(left) >= relockAfter) {
          lockAll();
        }
      },
    );
  }

  static String folderKey(String folder) {
    var f = folder.isEmpty ? '/' : folder;
    if (!f.startsWith('/')) f = '/$f';
    return f.endsWith('/') ? f : '$f/';
  }

  static Map<String, String> get _stored => {
    for (final entry in stows.noteLocks.value)
      if (entry.indexOf('\n') case final i when i > 0)
        entry.substring(0, i): entry.substring(i + 1),
  };

  static void _save(Map<String, String> locks) {
    stows.noteLocks.value = [
      for (final MapEntry(:key, :value) in locks.entries) '$key\n$value',
    ];
    changes._changed();
  }

  /// Whether [key] (a note path or folder key) has its own lock.
  static bool hasLock(String key) => _stored.containsKey(key);

  /// The lock that covers the note at [notePath]: its own, or the nearest
  /// locked folder above it.
  static String? lockForNote(String notePath) {
    final locks = _stored;
    if (locks.containsKey(notePath)) return notePath;
    return _lockForFolderOf(locks, notePath);
  }

  /// The lock that covers the folder [folder] (itself or a folder above).
  static String? lockForFolder(String folder) {
    final locks = _stored;
    final key = folderKey(folder);
    if (locks.containsKey(key)) return key;
    return _lockForFolderOf(locks, key.substring(0, key.length - 1));
  }

  static String? _lockForFolderOf(Map<String, String> locks, String path) {
    var i = path.lastIndexOf('/');
    String? found;
    // Walk up, keeping the topmost locked folder.
    while (i >= 0) {
      final folder = path.substring(0, i + 1);
      if (locks.containsKey(folder)) found = folder;
      if (i == 0) break;
      i = path.lastIndexOf('/', i - 1);
    }
    return found;
  }

  /// Whether the note at [notePath] needs its password now.
  static bool isNoteLocked(String notePath) {
    final key = lockForNote(notePath);
    return key != null && !_unlocked.contains(key);
  }

  /// Whether the folder [folder] needs its password now.
  static bool isFolderLocked(String folder) {
    final key = lockForFolder(folder);
    return key != null && !_unlocked.contains(key);
  }

  /// Unlocks [key] if [password] is right.
  static bool unlock(String key, String password) {
    final stored = _stored[key];
    if (stored == null || !_matches(stored, password)) return false;
    _unlocked.add(key);
    changes._changed();
    return true;
  }

  /// Locks [key] with [password].
  static void setLock(String key, String password) {
    final locks = _stored..[key] = _hash(password);
    _unlocked.remove(key);
    _save(locks);
  }

  /// Removes the lock on [key] if [password] is right.
  static bool removeLock(String key, String password) {
    final locks = _stored;
    final stored = locks[key];
    if (stored == null || !_matches(stored, password)) return false;
    locks.remove(key);
    _unlocked.remove(key);
    _save(locks);
    return true;
  }

  /// Locks everything again.
  static void lockAll() {
    if (_unlocked.isEmpty) return;
    _unlocked.clear();
    changes._changed();
  }

  /// Keeps locks with a note or folder when it is moved or renamed.
  /// [from] and [to] are note paths (no extension) or folder keys.
  static void moved(String from, String to) {
    final locks = _stored;
    var changed = false;
    for (final key in locks.keys.toList()) {
      String? newKey;
      if (key == from) {
        newKey = to;
      } else if (from.endsWith('/') && key.startsWith(from)) {
        newKey = to + key.substring(from.length);
      }
      if (newKey == null) continue;
      locks[newKey] = locks.remove(key)!;
      if (_unlocked.remove(key)) _unlocked.add(newKey);
      changed = true;
    }
    if (changed) _save(locks);
  }

  /// Forgets locks on a deleted note or folder.
  static void deleted(String path) {
    final locks = _stored;
    final before = locks.length;
    locks.removeWhere(
      (key, _) => key == path || (path.endsWith('/') && key.startsWith(path)),
    );
    if (locks.length != before) _save(locks);
  }

  @visibleForTesting
  static void resetForTesting() {
    _unlocked.clear();
    stows.noteLocks.value = [];
  }

  static const _iterations = 20000;

  static String _hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256)),
    );
    final hash = _pbkdf2(utf8.encode(password), salt, _iterations);
    return 'pbkdf2-sha256\$$_iterations\$${base64Encode(salt)}\$${base64Encode(hash)}';
  }

  static bool _matches(String stored, String password) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
    final iterations = int.tryParse(parts[1]) ?? _iterations;
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = _pbkdf2(utf8.encode(password), salt, iterations);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 with HMAC-SHA256, one 32-byte block.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.of(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }
}

class _Changes extends ChangeNotifier {
  void _changed() => notifyListeners();
}
