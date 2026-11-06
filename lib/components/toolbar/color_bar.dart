import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

typedef NamedColor = ({String name, Color color});

class ColorBar extends StatefulWidget {
  const new({
    super.key,
    required this.axis,
    required this.setColor,
    required this.currentColor,
    required this.invert,
    this.isHighlighter = false,
  });

  final Axis axis;
  final ValueChanged<Color> setColor;
  final Color? currentColor;
  final bool invert;

  /// Aha! copy: shows the highlighter's six colours instead of the pens'.
  final bool isHighlighter;

  /// Aha! copy: the six colours shown for pens (or the highlighter).
  static List<Color> slotsFor({required bool highlighter}) => [
    for (final s
        in (highlighter ? stows.highlighterColourSlots : stows.penColourSlots)
            .value)
      Color(int.parse(s)),
  ];

  /// Aha! copy: replaces colour [index] of the pens' (or highlighter's) six.
  static void setSlot(int index, Color color, {required bool highlighter}) {
    final stow = highlighter
        ? stows.highlighterColourSlots
        : stows.penColourSlots;
    final slots = List.of(stow.value);
    slots[index] = color.withAlpha(255).toARGB32().toString();
    stow.value = slots;
  }

  static List<NamedColor> get colorPresets =>
      stows.preferGreyscale.value ? greyScaleColorOptions : normalColorOptions;
  static final List<NamedColor> normalColorOptions = [
    (name: t.editor.colors.black, color: Colors.black),
    (name: t.editor.colors.red, color: Colors.red),
    (name: t.editor.colors.orange, color: Colors.orange),
    (name: t.editor.colors.yellow, color: Colors.yellow),
    (name: t.editor.colors.green, color: Colors.green),
    (name: t.editor.colors.cyan, color: Colors.cyan),
    (name: t.editor.colors.blue, color: Colors.blue),
    (name: t.editor.colors.purple, color: Colors.purple),
    (name: t.editor.colors.pink, color: Colors.pink),
    (name: t.editor.colors.white, color: Colors.white),
    ..._pastelColorOptions,
  ];
  static final List<NamedColor> _pastelColorOptions = [
    (
      name: t.editor.colors.pastelRed,
      color: const Color.fromRGBO(255, 173, 173, 1),
    ),
    (
      name: t.editor.colors.pastelOrange,
      color: const Color.fromRGBO(255, 214, 165, 1),
    ),
    (
      name: t.editor.colors.pastelYellow,
      color: const Color.fromRGBO(253, 255, 182, 1),
    ),
    (
      name: t.editor.colors.pastelGreen,
      color: const Color.fromRGBO(202, 255, 191, 1),
    ),
    (
      name: t.editor.colors.pastelCyan,
      color: const Color.fromRGBO(155, 246, 255, 1),
    ),
    (
      name: t.editor.colors.pastelBlue,
      color: const Color.fromRGBO(160, 196, 255, 1),
    ),
    (
      name: t.editor.colors.pastelPurple,
      color: const Color.fromRGBO(189, 178, 255, 1),
    ),
    (
      name: t.editor.colors.pastelPink,
      color: const Color.fromRGBO(255, 198, 255, 1),
    ),
  ];
  static final List<NamedColor> greyScaleColorOptions = [
    (name: t.editor.colors.black, color: Colors.black),
    (name: t.editor.colors.darkGrey, color: Colors.grey[800] ?? Colors.black54),
    (name: t.editor.colors.grey, color: Colors.grey),
    (
      name: t.editor.colors.lightGrey,
      color: Colors.grey[200] ?? Colors.black12,
    ),
    (name: t.editor.colors.white, color: Colors.white),
  ];
  static final List<NamedColor> _allColors = [
    ...normalColorOptions,
    ...greyScaleColorOptions,
  ];
  static String findColorName(Color searchColor) {
    for (final namedColor in _allColors) {
      if (namedColor.color.toARGB32() == searchColor.toARGB32()) {
        return namedColor.name;
      }
    }
    return describeColor(searchColor);
  }

  @visibleForTesting
  static String describeColor(Color color) {
    final hsl = HSLColor.fromColor(color);

    final String hueName;
    if (hsl.saturation < 0.1 || hsl.lightness < 0.05 || hsl.lightness > 0.95) {
      hueName = t.editor.colors.grey.toLowerCase();
    } else {
      hueName = switch (hsl.hue) {
        < 10 => t.editor.colors.red.toLowerCase(),
        < 35 => t.editor.colors.orange.toLowerCase(),
        < 70 => t.editor.colors.yellow.toLowerCase(),
        < 150 => t.editor.colors.green.toLowerCase(),
        < 200 => t.editor.colors.cyan.toLowerCase(),
        < 250 => t.editor.colors.blue.toLowerCase(),
        < 285 => t.editor.colors.purple.toLowerCase(),
        < 340 => t.editor.colors.pink.toLowerCase(),
        _ => t.editor.colors.red.toLowerCase(),
      };
    }

    final lightnessName = switch (hsl.lightness) {
      < 0.35 => t.editor.colors.dark,
      < 0.65 => null,
      _ => t.editor.colors.light,
    };

    if (lightnessName == null) {
      return t.editor.colors.customHue(h: hueName);
    } else {
      return t.editor.colors.customBrightnessHue(b: lightnessName, h: hueName);
    }
  }

