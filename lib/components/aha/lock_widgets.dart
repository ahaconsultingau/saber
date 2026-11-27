import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/aha/note_locks.dart';
import 'package:saber/i18n/strings.g.dart';

/// Aha! copy: asks for a lock's password, in place of what it covers (a
/// note, or a folder's contents).
class LockPrompt extends StatefulWidget {
  const new({super.key, required this.lockKey, required this.name});

  /// The lock to open (see [NoteLocks]).
  final String lockKey;

  /// The note or folder's name, shown above the field.
  final String name;

  @override
  State<LockPrompt> createState() => _LockPromptState();
}

class _LockPromptState extends State<LockPrompt> {
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  void _unlock() {
    if (!NoteLocks.unlock(widget.lockKey, password.text)) {
      setState(() => error = t.locks.wrongPassword);
      password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const .all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            key: const ValueKey('lockPrompt'),
            mainAxisSize: .min,
            spacing: 16,
            children: [
              Icon(Icons.lock_outline, size: 56, color: colorScheme.primary),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: TextTheme.of(context).titleLarge,
              ),
              Text(
                t.locks.locked,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              TextField(
                key: const ValueKey('lockPassword'),
                controller: password,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: t.locks.password,
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              FilledButton.icon(
                key: const ValueKey('lockUnlock'),
                onPressed: _unlock,
                icon: const Icon(Icons.lock_open),
                label: Text(t.locks.unlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aha! copy: adds a lock to [lockKey], or (when it has one) removes it.
/// Returns whether anything changed.
Future<bool> showLockDialog(
  BuildContext context, {
  required String lockKey,
  required String name,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _LockDialog(lockKey: lockKey, name: name),
  );
  return changed ?? false;
}

class _LockDialog extends StatefulWidget {
  const new({required this.lockKey, required this.name});

  final String lockKey;
  final String name;

  @override
  State<_LockDialog> createState() => _LockDialogState();
}

class _LockDialogState extends State<_LockDialog> {
  late final removing = NoteLocks.hasLock(widget.lockKey);
  final password = TextEditingController();
  final confirm = TextEditingController();
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void _done() {
    if (removing) {
      if (!NoteLocks.removeLock(widget.lockKey, password.text)) {
        return setState(() => error = t.locks.wrongPassword);
      }
    } else {
      if (password.text.length < 4) {
        return setState(() => error = t.locks.tooShort);
      }
      if (password.text != confirm.text) {
        return setState(() => error = t.locks.doesNotMatch);
      }
      NoteLocks.setLock(widget.lockKey, password.text);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAlertDialog(
      title: Text(removing ? t.locks.removeTitle : t.locks.addTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Text(widget.name, style: TextTheme.of(context).titleMedium),
            if (!removing) Text(t.locks.addHelp),
            TextField(
              key: const ValueKey('lockDialogPassword'),
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t.locks.password,
                errorText: removing ? error : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => removing ? _done() : null,
            ),
            if (!removing)
              TextField(
                key: const ValueKey('lockDialogConfirm'),
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.locks.confirm,
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _done(),
              ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          key: const ValueKey('lockDialogDone'),
          isDefaultAction: true,
          onPressed: _done,
          child: Text(removing ? t.locks.remove : t.locks.lock),
        ),
      ],
    );
  }
}

/// Aha! copy: the lock button in the bar shown when one note is selected.
class LockNoteButton extends StatelessWidget {
  const new({super.key, required this.notePath, required this.unselectNotes});

  final String notePath;
  final VoidCallback unselectNotes;

  @override
  Widget build(BuildContext context) {
    final locked = NoteLocks.hasLock(notePath);
    return IconButton(
      key: const ValueKey('lockNoteButton'),
      padding: EdgeInsets.zero,
      tooltip: locked ? t.locks.removeTitle : t.locks.addTitle,
      onPressed: () async {
        final changed = await showLockDialog(
          context,
          lockKey: notePath,
          name: notePath.substring(notePath.lastIndexOf('/') + 1),
        );
        if (changed) unselectNotes();
      },
      icon: Icon(locked ? Icons.lock_open : Icons.lock_outline),
    );
  }
}
