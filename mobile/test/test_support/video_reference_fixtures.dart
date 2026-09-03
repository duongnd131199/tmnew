import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

const videoPrimaryAccountId = '10001001';
const videoLargeAccountId = '10001002';
const videoEmptyAccountId = '10001003';
const videoAlternateAccountId = '10001004';

const videoDemoAccountProfiles = <DemoAccountProfile>[
  DemoAccountProfile(
    id: videoPrimaryAccountId,
    name: 'Demo Account One',
    company: 'Demo Markets Ltd',
    server: 'Demo-Live-01',
    accessPoint: 'Demo Access 01',
    balance: 2292.60,
    brand: DemoBrokerBrand.unknown,
    historyDeposit: 318441.72,
    historyWithdrawal: -325690.38,
    historyProfit: 21081.96,
    historySwap: 0,
    historyCommission: -11531.70,
    historyBalance: 2301.60,
  ),
  DemoAccountProfile(
    id: videoLargeAccountId,
    name: 'Demo Account Two',
    company: 'Demo Markets Ltd',
    server: 'Demo-Trial-02',
    accessPoint: 'Demo Access 02',
    balance: 27297978.10,
    brand: DemoBrokerBrand.unknown,
    historyDeposit: 12000119,
    historyWithdrawal: 0,
    historyProfit: 15297859.10,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 27297978.10,
    isDemo: true,
  ),
  DemoAccountProfile(
    id: videoEmptyAccountId,
    name: 'Demo Account Three',
    company: 'Sample Markets Ltd',
    server: 'Sample-Live-03',
    accessPoint: 'Demo Access 03',
    balance: 0,
    brand: DemoBrokerBrand.unknown,
    historyDeposit: 0,
    historyWithdrawal: 0,
    historyProfit: 0,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 0,
  ),
  DemoAccountProfile(
    id: videoAlternateAccountId,
    name: 'Demo Account Four',
    company: 'Sample Markets Ltd',
    server: 'Sample-Live-04',
    accessPoint: 'Demo Access 04',
    balance: 0,
    brand: DemoBrokerBrand.unknown,
    historyDeposit: 0,
    historyWithdrawal: 0,
    historyProfit: 0,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 0,
  ),
];

final videoDemoQuotes = <DemoQuote>[
  DemoQuote(
    symbol: 'XAUUSD+',
    name: 'Gold US Dollar',
    bid: 4104.09,
    ask: 4104.22,
    changePercent: 0,
    sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
  ),
  DemoQuote(
    symbol: 'XAUUSD',
    name: 'Gold US Dollar',
    bid: 4104.09,
    ask: 4104.22,
    changePercent: 0,
    sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
  ),
  DemoQuote(
    symbol: 'BTCUSD',
    name: 'Bitcoin',
    bid: 65175.98,
    ask: 65193.10,
    changePercent: 0,
    sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 30),
  ),
];

final videoReferenceDailyCandles = <String, List<MarketCandle>>{
  for (final symbol in const ['XAUUSD+', 'XAUUSD'])
    symbol: [
      MarketCandle(
        time: DateTime.utc(2026, 8, 30),
        open: 4104.40,
        high: 4105.00,
        low: 4103.80,
        close: 4104.09,
      ),
      MarketCandle(
        time: DateTime.utc(2026, 8, 31),
        open: 4104.09,
        high: 4104.22,
        low: 4104.09,
        close: 4104.09,
      ),
    ],
  'BTCUSD': [
    MarketCandle(
      time: DateTime.utc(2026, 8, 30),
      open: 65120,
      high: 65220,
      low: 65080,
      close: 65175.98,
    ),
    MarketCandle(
      time: DateTime.utc(2026, 8, 31),
      open: 65175.98,
      high: 65193.10,
      low: 65175.98,
      close: 65175.98,
    ),
  ],
};

double videoMarginCalculator(String accountId, int positionCount) =>
    switch (accountId) {
      videoPrimaryAccountId =>
        positionCount == 0 ? 0 : 1231.48 * positionCount / 6,
      videoLargeAccountId =>
        positionCount == 0 ? 0 : 1470684.33 * positionCount / 10,
      _ => 0,
    };

