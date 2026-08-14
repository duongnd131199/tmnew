import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/mock_quote_service.dart';
import 'package:trading_mobile/features/profile/application/ex_v2_account_profile_mapper.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

export 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';

const _nasdaqSearchQuotes = <DemoQuote>[
  DemoQuote(
    symbol: 'C',
    name: 'Citigroup Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CC',
    name: 'Chemours Company (The)',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CE',
    name: 'Celanese Corporation',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CF',
    name: 'CF Industries Holdings Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CG',
    name: 'The Carlyle Group Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CI',
    name: 'The Cigna Group',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CL',
    name: 'Colgate-Palmolive Company',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'CM',
    name: 'Canadian Imperial Bank of Commerce',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XP',
    name: 'XP Inc. - Class A',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XE',
    name: 'Xtrackers S&P 500 ESG ETF',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XBP',
    name: 'XBP Europe Holdings Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XEL',
    name: 'Xcel Energy Inc.',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XGN',
    name: 'Exagen Inc.',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XHR',
    name: 'Xenia Hotels & Resorts Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XLO',
    name: 'Xilio Therapeutics Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XOM',
    name: 'Exxon Mobil Corporation',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'U',
    name: 'Unity Software Inc Common Stock',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UE',
    name: 'Urban Edge Properties of Beneficial Interest',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UG',
    name: 'United-Guardian Inc - Common Stock',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UI',
    name: 'Ubiquiti Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UK',
    name: 'Ucommune International Ltd',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UP',
    name: 'Wheels Up Experience Inc Class A',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UA',
    name: 'Under Armour Inc Class C',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'UL',
    name: 'Unilever PLC American Depositary Shares',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USA',
    name: 'Liberty All-Star Equity Fund',
    bid: 5.83,
    ask: 5.84,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USB',
    name: 'U.S. Bancorp',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USAS',
    name: 'Americas Gold and Silver Corporation',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USAU',
    name: 'U.S. Gold Corp',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USEA',
    name: 'United Maritime Corporation - Common Stock',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USFD',
    name: 'US Foods Holding Corp',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USGO',
    name: 'U.S. GoldMining Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(symbol: 'USIO', name: 'Usio Inc', bid: 0, ask: 0, changePercent: 0),
  DemoQuote(
    symbol: 'USLM',
    name: 'United States Lime & Minerals Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USPH',
    name: 'U.S. Physical Therapy Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USNA',
    name: 'USANA Health Sciences Inc',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'USCB',
    name: 'USCB Financial Holdings Inc - Class A',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'XAUG',
    name: 'FT Vest U.S. Equity Enhance & Moderate Buffer ETF',
    bid: 0,
    ask: 0,
    changePercent: 0,
  ),
];

final demoQuotesProvider = Provider<List<DemoQuote>>((ref) {
  return const [
    DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 4104.09,
      ask: 4104.22,
      changePercent: 1.24,
    ),
    DemoQuote(
      symbol: 'XAUUSD',
      name: 'Gold US Dollar',
      bid: 4104.09,
      ask: 4104.22,
      changePercent: 1.24,
    ),
    DemoQuote(
      symbol: 'AUDNOK',
      name: 'Australian Dollar vs Norwegian Krona',
      bid: 6.83496,
      ask: 6.83643,
      changePercent: -0.18,
    ),
    DemoQuote(
      symbol: 'AUDCAD',
      name: 'Australian Dollar vs Canadian Dollar',
      bid: 0.95214,
      ask: 0.95222,
      changePercent: -0.08,
    ),
    DemoQuote(
      symbol: 'AUDCHF',
      name: 'Australian Dollar vs Swiss Franc',
      bid: 0.56382,
      ask: 0.56391,
      changePercent: -0.11,
    ),
    DemoQuote(
      symbol: 'AUDDKK',
      name: 'Australian Dollar vs Danish Krona',
      bid: 4.43821,
      ask: 4.43902,
      changePercent: -0.16,
    ),
    DemoQuote(
      symbol: 'AUDHKD',
      name: 'Australian Dollar vs Hong Kong Dollar',
      bid: 5.45816,
      ask: 5.45921,
      changePercent: -0.12,
    ),
    DemoQuote(
      symbol: 'AUDHUF',
      name: 'Australian Dollar vs Hungarian Forint',
      bid: 236.814,
      ask: 237.102,
      changePercent: -0.22,
    ),
    DemoQuote(
      symbol: 'AUDJPY',
      name: 'Australian Dollar vs Japanese Yen',
      bid: 113.422,
      ask: 113.438,
      changePercent: -0.15,
    ),
    DemoQuote(
      symbol: 'AUDNZD',
      name: 'Australian Dollar vs New Zealand Dollar',
      bid: 1.19421,
      ask: 1.19439,
      changePercent: -0.05,
    ),
    DemoQuote(
      symbol: 'AUDPLN',
      name: 'Australian Dollar vs Zloty',
      bid: 2.52814,
      ask: 2.52931,
      changePercent: -0.17,
    ),
    DemoQuote(
      symbol: 'AUDSEK',
      name: 'Australian Dollar vs Swedish Krona',
      bid: 6.57318,
      ask: 6.57502,
      changePercent: -0.19,
    ),
    DemoQuote(
      symbol: 'AUDSGD',
      name: 'Australian Dollar vs Singapore Dollar',
      bid: 0.89712,
      ask: 0.89729,
      changePercent: -0.09,
    ),
    DemoQuote(
      symbol: 'AUDTHB',
      name: 'Australian Dollar vs Thai Baht',
      bid: 22.742,
      ask: 22.781,
      changePercent: -0.13,
    ),
    DemoQuote(
      symbol: 'XAUEUR',
      name: 'Gold vs Euro',
      bid: 3565.43,
      ask: 3565.67,
      changePercent: 0.22,
    ),
    DemoQuote(
      symbol: 'XAUAUD',
      name: 'Gold vs Australian Dollar',
      bid: 5806.44,
      ask: 5808.33,
      changePercent: -0.05,
    ),
    DemoQuote(
      symbol: 'XAUCHF',
      name: 'Gold vs Swiss Franc',
      bid: 3286.41,
      ask: 3289.17,
      changePercent: -1.27,
    ),
    DemoQuote(
      symbol: 'XAUGBP',
      name: 'Gold vs Great Britain Pound',
      bid: 3041.22,
      ask: 3043.81,
      changePercent: -1.19,
    ),
    DemoQuote(
      symbol: 'EURUSD',
      name: 'Euro vs US Dollar',
      bid: 1.14381,
      ask: 1.14384,
      changePercent: -0.18,
    ),
    DemoQuote(
      symbol: 'GBPUSD',
      name: 'British Pound / US Dollar',
      bid: 1.34513,
      ask: 1.34520,
      changePercent: 0.11,
    ),
    DemoQuote(
      symbol: 'USDCHF',
      name: 'US Dollar / Swiss Franc',
      bid: 0.80735,
      ask: 0.80738,
      changePercent: -0.08,
    ),
    DemoQuote(
      symbol: 'USDJPY',
      name: 'US Dollar / Japanese Yen',
      bid: 162.393,
      ask: 162.397,
      changePercent: -0.25,
    ),
    DemoQuote(
      symbol: 'USDCNH',
      name: 'US Dollar / Chinese Yuan',
      bid: 6.77760,
      ask: 6.77847,
      changePercent: 0.06,
    ),
    DemoQuote(
      symbol: 'USDRUB',
      name: 'US Dollar / Russian Ruble',
      bid: 76.894,
      ask: 78.694,
      changePercent: 0.02,
    ),
    DemoQuote(
      symbol: 'AUDUSD',
      name: 'Australian Dollar / US Dollar',
      bid: 0.69814,
      ask: 0.69817,
      changePercent: 0.12,
    ),
    DemoQuote(
      symbol: 'NZDUSD',
      name: 'New Zealand Dollar / US Dollar',
      bid: 0.58423,
      ask: 0.58444,
      changePercent: -0.09,
    ),
    DemoQuote(
      symbol: 'USDCAD',
      name: 'US Dollar / Canadian Dollar',
      bid: 1.40230,
      ask: 1.40232,
      changePercent: -0.05,
    ),
    DemoQuote(
      symbol: 'USDSEK',
      name: 'US Dollar / Swedish Krona',
      bid: 9.63374,
      ask: 9.65530,
      changePercent: 0.04,
    ),
    DemoQuote(
      symbol: 'BTCUSD',
      name: 'Bitcoin',
      bid: 65175.98,
      ask: 65193.10,
      changePercent: 0.82,
    ),
    DemoQuote(
      symbol: 'US30',
      name: 'Dow Jones 30',
      bid: 44892.1,
      ask: 44895.9,
      changePercent: -0.36,
    ),
    ..._nasdaqSearchQuotes,
  ];
});

