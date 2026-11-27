import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/navbar/left_navbar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/main.dart';
import 'package:saber/pages/home/home.dart';

import 'utils/test_mock_channel_handlers.dart';

/// Reported: "reducing the width of the left side bar as when open it take
/// up close to ⅔ of the screen". Chosen: narrower, floating over the notes.
void main() {
  testWidgets('The open side bar is narrow, floats and closes on tap outside', (
    tester,
  ) async {
    FlavorConfig.setup();
    setupMockPathProvider();
    stows.sentryConsent.value = .granted;
    stows.layoutSize.value = .tablet;
    FileManager.documentsDirectory =
        '$tmpDir/floatingSidebar/${FileManager.appRootDirectoryPrefix}';
    tester.view.physicalSize = const Size(1600, 2560); // Lenovo, portrait
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: App.initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => HomePage(
            subpage: state.pathParameters['subpage'] ?? HomePage.recentSubpage,
            path: state.uri.queryParameters['path'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final title = find.text('Recent notes');
    final titleBefore = tester.getTopLeft(title);
    double railWidth() => tester
        .getSize(
          find
              .descendant(
                of: find.byType(LeftNavbar),
                matching: find.byType(Container),
              )
              .first,
        )
        .width;
    expect(railWidth(), LeftNavbar.collapsedWidth);

    // Open
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(railWidth(), LeftNavbar.expandedWidth);
    expect(
      LeftNavbar.expandedWidth / 800,
      lessThan(0.3),
      reason: 'under a third of the portrait screen',
    );
    expect(
      tester.getTopLeft(title),
      titleBefore,
      reason: 'the notes do not move when the side bar opens',
    );

    // Tap outside it (on the shaded page) closes it.
    await tester.tapAt(const Offset(600, 900));
    await tester.pumpAndSettle();
    expect(railWidth(), LeftNavbar.collapsedWidth);

    // Choosing a destination closes it too.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(railWidth(), LeftNavbar.collapsedWidth);
  });
}