  /// Returns whether the color is now pinned.
  static bool toggleColorPinned(String colorString) {
    if (stows.pinnedColors.value.contains(colorString)) {
      stows.pinnedColors.value.remove(colorString);
      stows.recentColorsChronological.value.remove(colorString);
      stows.recentColorsPositioned.value.remove(colorString);
      if (stows.recentColorsChronological.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace oldest
        final oldestColor = stows.recentColorsChronological.value.removeAt(0);
        stows.recentColorsChronological.value.add(colorString);
        final int oldestColorPosition = stows.recentColorsPositioned.value
            .indexOf(oldestColor);
        stows.recentColorsPositioned.value[oldestColorPosition] = colorString;
      } else {
        // not full, add to end
        stows.recentColorsChronological.value.add(colorString);
        stows.recentColorsPositioned.value.insert(0, colorString);
      }
      return false;
    } else {
      // add to pinned and remove from recent colors
      stows.pinnedColors.value.add(colorString);
      stows.recentColorsChronological.value.remove(colorString);
      stows.recentColorsPositioned.value.remove(colorString);
      return true;
    }
  }

  @override
  State<ColorBar> createState() => _ColorBarState();
}

class _ColorBarState extends State<ColorBar> {
  static var pickedColor = const Color.fromRGBO(255, 0, 0, 1);

  /// Aha! copy: six colours only, kept small. Tap one to use it; tap the one
  /// in use again (or press and hold any) to change it with the colour
  /// picker. The change is remembered.
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final slots = ColorBar.slotsFor(highlighter: widget.isHighlighter);
    final current = widget.currentColor?.withAlpha(255).toARGB32();

    final children = <Widget>[
      for (final (index, colour) in slots.indexed)
        Padding(
          padding: widget.axis == Axis.vertical
              ? const .symmetric(vertical: 3)
              : const .symmetric(horizontal: 3),
          child: _Swatch(
            key: ValueKey('colourSlot$index'),
            colour: colour.withInversion(widget.invert),
            selected: current == colour.toARGB32(),
            enabled: widget.currentColor != null,
            tooltip: ColorBar.findColorName(colour),
            outline: colorScheme.onSurface,
            onTap: () => current == colour.toARGB32()
                ? _editSlot(index, colour)
                : widget.setColor(colour),
            onLongPress: () => _editSlot(index, colour),
          ),
        ),
    ];

    return Center(
      child: Padding(
        padding: const .all(6),
        child: SingleChildScrollView(
          scrollDirection: widget.axis,
          child: Flex(
            direction: widget.axis,
            mainAxisSize: .min,
            children: children,
          ),
        ),
      ),
    );
  }

  /// Opens the colour picker on colour [index]; saving keeps the new colour
  /// in that spot and uses it.
  Future<void> _editSlot(int index, Color colour) async {
    pickedColor = colour;
    final confirmChange = await showDialog<bool>(
      context: context,
      builder: _colorPickerDialog,
    );
    if (!(confirmChange ?? false)) return;
    final chosen = pickedColor.withAlpha(255);
    ColorBar.setSlot(index, chosen, highlighter: widget.isHighlighter);
    if (mounted) setState(() {});
    widget.setColor(chosen);
  }

  Widget _colorPickerDialog(BuildContext context) => AdaptiveAlertDialog(
    title: Text(t.settings.accentColorPicker.pickAColor),
    content: SingleChildScrollView(
      child: ColorPicker(
        key: const ValueKey('colourSlotPicker'),
        color: pickedColor,
        // Aha! copy: the wheel only (the package also turns on its Material
        // swatch tabs unless told not to), so any colour can be made and its
        // code typed in.
        pickersEnabled: const {
          ColorPickerType.primary: false,
          ColorPickerType.accent: false,
          ColorPickerType.wheel: true,
        },
        // Aha! copy: the colour's code can be typed in too.
        showColorCode: true,
        colorCodeHasColor: true,
        onColorChanged: (Color color) {
          pickedColor = color;
        },
      ),
    ),
    actions: [
      CupertinoDialogAction(
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        onPressed: () => Navigator.of(context).pop(false),
      ),
      CupertinoDialogAction(
        child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        onPressed: () {
          Navigator.of(context).pop(true);
        },
      ),
    ],
  );
}

/// Aha! copy: one round colour on the colour bar, with a ring when in use.
class _Swatch extends StatelessWidget {
  const new({
    super.key,
    required this.colour,
    required this.selected,
    required this.enabled,
    required this.tooltip,
    required this.outline,
    required this.onTap,
    required this.onLongPress,
  });

  final Color colour;
  final bool selected;
  final bool enabled;
  final String tooltip;
  final Color outline;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const diameter = 32.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        onSecondaryTap: enabled ? onLongPress : null,
        child: Container(
          width: diameter,
          height: diameter,
          padding: const .all(3),
          decoration: BoxDecoration(
            shape: .circle,
            border: Border.all(
              color: selected ? outline : Colors.transparent,
              width: 2,
            ),
          ),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colour,
                shape: .circle,
                border: Border.all(color: outline.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