final mockQuoteServiceProvider = Provider<MockQuoteService>(
  (ref) => const MockQuoteService(),
);

final demoQuoteProvider = StreamProvider.family<DemoQuote, String>((
  ref,
  symbol,
) {
  final quotes = ref.watch(demoQuotesProvider);
  final initial = quotes.firstWhere(
    (quote) => quote.symbol == symbol,
    orElse: () => quotes.first,
  );
  final activeAccountId = ref.watch(activeDemoAccountIdProvider);
  final accountAdjusted =
      activeAccountId == '463696038' &&
          (symbol == 'XAUUSD+' || symbol == 'XAUUSD')
      ? DemoQuote(
          symbol: initial.symbol,
          name: initial.name,
          bid: 4102.396,
          ask: 4102.520,
          changePercent: initial.changePercent,
        )
      : initial;
  final marketApiConfig = ref.watch(marketApiConfigProvider);
  if (marketApiConfig.enabled) {
    return ref
        .watch(realtimeMarketServiceProvider)
        .watchQuote(symbol, accountAdjusted);
  }
  return ref.watch(mockQuoteServiceProvider).watchQuote(accountAdjusted);
});

const demoAccountProfiles = <DemoAccountProfile>[
  DemoAccountProfile(
    id: '28210230',
    name: 'Delete',
    company: 'Vantage Markets (Pty) Ltd',
    server: 'VantageMarkets-Live 19',
    accessPoint: 'AS01',
    balance: 2292.60,
    brand: DemoBrokerBrand.vantage,
    historyDeposit: 318441.72,
    historyWithdrawal: -325690.38,
    historyProfit: 21081.96,
    historySwap: 0,
    historyCommission: -11531.70,
    historyBalance: 2301.60,
  ),
  DemoAccountProfile(
    id: '463696038',
    name: 'Mỗi Ngày Một Tỷ 🍀',
    company: 'Exness Technologies Ltd',
    server: 'Exness-MT5Trial17',
    accessPoint: 'Access Point #2',
    balance: 27297978.10,
    brand: DemoBrokerBrand.exness,
    historyDeposit: 12000119,
    historyWithdrawal: 0,
    historyProfit: 15297859.10,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 27297978.10,
    isDemo: true,
  ),
  DemoAccountProfile(
    id: '425302695',
    name: 'Mỗi Ngày Một Tỷ 🍀',
    company: 'Exness Technologies Ltd',
    server: 'Exness-MT5Real15',
    accessPoint: 'Access Point #14',
    balance: 0,
    brand: DemoBrokerBrand.exness,
    historyDeposit: 0,
    historyWithdrawal: 0,
    historyProfit: 0,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 0,
  ),
  DemoAccountProfile(
    id: '425297911',
    name: 'Mỗi Ngày 10.000\$ 🍀',
    company: 'Exness Technologies Ltd',
    server: 'Exness-MT5Real15',
    accessPoint: 'Access Point #14',
    balance: 0,
    brand: DemoBrokerBrand.exness,
    historyDeposit: 0,
    historyWithdrawal: 0,
    historyProfit: 0,
    historySwap: 0,
    historyCommission: 0,
    historyBalance: 0,
  ),
];

