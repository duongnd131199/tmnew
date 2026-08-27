import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/reference_font_loader.dart';
import 'test_support/tab_reference_manifest.dart';
import 'test_support/video_reference_fixtures.dart';

final _referenceNow = DateTime.utc(2026, 8, 25, 22, 24, 35);
const _referenceFlutterSize = Size(393.3333333333, 853.3333333333);

void main() {
  setUpAll(loadReferenceFonts);

  for (final referenceCase in tabReferenceCases) {
    testWidgets(
      '${referenceCase.id} typography matches the canonical candidate',
      (tester) async {
        await _configureReferenceView(tester);
        await pumpTabReference(tester, referenceCase.state);

        final image = await _captureReferenceImage(tester);

        await expectLater(
          image,
          matchesGoldenFile(
            'goldens/tab-typography/${referenceCase.id}-590x1280.png',
          ),
        );
        image.dispose();
      },
    );
  }

  testWidgets('History scroll indicators match the canonical physical bounds', (
    tester,
  ) async {
    const expected = <TabReferenceState, Rect?>{
      TabReferenceState.historyPositions: null,
      TabReferenceState.historyOrders: Rect.fromLTWH(581, 177, 5, 687),
      TabReferenceState.historyOrdersSummary: Rect.fromLTWH(581, 474, 5, 688),
      TabReferenceState.historyDeals: Rect.fromLTWH(581, 525, 5, 637),
    };

    await _configureReferenceView(tester);
    for (final entry in expected.entries) {
      await pumpTabReference(tester, entry.key);
      final image = await _captureReferenceImage(tester);
      expect(
        await tester.runAsync(() => _historyScrollbarBounds(image)),
        entry.value,
        reason: entry.key.name,
      );
      image.dispose();
    }
  });

  testWidgets('Chart reference session hits the captured M1 time labels', (
    tester,
  ) async {
    await _configureReferenceView(tester);
    await pumpTabReference(tester, TabReferenceState.chart);

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.hitTargets.timeAxisLabels, const [
      '25 Aug 17:28',
      '25 Aug 17:44',
      '25 Aug 18:00',
      '25 Aug 18:16',
    ]);
  });

  testWidgets('reference tabs do not overflow supported widths', (
    tester,
  ) async {
    for (final width in <double>[360, 384, 393.3333333333, 430]) {
      for (final state in <TabReferenceState>[
        TabReferenceState.prices,
        TabReferenceState.trade,
        TabReferenceState.historyPositions,
        TabReferenceState.historyOrders,
        TabReferenceState.historyDeals,
      ]) {
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(Size(width, 853.3333333333));
        await pumpTabReference(tester, state);
        expect(tester.takeException(), isNull, reason: '$state at $width');
      }
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Future<ui.Image> _captureReferenceImage(WidgetTester tester) {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('tab-reference-root')),
  );
  return boundary.toImage(pixelRatio: tabReferenceDevicePixelRatio);
}

Future<Rect?> _historyScrollbarBounds(ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) return null;
  const left = 581;
  const width = 5;
  final matchingRows = <int>[];
  for (var y = 145; y < 1170; y++) {
    var matches = true;
    for (var x = left; x < left + width; x++) {
      final offset = (y * image.width + x) * 4;
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      if ((red - green).abs() > 2 ||
          (red - blue).abs() > 2 ||
          red < 145 ||
          red > 252) {
        matches = false;
        break;
      }
    }
    if (matches) matchingRows.add(y);
  }
  if (matchingRows.isEmpty) return null;

  var bestStart = matchingRows.first;
  var bestEnd = bestStart;
  var runStart = bestStart;
  var previous = bestStart;
  for (final y in matchingRows.skip(1)) {
    if (y != previous + 1) {
      if (previous - runStart > bestEnd - bestStart) {
        bestStart = runStart;
        bestEnd = previous;
      }
      runStart = y;
    }
    previous = y;
  }
  if (previous - runStart > bestEnd - bestStart) {
    bestStart = runStart;
    bestEnd = previous;
  }
  if (bestEnd - bestStart < 20) return null;
  return Rect.fromLTWH(
    left.toDouble(),
    bestStart.toDouble(),
    width.toDouble(),
    (bestEnd - bestStart + 1).toDouble(),
  );
}

