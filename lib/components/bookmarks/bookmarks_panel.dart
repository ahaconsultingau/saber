import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/editor/floating_side_panel.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/bookmarks/note_bookmarks.dart';
import 'package:saber/i18n/strings.g.dart';

/// "Thu 6 Nov 2026"
String formatBookmarkDate(DateTime date) =>
    DateFormat('EEE d MMM y').format(date);

/// Aha! copy: the Bookmarks panel, floating on the right of a note.
/// Lists the note's bookmarks, newest date first; tap one to jump to its
/// page, long-press to rename, re-date or remove it.
class BookmarksPanel extends StatelessWidget {
  const new({
    super.key,
    required this.bookmarks,
    required this.pageNumberOf,
    required this.currentPageIsBookmarked,
    required this.onJump,
    required this.onBookmarkThisPage,
    required this.onNewMeeting,
    required this.onEdit,
    required this.onClose,
  });

  final List<NoteBookmark> bookmarks;

  /// 1-based page number of a bookmark's page.
  final int Function(NoteBookmark) pageNumberOf;
  final bool currentPageIsBookmarked;
  final ValueChanged<NoteBookmark> onJump;
  final VoidCallback onBookmarkThisPage;
  final VoidCallback onNewMeeting;
  final ValueChanged<NoteBookmark> onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final strings = t.editor.bookmarks;
    final sorted = [...bookmarks]..sort((a, b) => b.date.compareTo(a.date));

    return FloatingSidePanel(
      key: const ValueKey('bookmarksPanel'),
      title: strings.title,
      onClose: onClose,
      children: [
        FilledButton.icon(
          onPressed: onNewMeeting,
          icon: const Icon(Icons.add),
          label: Text(strings.newMeeting),
        ),
        OutlinedButton.icon(
          onPressed: currentPageIsBookmarked ? null : onBookmarkThisPage,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(
            currentPageIsBookmarked
                ? strings.thisPageIsBookmarked
                : strings.bookmarkThisPage,
          ),
        ),
        const Divider(),
        if (sorted.isEmpty)
          Padding(
            padding: const .all(8),
            child: Text(
              strings.empty,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final b in sorted)
                Card(
                  margin: const .only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(
                      b.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      strings.dateAndPage(
                        date: formatBookmarkDate(b.date),
                        page: pageNumberOf(b),
                      ),
                    ),
                    onTap: () => onJump(b),
                    onLongPress: () => onEdit(b),
                    trailing: IconButton(
                      tooltip: strings.edit,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => onEdit(b),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the bookmark dialog returns.
sealed class BookmarkDialogResult;

class BookmarkSaved extends BookmarkDialogResult {
  new(this.name, this.date, this.writeHeading);
  final String name;
  final DateTime date;
  final bool writeHeading;
}

class BookmarkRemoved extends BookmarkDialogResult;

/// Aha! copy: names and dates a bookmark. For a new bookmark it can also
/// write the name and date at the top of the page (so the Mac app, which
/// has no bookmarks list, shows them too). For an existing one it offers
/// Remove.
class BookmarkDialog extends StatefulWidget {
  const new({
    super.key,
    required this.initialName,
    required this.initialDate,
    required this.isNew,
  });

  final String initialName;
  final DateTime initialDate;
  final bool isNew;

  @override
  State<BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<BookmarkDialog> {
  late final name = TextEditingController(text: widget.initialName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  late var date = widget.initialDate;
  var writeHeading = true;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    final text = name.text.trim();
    Navigator.of(context).pop<BookmarkDialogResult>(
      BookmarkSaved(
        text.isEmpty ? widget.initialName : text,
        date,
        widget.isNew && writeHeading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.editor.bookmarks;
    return AdaptiveAlertDialog(
      title: Text(widget.isNew ? strings.bookmarkThisPage : strings.edit),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 14,
          children: [
            TextField(
              key: const ValueKey('bookmarkName'),
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.name,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            InkWell(
              key: const ValueKey('bookmarkDate'),
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: strings.date,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
                child: Text(formatBookmarkDate(date)),
              ),
            ),
            if (widget.isNew)
              CheckboxListTile(
                key: const ValueKey('bookmarkWriteHeading'),
                contentPadding: .zero,
                controlAffinity: .leading,
                value: writeHeading,
                onChanged: (v) => setState(() => writeHeading = v ?? false),
                title: Text(strings.writeHeading),
              ),
          ],
        ),
      ),
      actions: [
        if (!widget.isNew)
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context)
                    .pop<BookmarkDialogResult>(BookmarkRemoved()),
            child: Text(strings.remove),
          ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _save,
          child: Text(strings.save),
        ),
      ],
    );
  }
}