final demoAccountsProvider = Provider<List<DemoAccountProfile>>((ref) {
  final serverMode = ref.watch(exV2EnabledProvider);
  final server = ref.watch(exV2AccountProvider).value;
  if (server == null) {
    return serverMode ? const <DemoAccountProfile>[] : demoAccountProfiles;
  }
  return [ExV2AccountProfileMapper.map(server)];
});

class ActiveDemoAccountController extends Notifier<String> {
  @override
  String build() => demoAccountProfiles.first.id;

  void select(String accountId) {
    if (demoAccountProfiles.any((account) => account.id == accountId)) {
      state = accountId;
    }
  }
}

final activeDemoAccountIdProvider =
    NotifierProvider<ActiveDemoAccountController, String>(
      ActiveDemoAccountController.new,
    );

final activeDemoAccountProvider = Provider<DemoAccountProfile>((ref) {
  final serverMode = ref.watch(exV2EnabledProvider);
  final server = ref.watch(exV2AccountProvider).value;
  if (server != null) return ref.watch(demoAccountsProvider).single;
  if (serverMode) {
    throw StateError('The authorized server account is not available yet.');
  }
  final accountId = ref.watch(activeDemoAccountIdProvider);
  return demoAccountProfiles.firstWhere(
    (account) => account.id == accountId,
    orElse: () => demoAccountProfiles.first,
  );
});

class DemoTradingState {
  const DemoTradingState({
    required this.positions,
    required this.deals,
    this.historyPositions = const [],
    this.pendingOrders = const [],
    this.orders = const [],
    this.balance = 100000,
  });

  final List<DemoPosition> positions;
  final List<DemoHistoryPosition> historyPositions;
  final List<DemoPendingOrder> pendingOrders;
  final List<DemoOrder> orders;
  final List<DemoDeal> deals;
  final double balance;

  DemoTradingState copyWith({
    List<DemoPosition>? positions,
    List<DemoHistoryPosition>? historyPositions,
    List<DemoPendingOrder>? pendingOrders,
    List<DemoOrder>? orders,
    List<DemoDeal>? deals,
    double? balance,
  }) {
    return DemoTradingState(
      positions: positions ?? this.positions,
      historyPositions: historyPositions ?? this.historyPositions,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      orders: orders ?? this.orders,
      deals: deals ?? this.deals,
      balance: balance ?? this.balance,
    );
  }
}

class DemoTradingController extends Notifier<DemoTradingState> {
  int _sequence = 0;
  final Map<String, DemoTradingState> _accountStates =
      <String, DemoTradingState>{};
  String? _activeAccountId;