Future<void> _configureReferenceView(WidgetTester tester) async {
  tester.view.devicePixelRatio = tabReferenceDevicePixelRatio;
  await tester.binding.setSurfaceSize(_referenceFlutterSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> pumpTabReference(
  WidgetTester tester,
  TabReferenceState state,
) async {
  final referenceQuotes = _referenceQuotesFor(state);
  final seedQuotes = _referenceSeedQuotesFor(state, referenceQuotes);
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('tab-reference-${state.name}'),
      overrides: [
        demoAccountCatalogProvider.overrideWithValue(videoDemoAccountProfiles),
        demoTradingSeedProvider.overrideWithValue(
          state == TabReferenceState.chart
              ? _referenceChartTradingSeed
              : _referenceTradingSeed,
        ),
        demoMarginCalculatorProvider.overrideWithValue(
          (_, positionCount) => positionCount == 0 ? 0 : 51043.86,
        ),
        demoQuotesProvider.overrideWithValue(seedQuotes),
        activeDemoAccountProvider.overrideWithValue(_referenceHistoryProfile),
        demoHistoryPositionsProvider.overrideWithValue(
          _referenceHistoryPositions,
        ),
        demoOrdersProvider.overrideWithValue(_referenceOrders),
        demoDealsProvider.overrideWithValue(_referenceDeals),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(_referenceCandles),
        ),
        realtimeCandleProvider.overrideWith(
          (ref, request) => const Stream<MarketCandle>.empty(),
        ),
        marketClockProvider.overrideWithValue(() => _referenceNow),
        if (state == TabReferenceState.chart)
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://reference.invalid'),
          ),
        if (state == TabReferenceState.chart)
          chartViewSessionSeedProvider.overrideWithValue(
            _referenceChartSession,
          ),
        demoQuoteProvider.overrideWith((ref, symbol) {
          final normalized = symbol.replaceAll('+', '');
          final quote = referenceQuotes.firstWhere(
            (item) => item.symbol.replaceAll('+', '') == normalized,
            orElse: () => referenceQuotes.first,
          );
          return Stream.value(
            DemoQuote(
              symbol: quote.symbol,
              name: quote.name,
              bid: quote.bid,
              ask: quote.ask,
              changePercent: quote.changePercent,
              sourceTimestamp: state == TabReferenceState.chart
                  ? _referenceCandles.last.time
                  : _referenceNow,
              previousClose: quote.previousClose,
              dailyLow: quote.dailyLow,
              dailyHigh: quote.dailyHigh,
            ),
          );
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: _referenceFlutterSize,
            devicePixelRatio: tabReferenceDevicePixelRatio,
            padding: EdgeInsets.only(top: 24),
            viewPadding: EdgeInsets.only(top: 24),
          ),
          child: RepaintBoundary(
            key: const Key('tab-reference-root'),
            child: Scaffold(
              extendBody: true,
              body: _screenFor(state),
              bottomNavigationBar: MtBottomNavigationBar(
                selectedIndex: _navigationIndexFor(state),
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  switch (state) {
    case TabReferenceState.chart:
      await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
      await tester.pump();
    case TabReferenceState.historyPositions:
      await _settleHistory(tester);
    case TabReferenceState.historyOrders:
      await tester.tap(find.byKey(const Key('history-tab-1')));
      await tester.pump();
      await _jumpHistoryBy(tester, 'history-orders-list', 21.3333333333);
    case TabReferenceState.historyOrdersSummary:
      await tester.tap(find.byKey(const Key('history-tab-1')));
      await tester.pump();
      await _jumpHistoryToEnd(tester, 'history-orders-list', trailingGap: 2);
    case TabReferenceState.historyDeals:
      await tester.tap(find.byKey(const Key('history-tab-2')));
      await tester.pump();
      await _jumpHistoryToEnd(
        tester,
        'history-deals-list',
        trailingGap: 1.3333333333,
      );
    case TabReferenceState.prices:
    case TabReferenceState.trade:
      break;
  }
}

final _referenceChartSession = ChartViewSessionState(
  activeSymbol: 'XAUUSD+',
  views: const {
    'XAUUSD': ChartViewSnapshot(
      symbol: 'XAUUSD+',
      timeframe: 'M1',
      viewport: ChartViewport(barSpacing: 5.5, rightPadding: 13.5),
      priceViewport: ChartPriceViewport.manual(
        centerPrice: 4627.93,
        range: 30.72,
      ),
    ),
  },
);

List<DemoQuote> _referenceQuotesFor(TabReferenceState state) => switch (state) {
  TabReferenceState.prices => const [
    DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4640.91,
      ask: 4641.24,
      changePercent: -.23,
      previousClose: 4651.65,
      dailyLow: 4601.08,
      dailyHigh: 4696.73,
    ),
    DemoQuote(
      symbol: 'BTCUSD',
      name: 'Bitcoin',
      bid: 35.04,
      ask: 35.05,
      changePercent: .66,
      previousClose: 34.81,
      dailyLow: 34.54,
      dailyHigh: 35.11,
    ),
  ],
  TabReferenceState.chart => const [
    DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4640.75,
      ask: 4641.03,
      changePercent: -.23,
    ),
  ],
  TabReferenceState.trade => const [
    DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4640.81,
      ask: 4641.04,
      changePercent: 0,
    ),
  ],
  _ => videoDemoQuotes,
};

List<DemoQuote> _referenceSeedQuotesFor(
  TabReferenceState state,
  List<DemoQuote> liveQuotes,
) => switch (state) {
  TabReferenceState.prices => const [
    DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4640.90,
      ask: 4641.23,
      changePercent: -.23,
      previousClose: 4651.65,
      dailyLow: 4601.08,
      dailyHigh: 4696.73,
    ),
    DemoQuote(
      symbol: 'BTCUSD',
      name: 'Bitcoin',
      bid: 35.05,
      ask: 35.06,
      changePercent: .66,
      previousClose: 34.81,
      dailyLow: 34.54,
      dailyHigh: 35.11,
    ),
  ],
  _ => liveQuotes,
};

DemoTradingState _referenceTradingSeed(String accountId) => DemoTradingState(
  positions: _referenceOpenPositions,
  deals: const [],
  balance: 103310,
);

DemoTradingState _referenceChartTradingSeed(String accountId) =>
    const DemoTradingState(
      positions: [
        DemoPosition(
          id: 'reference-chart-upper',
          symbol: 'XAUUSD+',
          side: 'BUY',
          volume: 1,
          openPrice: 4644.22,
          currentPrice: 4640.75,
          profit: -347,
        ),
        DemoPosition(
          id: 'reference-chart-lower-1',
          symbol: 'XAUUSD+',
          side: 'BUY',
          volume: 1,
          openPrice: 4637.47,
          currentPrice: 4640.75,
          profit: 328,
        ),
        DemoPosition(
          id: 'reference-chart-lower-2',
          symbol: 'XAUUSD+',
          side: 'BUY',
          volume: 1,
          openPrice: 4637.05,
          currentPrice: 4640.75,
          profit: 370,
        ),
      ],
      deals: [],
      balance: 103310,
    );

const _referenceOpenPositions = <DemoPosition>[
  DemoPosition(
    id: 'reference-open-1',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.05,
    currentPrice: 4640.81,
    profit: 376,
  ),
  DemoPosition(
    id: 'reference-open-2',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.05,
    currentPrice: 4640.81,
    profit: 376,
  ),
  DemoPosition(
    id: 'reference-open-3',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.06,
    currentPrice: 4640.81,
    profit: 375,
  ),
  DemoPosition(
    id: 'reference-open-4',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.08,
    currentPrice: 4640.81,
    profit: 373,
  ),
  DemoPosition(
    id: 'reference-open-5',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.08,
    currentPrice: 4640.81,
    profit: 373,
  ),
  DemoPosition(
    id: 'reference-open-6',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4637.47,
    currentPrice: 4640.81,
    profit: 334,
  ),
  DemoPosition(
    id: 'reference-open-7',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4644.22,
    currentPrice: 4640.81,
    profit: -341,
  ),
  DemoPosition(
    id: 'reference-open-8',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4644.22,
    currentPrice: 4640.81,
    profit: -341,
  ),
  DemoPosition(
    id: 'reference-open-9',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4644.21,
    currentPrice: 4640.81,
    profit: -340,
  ),
  DemoPosition(
    id: 'reference-open-10',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4644.21,
    currentPrice: 4640.81,
    profit: -340,
  ),
  DemoPosition(
    id: 'reference-open-11',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4644.21,
    currentPrice: 4640.81,
    profit: -340,
  ),
  DemoPosition(
    id: 'reference-open-12',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4641.566,
    currentPrice: 4640.81,
    profit: -75.6,
  ),
];

Widget _screenFor(TabReferenceState state) => switch (state) {
  TabReferenceState.prices => const MarketWatchScreen(),
  TabReferenceState.chart => const ChartScreen(
    symbol: 'XAUUSD+',
    initialTimeframe: 'M1',
    layoutProfile: ChartLayoutProfile.tabReferenceCapture,
  ),
  TabReferenceState.trade => const TradeScreen(),
  TabReferenceState.historyPositions ||
  TabReferenceState.historyOrders ||
  TabReferenceState.historyOrdersSummary ||
  TabReferenceState.historyDeals => const HistoryScreen(),
};

int _navigationIndexFor(TabReferenceState state) => switch (state) {
  TabReferenceState.prices => 0,
  TabReferenceState.chart => 1,
  TabReferenceState.trade => 2,
  TabReferenceState.historyPositions ||
  TabReferenceState.historyOrders ||
  TabReferenceState.historyOrdersSummary ||
  TabReferenceState.historyDeals => 3,
};

Future<void> _settleHistory(WidgetTester tester) async {
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump();
  }
}

