import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/toolbar/aha_slider.dart';
import 'package:saber/components/toolbar/size_picker.dart';
import 'package:saber/data/extensions/axis_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

class PenModal<T extends Pen> extends StatefulWidget {
  const new({super.key, required this.getTool, required this.setTool});

  /// Gets the current/last-used tool of type [T],
  /// e.g. [Pen.currentPen] or [Highlighter.currentHighlighter].
  final T Function() getTool;

  /// Sets a pen to be the current pen.
  final void Function(Pen) setTool;

  @override
  State<PenModal<T>> createState() => _PenModalState<T>();
}

class _PenModalState<T extends Pen> extends State<PenModal<T>> {
  @override
  Widget build(BuildContext context) {
    final axis = stows.editorToolbarAlignment.value.axis.opposite;
    final pen = widget.getTool();

    // Aha! copy: wraps onto a second line when the drawing options don't
    // all fit beside the pens.
    return Wrap(
      direction: axis,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        SizePicker(axis: axis, pen: pen),

        // Aha! copy: how soft the brush's edges are.
        if (pen.isBrush)
          AhaToolSlider(
            key: const ValueKey('brushFeather'),
            axis: axis,
            label: t.editor.penOptions.feathering,
            valueLabel: '${(pen.feather * 100).round()}%',
            value: pen.feather,
            min: 0,
            max: 1,
            onChanged: (v) => setState(() {
              pen.feather = v;
              stows.lastBrushFeather.value = v;
            }),
          ),

        // Aha! copy: on drawings, see-through paint and steadier lines.
        if (Pen.drawingMode && pen is! Highlighter) ...[
          if (pen is! Pencil)
            AhaToolSlider(
              key: const ValueKey('penOpacity'),
              axis: axis,
              label: t.editor.penOptions.opacity,
              valueLabel: '${(Pen.drawingOpacity * 100).round()}%',
              value: Pen.drawingOpacity,
              min: 0.05,
              max: 1,
              onChanged: (v) => setState(() => Pen.drawingOpacity = v),
            ),
          AhaToolSlider(
            key: const ValueKey('penSteadiness'),
            axis: axis,
            label: t.editor.penOptions.steadiness,
            valueLabel: '${(pen.options.streamline * 100).round()}%',
            value: pen.options.streamline.clamp(0, 0.95),
            min: 0,
            max: 0.95,
            onChanged: (v) => setState(() => pen.options.streamline = v),
          ),
        ],

        if (pen is! Highlighter && pen is! Pencil) ...[
          _PenSelector(
            isSelected: Pen.currentPen.icon == Pen.fountainPenIcon,
            onPressed: () => setState(() {
              widget.setTool(Pen.fountainPen());
            }),
            tooltip: t.editor.pens.fountainPen,
            icon: SvgPicture.asset(
              'assets/images/scribble_fountain.svg',
              width: 32,
              height: 32 / 508 * 374,
              theme: SvgTheme(
                currentColor: Pen.currentPen.icon == Pen.fountainPenIcon
                    ? ColorScheme.of(context).secondary
                    : ColorScheme.of(context).onSurface,
              ),
            ),
          ),
          _PenSelector(
            isSelected: Pen.currentPen.icon == Pen.ballpointPenIcon,
            onPressed: () => setState(() {
              widget.setTool(Pen.ballpointPen());
            }),
            tooltip: t.editor.pens.ballpointPen,
            icon: SvgPicture.asset(
              'assets/images/scribble_ballpoint.svg',
              width: 32,
              height: 32 / 508 * 374,
              theme: SvgTheme(
                currentColor: Pen.currentPen.icon == Pen.ballpointPenIcon
                    ? ColorScheme.of(context).secondary
                    : ColorScheme.of(context).onSurface,
              ),
            ),
          ),
          // Aha! copy: the paintbrush.
          _PenSelector(
            key: const ValueKey('brushPen'),
            isSelected: Pen.currentPen.icon == Pen.brushIcon,
            onPressed: () => setState(() {
              widget.setTool(Pen.brush());
            }),
            tooltip: t.editor.pens.brush,
            icon: const FaIcon(Pen.brushIcon),
          ),
          _PenSelector(
            isSelected: Pen.currentPen.icon == ShapePen.shapePenIcon,
            onPressed: () => setState(() {
              widget.setTool(ShapePen());
            }),
            tooltip: t.editor.pens.shapePen,
            icon: const FaIcon(ShapePen.shapePenIcon),
          ),
        ],
      ],
    );
  }
}

class const _PenSelector({
  super.key,
  required final bool isSelected,
  required final void Function() onPressed,
  required final String tooltip,
  required final Widget icon,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      isSelected: isSelected,
      style: IconButton.styleFrom(
        foregroundColor: isSelected
            ? ColorScheme.of(context).secondary
            : ColorScheme.of(context).onSurface,
        backgroundColor: isSelected
            ? ColorScheme.of(context).secondary.withValues(alpha: 0.1)
            : Colors.transparent,
        shape: const CircleBorder(),
      ),
      tooltip: tooltip,
      icon: icon,
    );
  }
}
