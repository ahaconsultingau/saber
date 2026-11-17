import 'package:material_ui/material_ui.dart';

/// Aha! copy: the panel that floats on the right of a note's page (clear of
/// the toolbar), used by Pages and Bookmarks so both open in the same spot
/// and look alike. A title, a close button, then [children].
class FloatingSidePanel extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
  });

  final String title;
  final VoidCallback onClose;

  /// The panel's content below the title; give the scrolling part Expanded.
  final List<Widget> children;

  /// How wide the panel is on a screen [screenWidth] wide.
  static double widthFor(double screenWidth) =>
      screenWidth * 0.4 < 320 ? screenWidth * 0.4 : 320;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextTheme.of(context).titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