List<Override> get videoReferenceOverrides => [
  demoAccountCatalogProvider.overrideWithValue(videoDemoAccountProfiles),
  demoTradingSeedProvider.overrideWithValue(videoTradingSeed),
  demoMarginCalculatorProvider.overrideWithValue(videoMarginCalculator),
  demoQuotesProvider.overrideWithValue(videoDemoQuotes),
  marketCandlesProvider.overrideWith(
    (ref, request) => Stream.value(
      videoReferenceDailyCandles[request.symbol] ?? const <MarketCandle>[],
    ),
  ),
];

ProviderContainer createVideoReferenceContainer({
  List<Override> overrides = const [],
}) => ProviderContainer(
  overrides: [
    for (final defaultOverride in videoReferenceOverrides)
      if (!overrides.any(
        (override) => identical(override.origin, defaultOverride.origin),
      ))
        defaultOverride,
    ...overrides,
  ],
);

DemoTradingState videoTradingSeed(String accountId) {
  return switch (accountId) {
    videoLargeAccountId => _hugeAccountFixture(),
    videoEmptyAccountId || videoAlternateAccountId => const DemoTradingState(
      positions: [],
      deals: [],
      balance: 0,
    ),
    _ => _smallAccountFixture(),
  };
}

DemoTradingState _smallAccountFixture() {
  const currentPrice = 4104.09;
  const openPrices = [4104.46, 4105.03, 4105.05, 4105.04, 4105.04, 4105.04];
  final positions = [
    for (var index = 0; index < openPrices.length; index++)
      DemoPosition(
        id: '$videoPrimaryAccountId${(index + 1).toString().padLeft(2, '0')}',
        symbol: 'XAUUSD+',
        side: 'BUY',
        volume: .25,
        openPrice: openPrices[index],
        currentPrice: currentPrice,
        profit: (currentPrice - openPrices[index]) * 25,
        openedAt: '2026.07.27 04:00:${(47 + index).toString().padLeft(2, '0')}',
      ),
  ];

  const orders = [
    DemoOrder(
      id: '57360798130',
      symbol: 'XAUUSD+',
      side: 'BUY',
      type: 'Market',
      volume: .25,
      requestedPrice: 4105.05,
      executedPrice: 4105.05,
      status: 'filled',
      time: '2026.07.27 04:00:49',
    ),
    DemoOrder(
      id: '57360797890',
      symbol: 'XAUUSD+',
      side: 'BUY',
      type: 'Market',
      volume: .25,
      requestedPrice: 4104.46,
      executedPrice: 4104.46,
      status: 'filled',
      time: '2026.07.27 04:00:47',
    ),
  ];
  const deals = [
    DemoDeal(
      id: '57016800413',
      orderId: '57360798130',
      symbol: 'XAUUSD+',
      side: 'BUY',
      volume: .25,
      price: 4105.05,
      profit: 0,
      time: '2026.07.27 04:00:49',
    ),
    DemoDeal(
      id: '57016800101',
      orderId: '57360797890',
      symbol: 'XAUUSD+',
      side: 'BUY',
      volume: .25,
      price: 4104.46,
      profit: 0,
      time: '2026.07.27 04:00:47',
    ),
  ];

  const oldHistory = <(String, double, double, double, String)>[
    ('SELL', .01, 4061.39, 4063.44, '2026.07.24 16:58:42'),
    ('SELL', .01, 4061.39, 4063.44, '2026.07.24 16:58:42'),
    ('SELL', .01, 4059.37, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4059.28, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4059.25, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4057.24, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4057.25, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4057.25, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4049.66, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4049.61, 4063.28, '2026.07.24 16:58:42'),
    ('SELL', .01, 4049.50, 4063.28, '2026.07.24 16:58:42'),
  ];
  const recentHistory = <(String, double, double, double, String)>[
    ('BUY', .25, 4107.36, 4108.56, '2026.07.27 04:02:04'),
    ('BUY', .25, 4107.12, 4109.95, '2026.07.27 04:02:35'),
    ('BUY', .25, 4107.16, 4110.16, '2026.07.27 04:02:41'),
    ('BUY', .25, 4107.07, 4108.56, '2026.07.27 04:02:55'),
    ('SELL', .25, 4107.72, 4111.29, '2026.07.27 04:06:12'),
    ('SELL', .25, 4108.03, 4111.29, '2026.07.27 04:06:12'),
    ('SELL', .25, 4108.04, 4111.29, '2026.07.27 04:06:12'),
    ('SELL', .25, 4109.41, 4101.24, '2026.07.27 04:30:11'),
    ('SELL', .25, 4109.57, 4101.24, '2026.07.27 04:30:11'),
    ('SELL', .25, 4109.58, 4101.24, '2026.07.27 04:30:11'),
    ('SELL', .25, 4109.58, 4101.24, '2026.07.27 04:30:11'),
    ('SELL', .25, 4109.98, 4101.24, '2026.07.27 04:30:11'),
    ('BUY', .25, 4111.02, 4109.68, '2026.07.27 05:00:47'),
    ('BUY', .25, 4111.26, 4109.68, '2026.07.27 05:00:47'),
    ('BUY', .25, 4111.34, 4109.68, '2026.07.27 05:00:47'),
    ('BUY', .25, 4112.02, 4109.68, '2026.07.27 05:00:47'),
    ('BUY', .25, 4112.54, 4109.68, '2026.07.27 05:00:47'),
    ('SELL', .25, 4108.71, 4104.37, '2026.07.27 05:13:10'),
    ('SELL', .25, 4108.83, 4104.37, '2026.07.27 05:13:10'),
    ('SELL', .25, 4109.12, 4104.37, '2026.07.27 05:13:10'),
    ('SELL', .25, 4107.48, 4104.37, '2026.07.27 05:13:10'),
    ('SELL', .25, 4107.48, 4104.37, '2026.07.27 05:13:10'),
    ('SELL', .25, 4107.46, 4104.37, '2026.07.27 05:13:10'),
  ];
  var historyIndex = 0;
  DemoHistoryPosition trade((String, double, double, double, String) item) {
    final direction = item.$1 == 'BUY' ? 1.0 : -1.0;
    return DemoHistoryPosition(
      id: 'small-history-${historyIndex++}',
      title: 'XAUUSD+',
      side: item.$1,
      volume: item.$2,
      openPrice: item.$3,
      closePrice: item.$4,
      profit: (item.$4 - item.$3) * direction * item.$2 * 100,
      time: item.$5,
    );
  }

  final history = <DemoHistoryPosition>[
    for (final item in oldHistory) trade(item),
    const DemoHistoryPosition(
      id: 'small-balance-adjustment',
      title: 'Balance',
      subtitle: 'Cash Adjustment-Debt W/O',
      profit: 1.41,
      time: '2026.07.24 17:15:21',
    ),
    const DemoHistoryPosition(
      id: 'small-balance-transfer',
      title: 'Balance',
      subtitle: 'Transfer In from 32401745',
      profit: 1000.10,
      time: '2026.07.27 03:52:05',
    ),
    for (final item in recentHistory) trade(item),
  ];

  return DemoTradingState(
    positions: positions,
    orders: orders,
    deals: deals,
    historyPositions: history,
    balance: 2292.60,
  );
}

