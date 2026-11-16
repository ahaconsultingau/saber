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
  });

  final Axis axis;

  /// The guide grid showing now.
  final CanvasBackgroundPattern grid;
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
