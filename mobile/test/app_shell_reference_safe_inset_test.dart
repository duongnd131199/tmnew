import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  testWidgets(
    'sample tabs cap a tall iPhone safe inset at the 24 logical pixel reference',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(top: 186, bottom: 102);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final router = GoRouter(
        initialLocation: '/sample',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/sample',
                    builder: (context, state) => Builder(
                      builder: (context) {
                        final media = MediaQuery.of(context);
                        return Scaffold(
                          body: Text(
                            '${media.padding.top}/'
                            '${media.viewPadding.top}/'
                            '${media.padding.bottom}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [chartMarketWarmupProvider.overrideWith((ref) async {})],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.text('24.0/24.0/34.0'), findsOneWidget);
    },
  );

  testWidgets(
    'bottom navigation is removed only while viewInsets.bottom is positive',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(top: 186, bottom: 102);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
      });

      final router = GoRouter(
        initialLocation: '/sample',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/sample',
                    builder: (context, state) => const Scaffold(
                      body: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [chartMarketWarmupProvider.overrideWith((ref) async {})],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.byType(MtBottomNavigationBar), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pump();
      expect(find.byType(MtBottomNavigationBar), findsNothing);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(find.byType(MtBottomNavigationBar), findsOneWidget);
    },
  );
}