DemoTradingState _hugeAccountFixture() {
  const currentPrice = 4102.396;
  const openPrices = [
    4108.117,
    4108.402,
    4108.299,
    4108.634,
    4108.145,
    4108.142,
    4107.734,
    4107.607,
    4107.143,
    4108.345,
  ];
  final positions = [
    for (var index = 0; index < openPrices.length; index++)
      DemoPosition(
        id: '$videoLargeAccountId${(index + 1).toString().padLeft(2, '0')}',
        symbol: 'XAUUSD',
        side: 'BUY',
        volume: 179,
        openPrice: openPrices[index],
        currentPrice: currentPrice,
        profit: (currentPrice - openPrices[index]) * 17900,
        openedAt: '2026.07.24 17:${(index + 8).toString().padLeft(2, '0')}:38',
      ),
  ];
  const rawHistory = <(String, double, double, String)>[
    ('SELL', 4062.981, 4062.568, '2026.07.24 18:04:32'),
    ('SELL', 4063.230, 4062.500, '2026.07.24 18:04:32'),
    ('SELL', 4063.207, 4062.605, '2026.07.24 18:04:33'),
    ('SELL', 4063.088, 4062.616, '2026.07.24 18:04:34'),
    ('SELL', 4063.088, 4062.616, '2026.07.24 18:04:34'),
    ('SELL', 4063.079, 4062.596, '2026.07.24 18:04:36'),
    ('SELL', 4063.149, 4062.605, '2026.07.24 18:04:36'),
    ('SELL', 4063.039, 4062.643, '2026.07.24 18:04:38'),
    ('SELL', 4063.212, 4062.594, '2026.07.24 18:04:39'),
    ('SELL', 4063.177, 4062.643, '2026.07.24 18:04:40'),
    ('SELL', 4062.945, 4062.461, '2026.07.24 18:04:41'),
    ('SELL', 4063.221, 4062.434, '2026.07.24 18:04:42'),
    ('SELL', 4076.888, 4062.754, '2026.07.24 18:16:35'),
    ('SELL', 4076.729, 4062.653, '2026.07.24 18:16:37'),
    ('SELL', 4076.926, 4062.739, '2026.07.24 18:16:38'),
    ('SELL', 4076.641, 4062.675, '2026.07.24 18:16:38'),
    ('SELL', 4075.688, 4062.739, '2026.07.24 18:16:39'),
    ('SELL', 4054.438, 4053.338, '2026.07.24 18:34:06'),
    ('SELL', 4054.589, 4053.338, '2026.07.24 18:34:07'),
    ('SELL', 4054.492, 4053.338, '2026.07.24 18:34:07'),
    ('SELL', 4054.913, 4053.573, '2026.07.24 18:34:08'),
    ('SELL', 4054.725, 4053.573, '2026.07.24 18:34:08'),
    ('SELL', 4054.695, 4053.501, '2026.07.24 18:34:09'),
    ('SELL', 4054.980, 4053.120, '2026.07.24 18:34:10'),
    ('SELL', 4054.977, 4053.051, '2026.07.24 18:34:10'),
    ('SELL', 4054.935, 4053.250, '2026.07.24 18:34:11'),
    ('SELL', 4054.935, 4053.798, '2026.07.24 18:34:12'),
    ('BUY', 4052.860, 4053.699, '2026.07.24 19:08:39'),
    ('BUY', 4052.891, 4053.699, '2026.07.24 19:08:39'),
    ('BUY', 4053.079, 4053.699, '2026.07.24 19:08:39'),
    ('BUY', 4052.516, 4053.699, '2026.07.24 19:08:39'),
    ('BUY', 4052.351, 4053.699, '2026.07.24 19:08:39'),
    ('BUY', 4055.724, 4107.268, '2026.07.27 01:15:52'),
    ('BUY', 4055.888, 4107.268, '2026.07.27 01:15:56'),
    ('BUY', 4055.860, 4108.040, '2026.07.27 01:16:01'),
    ('BUY', 4055.575, 4107.693, '2026.07.27 01:16:06'),
    ('BUY', 4055.575, 4107.788, '2026.07.27 01:16:11'),
  ];
  final history = <DemoHistoryPosition>[
    for (var index = 0; index < rawHistory.length; index++)
      () {
        final item = rawHistory[index];
        final direction = item.$1 == 'BUY' ? 1.0 : -1.0;
        return DemoHistoryPosition(
          id: 'huge-history-$index',
          title: 'XAUUSD',
          side: item.$1,
          volume: 179,
          openPrice: item.$2,
          closePrice: item.$3,
          profit: (item.$3 - item.$2) * direction * 17900,
          time: item.$4,
        );
      }(),
  ];
  final orders = [
    for (var index = 0; index < 12; index++)
      DemoOrder(
        id: 'huge-order-$index',
        symbol: 'XAUUSD',
        side: index.isEven ? 'BUY' : 'SELL',
        type: 'Market',
        volume: 179,
        requestedPrice: 4108 + index * .07,
        executedPrice: 4108 + index * .07,
        status: 'filled',
        time: '2026.07.24 17:${(8 + index).toString().padLeft(2, '0')}:38',
      ),
  ];
  final deals = [
    for (var index = 0; index < 12; index++)
      DemoDeal(
        id: 'huge-deal-$index',
        orderId: 'huge-order-$index',
        symbol: 'XAUUSD',
        side: index.isEven ? 'BUY' : 'SELL',
        volume: 179,
        price: 4108 + index * .07,
        profit: index.isEven ? 14663.20 + index * 500 : 249991.40 - index * 700,
        time: '2026.07.24 17:${(8 + index).toString().padLeft(2, '0')}:38',
      ),
  ];
  return DemoTradingState(
    positions: positions,
    orders: orders,
    deals: deals,
    historyPositions: history,
    balance: 27297978.10,
  );
}
