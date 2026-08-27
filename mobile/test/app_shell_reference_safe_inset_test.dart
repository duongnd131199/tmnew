import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
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
    'routed XAUUSD M1 chart matches the reference overlap without stealing navigation taps',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      const cases = <({double width, double safeBottom})>[
        (width: 360, safeBottom: 0),
        (width: 393.3333333333, safeBottom: 34),
        (width: 430, safeBottom: 34),
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
          closeTo(navigation.top + 10, .01),
          reason: '$testCase must use the canonical 10px chart overlap',
        );
      }

      await tester.tap(find.byKey(const ValueKey('bottom-nav-target-trade')));
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, '/trade');
    },
  );

  testWidgets(
    'routed M1 canvas and time-label origin equal the canonical capture profile',
    (tester) async {
      tester.view.physicalSize = const Size(590, 1280);
      tester.view.devicePixelRatio = 1.5;
      tester.view.padding = const FakeViewPadding(top: 36, bottom: 51);
      tester.view.viewPadding = const FakeViewPadding(top: 36, bottom: 51);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final overrides = [
        chartMarketWarmupProvider.overrideWith((ref) async {}),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
        realtimeCandleProvider.overrideWith(
          (ref, request) => const Stream<MarketCandle>.empty(),
        ),
      ];

      ({Rect canvas, Rect timeAxis, Offset firstLabelOrigin}) geometry() {
        final canvasFinder = find.byKey(const Key('chart-canvas'));
        final canvas = tester.getRect(canvasFinder);
        final painter =
            tester.widget<CustomPaint>(canvasFinder).painter!
                as Mt5CandlePainter;
        final firstLabelOrigin =
            canvas.topLeft + painter.hitTargets.timeAxisLabelOrigins.first;
        return (
          canvas: canvas,
          timeAxis: painter.hitTargets.timeAxisRect.shift(canvas.topLeft),
          firstLabelOrigin: firstLabelOrigin,
        );
      }

      addTearDown(() => appRouter.go('/'));
      appRouter.go('/chart?symbol=XAUUSD%2B&timeframe=M1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pump();
      final routed = geometry();

      const canonicalMedia = MediaQueryData(
        size: Size(393.3333333333, 853.3333333333),
        devicePixelRatio: 1.5,
        padding: EdgeInsets.only(top: 24, bottom: 79),
        viewPadding: EdgeInsets.only(top: 24, bottom: 79),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: MediaQuery(
              data: canonicalMedia,
              child: ChartScreen(
                symbol: 'XAUUSD+',
                initialTimeframe: 'M1',
                layoutProfile: ChartLayoutProfile.tabReferenceCapture,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final canonical = geometry();

      expect(routed.canvas, canonical.canvas);
      expect(routed.timeAxis, canonical.timeAxis);
      expect(routed.firstLabelOrigin, canonical.firstLabelOrigin);
      expect(routed.firstLabelOrigin.dy, routed.timeAxis.top);
    },
  );
}
