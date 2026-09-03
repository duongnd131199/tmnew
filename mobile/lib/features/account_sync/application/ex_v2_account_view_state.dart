import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_wallet_history_mapper.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

final class ExV2AccountPresentation {
  const ExV2AccountPresentation({
    required this.brokerId,
    required this.companyName,
    required this.serverId,
    required this.tradingServer,
    this.accessPoint,
  });

  final String brokerId;
  final String companyName;
  final String serverId;
  final String tradingServer;
  final String? accessPoint;
}

final class ExV2AccountMetricSnapshot {
  const ExV2AccountMetricSnapshot({
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.profit,
    required this.historySummary,
  });

  factory ExV2AccountMetricSnapshot.fromState(ExV2AccountViewState state) {
    final optimisticRealizedProfit = state._optimisticRealizedProfit;
    return ExV2AccountMetricSnapshot(
      balance: state.balance,
      equity: state.equity,
      margin: state.margin,
      freeMargin: state.freeMargin,
      marginLevel: state.marginLevel,
      profit: state.profit,
      historySummary: ExV2HistorySummary(
        deposit: state.historySummary.deposit,
        withdrawal: state.historySummary.withdrawal,
        realizedProfit:
            state.historySummary.realizedProfit + optimisticRealizedProfit,
        swap: state.historySummary.swap,
        commission: state.historySummary.commission,
        netChange: state.historySummary.netChange + optimisticRealizedProfit,
      ),
    );
  }

  final double balance;
  final double equity;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final double profit;
  final ExV2HistorySummary historySummary;
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
    this.liveValuationPositionIds = const <String>{},
    this.pendingCloseValuationPositions = const <DemoPosition>[],
    this.lockedAccountMetrics,
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
    historyPositions: ExV2WalletHistoryMapper.entries(
      historyTransactions: const [],
      deposits: bootstrap.recentDeposits
          .map((deposit) => deposit.toJson())
          .toList(growable: false),
      withdrawals: const [],
    ),
    deposits: bootstrap.recentDeposits
        .map((deposit) => deposit.toJson())
        .toList(growable: false),
    historySummary: bootstrap.historySummary,
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
  final Set<String> liveValuationPositionIds;
  final List<DemoPosition> pendingCloseValuationPositions;
  final ExV2AccountMetricSnapshot? lockedAccountMetrics;
  final Set<String> pendingOperationIds;

  String get accountCode => bootstrap.account.accountCode;
  bool get hasLiveValuation =>
      positions.isNotEmpty &&
      positions.every(
        (position) => liveValuationPositionIds.contains(position.id),
      );
  bool get _hasOptimisticClose => pendingCloseValuationPositions.isNotEmpty;
  bool get _hasCompleteOptimisticValuation =>
      _hasOptimisticClose &&
      positions.every(
        (position) => liveValuationPositionIds.contains(position.id),
      ) &&
      pendingCloseValuationPositions.every(
        (position) => liveValuationPositionIds.contains(position.id),
      );

  double get _preCloseVolume {
    final pendingIds = pendingCloseValuationPositions
        .map((position) => position.id)
        .toSet();
    return <DemoPosition>[
      ...positions.where((position) => !pendingIds.contains(position.id)),
      ...pendingCloseValuationPositions,
    ].fold<double>(0, (total, position) => total + position.volume);
  }

  double _closedRatio(DemoPosition original) {
    final remaining = positions
        .where((position) => position.id == original.id)
        .map((position) => position.volume)
        .firstOrNull;
    if (original.volume <= 0) return 0;
    return ((original.volume - (remaining ?? 0)) / original.volume).clamp(
      0.0,
      1.0,
    );
  }

  double get _optimisticRealizedProfit {
    final totalVolume = _preCloseVolume;
    if (!_hasOptimisticClose || totalVolume <= 0) return 0;
    return pendingCloseValuationPositions.fold<double>(0, (total, position) {
      final positionProfit = liveValuationPositionIds.contains(position.id)
          ? position.profit
          : bootstrap.summary.profit * position.volume / totalVolume;
      return total + positionProfit * _closedRatio(position);
    });
  }

  double get _optimisticMarginReduction {
    final totalVolume = _preCloseVolume;
    if (!_hasOptimisticClose || totalVolume <= 0) return 0;
    final closedVolume = pendingCloseValuationPositions.fold<double>(
      0,
      (total, position) => total + position.volume * _closedRatio(position),
    );
    return bootstrap.summary.margin * closedVolume / totalVolume;
  }

