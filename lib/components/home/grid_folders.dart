import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/aha/lock_widgets.dart';
import 'package:saber/components/home/delete_folder_button.dart';
import 'package:saber/components/home/new_folder_dialog.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/components/home/rename_folder_button.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/data/aha/note_locks.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/i18n/strings.g.dart';

class GridFolders extends StatelessWidget {
  const new({
    super.key,
    required this.isAtRoot,
    required this.onTap,
    required this.crossAxisCount,
    required this.createFolder,
    required this.renameFolder,
    required this.isFolderEmpty,
    required this.deleteFolder,
    required this.doesFolderExist,
    required this.folders,
    this.parentPath,
    this.onNotesDropped,
  });

  final bool isAtRoot;
  final Function(String) onTap;
  final int crossAxisCount;

  final void Function(String) createFolder;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String oldName, String newName) renameFolder;
  final Future<bool> Function(String) isFolderEmpty;
  final Future<void> Function(String) deleteFolder;

  final List<String> folders;

  /// Aha! copy: the folder these are in, for their password locks.
  final String? parentPath;

  /// Aha! copy: notes dragged onto a folder card ('..' for the folder
  /// above). Null turns dropping off.
  final void Function(String folderName, List<String> notes)? onNotesDropped;

  @override
  Widget build(BuildContext context) {
    /// The cards that come before the actual folders
    final extraCards = <_FolderCardType>[
      if (!isAtRoot) .backFolder,
      .newFolder,
    ];

    return SliverPadding(
      padding: const .symmetric(horizontal: 12, vertical: 8),
      sliver: SliverAlignedGrid.count(
        itemCount: folders.length + extraCards.length,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        itemBuilder: (context, index) {
          final cardType = extraCards.getOrNull(index) ?? .realFolder;
          final folderName = cardType == .realFolder
              ? folders[index - extraCards.length]
              : null;
          return _GridFolder(
            cardType: cardType,
            folderName: folderName,
            createFolder: createFolder,
            doesFolderExist: doesFolderExist,
            renameFolder: renameFolder,
            isFolderEmpty: isFolderEmpty,
            deleteFolder: deleteFolder,
            onTap: onTap,
            parentPath: parentPath,
            onNotesDropped: onNotesDropped,
          );
        },
      ),
    );
  }
}

class _GridFolder extends StatefulWidget {
  const new({
    required this.cardType,
    required this.folderName,
    required this.createFolder,
    required this.doesFolderExist,
    required this.renameFolder,
    required this.isFolderEmpty,
    required this.deleteFolder,
    required this.onTap,
    this.parentPath,
    this.onNotesDropped,
  }) : assert(
         (folderName == null) ^ (cardType == .realFolder),
         'Real folders must specify a folder name',
       );

  final _FolderCardType cardType;
  final String? folderName;
  final void Function(String) createFolder;
  final bool Function(String) doesFolderExist;
  final Future<void> Function(String oldName, String newName) renameFolder;
  final Future<bool> Function(String) isFolderEmpty;
  final Future<void> Function(String) deleteFolder;
  final Function(String) onTap;
  final String? parentPath;
  final void Function(String folderName, List<String> notes)? onNotesDropped;

  /// The lock key of this folder.
  String get lockKey =>
      NoteLocks.folderKey('${parentPath ?? ''}/${folderName ?? ''}');

  @override
  State<_GridFolder> createState() => _GridFolderState();
}

