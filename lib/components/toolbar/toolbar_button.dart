import 'package:material_ui/material_ui.dart';

class ToolbarIconButton extends StatelessWidget {
  const new({
    super.key,
    this.tooltip,
    this.selected = false,
    this.enabled = true,
    required this.onPressed,
    required this.padding,
    required this.child,
    this.accent,
  });

  /// Aha! copy: the tool's own colour. The icon shows in it, and the button
  /// fills with it while the tool is in use. Null for the plain buttons.
  final Color? accent;

  final String? tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final backgroundColor = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled) ||
          !states.contains(WidgetState.selected)) {
        return Colors.transparent;
      }
      return accent ?? colorScheme.primary;
    });
    final foregroundColor = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.4);
      }
      if (states.contains(WidgetState.selected)) {
        return accent == null ? colorScheme.onPrimary : Colors.white;
      }
      return accent ?? colorScheme.primary;
    });
    final buttonStyle = ButtonStyle(
      backgroundColor: backgroundColor,
      iconColor: foregroundColor,
      foregroundColor: foregroundColor,
      iconSize: const WidgetStatePropertyAll(20),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: padding,
      child: IconButton.filled(
        style: buttonStyle,
        onPressed: (enabled) ? onPressed : null,
        tooltip: tooltip,
        isSelected: selected,
        icon: child,
      ),
    );
  }
}