  @override
  DemoTradingState build() {
    if (ref.watch(exV2EnabledProvider)) {
      final server = ref.watch(exV2AccountProvider).value;
      if (server == null) {
        return const DemoTradingState(positions: [], deals: [], balance: 0);
      }
      return DemoTradingState(
        positions: server.positions,
        historyPositions: server.historyPositions,
        pendingOrders: server.pendingOrders,
        orders: server.orders,
        deals: server.deals,
        balance: server.balance,
      );
    }
    final accountId = ref.watch(activeDemoAccountIdProvider);
    _activeAccountId = accountId;
    final cached = _accountStates[accountId];
    if (cached != null) return cached;
    if (accountId != '__legacy_reference__') {
      final initial = _buildAccountTradingFixture(accountId);
      _accountStates[accountId] = initial;
      return initial;
    }
    final initial = const DemoTradingState(
      positions: [
        DemoPosition(
          id: '57360797890',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4078.77,
          currentPrice: 4053.67,
          profit: -25.10,
          openedAt: '2026.07.01 19:37:39',
        ),
        DemoPosition(
          id: '57360798021',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4078.84,
          currentPrice: 4053.67,
          profit: -25.17,
          openedAt: '2026.07.01 19:37:40',
        ),
        DemoPosition(
          id: '57360798130',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4078.87,
          currentPrice: 4053.67,
          profit: -25.20,
          openedAt: '2026.07.01 19:37:41',
        ),
        DemoPosition(
          id: '57360976645',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4073.71,
          currentPrice: 4053.67,
          profit: -20.04,
          openedAt: '2026.07.01 19:48:35',
        ),
        DemoPosition(
          id: '57360977002',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4073.73,
          currentPrice: 4053.67,
          profit: -20.06,
          openedAt: '2026.07.01 19:48:36',
        ),
        DemoPosition(
          id: '57360977704',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          openPrice: 4073.64,
          currentPrice: 4053.93,
          profit: 19.71,
          openedAt: '2026.07.01 19:48:37',
        ),
        DemoPosition(
          id: '57360977918',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          openPrice: 4073.63,
          currentPrice: 4053.93,
          profit: 19.70,
          openedAt: '2026.07.01 19:48:38',
        ),
        DemoPosition(
          id: '57362543211',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4032.75,
          currentPrice: 4053.67,
          profit: 20.92,
          openedAt: '2026.07.02 03:00:56',
        ),
        DemoPosition(
          id: '57375209920',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          openPrice: 4039.05,
          currentPrice: 4053.93,
          profit: -14.88,
          openedAt: '2026.07.08 19:15:38',
        ),
        DemoPosition(
          id: '57375210983',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          openPrice: 4039.03,
          currentPrice: 4053.67,
          profit: 14.64,
          openedAt: '2026.07.08 19:15:49',
        ),
        DemoPosition(
          id: '57375211406',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          openPrice: 4038.72,
          currentPrice: 4053.93,
          profit: -15.21,
          openedAt: '2026.07.08 19:15:55',
        ),
      ],
      orders: [
        DemoOrder(
          id: '57360797890',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4078.77,
          executedPrice: 4078.77,
          status: 'filled',
          time: '2026.07.01 19:37:39',
        ),
        DemoOrder(
          id: '57360798021',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4078.84,
          executedPrice: 4078.84,
          status: 'filled',
          time: '2026.07.01 19:37:40',
        ),
        DemoOrder(
          id: '57360798130',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4078.87,
          executedPrice: 4078.87,
          status: 'filled',
          time: '2026.07.01 19:37:41',
        ),
        DemoOrder(
          id: '57360976645',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4073.71,
          executedPrice: 4073.71,
          status: 'filled',
          time: '2026.07.01 19:48:35',
        ),
        DemoOrder(
          id: '57360977002',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4073.73,
          executedPrice: 4073.73,
          status: 'filled',
          time: '2026.07.01 19:48:36',
        ),
        DemoOrder(
          id: '57360977704',
          symbol: 'XAUUSD',
          side: 'SELL',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4073.64,
          executedPrice: 4073.64,
          status: 'filled',
          time: '2026.07.01 19:48:37',
        ),
        DemoOrder(
          id: '57360977918',
          symbol: 'XAUUSD',
          side: 'SELL',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4073.63,
          executedPrice: 4073.63,
          status: 'filled',
          time: '2026.07.01 19:48:38',
        ),
        DemoOrder(
          id: '57362543211',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Buy Limit',
          volume: 0.01,
          requestedPrice: 4032.75,
          executedPrice: 4032.75,
          status: 'filled',
          time: '2026.07.02 03:00:56',
        ),
        DemoOrder(
          id: '57375209920',
          symbol: 'XAUUSD',
          side: 'SELL',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4039.05,
          executedPrice: 4039.05,
          status: 'filled',
          time: '2026.07.08 19:15:38',
        ),
        DemoOrder(
          id: '57375210983',
          symbol: 'XAUUSD',
          side: 'BUY',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4039.03,
          executedPrice: 4039.03,
          status: 'filled',
          time: '2026.07.08 19:15:49',
        ),
        DemoOrder(
          id: '57375211406',
          symbol: 'XAUUSD',
          side: 'SELL',
          type: 'Market',
          volume: 0.01,
          requestedPrice: 4038.72,
          executedPrice: 4038.72,
          status: 'filled',
          time: '2026.07.08 19:15:55',
        ),
      ],
      deals: [
        DemoDeal(
          id: '57016800101',
          orderId: '57360797890',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4078.77,
          profit: 0,
          time: '2026.07.01 19:37:39',
        ),
        DemoDeal(
          id: '57016800272',
          orderId: '57360798021',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4078.84,
          profit: 0,
          time: '2026.07.01 19:37:40',
        ),
        DemoDeal(
          id: '57016800413',
          orderId: '57360798130',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4078.87,
          profit: 0,
          time: '2026.07.01 19:37:41',
        ),
        DemoDeal(
          id: '57016812881',
          orderId: '57360976645',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4073.71,
          profit: 0,
          time: '2026.07.01 19:48:35',
        ),
        DemoDeal(
          id: '57016813002',
          orderId: '57360977002',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4073.73,
          profit: 0,
          time: '2026.07.01 19:48:36',
        ),
        DemoDeal(
          id: '57016813223',
          orderId: '57360977704',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          price: 4073.64,
          profit: 0,
          time: '2026.07.01 19:48:37',
        ),
        DemoDeal(
          id: '57016813442',
          orderId: '57360977918',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          price: 4073.63,
          profit: 0,
          time: '2026.07.01 19:48:38',
        ),
        DemoDeal(
          id: '57018649876',
          orderId: '57362543211',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4032.75,
          profit: 0,
          time: '2026.07.02 03:00:56',
        ),
        DemoDeal(
          id: '57034450221',
          orderId: '57375209920',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          price: 4039.05,
          profit: 0,
          time: '2026.07.08 19:15:38',
        ),
        DemoDeal(
          id: '57034451104',
          orderId: '57375210983',
          symbol: 'XAUUSD',
          side: 'BUY',
          volume: 0.01,
          price: 4039.03,
          profit: 0,
          time: '2026.07.08 19:15:49',
        ),
        DemoDeal(
          id: '57034451633',
          orderId: '57375211406',
          symbol: 'XAUUSD',
          side: 'SELL',
          volume: 0.01,
          price: 4038.72,
          profit: 0,
          time: '2026.07.08 19:15:55',
        ),
      ],
    );
    _accountStates[accountId] = initial;
    return initial;
  }