class _GridFolderState extends State<_GridFolder> {
  ValueNotifier<bool> expanded = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final cardElevatedColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.05),
      colorScheme.surface,
    );
    // Aha! copy: notes can be dragged onto a folder (or onto the card for
    // the folder above) to move them there.
    final dropName = switch (widget.cardType) {
      .realFolder => widget.folderName,
      .backFolder => '..',
      .newFolder => null,
    };
    if (dropName == null || widget.onNotesDropped == null) {
      return _buildCard(context, colorScheme, cardElevatedColor);
    }
    return DragTarget<NoteDrag>(
      onAcceptWithDetails: (details) =>
          widget.onNotesDropped!(dropName, details.data.paths),
      builder: (context, candidates, _) => AnimatedContainer(
        key: ValueKey('folderDrop-$dropName'),
        duration: const Duration(milliseconds: 150),
        // Drawn over the card, so it doesn't change the card's size.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: candidates.isEmpty
                ? Colors.transparent
                : colorScheme.primary,
            width: 3,
          ),
        ),
        child: _buildCard(context, colorScheme, cardElevatedColor),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme colorScheme,
    Color cardElevatedColor,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (expanded.value) return;
          switch (widget.cardType) {
            case .newFolder:
              showDialog(
                context: context,
                builder: (context) => NewFolderDialog(
                  createFolder: widget.createFolder,
                  doesFolderExist: widget.doesFolderExist,
                ),
              );
            case .backFolder:
              widget.onTap('..');
            case .realFolder:
              widget.onTap(widget.folderName!);
          }
        },
        onLongPress: widget.cardType == .realFolder
            ? () => expanded.value = !expanded.value
            : null,
        onSecondaryTap: widget.cardType == .realFolder
            ? () => expanded.value = !expanded.value
            : null,
        child: Card(
          child: Padding(
            padding: const .all(8),
            child: Column(
              mainAxisSize: .min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Center(
                        child: Tooltip(
                          message: switch (widget.cardType) {
                            .backFolder => t.home.backFolder,
                            .newFolder => t.home.newFolder.newFolder,
                            .realFolder => '',
                          },
                          child: AdaptiveIcon(
                            icon: switch (widget.cardType) {
                              .backFolder => Icons.folder_open,
                              .newFolder => Icons.create_new_folder,
                              .realFolder => Icons.folder,
                            },
                            cupertinoIcon: switch (widget.cardType) {
                              .backFolder => CupertinoIcons.folder_open,
                              .newFolder =>
                                CupertinoIcons.folder_fill_badge_plus,
                              .realFolder => CupertinoIcons.folder_fill,
                            },
                            size: 50,
                          ),
                        ),
                      ),
                      if (widget.cardType == .realFolder)
                        Positioned.fill(
                          child: ValueListenableBuilder(
                            valueListenable: expanded,
                            builder: (context, expanded, child) =>
                                AnimatedOpacity(
                                  opacity: expanded ? 1 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: IgnorePointer(
                                    ignoring: !expanded,
                                    child: child!,
                                  ),
                                ),
                            child: GestureDetector(
                              onTap: () => expanded.value = !expanded.value,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: .topCenter,
                                    end: .bottomCenter,
                                    colors: [
                                      cardElevatedColor.withValues(alpha: 0.3),
                                      cardElevatedColor.withValues(alpha: 0.9),
                                      cardElevatedColor.withValues(alpha: 1),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: .center,
                                  crossAxisAlignment: .end,
                                  children: [
                                    RenameFolderButton(
                                      folderName: widget.folderName!,
                                      doesFolderExist: widget.doesFolderExist,
                                      renameFolder: (String folderName) async {
                                        await widget.renameFolder(
                                          widget.folderName!,
                                          folderName,
                                        );
                                        expanded.value = false;
                                      },
                                    ),
                                    // Aha! copy: lock with a password.
                                    IconButton(
                                      key: const ValueKey('lockFolderButton'),
                                      tooltip: NoteLocks.hasLock(widget.lockKey)
                                          ? t.locks.removeTitle
                                          : t.locks.addTitle,
                                      onPressed: () async {
                                        final changed = await showLockDialog(
                                          context,
                                          lockKey: widget.lockKey,
                                          name: widget.folderName!,
                                        );
                                        if (changed) expanded.value = false;
                                        if (mounted) setState(() {});
                                      },
                                      icon: Icon(
                                        NoteLocks.hasLock(widget.lockKey)
                                            ? Icons.lock_open
                                            : Icons.lock_outline,
                                      ),
                                    ),
                                    DeleteFolderButton(
                                      folderName: widget.folderName!,
                                      deleteFolder: (String folderName) async {
                                        await widget.deleteFolder(folderName);
                                        expanded.value = false;
                                      },
                                      isFolderEmpty: widget.isFolderEmpty,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                switch (widget.cardType) {
                  .backFolder => const Icon(Icons.arrow_back),
                  .newFolder => Text(t.home.newFolder.newFolder),
                  .realFolder => Row(
                    mainAxisSize: .min,
                    spacing: 4,
                    children: [
                      if (NoteLocks.hasLock(widget.lockKey))
                        const Icon(Icons.lock_outline, size: 16),
                      Flexible(child: Text(widget.folderName!)),
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _FolderCardType { backFolder, newFolder, realFolder }
