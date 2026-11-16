import 'package:material_ui/material_ui.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// Aha! copy: the extra tools shown above the toolbar on drawings only.
class DrawRow extends StatelessWidget {
  const new({
    super.key,
    required this.axis,
    required this.grid,
    required this.setGrid,
    required this.flipped,
    required this.toggleFlip,
    required this.layersOpen,
    required this.toggleLayers,
    this.activeLayerName,
    required this.picking,
    required this.togglePicking,
    required this.hasTracing,
    required this.tracingHidden,
    required this.addTracing,
    required this.setTracingHidden,
    required this.removeTracing,
  });

  /// Whether the drawing has a tracing image, and whether it's hidden.
  final bool hasTracing;
  final bool tracingHidden;
  final VoidCallback addTracing;
  final ValueChanged<bool> setTracingHidden;

  /// Removes the tracing image from the page in view.
  final VoidCallback removeTracing;

  /// Whether the Layers panel is open, and the layer in use.
  final bool layersOpen;
  final VoidCallback toggleLayers;
  final String? activeLayerName;

  /// Whether the next touch on the page picks a colour.
  final bool picking;
  final VoidCallback togglePicking;

  final Axis axis;

  /// The guide grid showing now, or null on textured paper (which has
  /// no grid).
  final CanvasBackgroundPattern? grid;
  final ValueChanged<CanvasBackgroundPattern> setGrid;

  final bool flipped;
  final VoidCallback toggleFlip;

  /// The guide grids a drawing can have.
  static const grids = [
    CanvasBackgroundPattern.none,
    CanvasBackgroundPattern.dots,
    CanvasBackgroundPattern.grid,
    CanvasBackgroundPattern.isometric,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: const .symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        key: const ValueKey('drawRow'),
        direction: axis,
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            t.editor.draw.row.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.primary,
            ),
          ),
          FilterChip(
            key: const ValueKey('drawLayers'),
            avatar: layersOpen ? null : const Icon(Icons.layers, size: 18),
            label: Text(
              activeLayerName == null
                  ? t.editor.draw.layers
                  : '${t.editor.draw.layers} · $activeLayerName',
            ),
            selected: layersOpen,
            onSelected: (_) => toggleLayers(),
          ),
          FilterChip(
            key: const ValueKey('drawPick'),
            avatar: picking ? null : const Icon(Icons.colorize, size: 18),
            label: Text(t.editor.draw.pickColour),
            tooltip: t.editor.draw.pickColourHint,
            selected: picking,
            onSelected: (_) => togglePicking(),
          ),
          if (!hasTracing)
            ActionChip(
              key: const ValueKey('drawTracing'),
              avatar: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(t.editor.draw.tracingImage),
              onPressed: addTracing,
            )
          else
            PopupMenuButton<String>(
              key: const ValueKey('drawTracing'),
              tooltip: t.editor.draw.tracingImage,
              onSelected: (choice) => switch (choice) {
                'toggle' => setTracingHidden(!tracingHidden),
                'add' => addTracing(),
                _ => removeTracing(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('drawTracing-toggle'),
                  value: 'toggle',
                  child: Text(
                    tracingHidden
                        ? t.editor.draw.showTracing
                        : t.editor.draw.hideTracing,
                  ),
                ),
                PopupMenuItem(
                  key: const ValueKey('drawTracing-add'),
                  value: 'add',
                  child: Text(t.editor.draw.addTracing),
                ),
                PopupMenuItem(
                  key: const ValueKey('drawTracing-remove'),
                  value: 'remove',
                  child: Text(t.editor.draw.removeTracing),
                ),
              ],
              child: Chip(
                avatar: Icon(
                  tracingHidden ? Icons.visibility_off : Icons.image_outlined,
                  size: 18,
                ),
                label: Text(t.editor.draw.tracingImage),
              ),
            ),
          if (grid != null)
            PopupMenuButton<CanvasBackgroundPattern>(
              key: const ValueKey('drawGrid'),
              tooltip: t.editor.draw.grid,
              onSelected: setGrid,
              itemBuilder: (context) => [
                for (final pattern in grids)
                  CheckedPopupMenuItem(
                    key: ValueKey('drawGrid-${pattern.name}'),
                    value: pattern,
                    checked: pattern == grid,
                    child: Text(
                      pattern == .none
                          ? t.home.newDrawing.plain
                          : pattern.localizedName,
                    ),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.grid_4x4, size: 18),
                label: Text(t.editor.draw.grid),
              ),
            ),
          FilterChip(
            key: const ValueKey('drawFlip'),
            avatar: flipped ? null : const Icon(Icons.flip, size: 18),
            label: Text(t.editor.draw.flipView),
            selected: flipped,
            onSelected: (_) => toggleFlip(),
          ),
        ],
      ),
    );
  }
}
