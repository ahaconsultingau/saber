import 'dart:ui' show lerpDouble;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/files/file_tree.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/data/routes.dart';

class const LeftNavbar({
  super.key,
  final int selectedIndex = 0,
  final ValueChanged<int>? onDestinationSelected,
}) extends HookWidget {
  /// Width of the closed side bar (icons only). The page beside it is
  /// padded by this much; the open side bar floats over the page.
  static const collapsedWidth = 88.0;

  /// Aha! copy: width of the open side bar. Was 324, which took up to two
  /// thirds of a portrait tablet and pushed the notes across.
  static const expandedWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final expandAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );
    final expandAnimation = expandAnimationController.drive(
      CurveTween(curve: Curves.easeInOut),
    );

    final isFullyCollapsed = useListenableSelector(
      expandAnimation,
      () => expandAnimation.value <= 0,
    );
    final hasBeenExpanded = useRef(false);
    hasBeenExpanded.value |= !isFullyCollapsed;

    void collapse() => expandAnimationController.reverse();

    final theme = Theme.of(context);
    final backgroundColor = switch (theme.platform) {
      .linux => theme.colorScheme.surface,
      _ => theme.colorScheme.surfaceContainer,
    };
    final screenWidth = MediaQuery.sizeOf(context).width;

    final routes = HomeRoutes.routes;

    final rail = AnimatedBuilder(
      animation: expandAnimation,
      builder: (context, child) => Container(
        width: lerpDouble(collapsedWidth, expandedWidth, expandAnimation.value),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: theme.platform == .linux
              ? BoxBorder.fromSTEB(end: BorderSide(color: theme.dividerColor))
              : null,
          boxShadow: [
            if (expandAnimation.value > 0)
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.18 * expandAnimation.value,
                ),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
          ],
        ),
        child: child,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: expandedWidth,
          maxWidth: expandedWidth,
          child: Padding(
            padding: const .symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 12,
              children: [
                const SizedBox(height: kToolbarHeight - 2),
                TextButton(
                  onPressed: () {
                    if (expandAnimationController.isForwardOrCompleted) {
                      expandAnimationController.reverse();
                    } else {
                      expandAnimationController.forward();
                    }
                  },
                  child: RotationTransition(
                    turns: expandAnimation.drive(Tween(begin: 0, end: 0.5)),
                    child: const AdaptiveIcon(
                      icon: Icons.chevron_right,
                      cupertinoIcon: CupertinoIcons.chevron_right,
                    ),
                  ),
                ),
                const SizedBox(),
                for (int i = 0; i < routes.length; ++i)
                  _RouteTile(
                    route: routes[i],
                    selected: i == selectedIndex,
                    onTap: () {
                      collapse();
                      onDestinationSelected?.call(i);
                    },
                    expandAnimation: expandAnimation,
                  ),
                Expanded(
                  child: hasBeenExpanded.value
                      ? Offstage(
                          offstage: isFullyCollapsed,
                          child: FadeTransition(
                            opacity: expandAnimation,
                            child: FileTree(onFileOpened: collapse),
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          rail,
          // Aha! copy: while open, a light shade over the page; tapping it
          // closes the side bar.
          if (!isFullyCollapsed)
            SizedBox(
              width: (screenWidth - expandedWidth).clamp(0, double.infinity),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: collapse,
                child: FadeTransition(
                  opacity: expandAnimation,
                  child: const ColoredBox(color: Color(0x2E000000)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class const _RouteTile({
  required final HomeRoute route,
  required final bool selected,
  required final VoidCallback onTap,
  required final Animation<double> expandAnimation,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? theme.navigationRailTheme.indicatorColor ??
                      theme.colorScheme.secondaryContainer
                : null,
            borderRadius: const .all(.circular(32)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: const .all(.circular(32)),
            child: Padding(
              padding: const .symmetric(vertical: 6, horizontal: 18),
              child: Semantics(
                label: route.destination.label,
                selected: selected,
                child: route.destination.icon,
              ),
            ),
          ),
        ),
        Flexible(
          child: ExcludeSemantics(
            // semantics redundant with icon label above
            child: SizeTransition(
              sizeFactor: expandAnimation,
              axis: .horizontal,
              alignment: .centerStart,
              child: GestureDetector(
                onTap: onTap,
                child: Padding(
                  padding: const .directional(start: 8),
                  child: Text(
                    route.destination.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: .ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
