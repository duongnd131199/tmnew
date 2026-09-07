import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: '/market',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/market',
                  builder: (context, state) => const MarketWatchScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chart',
                  builder: (context, state) =>
                      const Scaffold(body: Text('CHART')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trade',
                  builder: (context, state) => const TradeScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    container.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  double marketRowOffset(WidgetTester tester, String symbol) {
    final row = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(symbol),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return row.transform?.storage[12] ?? 0;
  }

  double tradeRowOffset(WidgetTester tester, String positionId) {
    final row = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('trade-position-surface-$positionId')),
    );
    return row.transform?.storage[12] ?? 0;
  }

  testWidgets('Prices closes a revealed row after leaving and returning', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.text('XAUUSD'), const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(marketRowOffset(tester, 'XAUUSD'), -142);

    await tester.tap(find.text('Giao dich'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gia'));
    await tester.pumpAndSettle();

    expect(marketRowOffset(tester, 'XAUUSD'), 0);
  });

  testWidgets('Trade closes a revealed position after leaving and returning', (
    tester,
  ) async {
    await pumpApp(tester);
    final positionId = container.read(demoPositionsProvider).first.id;

    await tester.tap(find.text('Giao dich'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(ValueKey('trade-position-$positionId')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    expect(tradeRowOffset(tester, positionId), -168);

    await tester.tap(find.text('Gia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giao dich'));
    await tester.pumpAndSettle();

    expect(tradeRowOffset(tester, positionId), 0);
  });
}
