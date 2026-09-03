import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

const _viewport = Size(393, 320);
const _safeTop = 24.0;

List<DemoQuote> _scrollableQuotes() => List<DemoQuote>.generate(
  12,
  (index) => DemoQuote(
    symbol: 'SYM$index',
    name: 'Symbol $index',
    bid: 100 + index.toDouble(),
    ask: 100.5 + index.toDouble(),
    changePercent: index.isEven ? 1 : -1,
  ),
);

DemoTradingState _scrollableTradeSeed(String accountId) => DemoTradingState(
  balance: 100000,
  positions: List<DemoPosition>.generate(
    30,
    (index) => DemoPosition(
      id: 'header-fade-position-$index',
      symbol: 'XAUUSD',
      side: index.isEven ? 'BUY' : 'SELL',
      volume: .25,
      openPrice: 4600 + index.toDouble(),
      currentPrice: 4601 + index.toDouble(),
      profit: index.isEven ? 25 : -25,
    ),
  ),
  deals: const [],
);

void _useViewport(WidgetTester tester) {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

LinearGradient _headerGradient(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  final fade = tester.widget<DecoratedBox>(finder);
  return (fade.decoration as BoxDecoration).gradient! as LinearGradient;
}

void _expectHistoryFade(LinearGradient gradient) {
  expect(gradient.begin, Alignment.topCenter);
  expect(gradient.end, Alignment.bottomCenter);
  expect(gradient.stops, const [0, .72, 1]);
  expect(gradient.colors, [
    AppColors.background.withValues(alpha: .88),
    AppColors.background.withValues(alpha: .80),
    AppColors.background.withValues(alpha: 0),
  ]);
}

void main() {
  testWidgets('Prices rows scroll behind the fixed translucent header', (
    tester,
  ) async {
    _useViewport(tester);
    final quotes = _scrollableQuotes();
    final container = ProviderContainer(
      overrides: [
        demoQuotesProvider.overrideWithValue(quotes),
        demoQuoteProvider.overrideWith((ref, symbol) {
          return Stream.value(
            quotes.firstWhere((quote) => quote.symbol == symbol),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    for (final quote in quotes) {
      container.read(marketSymbolsProvider.notifier).add(quote.symbol);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: _viewport,
              padding: EdgeInsets.only(top: _safeTop),
              viewPadding: EdgeInsets.only(top: _safeTop),
            ),
            child: MarketWatchScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    const overlayKey = Key('market-header-overlay');
    _expectHistoryFade(_headerGradient(tester, overlayKey));
    final headerTop = tester.getTopLeft(
      find.byKey(const Key('market-search-button')),
    );
    final row = find.byKey(const ValueKey('market-symbol-SYM3'));
    expect(tester.getTopLeft(row).dy, greaterThan(_safeTop + 78));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(row).dy, lessThan(_safeTop + 78));
    expect(
      tester.getTopLeft(find.byKey(const Key('market-search-button'))),
      headerTop,
    );
  });

  testWidgets('Trade rows scroll behind the fixed translucent header', (
    tester,
  ) async {
    _useViewport(tester);
    final container = ProviderContainer(
      overrides: [
        demoTradingSeedProvider.overrideWithValue(_scrollableTradeSeed),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => const Stream<DemoQuote>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: _viewport,
              padding: EdgeInsets.only(top: _safeTop),
              viewPadding: EdgeInsets.only(top: _safeTop),
            ),
            child: TradeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    const overlayKey = Key('trade-header-overlay');
    _expectHistoryFade(_headerGradient(tester, overlayKey));
    final headerTop = tester.getTopLeft(
      find.byKey(const Key('trade-header-profit')),
    );
    final row = find.byKey(
      const ValueKey('trade-position-primary-header-fade-position-0'),
    );
    expect(tester.getTopLeft(row).dy, greaterThan(_safeTop + 72));

    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(180);
    await tester.pump();

    expect(tester.getTopLeft(row).dy, lessThan(_safeTop + 72));
    expect(
      tester.getTopLeft(find.byKey(const Key('trade-header-profit'))),
      headerTop,
    );
  });
}