  double get balance =>
      lockedAccountMetrics?.balance ??
      bootstrap.summary.balance + _optimisticRealizedProfit;
  double get profit =>
      lockedAccountMetrics?.profit ??
      (_hasOptimisticClose
          ? _hasCompleteOptimisticValuation
                ? positions.fold<double>(
                    0,
                    (total, position) => total + position.profit,
                  )
                : bootstrap.summary.profit - _optimisticRealizedProfit
          : hasLiveValuation
          ? positions.fold<double>(
              0,
              (total, position) => total + position.profit,
            )
          : bootstrap.summary.profit);
  double get equity =>
      lockedAccountMetrics?.equity ??
      (_hasOptimisticClose || hasLiveValuation
          ? balance + profit
          : bootstrap.summary.equity);
  double get margin =>
      lockedAccountMetrics?.margin ??
      (bootstrap.summary.margin - _optimisticMarginReduction).clamp(
        0.0,
        double.infinity,
      );
  double get freeMargin =>
      lockedAccountMetrics?.freeMargin ??
      (_hasOptimisticClose || hasLiveValuation
          ? equity - margin
          : bootstrap.summary.freeMargin);
  double get marginLevel =>
      lockedAccountMetrics?.marginLevel ??
      (_hasOptimisticClose || hasLiveValuation
          ? (margin == 0 ? 0 : equity / margin * 100)
          : bootstrap.summary.marginLevel);
  ExV2HistorySummary get displayHistorySummary =>
      lockedAccountMetrics?.historySummary ?? historySummary;
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
    Set<String>? liveValuationPositionIds,
    List<DemoPosition>? pendingCloseValuationPositions,
    ExV2AccountMetricSnapshot? lockedAccountMetrics,
    bool clearLockedAccountMetrics = false,
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
    liveValuationPositionIds:
        liveValuationPositionIds ?? this.liveValuationPositionIds,
    pendingCloseValuationPositions:
        pendingCloseValuationPositions ?? this.pendingCloseValuationPositions,
    lockedAccountMetrics: clearLockedAccountMetrics
        ? null
        : lockedAccountMetrics ?? this.lockedAccountMetrics,
    pendingOperationIds: pendingOperationIds ?? this.pendingOperationIds,
  );

  ExV2AccountViewState withMarketPrice({
    required String symbol,
    required double bid,
    required double ask,
  }) {
    final matchingPositionIds = positions
        .where((position) => position.symbol == symbol)
        .map((position) => position.id)
        .toSet();
    if (matchingPositionIds.isEmpty) return this;
    return copyWith(
      positions: [
        for (final position in positions)
          if (!matchingPositionIds.contains(position.id))
            position
          else
            _withPrice(position, bid: bid, ask: ask),
      ],
      liveValuationPositionIds: Set<String>.unmodifiable({
        ...liveValuationPositionIds,
        ...matchingPositionIds,
      }),
    );
  }

  ExV2AccountViewState preserveLiveValuationFrom(
    ExV2AccountViewState previous,
  ) {
    if (previous.liveValuationPositionIds.isEmpty ||
        previous.bootstrap.account.id != bootstrap.account.id ||
        previous.bootstrap.summary.accountId != bootstrap.summary.accountId) {
      return this;
    }
    final previousPositions = {
      for (final position in previous.positions) position.id: position,
    };
    final preservablePositionIds = positions
        .where((position) {
          final previousPosition = previousPositions[position.id];
          return previous.liveValuationPositionIds.contains(position.id) &&
              previousPosition != null &&
              previousPosition.symbol == position.symbol &&
              previousPosition.side == position.side;
        })
        .map((position) => position.id)
        .toSet();
    return copyWith(
      positions: [
        for (final position in positions)
          if (preservablePositionIds.contains(position.id))
            _withCurrentPrice(
              position,
              previousPositions[position.id]!.currentPrice,
            )
          else
            position,
      ],
      liveValuationPositionIds: Set<String>.unmodifiable(
        preservablePositionIds,
      ),
    );
  }

  DemoPosition _withPrice(
    DemoPosition position, {
    required double bid,
    required double ask,
  }) {
    final isBuy = position.side == 'BUY';
    final price = isBuy ? bid : ask;
    return _withCurrentPrice(position, price);
  }

  DemoPosition _withCurrentPrice(DemoPosition position, double price) {
    final isBuy = position.side == 'BUY';
    final direction = isBuy ? 1.0 : -1.0;
    return position.copyWith(
      currentPrice: price,
      profit: (price - position.openPrice) * direction * position.volume * 100,
    );
  }
}