  void _commit(DemoTradingState next) {
    state = next;
    final accountId = _activeAccountId;
    if (accountId != null) _accountStates[accountId] = next;
  }

  void resetActiveAccountFixture() {
    final accountId = _activeAccountId;
    if (accountId == null || accountId == '__legacy_reference__') return;
    _commit(_buildAccountTradingFixture(accountId));
  }

  DemoTradingState? stateForAccount(String accountId) =>
      _accountStates[accountId];

  void _submitServer(Future<dynamic> operation) {
    unawaited(() async {
      try {
        await operation;
      } catch (_) {
        // The initiating screen keeps its current data; SignalR or pull-to-refresh
        // will reconcile it. Never fall back to a local financial mutation.
      }
    }());
  }

  String placeOrder({
    required String symbol,
    required String side,
    required double volume,
    required double executedPrice,
    double? stopLoss,
    double? takeProfit,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      final metadata = ExV2CommandMetadata.create();
      _submitServer(
        ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: symbol,
              side: side,
              volume: volume,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              commandMetadata: metadata,
            ),
      );
      return metadata.idempotencyKey;
    }
    final id = _nextId();
    final time = _nowLabel();
    final normalizedSide = side.toUpperCase();
    final position = DemoPosition(
      id: id,
      symbol: symbol,
      side: normalizedSide,
      volume: volume,
      openPrice: executedPrice,
      currentPrice: executedPrice,
      profit: 0,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      openedAt: time,
    );
    final order = DemoOrder(
      id: id,
      symbol: symbol,
      side: normalizedSide,
      type: 'Market',
      volume: volume,
      requestedPrice: executedPrice,
      executedPrice: executedPrice,
      status: 'filled',
      time: time,
    );
    final deal = DemoDeal(
      id: _nextId(prefix: 'D'),
      orderId: id,
      symbol: symbol,
      side: normalizedSide,
      volume: volume,
      profit: 0,
      time: time,
      price: executedPrice,
    );
    _commit(
      state.copyWith(
        positions: [position, ...state.positions],
        orders: [order, ...state.orders],
        deals: [deal, ...state.deals],
      ),
    );
    return id;
  }

  String placePendingOrder({
    required String symbol,
    required String type,
    required double volume,
    required double price,
    double? stopLoss,
    double? takeProfit,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      final metadata = ExV2CommandMetadata.create();
      final normalized = type.trim().toLowerCase();
      final side = normalized.startsWith('buy') ? 'buy' : 'sell';
      final orderType = normalized.contains('stop') ? 'stop' : 'limit';
      _submitServer(
        ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: symbol,
              type: orderType,
              side: side,
              volume: volume,
              requestedPrice: price,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              commandMetadata: metadata,
            ),
      );
      return metadata.idempotencyKey;
    }
    final id = _nextId();
    final time = _nowLabel();
    final side = type.toLowerCase().startsWith('buy') ? 'BUY' : 'SELL';
    final pending = DemoPendingOrder(
      id: id,
      symbol: symbol,
      side: side,
      type: type,
      volume: volume,
      price: price,
      createdAt: time,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
    );
    final order = DemoOrder(
      id: id,
      symbol: symbol,
      side: side,
      type: type,
      volume: volume,
      requestedPrice: price,
      status: 'placed',
      time: time,
    );
    _commit(
      state.copyWith(
        pendingOrders: [pending, ...state.pendingOrders],
        orders: [order, ...state.orders],
      ),
    );
    return id;
  }

  bool modifyPosition(
    String positionId, {
    double? stopLoss,
    double? takeProfit,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      final server = ref.read(exV2AccountProvider).value;
      if (server == null ||
          !server.positions.any((position) => position.id == positionId)) {
        return false;
      }
      _submitServer(
        ref
            .read(exV2AccountProvider.notifier)
            .updatePositionProtection(
              positionId: positionId,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: clearStopLoss,
              clearTakeProfit: clearTakeProfit,
            ),
      );
      return true;
    }
    var found = false;
    final positions = [
      for (final position in state.positions)
        if (position.id == positionId)
          () {
            found = true;
            return position.copyWith(
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: clearStopLoss,
              clearTakeProfit: clearTakeProfit,
            );
          }()
        else
          position,
    ];
    if (found) _commit(state.copyWith(positions: positions));
    return found;
  }

  bool modifyPendingOrder(
    String orderId, {
    double? price,
    double? stopLoss,
    double? takeProfit,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      final server = ref.read(exV2AccountProvider).value;
      final matches = server?.pendingOrders.where(
        (order) => order.id == orderId,
      );
      if (matches == null || matches.isEmpty) return false;
      _submitServer(
        ref
            .read(exV2AccountProvider.notifier)
            .modifyPendingOrder(
              orderId: orderId,
              price: price,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: clearStopLoss,
              clearTakeProfit: clearTakeProfit,
            ),
      );
      return true;
    }
    var found = false;
    final pendingOrders = [
      for (final order in state.pendingOrders)
        if (order.id == orderId)
          () {
            found = true;
            return order.copyWith(
              price: price,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: clearStopLoss,
              clearTakeProfit: clearTakeProfit,
            );
          }()
        else
          order,
    ];
    if (!found) return false;
    final orders = [
      for (final order in state.orders)
        order.id == orderId && price != null
            ? order.copyWith(requestedPrice: price)
            : order,
    ];
    _commit(state.copyWith(pendingOrders: pendingOrders, orders: orders));
    return true;
  }

  bool closePosition(
    String positionId, {
    double? volume,
    double? realizedProfit,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      final matches = state.positions.where(
        (position) => position.id == positionId,
      );
      if (matches.isEmpty) return false;
      final position = matches.first;
      final closeVolume = volume == null || volume >= position.volume
          ? null
          : volume;
      _submitServer(
        ref
            .read(exV2AccountProvider.notifier)
            .closePosition(positionId, volume: closeVolume),
      );
      return true;
    }
    final matches = state.positions.where((item) => item.id == positionId);
    if (matches.isEmpty) return false;
    final position = matches.first;
    final requestedVolume = volume ?? position.volume;
    if (requestedVolume <= 0) return false;
    final closeVolume = requestedVolume.clamp(0.0, position.volume).toDouble();
    final remainingVolume = position.volume - closeVolume;
    final ratio = closeVolume / position.volume;
    final profit = realizedProfit ?? position.profit * ratio;
    final time = _nowLabel();
    final closingSide = position.side == 'BUY' ? 'SELL' : 'BUY';
    final orderId = _nextId();
    final order = DemoOrder(
      id: orderId,
      symbol: position.symbol,
      side: closingSide,
      type: 'Market',
      volume: closeVolume,
      requestedPrice: position.currentPrice,
      executedPrice: position.currentPrice,
      status: 'filled',
      time: time,
    );
    final deal = DemoDeal(
      id: _nextId(prefix: 'D'),
      orderId: orderId,
      symbol: position.symbol,
      side: closingSide,
      volume: closeVolume,
      profit: profit,
      time: time,
      price: position.currentPrice,
      entry: 'out',
    );
    _commit(
      state.copyWith(
        positions: [
          for (final item in state.positions)
            if (item.id != positionId)
              item
            else if (remainingVolume > 0.00000001)
              item.copyWith(
                volume: remainingVolume,
                profit: item.profit - profit,
              ),
        ],
        historyPositions: [
          ...state.historyPositions,
          DemoHistoryPosition(
            id: 'closed-${position.id}-$time',
            title: position.symbol,
            side: position.side,
            volume: closeVolume,
            openPrice: position.openPrice,
            closePrice: position.currentPrice,
            profit: profit,
            time: time,
          ),
        ],
        orders: [order, ...state.orders],
        deals: [deal, ...state.deals],
        balance: state.balance + profit,
      ),
    );
    return true;
  }

  bool closeBy(String positionId) {
    final source = state.positions.where((item) => item.id == positionId);
    if (source.isEmpty) return false;
    final position = source.first;
    final opposite = state.positions.where(
      (item) =>
          item.id != position.id &&
          item.symbol == position.symbol &&
          item.side != position.side,
    );
    if (opposite.isEmpty) return false;
    return closeByPositions(position.id, opposite.first.id);
  }

  bool closeByPositions(String positionId, String oppositePositionId) {
    final firstMatches = state.positions.where((item) => item.id == positionId);
    final secondMatches = state.positions.where(
      (item) => item.id == oppositePositionId,
    );
    if (firstMatches.isEmpty || secondMatches.isEmpty) return false;
    final first = firstMatches.first;
    final second = secondMatches.first;
    if (first.id == second.id ||
        first.symbol != second.symbol ||
        first.side == second.side) {
      return false;
    }
    if (ref.read(exV2EnabledProvider)) {
      _submitServer(
        ref.read(exV2AccountProvider.notifier).closeBy(first.id, second.id),
      );
      return true;
    }
    final matchedVolume = first.volume < second.volume
        ? first.volume
        : second.volume;
    closePosition(first.id, volume: matchedVolume);
    closePosition(second.id, volume: matchedVolume);
    return true;
  }

  int closeAllPositions({
    bool profitableOnly = false,
    bool losingOnly = false,
  }) {
    final targets = state.positions
        .where(
          (position) =>
              (!profitableOnly || position.profit > 0) &&
              (!losingOnly || position.profit < 0),
        )
        .map((position) => position.id)
        .toList(growable: false);
    for (final id in targets) {
      closePosition(id);
    }
    return targets.length;
  }

  bool cancelPendingOrder(String orderId) {
    if (!state.pendingOrders.any((item) => item.id == orderId)) return false;
    if (ref.read(exV2EnabledProvider)) {
      _submitServer(
        ref.read(exV2AccountProvider.notifier).cancelOrder(orderId),
      );
      return true;
    }
    _commit(
      state.copyWith(
        pendingOrders: state.pendingOrders
            .where((item) => item.id != orderId)
            .toList(),
        orders: [
          for (final order in state.orders)
            order.id == orderId
                ? order.copyWith(status: 'canceled', time: _nowLabel())
                : order,
        ],
      ),
    );
    return true;
  }

  int cancelAllPendingOrders({bool limitOnly = false}) {
    final removed = state.pendingOrders
        .where((item) => !limitOnly || item.isLimit)
        .toList();
    if (removed.isEmpty) return 0;
    if (ref.read(exV2EnabledProvider)) {
      for (final order in removed) {
        _submitServer(
          ref.read(exV2AccountProvider.notifier).cancelOrder(order.id),
        );
      }
      return removed.length;
    }
    final removedIds = removed.map((item) => item.id).toSet();
    _commit(
      state.copyWith(
        pendingOrders: state.pendingOrders
            .where((item) => !removedIds.contains(item.id))
            .toList(),
        orders: [
          for (final order in state.orders)
            removedIds.contains(order.id)
                ? order.copyWith(status: 'canceled', time: _nowLabel())
                : order,
        ],
      ),
    );
    return removed.length;
  }

  void updateMarketPrice({
    required String symbol,
    required double bid,
    required double ask,
  }) {
    if (ref.read(exV2EnabledProvider)) {
      ref
          .read(exV2AccountProvider.notifier)
          .updateMarketPrice(symbol: symbol, bid: bid, ask: ask);
      return;
    }
    final positions = <DemoPosition>[];
    final closeIds = <String>[];
    for (final position in state.positions) {
      if (position.symbol != symbol) {
        positions.add(position);
        continue;
      }
      final currentPrice = position.side == 'BUY' ? bid : ask;
      final direction = position.side == 'BUY' ? 1.0 : -1.0;
      final profit =
          (currentPrice - position.openPrice) *
          direction *
          position.volume *
          100;
      final updated = position.copyWith(
        currentPrice: currentPrice,
        profit: profit,
      );
      positions.add(updated);
      final hitStop =
          position.stopLoss != null &&
          (position.side == 'BUY'
              ? bid <= position.stopLoss!
              : ask >= position.stopLoss!);
      final hitTake =
          position.takeProfit != null &&
          (position.side == 'BUY'
              ? bid >= position.takeProfit!
              : ask <= position.takeProfit!);
      if (hitStop || hitTake) closeIds.add(position.id);
    }
    _commit(state.copyWith(positions: positions));

    final triggered = state.pendingOrders.where((order) {
      if (order.symbol != symbol) return false;
      return switch (order.type.toLowerCase()) {
        'buy limit' => ask <= order.price,
        'buy stop' => ask >= order.price,
        'sell limit' => bid >= order.price,
        'sell stop' => bid <= order.price,
        _ => false,
      };
    }).toList();
    for (final order in triggered) {
      _fillPendingOrder(order, order.side == 'BUY' ? ask : bid);
    }
    for (final positionId in closeIds) {
      closePosition(positionId);
    }
  }

  void _fillPendingOrder(DemoPendingOrder pending, double executedPrice) {
    if (!state.pendingOrders.any((item) => item.id == pending.id)) return;
    final time = _nowLabel();
    final position = DemoPosition(
      id: pending.id,
      symbol: pending.symbol,
      side: pending.side,
      volume: pending.volume,
      openPrice: executedPrice,
      currentPrice: executedPrice,
      profit: 0,
      stopLoss: pending.stopLoss,
      takeProfit: pending.takeProfit,
      openedAt: time,
    );
    final deal = DemoDeal(
      id: _nextId(prefix: 'D'),
      orderId: pending.id,
      symbol: pending.symbol,
      side: pending.side,
      volume: pending.volume,
      profit: 0,
      time: time,
      price: executedPrice,
    );
    _commit(
      state.copyWith(
        positions: [position, ...state.positions],
        pendingOrders: state.pendingOrders
            .where((item) => item.id != pending.id)
            .toList(),
        orders: [
          for (final order in state.orders)
            order.id == pending.id
                ? order.copyWith(
                    status: 'filled',
                    executedPrice: executedPrice,
                    time: time,
                  )
                : order,
        ],
        deals: [deal, ...state.deals],
      ),
    );
  }

  String _nextId({String prefix = ''}) {
    _sequence = (_sequence + 1) % 1000;
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = '$millis${_sequence.toString().padLeft(3, '0')}';
    return '$prefix${suffix.substring(suffix.length - 11)}';
  }

  String _nowLabel() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}.${two(now.month)}.${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }
}

