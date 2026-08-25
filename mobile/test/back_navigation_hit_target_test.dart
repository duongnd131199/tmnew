import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_indicators_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_objects_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_edit_screen.dart';

void main() {
  testWidgets('SymbolEditScreen chevron returns to the market parent route', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await _pumpRouter(tester, router);
    router.push('/market/edit');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/market');
    expect(find.text('Market parent'), findsOneWidget);
  });

  testWidgets(
    'MarketColumnsScreen chevron returns to the market parent route',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);

      await _pumpRouter(tester, router);
      router.push('/market/columns');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/market');
      expect(find.text('Market parent'), findsOneWidget);
    },
  );

  testWidgets('ChartObjectsScreen chevron returns to the chart parent route', (
    tester,
  ) async {
    final router = _router(initialLocation: '/chart');
    addTearDown(router.dispose);

    await _pumpRouter(tester, router);
    router.push('/chart-objects');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/chart');
    expect(find.text('Chart parent'), findsOneWidget);
  });

  testWidgets('ChartIndicatorsScreen custom back control returns to chart', (
    tester,
  ) async {
    final router = _router(initialLocation: '/chart');
    addTearDown(router.dispose);

    await _pumpRouter(tester, router);
    router.push('/chart-indicators');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/chart');
    expect(find.text('Chart parent'), findsOneWidget);
  });
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) {
  return tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
}

GoRouter _router({String initialLocation = '/market'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/market',
      builder: (context, state) => const _ParentScreen('Market parent'),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) => const SymbolEditScreen(),
        ),
        GoRoute(
          path: 'columns',
          builder: (context, state) => const MarketColumnsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/chart',
      builder: (context, state) => const _ParentScreen('Chart parent'),
    ),
    GoRoute(
      path: '/chart-objects',
      builder: (context, state) =>
          const ChartObjectsScreen(symbol: 'XAUUSD', timeframe: 'M1'),
    ),
    GoRoute(
      path: '/chart-indicators',
      builder: (context, state) =>
          const ChartIndicatorsScreen(symbol: 'XAUUSD', timeframe: 'M1'),
    ),
  ],
);

class _ParentScreen extends StatelessWidget {
  const _ParentScreen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
