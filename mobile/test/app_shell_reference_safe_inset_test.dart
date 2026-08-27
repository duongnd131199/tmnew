import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  testWidgets(
    'sample tabs cap the top inset and retain shell bottom clearance',
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
                            key: const Key('sample-media-values'),
                            '${media.padding.top}/'
                            '${media.viewPadding.top}/'
                            '${media.padding.bottom}/'
                            '${media.viewPadding.bottom}',
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

      expect(
        tester.widget<Text>(find.byKey(const Key('sample-media-values'))).data,
        '24.0/24.0/79.0/0.0',
      );
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
                    builder: (context, state) =>
                        const Scaffold(body: SizedBox.expand()),
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

  testWidgets(
    'XAUUSD M1 chart honors the complete shell bottom clearance at supported widths and insets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      const cases = <({double width, double safeBottom, double clearance})>[
        (width: 360, safeBottom: 0, clearance: 79),
        (width: 393.3333333333, safeBottom: 34, clearance: 79),
        (width: 430, safeBottom: 34, clearance: 79),
      ];
      final firstCase = cases.first;
      tester.view.physicalSize = Size(firstCase.width, 853.3333333333);
      tester.view.padding = FakeViewPadding(
        top: 24,
        bottom: firstCase.safeBottom,
      );
      tester.view.viewPadding = FakeViewPadding(
        top: 24,
        bottom: firstCase.safeBottom,
      );
      addTearDown(() => appRouter.go('/'));
      appRouter.go('/chart?symbol=XAUUSD%2B&timeframe=M1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chartMarketWarmupProvider.overrideWith((ref) async {}),
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => const Stream<MarketCandle>.empty(),
            ),
          ],
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );

      for (final testCase in cases) {
        tester.view.physicalSize = Size(testCase.width, 853.3333333333);
        tester.view.padding = FakeViewPadding(
          top: 24,
          bottom: testCase.safeBottom,
        );
        tester.view.viewPadding = FakeViewPadding(
          top: 24,
          bottom: testCase.safeBottom,
        );
        await tester.pump();

        final canvas = tester.getRect(find.byKey(const Key('chart-canvas')));
        final navigation = tester.getRect(find.byType(MtBottomNavigationBar));
        expect(
          canvas.bottom,
          closeTo(853.3333333333 - testCase.clearance, .01),
          reason: '$testCase must preserve the full shell/device clearance',
        );
        expect(
          canvas.bottom,
          lessThanOrEqualTo(navigation.top + .01),
          reason: '$testCase must not paint into the bottom navigation',
        );
      }
    },
  );
}
