import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/editor/floating_side_panel.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/aha/note_drawings.dart';
import 'package:saber/i18n/strings.g.dart';

/// Aha! copy: what can be done to a layer from its menu.
enum LayerAction { rename, opacity, fillLines, mergeDown, delete }

/// Aha! copy: a drawing's layers, top first, in a panel on the right.
///
/// Tap a layer to draw on it; the eye hides or shows it; drag the handle to
/// reorder; the menu renames, fades, merges or deletes it, or makes it the
/// layer paint fill takes its edges from.
class LayersPanel extends StatelessWidget {
  const new({
    super.key,
    required this.drawing,
    required this.onChanged,
    required this.onAddLayer,
    required this.onMergeDown,
    required this.onDelete,
    required this.onClose,
  });

  final DrawingSettings drawing;

  /// Called after the panel changed [drawing] (order, names, visibility,
  /// opacity, the active layer or the fill edges layer).
  final VoidCallback onChanged;
  final VoidCallback onAddLayer;
  final ValueChanged<DrawingLayer> onMergeDown;
  final ValueChanged<DrawingLayer> onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = t.editor.layers;
    final layers = drawing.layers.reversed.toList(); // top first
    return FloatingSidePanel(
      key: const ValueKey('layersPanel'),
      title: strings.title,
      onClose: onClose,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('addLayer'),
              onPressed: drawing.layers.length < DrawingSettings.maxLayers
                  ? onAddLayer
                  : null,
              icon: const Icon(Icons.add),
              label: Text(strings.add),
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const .symmetric(horizontal: 8),
            itemCount: layers.length,
            onReorderItem: (from, to) {
              // [from] and [to] count from the top; the list is bottom first.
              final moved = layers.removeAt(from);
              layers.insert(to, moved);
              drawing.layers
                ..clear()
                ..addAll(layers.reversed);
              onChanged();
            },
            itemBuilder: (context, index) => _LayerTile(
              key: ValueKey('layer-${layers[index].id}'),
              index: index,
              layer: layers[index],
              drawing: drawing,
              onChanged: onChanged,
              onMergeDown: onMergeDown,
              onDelete: onDelete,
            ),
          ),
        ),
        Padding(
          padding: const .fromLTRB(16, 4, 16, 12),
          child: Text(
            strings.help,
            style: TextTheme.of(context).bodySmall
                ?.copyWith(color: ColorScheme.of(context).onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _LayerTile extends StatelessWidget {
  const new({
    super.key,
    required this.index,
    required this.layer,
    required this.drawing,
    required this.onChanged,
    required this.onMergeDown,
    required this.onDelete,
  });

  final int index;
  final DrawingLayer layer;
  final DrawingSettings drawing;
  final VoidCallback onChanged;
  final ValueChanged<DrawingLayer> onMergeDown;
  final ValueChanged<DrawingLayer> onDelete;

  bool get _isBottom => drawing.layers.first == layer;

  @override
  Widget build(BuildContext context) {
    final strings = t.editor.layers;
    final colorScheme = ColorScheme.of(context);
    final active = drawing.activeLayer == layer.id;
    final fillLines = drawing.fillLinesLayer == layer.id;
    return Padding(
      padding: const .symmetric(vertical: 3),
      child: Material(
        color: active
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active ? colorScheme.primary : colorScheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            drawing.activeLayer = layer.id;
            onChanged();
          },
          child: Padding(
            padding: const .fromLTRB(4, 2, 4, 2),
            child: Row(
              children: [
                IconButton(
                  key: ValueKey('layerEye-${layer.id}'),
                  tooltip: layer.hidden ? strings.show : strings.hide,
                  icon: Icon(
                    layer.hidden ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () {
                    layer.hidden = !layer.hidden;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        layer.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: active ? FontWeight.w700 : null,
                          color: layer.hidden
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      if (fillLines || layer.opacity < 1)
                        Text(
                          [
                            if (layer.opacity < 1)
                              '${(layer.opacity * 100).round()}%',
                            if (fillLines) strings.fillLinesShort,
                          ].join(' · '),
                          style: TextTheme.of(context).bodySmall,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<LayerAction>(
                  key: ValueKey('layerMenu-${layer.id}'),
                  tooltip: strings.menu,
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: LayerAction.rename,
                      child: Text(strings.rename),
                    ),
                    PopupMenuItem(
                      key: ValueKey('layerOpacity-${layer.id}'),
                      value: LayerAction.opacity,
                      child: Text(strings.opacity),
                    ),
                    CheckedPopupMenuItem(
                      key: ValueKey('layerFillLines-${layer.id}'),
                      value: LayerAction.fillLines,
                      checked: fillLines,
                      child: Text(strings.fillLines),
                    ),
                    PopupMenuItem(
                      key: ValueKey('layerMerge-${layer.id}'),
                      value: LayerAction.mergeDown,
                      enabled: !_isBottom,
                      child: Text(strings.mergeDown),
                    ),
                    PopupMenuItem(
                      key: ValueKey('layerDelete-${layer.id}'),
                      value: LayerAction.delete,
                      enabled: drawing.layers.length > 1,
                      child: Text(strings.delete),
                    ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: .all(8),
                    child: Icon(Icons.drag_handle, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, LayerAction action) async {
    final strings = t.editor.layers;
    switch (action) {
      case LayerAction.rename:
        final name = await _askName(context, layer.name);
        if (name == null || name.trim().isEmpty) return;
        layer.name = name.trim();
        onChanged();
      case LayerAction.opacity:
        await showDialog<void>(
          context: context,
          builder: (context) =>
              _OpacityDialog(layer: layer, onChanged: onChanged),
        );
      case LayerAction.fillLines:
        drawing.fillLinesLayer = drawing.fillLinesLayer == layer.id
            ? null
            : layer.id;
        onChanged();
      case LayerAction.mergeDown:
        onMergeDown(layer);
      case LayerAction.delete:
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
            title: Text(strings.deleteTitle(name: layer.name)),
            content: Text(strings.deleteHelp),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t.common.cancel),
              ),
              CupertinoDialogAction(
                key: const ValueKey('layerDeleteConfirm'),
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(strings.delete),
              ),
            ],
          ),
        );
        if (sure ?? false) onDelete(layer);
    }
  }

  static Future<String?> _askName(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.editor.layers.rename),
        content: TextField(
          key: const ValueKey('layerName'),
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(t.common.done),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _OpacityDialog extends StatefulWidget {
  const new({required this.layer, required this.onChanged});

  final DrawingLayer layer;
  final VoidCallback onChanged;

  @override
  State<_OpacityDialog> createState() => _OpacityDialogState();
}

class _OpacityDialogState extends State<_OpacityDialog> {
  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    return AdaptiveAlertDialog(
      title: Text(
        '${t.editor.layers.opacity}: ${(layer.opacity * 100).round()}%',
      ),
      content: Slider(
        key: const ValueKey('layerOpacitySlider'),
        value: layer.opacity,
        min: 0.05,
        max: 1,
        onChanged: (value) {
          setState(() => layer.opacity = value);
          widget.onChanged();
        },
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.done),
        ),
      ],
    );
  }
}
