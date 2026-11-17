import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';

/// Aha! copy: Settings › New pages. The page design and starting pen every
/// new note begins with. The spacing and thickness sliders match the ones in
/// a note's own page menu.
class NewPageDesignSettings extends HookWidget {
  const new({super.key});

  /// Page colours offered as presets, besides "Any colour…".
  /// 0 means Saber's usual page colour.
  static const presetColours = <int>[0, 0xFFFBF6E9, 0xFFF0F0F3, 0xFFEEF5FB];

  static String presetName(int argb) => switch (argb) {
    0 => t.settings.newPages.colours.white,
    0xFFFBF6E9 => t.settings.newPages.colours.cream,
    0xFFF0F0F3 => t.settings.newPages.colours.softGrey,
    0xFFEEF5FB => t.settings.newPages.colours.paleBlue,
    _ => t.settings.newPages.colours.custom,
  };

  /// The starting pens offered; '' is "the pen you last used".
  static final startingTools = <String>[
    '',
    ToolId.fountainPen.name,
    ToolId.ballpointPen.name,
    ToolId.pencil.name,
    ToolId.highlighter.name,
  ];

  static String toolName(String name) => switch (name) {
    '' => t.settings.newPages.lastUsedPen,
    'fountainPen' => t.editor.pens.fountainPen,
    'ballpointPen' => t.editor.pens.ballpointPen,
    'pencil' => t.editor.pens.pencil,
    'highlighter' => t.editor.pens.highlighter,
    _ => name,
  };

  @override
  Widget build(BuildContext context) {
    final pattern = useValueListenable(stows.newNoteBackgroundPattern);
    final lineHeight = useValueListenable(stows.newNoteLineHeight);
    final lineThickness = useValueListenable(stows.newNoteLineThickness);
    final colour = useValueListenable(stows.newNoteBackgroundColor);
    final tool = useValueListenable(stows.newNoteStartingTool);
    final textTheme = TextTheme.of(context);
    final colorScheme = ColorScheme.of(context);
    final pageColour = colour == 0
        ? InnerCanvas.defaultBackgroundColor
        : Color(colour);

    Widget heading(String text) => Padding(
      padding: const .only(top: 12, bottom: 6),
      child: Text(text, style: textTheme.titleSmall),
    );

    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                heading(t.settings.newPages.lineStyle),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in CanvasBackgroundPattern.values)
                      ChoiceChip(
                        label: Text(p.localizedName),
                        selected: pattern == p,
                        onSelected: (_) =>
                            stows.newNoteBackgroundPattern.value = p,
                      ),
                  ],
                ),
                heading(t.editor.menu.lineHeight),
                Row(
                  children: [
                    Text(lineHeight.toString()),
                    Expanded(
                      child: Slider(
                        value: lineHeight.toDouble(),
                        min: 20,
                        max: 100,
                        divisions: 8,
                        onChanged: (v) =>
                            stows.newNoteLineHeight.value = v.toInt(),
                      ),
                    ),
                  ],
                ),
                heading(t.editor.menu.lineThickness),
                Row(
                  children: [
                    Text(lineThickness.toString()),
                    Expanded(
                      child: Slider(
                        value: lineThickness.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        onChanged: (v) =>
                            stows.newNoteLineThickness.value = v.toInt(),
                      ),
                    ),
                  ],
                ),
                heading(t.settings.newPages.pageColour),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in presetColours)
                      _ColourChoice(
                        label: presetName(c),
                        colour: c == 0
                            ? InnerCanvas.defaultBackgroundColor
                            : Color(c),
                        selected: colour == c,
                        onTap: () => stows.newNoteBackgroundColor.value = c,
                      ),
                    _ColourChoice(
                      label: t.settings.newPages.colours.anyColour,
                      colour: presetColours.contains(colour)
                          ? null
                          : Color(colour),
                      selected: !presetColours.contains(colour),
                      onTap: () => _pickAnyColour(context, pageColour),
                    ),
                  ],
                ),
                heading(t.settings.newPages.startingPen),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in startingTools)
                      ChoiceChip(
                        label: Text(toolName(name)),
                        selected: tool == name,
                        onSelected: (_) =>
                            stows.newNoteStartingTool.value = name,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: .start,
            children: [
              heading(t.settings.newPages.preview),
              CanvasBackgroundPreview(
                selected: false,
                invert: false,
                backgroundColor: pageColour,
                backgroundPattern: pattern,
                backgroundImage: null,
                pageSize: const Size(1000, 1400),
                lineHeight: lineHeight,
                lineThickness: lineThickness,
              ),
              const SizedBox(height: 6),
              Text(
                t.settings.newPages.previewNote,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAnyColour(BuildContext context, Color current) async {
    var picked = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.settings.accentColorPicker.pickAColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: current,
            pickersEnabled: const {ColorPickerType.wheel: true},
            onColorChanged: (c) => picked = c,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      stows.newNoteBackgroundColor.value = picked.withAlpha(255).toARGB32();
    }
  }
}

/// A round colour swatch with its name, selectable. A null [colour] shows a
/// rainbow ring (for "Any colour…").
class _ColourChoice extends StatelessWidget {
  const new({
    required this.label,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const .only(left: 6, right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: .circle,
                color: colour,
                gradient: colour == null
                    ? const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      )
                    : null,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