DemoTradingState _buildAccountTradingFixture(String accountId) {
  return switch (accountId) {
    '463696038' => _hugeAccountFixture(),
    '425302695' ||
    '425297911' => const DemoTradingState(positions: [], deals: [], balance: 0),
    _ => _smallAccountFixture(),
  };
}

DemoTradingState _smallAccountFixture() {
  const currentPrice = 4104.09;
  const openPrices = [4104.46, 4105.03, 4105.05, 4105.04, 4105.04, 4105.04];
  final positions = [
    for (var index = 0; index < openPrices.length; index++)
      DemoPosition(
        id: '28210230${(index + 1).toString().padLeft(2, '0')}',
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
        id: '463696038${(index + 1).toString().padLeft(2, '0')}',
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

final demoTradingProvider =
    NotifierProvider<DemoTradingController, DemoTradingState>(
      DemoTradingController.new,
    );
final demoPositionsProvider = Provider<List<DemoPosition>>(
  (ref) => ref.watch(demoTradingProvider).positions,
);
final demoPendingOrdersProvider = Provider<List<DemoPendingOrder>>(
  (ref) => ref.watch(demoTradingProvider).pendingOrders,
);
final demoOrdersProvider = Provider<List<DemoOrder>>(
  (ref) => ref.watch(demoTradingProvider).orders,
);
final demoDealsProvider = Provider<List<DemoDeal>>(
  (ref) => ref.watch(demoTradingProvider).deals,
);
final demoHistoryPositionsProvider = Provider<List<DemoHistoryPosition>>(
  (ref) => ref.watch(demoTradingProvider).historyPositions,
);

class DemoAccountSnapshot {
  const DemoAccountSnapshot({
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.profit,
  });

  final double balance;
  final double equity;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final double profit;
}

final demoAccountProvider = Provider<DemoAccountSnapshot>((ref) {
  final server = ref.watch(exV2AccountProvider).value;
  if (server != null) {
    return DemoAccountSnapshot(
      balance: server.balance,
      equity: server.equity,
      margin: server.margin,
      freeMargin: server.freeMargin,
      marginLevel: server.marginLevel,
      profit: server.profit,
    );
  }
  final trading = ref.watch(demoTradingProvider);
  final account = ref.watch(activeDemoAccountProvider);
  final profit = trading.positions.fold<double>(
    0,
    (total, position) => total + position.profit,
  );
  final margin = switch (account.id) {
    '28210230' =>
      trading.positions.isEmpty ? 0.0 : 1231.48 * trading.positions.length / 6,
    '463696038' =>
      trading.positions.isEmpty
          ? 0.0
          : 1470684.33 * trading.positions.length / 10,
    _ => 0.0,
  };
  final equity = trading.balance + profit;
  final freeMargin = equity - margin;
  return DemoAccountSnapshot(
    balance: trading.balance,
    equity: equity,
    margin: margin,
    freeMargin: freeMargin,
    marginLevel: margin <= 0 ? 0 : equity / margin * 100,
    profit: profit,
  );
});

class ChartIndicatorsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String indicator) {
    state = state.contains(indicator)
        ? ({...state}..remove(indicator))
        : {...state, indicator};
  }
}

final chartIndicatorsProvider =
    NotifierProvider<ChartIndicatorsController, Set<String>>(
      ChartIndicatorsController.new,
    );

class ChartIndicatorsVisibilityController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final chartIndicatorsVisibilityProvider =
    NotifierProvider<ChartIndicatorsVisibilityController, bool>(
      ChartIndicatorsVisibilityController.new,
    );

class DemoChartObject {
  const DemoChartObject({
    required this.id,
    required this.type,
    this.visible = true,
    this.locked = false,
  });

  final String id;
  final String type;
  final bool visible;
  final bool locked;

  DemoChartObject copyWith({bool? visible, bool? locked}) {
    return DemoChartObject(
      id: id,
      type: type,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
    );
  }
}

class ChartObjectsController extends Notifier<List<DemoChartObject>> {
  int _nextObjectId = 0;

  @override
  List<DemoChartObject> build() => const [];

  void add(String type) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextObjectId++}';
    state = [...state, DemoChartObject(id: id, type: type)];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void setAllVisible(bool visible) {
    state = [for (final item in state) item.copyWith(visible: visible)];
  }

  void setAllLocked(bool locked) {
    state = [for (final item in state) item.copyWith(locked: locked)];
  }
}

final chartObjectsProvider =
    NotifierProvider<ChartObjectsController, List<DemoChartObject>>(
      ChartObjectsController.new,
    );

class MarketSymbolsController extends Notifier<List<String>> {
  @override
  List<String> build() => const ['XAUUSD+', 'BTCUSD'];

  void add(String symbol) {
    if (!state.contains(symbol)) state = [...state, symbol];
  }

  void remove(String symbol) {
    state = state.where((item) => item != symbol).toList();
  }

  void removeAll(Iterable<String> symbols) {
    final removed = symbols.toSet();
    if (removed.isEmpty) return;
    state = state.where((item) => !removed.contains(item)).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
  }
}

final marketSymbolsProvider =
    NotifierProvider<MarketSymbolsController, List<String>>(
      MarketSymbolsController.new,
    );

class MarketColumnsController extends Notifier<List<String>> {
  @override
  List<String> build() => const ['Chào mua', 'Chào bán', 'Ngày %'];

  void add(String column) {
    if (!state.contains(column)) state = [...state, column];
  }

  void remove(String column) {
    state = state.where((item) => item != column).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
  }
}

final marketColumnsProvider =
    NotifierProvider<MarketColumnsController, List<String>>(
      MarketColumnsController.new,
    );
