import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

final class ExV2AccountPresentation {
  const ExV2AccountPresentation({
    required this.brokerId,
    required this.companyName,
    required this.serverId,
    required this.tradingServer,
  });

  final String brokerId;
  final String companyName;
  final String serverId;
  final String tradingServer;
}

final class ExV2AccountViewState {
  const ExV2AccountViewState({
    required this.bootstrap,
    required this.positions,
    required this.pendingOrders,
    required this.orders,
    required this.deals,
    this.historyPositions = const [],
    this.historySummary = const ExV2HistorySummary.empty(),
    this.historyTransactions = const [],
    this.deposits = const [],
    this.withdrawals = const [],
    this.transfers = const [],
    this.notifications = const [],
    this.settings = const {},
    this.presentation,
    this.hasLiveValuation = false,
    this.pendingOperationIds = const {},
  });

  factory ExV2AccountViewState.fromBootstrap(
    ExV2Bootstrap bootstrap, {
    ExV2AccountPresentation? presentation,
  }) => ExV2AccountViewState(
    bootstrap: bootstrap,
    presentation: presentation,
    positions: bootstrap.positions
        .map(ExV2DemoMapper.position)
        .toList(growable: false),
    pendingOrders: bootstrap.pendingOrders
        .map(ExV2DemoMapper.pendingOrder)
        .toList(growable: false),
    orders: bootstrap.pendingOrders
        .map(ExV2DemoMapper.order)
        .toList(growable: false),
    deals: bootstrap.recentDeals
        .map(ExV2DemoMapper.deal)
        .toList(growable: false),
  );

  final ExV2Bootstrap bootstrap;
  final List<DemoPosition> positions;
  final List<DemoPendingOrder> pendingOrders;
  final List<DemoOrder> orders;
  final List<DemoDeal> deals;
  final List<DemoHistoryPosition> historyPositions;
  final ExV2HistorySummary historySummary;
  final List<JsonMap> historyTransactions;
  final List<JsonMap> deposits;
  final List<JsonMap> withdrawals;
  final List<JsonMap> transfers;
  final List<JsonMap> notifications;
  final JsonMap settings;
  final ExV2AccountPresentation? presentation;
  final bool hasLiveValuation;
  final Set<String> pendingOperationIds;

  String get accountCode => bootstrap.account.accountCode;
  double get balance => bootstrap.summary.balance;
  double get profit => hasLiveValuation
      ? positions.fold<double>(0, (total, position) => total + position.profit)
      : bootstrap.summary.profit;
  double get equity =>
      hasLiveValuation ? balance + profit : bootstrap.summary.equity;
  double get margin => bootstrap.summary.margin;
  double get freeMargin =>
      hasLiveValuation ? equity - margin : bootstrap.summary.freeMargin;
  double get marginLevel => hasLiveValuation
      ? (margin == 0 ? 0 : equity / margin * 100)
      : bootstrap.summary.marginLevel;
  ExV2Wallet get wallet => bootstrap.wallet;
  ExV2Performance get performance => bootstrap.performance;

  String? positionRowVersion(String id) => bootstrap.positions
      .where((position) => position.id == id)
      .map((position) => position.rowVersion)
      .firstOrNull;

  String? orderRowVersion(String id) => bootstrap.pendingOrders
      .where((order) => order.id == id)
      .map((order) => order.rowVersion)
      .firstOrNull;

  ExV2AccountViewState copyWith({
    ExV2Bootstrap? bootstrap,
    List<DemoPosition>? positions,
    List<DemoPendingOrder>? pendingOrders,
    List<DemoOrder>? orders,
    List<DemoDeal>? deals,
    List<DemoHistoryPosition>? historyPositions,
    ExV2HistorySummary? historySummary,
    List<JsonMap>? historyTransactions,
    List<JsonMap>? deposits,
    List<JsonMap>? withdrawals,
    List<JsonMap>? transfers,
    List<JsonMap>? notifications,
    JsonMap? settings,
    ExV2AccountPresentation? presentation,
    bool? hasLiveValuation,
    Set<String>? pendingOperationIds,
  }) => ExV2AccountViewState(
    bootstrap: bootstrap ?? this.bootstrap,
    positions: positions ?? this.positions,
    pendingOrders: pendingOrders ?? this.pendingOrders,
    orders: orders ?? this.orders,
    deals: deals ?? this.deals,
    historyPositions: historyPositions ?? this.historyPositions,
    historySummary: historySummary ?? this.historySummary,
    historyTransactions: historyTransactions ?? this.historyTransactions,
    deposits: deposits ?? this.deposits,
    withdrawals: withdrawals ?? this.withdrawals,
    transfers: transfers ?? this.transfers,
    notifications: notifications ?? this.notifications,
    settings: settings ?? this.settings,
    presentation: presentation ?? this.presentation,
    hasLiveValuation: hasLiveValuation ?? this.hasLiveValuation,
    pendingOperationIds: pendingOperationIds ?? this.pendingOperationIds,
  );

  ExV2AccountViewState withMarketPrice({
    required String symbol,
    required double bid,
    required double ask,
  }) => copyWith(
    positions: [
      for (final position in positions)
        if (position.symbol != symbol)
          position
        else
          _withPrice(position, bid: bid, ask: ask),
    ],
    hasLiveValuation: true,
  );

  DemoPosition _withPrice(
    DemoPosition position, {
    required double bid,
    required double ask,
  }) {
    final isBuy = position.side == 'BUY';
    final price = isBuy ? bid : ask;
    final direction = isBuy ? 1.0 : -1.0;
    return position.copyWith(
      currentPrice: price,
      profit: (price - position.openPrice) * direction * position.volume * 100,
    );
  }
}