Future<void> _jumpHistoryToEnd(
  WidgetTester tester,
  String pageStorageKey, {
  double trailingGap = 0,
}) async {
  final listFinder = find.byKey(PageStorageKey(pageStorageKey));
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: listFinder, matching: find.byType(Scrollable)),
  );
  scrollable.position.jumpTo(
    (scrollable.position.maxScrollExtent - trailingGap).clamp(
      scrollable.position.minScrollExtent,
      scrollable.position.maxScrollExtent,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _jumpHistoryBy(
  WidgetTester tester,
  String pageStorageKey,
  double offset,
) async {
  final listFinder = find.byKey(PageStorageKey(pageStorageKey));
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: listFinder, matching: find.byType(Scrollable)),
  );
  scrollable.position.jumpTo(offset);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

final _referenceCandles = List<MarketCandle>.generate(96, (index) {
  final time = DateTime(2026, 8, 25, 16, 49).add(Duration(minutes: index));
  final wave = switch (index % 8) {
    0 => -1.8,
    1 => .9,
    2 => -.6,
    3 => 2.4,
    4 => 1.2,
    5 => -1.5,
    6 => .5,
    _ => -.3,
  };
  final open = 4624 + index * .16 + wave;
  final close = open + (index.isEven ? 1.15 : -.85);
  return MarketCandle(
    time: time,
    open: open,
    high: (open > close ? open : close) + .7,
    low: (open < close ? open : close) - .65,
    close: close,
    volume: 900 + index * 11,
  );
});

const _referenceHistoryPositions = <DemoHistoryPosition>[
  DemoHistoryPosition(
    id: 'reference-balance',
    title: 'Balance',
    profit: 100000,
    time: '2026.08.22 03:41:08',
  ),
  DemoHistoryPosition(
    id: 'reference-position-1',
    title: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4622.83,
    closePrice: 4631.37,
    profit: 854,
    time: '2026.08.24 10:45:11',
  ),
  DemoHistoryPosition(
    id: 'reference-position-2',
    title: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4622.86,
    closePrice: 4631.37,
    profit: 851,
    time: '2026.08.24 10:45:11',
  ),
  DemoHistoryPosition(
    id: 'reference-position-3',
    title: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4623.23,
    closePrice: 4631.37,
    profit: 814,
    time: '2026.08.24 10:45:11',
  ),
  DemoHistoryPosition(
    id: 'reference-position-4',
    title: 'XAUUSD+',
    side: 'BUY',
    volume: 1,
    openPrice: 4623.46,
    closePrice: 4631.37,
    profit: 791,
    time: '2026.08.24 10:45:11',
  ),
];

const _referenceHistoryProfile = DemoAccountProfile(
  id: videoPrimaryAccountId,
  name: 'Reference Account',
  company: 'Demo Markets Ltd',
  server: 'Demo-Live-01',
  accessPoint: 'Demo Access 01',
  balance: 103310,
  brand: DemoBrokerBrand.unknown,
  historyDeposit: 100000,
  historyWithdrawal: 0,
  historyProfit: 3310,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 103310,
);

const _referenceOrderCaptures = <(String, double, String)>[
  ('BUY', 4637.05, '2026.08.24 04:17:35'),
  ('BUY', 4637.05, '2026.08.24 04:17:35'),
  ('BUY', 4637.06, '2026.08.24 04:17:36'),
  ('BUY', 4637.08, '2026.08.24 04:17:37'),
  ('SELL', 4631.37, '2026.08.24 10:45:11'),
  ('SELL', 4631.37, '2026.08.24 10:45:11'),
  ('SELL', 4631.37, '2026.08.24 10:45:11'),
  ('SELL', 4631.37, '2026.08.24 10:45:11'),
  ('BUY', 4637.05, '2026.08.24 11:58:13'),
  ('BUY', 4637.05, '2026.08.24 11:58:14'),
  ('BUY', 4637.06, '2026.08.24 11:58:16'),
  ('BUY', 4637.08, '2026.08.24 11:58:16'),
  ('BUY', 4637.08, '2026.08.24 11:58:16'),
  ('BUY', 4637.47, '2026.08.24 11:58:17'),
  ('BUY', 4644.22, '2026.08.25 18:22:41'),
  ('BUY', 4644.22, '2026.08.25 18:22:41'),
  ('BUY', 4644.21, '2026.08.25 18:22:42'),
  ('BUY', 4644.21, '2026.08.25 18:22:42'),
  ('BUY', 4644.21, '2026.08.25 18:22:42'),
];

final _referenceOrders = <DemoOrder>[
  for (var index = 0; index < _referenceOrderCaptures.length; index++)
    DemoOrder(
      id: 'reference-order-$index',
      symbol: 'XAUUSD+',
      side: _referenceOrderCaptures[index].$1,
      type: 'Market',
      volume: 1,
      requestedPrice: _referenceOrderCaptures[index].$2,
      executedPrice: _referenceOrderCaptures[index].$2,
      status: 'filled',
      time: _referenceOrderCaptures[index].$3,
    ),
];

final _referenceDeals = <DemoDeal>[
  for (var index = 0; index < 9; index++)
    DemoDeal(
      id: 'reference-prior-deal-$index',
      orderId: 'reference-prior-order-$index',
      symbol: 'XAUUSD+',
      side: 'SELL',
      volume: 1,
      price: 4631.37,
      profit: switch (index) {
        5 => 854,
        6 => 851,
        7 => 814,
        8 => 791,
        _ => 0,
      },
      entry: 'out',
      time: '2026.08.24 10:45:11',
    ),
  for (var index = 0; index < 11; index++)
    DemoDeal(
      id: 'reference-deal-$index',
      orderId: 'reference-order-$index',
      symbol: 'XAUUSD+',
      side: 'BUY',
      volume: 1,
      price: _referenceOpenPositions[index].openPrice,
      profit: 0,
      time: switch (index) {
        0 => '2026.08.24 11:58:13',
        1 => '2026.08.24 11:58:14',
        2 => '2026.08.24 11:58:16',
        3 => '2026.08.24 11:58:16',
        4 => '2026.08.24 11:58:16',
        5 => '2026.08.24 11:58:17',
        6 => '2026.08.25 18:22:41',
        7 => '2026.08.25 18:22:41',
        _ => '2026.08.25 18:22:42',
      },
    ),
];
