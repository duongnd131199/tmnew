import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_history_reconciler.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_realtime_service.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_wallet_history_mapper.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

final class ExV2Config {
  const ExV2Config({required this.restBaseUrl, required this.hubUrl});

  static const production = ExV2Config(
    restBaseUrl: 'https://trochoi.top/ex/v2/api',
    hubUrl: 'https://trochoi.top/ex/v2/hubs/trading',
  );

  final String restBaseUrl;
  final String hubUrl;
}

final class ExV2LoginConfig {
  const ExV2LoginConfig({required this.brokerId, required this.serverId});

  static const production = ExV2LoginConfig(
    brokerId: 'yodo-demo',
    serverId: 'yodo-demo-01',
  );

  final String brokerId;
  final String serverId;
}

final exV2EnabledProvider = Provider<bool>((ref) => false);
final exV2RealtimeEnabledProvider = Provider<bool>((ref) => false);

final exV2ConfigProvider = Provider<ExV2Config>((ref) => ExV2Config.production);

final exV2LoginConfigProvider = Provider<ExV2LoginConfig>(
  (ref) => ExV2LoginConfig.production,
);

final deviceTokenStoreProvider = Provider<DeviceTokenStore>(
  (ref) => const SecureDeviceTokenStore(FlutterSecureStorage()),
);

final exV2DioProvider = Provider<Dio>((ref) {
  final config = ref.watch(exV2ConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.restBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );
});

final exV2ApiClientProvider = Provider<ExV2ApiClient>((ref) {
  final store = ref.watch(deviceTokenStoreProvider);
  return ExV2ApiClient(
    dio: ref.watch(exV2DioProvider),
    tokenReader: store.read,
  );
});

final exV2RepositoryProvider = Provider<ExV2Repository>(
  (ref) => ExV2Repository(ref.watch(exV2ApiClientProvider)),
);

typedef ExV2OrderFailureReporter = void Function(Object error);

final exV2OrderFailureReporterProvider = Provider<ExV2OrderFailureReporter>(
  (ref) =>
      (error) => developer.log(
        safeOrderFailureDiagnostic(error),
        name: 'trading.order',
      ),
);

final exV2RealtimeServiceProvider = Provider<ExV2RealtimeService>((ref) {
  final config = ref.watch(exV2ConfigProvider);
  final tokenStore = ref.watch(deviceTokenStoreProvider);
  return ExV2RealtimeService(
    hubUrl: config.hubUrl,
    tokenReader: tokenStore.read,
  );
});

final class ExV2WalletView {
  const ExV2WalletView({required this.wallet, required this.transactions});

  final ExV2Wallet wallet;
  final List<JsonMap> transactions;
}

final exV2WalletViewProvider = Provider<AsyncValue<ExV2WalletView>>((ref) {
  return ref.watch(exV2AccountProvider).whenData((state) {
    if (state == null) throw const ExV2TokenMissing();
    return ExV2WalletView(
      wallet: state.wallet,
      transactions: [
        ...state.historyTransactions,
        for (final item in state.deposits)
          {...item, 'type': item['type'] ?? 'deposit'},
        for (final item in state.withdrawals)
          {...item, 'type': item['type'] ?? 'withdrawal'},
        for (final item in state.transfers)
          {...item, 'type': item['type'] ?? 'transfer'},
      ],
    );
  });
});

final exV2NotificationsProvider = Provider<AsyncValue<List<JsonMap>>>((ref) {
  return ref
      .watch(exV2AccountProvider)
      .whenData((state) => state?.notifications ?? const []);
});

final exV2AccountProvider =
    AsyncNotifierProvider<ExV2AccountController, ExV2AccountViewState?>(
      ExV2AccountController.new,
      retry: (_, _) => null,
    );

final class ExV2AccountGeneration {
  const ExV2AccountGeneration({required this.accountId, required this.value});

  final String? accountId;
  final int value;

  @override
  bool operator ==(Object other) =>
      other is ExV2AccountGeneration &&
      other.accountId == accountId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(accountId, value);
}

enum ExV2BootstrapPublication { committed, idempotentReplay, rejectedStale }

/// A stable UI generation that advances only after a different account
/// bootstrap has been committed to [exV2AccountProvider]. Loading, refresh
/// errors, and same-account bootstrap refreshes leave this token unchanged.
final exV2AccountGenerationProvider =
    NotifierProvider<ExV2AccountGenerationController, ExV2AccountGeneration>(
      ExV2AccountGenerationController.new,
    );

final class ExV2AccountGenerationController
    extends Notifier<ExV2AccountGeneration> {
  String? _committedAccountId;
  int _value = 0;

  @override
  ExV2AccountGeneration build() {
    _committedAccountId = ref
        .read(exV2AccountProvider)
        .value
        ?.bootstrap
        .account
        .id;
    ref.listen(exV2AccountProvider, (_, next) {
      final nextAccountId = next.value?.bootstrap.account.id;
      if (nextAccountId == null || nextAccountId == _committedAccountId) return;
      final previousAccountId = _committedAccountId;
      _committedAccountId = nextAccountId;
      if (previousAccountId == null) {
        state = ExV2AccountGeneration(accountId: nextAccountId, value: _value);
        return;
      }
      _value += 1;
      state = ExV2AccountGeneration(accountId: nextAccountId, value: _value);
    });
    return ExV2AccountGeneration(accountId: _committedAccountId, value: _value);
  }
}

typedef _AccountMutationScope = ({String accountId, int generation});
typedef _TradingHistorySnapshot = ({
  List<DemoDeal> deals,
  List<DemoHistoryPosition> positions,
  ExV2HistorySummary summary,
  bool hasAnyVersionMetadata,
  int? snapshotVersion,
});
typedef _WalletRequestOverlay = ({
  String accountId,
  bool isDeposit,
  JsonMap row,
  double? minimumDepositTotal,
});

enum _CloseSyncApplyResult { applied, duplicate, rejected }

extension on _CloseSyncApplyResult {
  bool get accepted =>
      this == _CloseSyncApplyResult.applied ||
      this == _CloseSyncApplyResult.duplicate;
}

final class ExV2AccountController extends AsyncNotifier<ExV2AccountViewState?> {
  static const _initialBootstrapRetryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 750),
  ];

  StreamSubscription<ExV2RealtimeEvent>? _realtimeSubscription;
  ExV2RealtimeService? _realtimeService;
  Timer? _refreshDebounce;
  bool _realtimeStarted = false;
  int _loadGeneration = 0;
  int _accountGeneration = 0;
  int _publishedActivationAuthority = 0;
  bool _deferredRefreshRequested = false;
  Future<void>? _refreshInFlight;
  bool _refreshAfterInFlightQueued = false;
  bool _queuedRefreshAllowsAccountSwitch = false;
  Future<void>? _orderReconciliationInFlight;
  bool _orderReconciliationQueued = false;
  Future<void> _closeCommandTail = Future<void>.value();
  final Set<String> _optimisticHiddenPositionIds = <String>{};
  final Set<String> _groupedClosePositionIds = <String>{};
  final Set<String> _optimisticHiddenOrderIds = <String>{};
  final Map<String, ExV2CommandMetadata> _pendingCloseCommandMetadata =
      <String, ExV2CommandMetadata>{};
  final Map<String, bool> _appliedCloseOperationKeys = <String, bool>{};
  final Map<String, bool> _processedCloseEventKeys = <String, bool>{};
  final Map<String, bool> _processedDepositEventKeys = <String, bool>{};
  final Map<String, _WalletRequestOverlay> _walletRequestOverlays =
      <String, _WalletRequestOverlay>{};
  String? _automaticStopOutAccountId;

  static const _maximumCloseDedupEntries = 256;

  _AccountMutationScope _captureMutationScope(ExV2AccountViewState current) =>
      (accountId: current.bootstrap.account.id, generation: _accountGeneration);

  bool _isMutationScopeCurrent(_AccountMutationScope scope) {
    if (!ref.mounted) return false;
    final current = state.value;
    return scope.generation == _accountGeneration &&
        current != null &&
        current.bootstrap.account.id == scope.accountId &&
        current.bootstrap.summary.accountId == scope.accountId;
  }

  Future<T> _runSerializedCloseCommand<T>(Future<T> Function() command) {
    final result = _closeCommandTail.then((_) => command());
    _closeCommandTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<ExV2AccountViewState?> build() async {
    if (!ref.watch(exV2EnabledProvider)) return null;
    ref.onDispose(() {
      _refreshDebounce?.cancel();
      unawaited(_realtimeSubscription?.cancel());
      unawaited(_realtimeService?.dispose());
    });
    final token = await ref.watch(deviceTokenStoreProvider).read();
    if (!ref.mounted) return null;
    if (token == null || token.trim().isEmpty) return null;
    final generation = ++_loadGeneration;
    final result = await _loadInitialCore();
    unawaited(_hydrateAndPublish(result, generation));
    unawaited(_startRealtime());
    return result;
  }

  Future<ExV2AccountViewState> _loadInitialCore() async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _loadCore();
      } on ExV2RequestFailure catch (error) {
        final retryable =
            error.statusCode == null ||
            (error.statusCode != null && error.statusCode! >= 500);
        if (!retryable || attempt >= _initialBootstrapRetryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_initialBootstrapRetryDelays[attempt]);
        if (!ref.mounted) rethrow;
      }
    }
  }

  Future<void> _startRealtime() async {
    if (!ref.read(exV2RealtimeEnabledProvider)) return;
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    final ExV2RealtimeService realtime = ref.read(exV2RealtimeServiceProvider);
    _realtimeService = realtime;
    _realtimeSubscription = realtime.events.listen(_onRealtimeEvent);
    try {
      await realtime.start();
    } catch (_) {
      _realtimeStarted = false;
    }
  }

  Future<void> restartRealtimeForCurrentToken() async {
    final subscription = _realtimeSubscription;
    final service = _realtimeService;
    _realtimeSubscription = null;
    _realtimeService = null;
    _realtimeStarted = false;
    try {
      await subscription?.cancel();
    } catch (_) {
      // A confirmed account switch must survive realtime cleanup failures.
    }
    if (!ref.mounted) return;
    try {
      await service?.dispose();
    } catch (_) {
      // The next connection still gets a fresh service for the current token.
    }
    if (!ref.mounted) return;
    ref.invalidate(exV2RealtimeServiceProvider);
    try {
      await _startRealtime();
    } catch (_) {
      // REST state is authoritative; realtime can reconnect on the next event.
    }
  }

  void _onRealtimeEvent(ExV2RealtimeEvent event) {
    final current = state.value;
    final changesActiveAccount = event.name == 'ActiveAccountChanged';
    if (!changesActiveAccount &&
        current != null &&
        event.accountId != null &&
        event.accountId != current.bootstrap.account.id) {
      return;
    }
    if (event.name == 'DepositRequestUpdated') {
      if (_applyDepositRealtimeEvent(event)) return;
      if (current != null) _scheduleRealtimeRefresh();
      return;
    }
    if (event.name != 'CloseExecutionCommitted' &&
        !changesActiveAccount &&
        current != null &&
        event.version != null &&
        event.version! <= current.bootstrap.version) {
      return;
    }
    if (event.name == 'CloseExecutionCommitted') {
      if (current == null || event.accountId == null || event.version == null) {
        if (current != null) _scheduleRealtimeRefresh();
        return;
      }
      final payload = event.data['data'];
      JsonMap? payloadMap;
      if (payload is Map<String, dynamic>) {
        payloadMap = payload;
      } else if (payload is Map) {
        payloadMap = payload.cast<String, dynamic>();
      }
      if (payloadMap != null) {
        try {
          final sync = ExV2CloseSync.fromJson(payloadMap);
          if (sync.accountId == event.accountId &&
              sync.version == event.version) {
            final affectedIds = sync.affectedPositions
                .map((position) => position.id)
                .toSet();
            final completedOperationIds = _completedOperationsForCloseSync(
              current,
              sync,
            );
            final result = _applyCloseSync(
              sync: sync,
              scope: _captureMutationScope(current),
              completedOperationIds: completedOperationIds,
              affectedRequestIds: affectedIds,
              eventId: event.eventId,
            );
            if (result.accepted || sync.version < current.bootstrap.version) {
              return;
            }
          }
        } on FormatException {
          // A malformed additive payload falls back to canonical REST reads.
        }
      }
    }
    _scheduleRealtimeRefresh(allowAccountSwitch: changesActiveAccount);
  }

  bool _applyDepositRealtimeEvent(ExV2RealtimeEvent event) {
    final current = state.value;
    final accountId = event.accountId;
    final version = event.version;
    final eventId = event.eventId;
    if (current == null ||
        accountId == null ||
        version == null ||
        eventId == null ||
        accountId != current.bootstrap.account.id) {
      return false;
    }
    final eventKey = '${_normalizedId(accountId)}:${_normalizedId(eventId)}';
    if (_processedDepositEventKeys.containsKey(eventKey)) return true;
    if (version < current.bootstrap.version) {
      _rememberBounded(_processedDepositEventKeys, eventKey);
      return true;
    }
    final rawPayload = event.data['data'];
    final JsonMap payload;
    if (rawPayload is Map<String, dynamic>) {
      payload = rawPayload;
    } else if (rawPayload is Map) {
      payload = rawPayload.cast<String, dynamic>();
    } else {
      return false;
    }
    try {
      final ExV2Deposit deposit;
      final ExV2DepositDecision? decision;
      if (payload.containsKey('deposit')) {
        decision = ExV2DepositDecision.fromJson(payload);
        if (decision.version != version ||
            decision.accountSummary.accountId != accountId ||
            (decision.transaction != null &&
                decision.transaction!.accountId != accountId)) {
          return false;
        }
        deposit = decision.deposit;
      } else {
        decision = null;
        deposit = ExV2Deposit.fromJson(payload);
      }
      if (deposit.accountId != accountId ||
          deposit.snapshotVersion != version) {
        return false;
      }
      final row = <String, dynamic>{...deposit.toJson(), 'type': 'deposit'};
      final deposits = _upsertJsonRow(row, current.deposits);
      final historyTransactions = decision?.transaction == null
          ? current.historyTransactions
          : _upsertJsonRow(
              decision!.transaction!.toJson(),
              current.historyTransactions,
            );
      final nextVersion = version > current.bootstrap.version
          ? version
          : current.bootstrap.version;
      final nextBase = current.copyWith(
        bootstrap: current.bootstrap.copyWith(
          version: nextVersion,
          summary: decision?.accountSummary,
          recentDeposits: deposits
              .map(ExV2Deposit.fromJson)
              .toList(growable: false),
          historySummary: decision?.historySummary,
        ),
        deposits: deposits,
        historyTransactions: historyTransactions,
        historySummary: decision?.historySummary,
        clearLockedAccountMetrics: decision != null,
      );
      final overlayKey = _walletOverlayKey(
        accountId: accountId,
        isDeposit: true,
        row: row,
        fallback: deposit.id,
      );
      _walletRequestOverlays[overlayKey] = (
        accountId: accountId,
        isDeposit: true,
        row: row,
        minimumDepositTotal: decision?.historySummary.deposit,
      );
      state = AsyncData(
        nextBase.copyWith(
          historyPositions: _historyWithWalletRequests(
            nextBase,
            deposits: deposits,
            withdrawals: nextBase.withdrawals,
          ),
        ),
      );
      _rememberBounded(_processedDepositEventKeys, eventKey);
      if (version > current.bootstrap.version + 1) {
        _scheduleRealtimeRefresh();
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  List<JsonMap> _upsertJsonRow(JsonMap incoming, Iterable<JsonMap> existing) {
    final incomingId = _normalizedId(incoming['id']?.toString() ?? '');
    if (incomingId.isEmpty) {
      throw const FormatException('Canonical row id is required');
    }
    return <JsonMap>[
      incoming,
      ...existing.where(
        (row) => _normalizedId(row['id']?.toString() ?? '') != incomingId,
      ),
    ];
  }

  Set<String> _completedOperationsForCloseSync(
    ExV2AccountViewState current,
    ExV2CloseSync sync,
  ) {
    final normalizedPositionIds = sync.affectedPositions
        .map((position) => position.id)
        .map(_normalizedId)
        .toSet();
    return current.pendingOperationIds.where((operationId) {
      final metadata = _pendingCloseCommandMetadata[operationId];
      if (metadata == null ||
          _normalizedId(metadata.idempotencyKey) !=
              _normalizedId(sync.operation.idempotencyKey) ||
          _normalizedId(metadata.correlationId) !=
              _normalizedId(sync.operation.correlationId)) {
        return false;
      }
      if (operationId.startsWith('position:')) {
        return normalizedPositionIds.contains(
          _normalizedId(operationId.substring('position:'.length)),
        );
      }
      if (!operationId.startsWith('close-by:')) return false;
      final positionIds = operationId
          .substring('close-by:'.length)
          .split(':')
          .map(_normalizedId)
          .toList(growable: false);
      return positionIds.length == 2 &&
          positionIds.every(normalizedPositionIds.contains);
    }).toSet();
  }

  void _scheduleRealtimeRefresh({bool allowAccountSwitch = false}) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(
        refresh(
          allowDuringGroupedClose: allowAccountSwitch,
          queueAfterInFlight: true,
        ),
      );
    });
  }

  Future<ExV2AccountViewState> _loadCore({
    bool applyOptimisticHides = true,
  }) async {
    final repository = ref.read(exV2RepositoryProvider);
    final bootstrap = await repository.bootstrap();
    final core = ExV2AccountViewState.fromBootstrap(bootstrap);
    if (!applyOptimisticHides) return core;
    final serverPositionIds = core.positions
        .map((position) => position.id)
        .toSet();
    final serverPendingOrderIds = core.pendingOrders
        .map((order) => order.id)
        .toSet();
    _optimisticHiddenPositionIds.removeWhere(
      (id) => !serverPositionIds.contains(id),
    );
    _optimisticHiddenOrderIds.removeWhere(
      (id) => !serverPendingOrderIds.contains(id),
    );
    if (_optimisticHiddenPositionIds.isEmpty &&
        _optimisticHiddenOrderIds.isEmpty) {
      return core;
    }
    return core.copyWith(
      positions: core.positions
          .where(
            (position) => !_optimisticHiddenPositionIds.contains(position.id),
          )
          .toList(growable: false),
      pendingOrders: core.pendingOrders
          .where((order) => !_optimisticHiddenOrderIds.contains(order.id))
          .toList(growable: false),
    );
  }

  Future<ExV2AccountViewState> _hydrate(ExV2AccountViewState base) async {
    final repository = ref.read(exV2RepositoryProvider);
    final results = await Future.wait<Object?>([
      _readOr(repository.historyOrders(), const <JsonMap>[]),
      _readOrNull(repository.historyDeals()),
      _readOrNull(repository.historyPositions()),
      _readOr(repository.historyTransactions(), const <JsonMap>[]),
      _readOr(repository.walletTransactions(), const <JsonMap>[]),
      _readOr(repository.deposits(), base.deposits),
      _readOr(repository.withdrawals(), const <JsonMap>[]),
      _readOr(repository.transfers(), const <JsonMap>[]),
      _readOr(repository.notifications(), const <JsonMap>[]),
      _readOr(repository.settings(), const <String, dynamic>{}),
      _readOr(repository.historySummary(), base.historySummary),
    ]);
    final orderRows = results[0] as List<JsonMap>;
    final dealRows = results[1] as List<JsonMap>?;
    final historyRows = results[2] as List<JsonMap>?;
    final transactionRows = <JsonMap>[
      ...results[3] as List<JsonMap>,
      ...results[4] as List<JsonMap>,
    ];
    final hasCoherentTradingHistory = dealRows != null && historyRows != null;
    final tradingHistory = hasCoherentTradingHistory
        ? _mapRows(
            ExV2HistoryReconciler.enrichClosedPositions(historyRows, dealRows),
            ExV2DemoMapper.historyPosition,
          )
        : base.historyPositions
              .where((position) => !position.id.startsWith('wallet-'))
              .toList(growable: false);
    final serverHistorySummary = results[10] as ExV2HistorySummary;
    final deposits = _mergeWalletRequestOverlays(
      accountId: base.bootstrap.account.id,
      isDeposit: true,
      serverRows: results[5] as List<JsonMap>,
      serverDepositTotal: serverHistorySummary.deposit,
    );
    final withdrawals = _mergeWalletRequestOverlays(
      accountId: base.bootstrap.account.id,
      isDeposit: false,
      serverRows: results[6] as List<JsonMap>,
      serverDepositTotal: serverHistorySummary.deposit,
    );
    final walletHistory = ExV2WalletHistoryMapper.entries(
      historyTransactions: transactionRows,
      deposits: deposits,
      withdrawals: withdrawals,
    );
    final combinedHistory = ExV2WalletHistoryMapper.normalizeReferences(
      [...tradingHistory, ...walletHistory]
        ..sort((left, right) => left.time.compareTo(right.time)),
    );
    return base.copyWith(
      orders: _mapRows(orderRows, ExV2DemoMapper.historyOrder),
      deals: hasCoherentTradingHistory
          ? _mapRows(dealRows, ExV2DemoMapper.historyDeal)
          : base.deals,
      historyPositions: combinedHistory,
      historyTransactions: transactionRows,
      deposits: deposits,
      withdrawals: withdrawals,
      transfers: results[7] as List<JsonMap>,
      notifications: results[8] as List<JsonMap>,
      settings: results[9] as JsonMap,
      historySummary: serverHistorySummary,
    );
  }

  Future<void> _hydrateAndPublish(
    ExV2AccountViewState base,
    int generation,
  ) async {
    final hydrated = await _hydrate(base);
    if (!ref.mounted || generation != _loadGeneration) return;
    final published = _applyOptimisticOverlay(hydrated, state.value);
    state = AsyncData(published);
    _maybeTriggerAutomaticStopOut(published);
  }

  ExV2AccountViewState _applyOptimisticOverlay(
    ExV2AccountViewState incoming,
    ExV2AccountViewState? current, {
    bool acceptGroupedCloseHistory = false,
  }) {
    if (current != null &&
        incoming.bootstrap.account.id == current.bootstrap.account.id &&
        incoming.presentation == null &&
        current.presentation != null) {
      incoming = incoming.copyWith(presentation: current.presentation);
    }
    if (current == null) return _applyAutomaticStopOutDisplay(incoming);
    incoming = incoming.preserveLiveValuationFrom(current);
    if (current.pendingOperationIds.isEmpty &&
        _optimisticHiddenPositionIds.isEmpty &&
        _groupedClosePositionIds.isEmpty &&
        _optimisticHiddenOrderIds.isEmpty) {
      return _applyAutomaticStopOutDisplay(incoming);
    }
    final preserveGroupedCloseHistory =
        _groupedClosePositionIds.isNotEmpty && !acceptGroupedCloseHistory;
    final closingPositionIds = current.pendingOperationIds
        .where((id) => id.startsWith('position:'))
        .map((id) => id.substring('position:'.length))
        .toSet();
    final protectionIds = current.pendingOperationIds
        .where((id) => id.startsWith('protection:'))
        .map((id) => id.substring('protection:'.length))
        .toSet();
    final modifiedOrderIds = current.pendingOperationIds
        .where((id) => id.startsWith('modify-order:'))
        .map((id) => id.substring('modify-order:'.length))
        .toSet();
    final currentPositions = {
      for (final item in current.positions) item.id: item,
    };
    final currentPendingOrders = {
      for (final item in current.pendingOrders) item.id: item,
    };
    final sendingOrders = current.orders
        .where((order) => order.status == 'sending')
        .toList(growable: false);
    return _applyAutomaticStopOutDisplay(
      incoming.copyWith(
        positions: [
          for (final position in incoming.positions)
            if (_optimisticHiddenPositionIds.contains(position.id))
              ...const <DemoPosition>[]
            else if (closingPositionIds.contains(position.id) ||
                protectionIds.contains(position.id))
              currentPositions[position.id] ?? position
            else
              position,
        ],
        pendingOrders: [
          for (final order in incoming.pendingOrders)
            if (modifiedOrderIds.contains(order.id))
              currentPendingOrders[order.id] ?? order
            else
              order,
        ],
        orders: [
          ...sendingOrders,
          ...incoming.orders.where(
            (order) => !sendingOrders.any((item) => item.id == order.id),
          ),
        ],
        deals: preserveGroupedCloseHistory ? current.deals : incoming.deals,
        historyPositions: preserveGroupedCloseHistory
            ? current.historyPositions
            : incoming.historyPositions,
        historySummary: preserveGroupedCloseHistory
            ? current.historySummary
            : incoming.historySummary,
        deposits: current.deposits,
        withdrawals: current.withdrawals,
        transfers: current.transfers,
        notifications: current.notifications,
        settings: current.settings,
        pendingOperationIds: current.pendingOperationIds,
      ),
    );
  }

  List<JsonMap> _mergeWalletRequestOverlays({
    required String accountId,
    required bool isDeposit,
    required List<JsonMap> serverRows,
    required double serverDepositTotal,
  }) {
    final merged = [...serverRows];
    final reconciledKeys = <String>[];
    for (final entry in _walletRequestOverlays.entries) {
      final overlay = entry.value;
      if (overlay.accountId != accountId || overlay.isDeposit != isDeposit) {
        continue;
      }
      final observed = serverRows.any(
        (row) => _sameWalletRequest(row, overlay.row),
      );
      final summaryCaughtUp =
          overlay.minimumDepositTotal == null ||
          serverDepositTotal >= overlay.minimumDepositTotal!;
      if (observed && summaryCaughtUp) {
        reconciledKeys.add(entry.key);
        continue;
      }
      if (!observed) merged.add(overlay.row);
    }
    for (final key in reconciledKeys) {
      _walletRequestOverlays.remove(key);
    }
    return merged;
  }

  bool _sameWalletRequest(JsonMap left, JsonMap right) {
    final leftId = left['id']?.toString().trim();
    final rightId = right['id']?.toString().trim();
    if (leftId != null &&
        leftId.isNotEmpty &&
        rightId != null &&
        rightId.isNotEmpty) {
      return _normalizedId(leftId) == _normalizedId(rightId);
    }
    final leftReference = left['reference']?.toString().trim();
    final rightReference = right['reference']?.toString().trim();
    return leftReference != null &&
        leftReference.isNotEmpty &&
        rightReference != null &&
        rightReference.isNotEmpty &&
        leftReference.toLowerCase() == rightReference.toLowerCase();
  }

  String _walletOverlayKey({
    required String accountId,
    required bool isDeposit,
    required JsonMap row,
    required String fallback,
  }) {
    final id = row['id']?.toString().trim();
    final reference = row['reference']?.toString().trim();
    final identity = id != null && id.isNotEmpty
        ? id
        : reference != null && reference.isNotEmpty
        ? reference
        : fallback;
    return '$accountId:${isDeposit ? 'deposit' : 'withdrawal'}:$identity';
  }

  List<DemoHistoryPosition> _historyWithWalletRequests(
    ExV2AccountViewState current, {
    required List<JsonMap> deposits,
    required List<JsonMap> withdrawals,
  }) {
    final walletHistory = ExV2WalletHistoryMapper.entries(
      historyTransactions: current.historyTransactions,
      deposits: deposits,
      withdrawals: withdrawals,
    );
    return ExV2WalletHistoryMapper.normalizeReferences(
      [
        ...current.historyPositions.where(
          (position) => !position.id.startsWith('wallet-'),
        ),
        ...walletHistory,
      ]..sort((left, right) => left.time.compareTo(right.time)),
    );
  }

  Future<T> _readOr<T>(Future<T> operation, T fallback) async {
    try {
      return await operation;
    } catch (_) {
      return fallback;
    }
  }

  Future<T?> _readOrNull<T>(Future<T> operation) async {
    try {
      return await operation;
    } catch (_) {
      return null;
    }
  }

  Future<ExV2Order> createOrder({
    required String symbol,
    required String side,
    required double volume,
    String type = 'market',
    double? requestedPrice,
    double? stopLoss,
    double? takeProfit,
    ExV2CommandMetadata? commandMetadata,
  }) async {
    final metadata = commandMetadata ?? ExV2CommandMetadata.create();
    final serverType = type.trim().toLowerCase() == 'market'
        ? 'market'
        : 'pending';
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final operationId = 'order:${metadata.idempotencyKey}';
    final placeholder = DemoOrder(
      id: metadata.idempotencyKey,
      symbol: symbol,
      side: side.toUpperCase(),
      type: type,
      volume: volume,
      requestedPrice: requestedPrice ?? 0,
      status: 'sending',
      time: ExV2DemoMapper.dateLabel(DateTime.now().toUtc()),
    );
    state = AsyncData(
      before.copyWith(
        orders: [placeholder, ...before.orders],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    late final ExV2Order order;
    try {
      order = await ref
          .read(exV2RepositoryProvider)
          .createOrder(
            clientOrderId: metadata.idempotencyKey,
            symbol: symbol,
            type: serverType,
            side: side.toLowerCase(),
            volume: volume,
            requestedPrice: requestedPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            metadata: metadata,
          );
    } catch (error) {
      try {
        ref.read(exV2OrderFailureReporterProvider)(error);
      } catch (_) {
        // Diagnostics must never replace the original trading failure.
      }
      if (!_isMutationScopeCurrent(scope)) rethrow;
      final current = state.value ?? before;
      state = AsyncData(
        current.copyWith(
          orders: current.orders
              .where((item) => item.id != metadata.idempotencyKey)
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
    if (!_isMutationScopeCurrent(scope)) return order;
    final current = state.value ?? before;
    final confirmedOrder = ExV2DemoMapper.order(order);
    state = AsyncData(
      current.copyWith(
        orders: [
          confirmedOrder,
          ...current.orders.where(
            (item) => item.id != metadata.idempotencyKey && item.id != order.id,
          ),
        ],
        pendingOperationIds: {
          ...current.pendingOperationIds.where((id) => id != operationId),
        },
      ),
    );
    _scheduleOrderReconciliation();
    return order;
  }

  ExV2AccountViewState _mergeCoreWithHydrated(
    ExV2AccountViewState core,
    ExV2AccountViewState hydrated, {
    List<DemoOrder>? orders,
    List<DemoDeal>? deals,
    List<DemoHistoryPosition>? historyPositions,
    ExV2HistorySummary? historySummary,
    Set<String>? pendingOperationIds,
  }) => _applyAutomaticStopOutDisplay(
    core.copyWith(
      orders: orders ?? hydrated.orders,
      deals: deals ?? hydrated.deals,
      historyPositions: historyPositions ?? hydrated.historyPositions,
      historySummary: _preserveHydratedDeposit(
        current: hydrated.historySummary,
        incoming: historySummary ?? hydrated.historySummary,
      ),
      historyTransactions: hydrated.historyTransactions,
      deposits: hydrated.deposits,
      withdrawals: hydrated.withdrawals,
      transfers: hydrated.transfers,
      notifications: hydrated.notifications,
      settings: hydrated.settings,
      presentation: hydrated.presentation,
      pendingCloseValuationPositions: hydrated.pendingCloseValuationPositions,
      lockedAccountMetrics: hydrated.lockedAccountMetrics,
      pendingOperationIds: pendingOperationIds ?? hydrated.pendingOperationIds,
    ),
  );

  ExV2HistorySummary _preserveHydratedDeposit({
    required ExV2HistorySummary current,
    required ExV2HistorySummary incoming,
  }) => incoming.deposit == 0 && current.deposit != 0
      ? ExV2HistorySummary(
          deposit: current.deposit,
          withdrawal: incoming.withdrawal,
          realizedProfit: incoming.realizedProfit,
          swap: incoming.swap,
          commission: incoming.commission,
          netChange: incoming.netChange,
        )
      : incoming;

  ExV2AccountViewState _applyAutomaticStopOutDisplay(
    ExV2AccountViewState value,
  ) {
    if (_automaticStopOutAccountId != value.bootstrap.account.id) return value;
    final summary = value.bootstrap.summary;
    return value.copyWith(
      bootstrap: value.bootstrap.copyWith(
        summary: ExV2AccountSummary(
          accountId: summary.accountId,
          currency: summary.currency,
          balance: 0,
          equity: 0,
          profit: 0,
          margin: 0,
          freeMargin: 0,
          marginLevel: 0,
          updatedAt: summary.updatedAt,
        ),
      ),
      liveValuationPositionIds: const <String>{},
      clearLockedAccountMetrics: true,
    );
  }

  void _maybeTriggerAutomaticStopOut(ExV2AccountViewState current) {
    final accountId = current.bootstrap.account.id;
    if (current.positions.isEmpty ||
        current.equity > 0 ||
        _automaticStopOutAccountId == accountId) {
      return;
    }
    _automaticStopOutAccountId = accountId;
    final closing = closePositions(
      current.positions.map((position) => position.id).toList(growable: false),
    );
    final optimistic = state.value;
    if (optimistic != null && optimistic.bootstrap.account.id == accountId) {
      state = AsyncData(_applyAutomaticStopOutDisplay(optimistic));
    }
    unawaited(_settleAutomaticStopOut(accountId, closing));
  }

  Future<void> _settleAutomaticStopOut(
    String accountId,
    Future<void> closing,
  ) async {
    try {
      await closing;
    } catch (_) {
      // The canonical refresh below restores the server state after failure.
    }
    if (!ref.mounted || _automaticStopOutAccountId != accountId) return;
    final current = state.value;
    if (current == null || current.bootstrap.account.id != accountId) {
      _automaticStopOutAccountId = null;
      return;
    }
    if (current.positions.isEmpty) {
      state = AsyncData(_applyAutomaticStopOutDisplay(current));
      return;
    }
    _automaticStopOutAccountId = null;
    await refresh(queueAfterInFlight: true);
  }

  _CloseSyncApplyResult _applyCloseSync({
    required ExV2CloseSync sync,
    required _AccountMutationScope scope,
    required Set<String> completedOperationIds,
    required Set<String> affectedRequestIds,
    String? eventId,
  }) {
    if (!_isMutationScopeCurrent(scope)) {
      return _CloseSyncApplyResult.rejected;
    }
    final current = state.value;
    if (current == null ||
        sync.accountId != scope.accountId ||
        sync.accountSummary.accountId != scope.accountId ||
        !_hasCoherentCloseSyncShape(sync)) {
      return _CloseSyncApplyResult.rejected;
    }
    final operationKey = _closeOperationKey(sync);
    final eventKey = eventId == null
        ? null
        : '${_normalizedId(sync.accountId)}:${_normalizedId(eventId)}';
    if (eventKey != null && _processedCloseEventKeys.containsKey(eventKey)) {
      return _CloseSyncApplyResult.duplicate;
    }
    if (_appliedCloseOperationKeys.containsKey(operationKey)) {
      if (eventKey != null) {
        _rememberBounded(_processedCloseEventKeys, eventKey);
      }
      return _CloseSyncApplyResult.duplicate;
    }
    if (sync.version < current.bootstrap.version) {
      if (eventKey != null) {
        _rememberBounded(_processedCloseEventKeys, eventKey);
      }
      return _CloseSyncApplyResult.rejected;
    }
    final hasVersionGap = sync.version > current.bootstrap.version + 1;
    try {
      final affectedById = {
        for (final position in sync.affectedPositions)
          _normalizedId(position.id): position,
      };
      final updatedBootstrapPositions = <ExV2Position>[
        for (final position in current.bootstrap.positions)
          if (affectedById.remove(_normalizedId(position.id))
              case final affected?)
            if (_isOpenPosition(affected))
              affected
            else
              ...const <ExV2Position>[]
          else
            position,
        for (final affected in affectedById.values)
          if (_isOpenPosition(affected)) affected,
      ];
      final recentDeals = _upsertById(
        sync.deals,
        current.bootstrap.recentDeals,
        (deal) => deal.id,
      );
      final bootstrap = current.bootstrap.copyWith(
        serverTime: sync.committedAt,
        version: sync.version,
        summary: sync.accountSummary,
        positions: updatedBootstrapPositions,
        recentDeals: recentDeals,
      );
      final core = ExV2AccountViewState.fromBootstrap(bootstrap);
      final syncOrders = sync.orders
          .map(ExV2DemoMapper.historyOrder)
          .toList(growable: false);
      final syncDeals = sync.deals
          .map(ExV2DemoMapper.deal)
          .toList(growable: false);
      final syncHistoryPositions = sync.closedPositions
          .map(ExV2DemoMapper.historyPosition)
          .toList(growable: false);
      final openPositionIds = updatedBootstrapPositions
          .map((position) => position.id)
          .toSet();
      final settledCurrent = current.copyWith(
        liveValuationPositionIds: current.liveValuationPositionIds
            .where(openPositionIds.contains)
            .toSet(),
        pendingOperationIds: {
          ...current.pendingOperationIds.where(
            (operationId) => !completedOperationIds.contains(operationId),
          ),
        },
        pendingCloseValuationPositions: current.pendingCloseValuationPositions
            .where((position) => !affectedRequestIds.contains(position.id))
            .toList(growable: false),
      );
      final merged = _mergeCoreWithHydrated(
        core,
        settledCurrent,
        orders: _upsertById(syncOrders, current.orders, (order) => order.id),
        deals: _upsertById(syncDeals, current.deals, (deal) => deal.id),
        historyPositions: _upsertByIdAtEnd(
          syncHistoryPositions,
          current.historyPositions,
          (position) => position.id,
        ),
        historySummary: sync.historySummary,
        pendingOperationIds: settledCurrent.pendingOperationIds,
      );
      ++_loadGeneration;
      _optimisticHiddenPositionIds.removeAll(affectedRequestIds);
      for (final operationId in completedOperationIds) {
        _pendingCloseCommandMetadata.remove(operationId);
      }
      state = AsyncData(
        _applyOptimisticOverlay(
          merged,
          settledCurrent,
          acceptGroupedCloseHistory: true,
        ),
      );
      _rememberBounded(_appliedCloseOperationKeys, operationKey);
      if (eventKey != null) {
        _rememberBounded(_processedCloseEventKeys, eventKey);
      }
      if (hasVersionGap) {
        _scheduleRealtimeRefresh();
      }
      return _CloseSyncApplyResult.applied;
    } on FormatException {
      return _CloseSyncApplyResult.rejected;
    }
  }

  String _closeOperationKey(ExV2CloseSync sync) =>
      '${_normalizedId(sync.accountId)}:${sync.version}:'
      '${_normalizedId(sync.operation.idempotencyKey)}';

  void _rememberBounded(Map<String, bool> values, String key) {
    values.remove(key);
    values[key] = true;
    if (values.length > _maximumCloseDedupEntries) {
      values.remove(values.keys.first);
    }
  }

  void _clearCloseSyncDeduplication() {
    _appliedCloseOperationKeys.clear();
    _processedCloseEventKeys.clear();
    _processedDepositEventKeys.clear();
  }

  List<T> _upsertById<T>(
    Iterable<T> incoming,
    Iterable<T> existing,
    String Function(T value) idOf,
  ) {
    final incomingItems = incoming.toList(growable: false);
    final incomingIds = incomingItems
        .map((value) => _normalizedId(idOf(value)))
        .toSet();
    return <T>[
      ...incomingItems,
      ...existing.where(
        (value) => !incomingIds.contains(_normalizedId(idOf(value))),
      ),
    ];
  }

  List<T> _upsertByIdAtEnd<T>(
    Iterable<T> incoming,
    Iterable<T> existing,
    String Function(T value) idOf,
  ) {
    final incomingItems = incoming.toList(growable: false);
    final incomingIds = incomingItems
        .map((value) => _normalizedId(idOf(value)))
        .toSet();
    return <T>[
      ...existing.where(
        (value) => !incomingIds.contains(_normalizedId(idOf(value))),
      ),
      ...incomingItems,
    ];
  }

  String _normalizedId(String value) => value.trim().toLowerCase();

  bool _hasCoherentCloseSyncShape(ExV2CloseSync sync) {
    final affectedIds = sync.affectedPositions
        .map((position) => _normalizedId(position.id))
        .toSet();
    if (affectedIds.length != sync.affectedPositions.length ||
        sync.deals.isEmpty) {
      return false;
    }
    return switch (sync.operation.mode) {
      ExV2CloseMode.full || ExV2CloseMode.partial => affectedIds.length == 1,
      ExV2CloseMode.closeBy => affectedIds.length == 2,
    };
  }

  bool _closeSyncMatchesCommand({
    required ExV2CloseSync sync,
    required ExV2CommandMetadata metadata,
    required String mode,
    required Set<String> positionIds,
  }) {
    if (!_hasCoherentCloseSyncShape(sync) ||
        _normalizedId(sync.operation.mode.wireName) != _normalizedId(mode) ||
        _normalizedId(sync.operation.idempotencyKey) !=
            _normalizedId(metadata.idempotencyKey) ||
        _normalizedId(sync.operation.correlationId) !=
            _normalizedId(metadata.correlationId)) {
      return false;
    }
    final expectedIds = positionIds.map(_normalizedId).toSet();
    final affectedIds = sync.affectedPositions
        .map((position) => _normalizedId(position.id))
        .toSet();
    return expectedIds.length == affectedIds.length &&
        expectedIds.every(affectedIds.contains);
  }

  bool _pendingCloseCommandMatches(
    String operationId,
    ExV2CommandMetadata metadata,
  ) {
    final pendingMetadata = _pendingCloseCommandMetadata[operationId];
    return pendingMetadata != null &&
        _normalizedId(pendingMetadata.idempotencyKey) ==
            _normalizedId(metadata.idempotencyKey) &&
        _normalizedId(pendingMetadata.correlationId) ==
            _normalizedId(metadata.correlationId);
  }

  bool _isOpenPosition(ExV2Position position) =>
      position.status.trim().toLowerCase() == 'open' &&
      position.remainingVolume > 0.000000001;

  Future<DemoDeal?> closePosition(String positionId, {double? volume}) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final originalIndex = before.positions.indexWhere(
      (position) => position.id == positionId,
    );
    if (originalIndex < 0) {
      throw StateError('Position $positionId is not open');
    }
    final operationId = 'position:$positionId';
    if (before.pendingOperationIds.contains(operationId)) {
      throw StateError('Position $positionId is already closing');
    }
    final originalPosition = before.positions[originalIndex];
    final requestedCloseVolume = volume ?? originalPosition.volume;
    final closeVolume = requestedCloseVolume > originalPosition.volume
        ? originalPosition.volume
        : requestedCloseVolume;
    final isPartial = closeVolume > 0 && closeVolume < originalPosition.volume;
    if (!isPartial) _optimisticHiddenPositionIds.add(positionId);
    state = AsyncData(
      before.copyWith(
        positions: [
          for (final position in before.positions)
            if (position.id != positionId)
              position
            else if (isPartial)
              position.copyWith(
                volume: position.volume - closeVolume,
                profit:
                    position.profit *
                    (position.volume - closeVolume) /
                    position.volume,
              ),
        ],
        pendingCloseValuationPositions: [
          originalPosition,
          ...before.pendingCloseValuationPositions.where(
            (position) => position.id != positionId,
          ),
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );

    final baselineExitVolume = _exitVolume(before.deals, positionId);
    final baselineExitProfit = _exitProfit(before.deals);
    final baselineHistoryRealizedProfit = before.historySummary.realizedProfit;
    final metadata = ExV2CommandMetadata.create();
    var commandCommitted = false;
    try {
      final repository = ref.read(exV2RepositoryProvider);
      ExV2ClosePositionResponse? commandResponse;
      _pendingCloseCommandMetadata[operationId] = metadata;
      try {
        await _runSerializedCloseCommand<void>(() async {
          if (!_isMutationScopeCurrent(scope)) return;
          commandResponse = isPartial
              ? await repository.partialClose(
                  positionId: positionId,
                  volume: closeVolume,
                  metadata: metadata,
                )
              : await repository.closePosition(
                  positionId: positionId,
                  volume: closeVolume,
                  metadata: metadata,
                );
        });
        if (!_isMutationScopeCurrent(scope)) return null;
        commandCommitted = true;
      } on ExV2RequestFailure {
        if (!_isMutationScopeCurrent(scope)) rethrow;
        if (await _reconcileMissingPosition(
          positionId: positionId,
          operationId: operationId,
          scope: scope,
        )) {
          return null;
        }
        rethrow;
      }

      final closeSync = commandResponse?.sync;
      if (closeSync != null &&
          _closeSyncMatchesCommand(
            sync: closeSync,
            metadata: metadata,
            mode: isPartial ? 'partial' : 'full',
            positionIds: {positionId},
          )) {
        final applyResult = _applyCloseSync(
          sync: closeSync,
          scope: scope,
          completedOperationIds: {operationId},
          affectedRequestIds: {positionId},
        );
        if (applyResult.accepted) {
          final syncedDeals = closeSync.deals
              .map(ExV2DemoMapper.deal)
              .toList(growable: false);
          return _closingDeal(syncedDeals, positionId);
        }
      }

      return await _reconcileCommittedClose(
        positionId: positionId,
        operationId: operationId,
        fallback: before,
        isPartial: isPartial,
        closeVolume: closeVolume,
        expectedRemainingVolume: originalPosition.volume - closeVolume,
        baselineExitVolume: baselineExitVolume,
        baselineExitProfit: baselineExitProfit,
        baselineHistoryRealizedProfit: baselineHistoryRealizedProfit,
        minimumBootstrapVersion: before.bootstrap.version,
        commandMetadata: metadata,
        scope: scope,
      );
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) {
        if (commandCommitted) return null;
        rethrow;
      }
      if (commandCommitted) {
        _finishCommittedCloseWithoutDeal(operationId, metadata, before, scope);
        return null;
      }
      final current = state.value ?? before;
      if (!_pendingCloseCommandMatches(operationId, metadata)) {
        rethrow;
      }
      _optimisticHiddenPositionIds.remove(positionId);
      _pendingCloseCommandMetadata.remove(operationId);
      if (current.bootstrap.version > before.bootstrap.version) {
        final settledCurrent = current.copyWith(
          pendingCloseValuationPositions: current.pendingCloseValuationPositions
              .where((position) => position.id != positionId)
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        );
        final latestCore = ExV2AccountViewState.fromBootstrap(
          current.bootstrap,
          presentation: current.presentation,
        );
        state = AsyncData(
          _applyOptimisticOverlay(
            _mergeCoreWithHydrated(latestCore, settledCurrent),
            settledCurrent,
          ),
        );
        unawaited(refresh(queueAfterInFlight: true));
        rethrow;
      }
      final restored = [
        for (final position in current.positions)
          if (position.id == positionId) originalPosition else position,
      ];
      if (!restored.any((position) => position.id == positionId)) {
        restored.insert(
          originalIndex.clamp(0, restored.length),
          originalPosition,
        );
      }
      state = AsyncData(
        current.copyWith(
          positions: restored,
          pendingCloseValuationPositions: current.pendingCloseValuationPositions
              .where((position) => position.id != positionId)
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> closePositions(Iterable<String> positionIds) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final seenIds = <String>{};
    final targets = <DemoPosition>[];
    for (final positionId in positionIds) {
      if (!seenIds.add(positionId)) continue;
      final position = before.positions
          .where((item) => item.id == positionId)
          .firstOrNull;
      if (position == null ||
          before.pendingOperationIds.contains('position:$positionId')) {
        continue;
      }
      targets.add(position);
    }
    if (targets.isEmpty) return;

    ++_loadGeneration;
    final scope = _captureMutationScope(before);
    final targetIds = targets.map((position) => position.id).toSet();
    final operationIds = {
      for (final positionId in targetIds) 'position:$positionId',
    };
    _optimisticHiddenPositionIds.addAll(targetIds);
    _groupedClosePositionIds.addAll(targetIds);
    final optimistic = before.copyWith(
      positions: before.positions
          .where((position) => !targetIds.contains(position.id))
          .toList(growable: false),
      pendingCloseValuationPositions: [
        ...targets,
        ...before.pendingCloseValuationPositions.where(
          (position) => !targetIds.contains(position.id),
        ),
      ],
      clearLockedAccountMetrics: true,
      pendingOperationIds: {...before.pendingOperationIds, ...operationIds},
    );
    state = AsyncData(
      optimistic.copyWith(
        lockedAccountMetrics: ExV2AccountMetricSnapshot.fromState(optimistic),
      ),
    );

    final repository = ref.read(exV2RepositoryProvider);
    final commandSucceededIds = <String>{};
    final syncAppliedIds = <String>{};
    for (final target in targets) {
      if (!_isMutationScopeCurrent(scope)) return;
      try {
        var dispatched = false;
        ExV2ClosePositionResponse? commandResponse;
        final metadata = ExV2CommandMetadata.create();
        _pendingCloseCommandMetadata['position:${target.id}'] = metadata;
        await _runSerializedCloseCommand<void>(() async {
          if (!_isMutationScopeCurrent(scope)) return;
          dispatched = true;
          commandResponse = await repository.closePosition(
            positionId: target.id,
            volume: target.volume,
            metadata: metadata,
          );
        });
        if (dispatched) {
          commandSucceededIds.add(target.id);
          final closeSync = commandResponse?.sync;
          if (closeSync != null &&
              _closeSyncMatchesCommand(
                sync: closeSync,
                metadata: metadata,
                mode: 'full',
                positionIds: {target.id},
              )) {
            final applyResult = _applyCloseSync(
              sync: closeSync,
              scope: scope,
              completedOperationIds: {'position:${target.id}'},
              affectedRequestIds: {target.id},
            );
            if (applyResult.accepted) syncAppliedIds.add(target.id);
          }
        }
      } catch (_) {
        // Continue the group. The final canonical read decides whether an
        // ambiguous response committed and restores only positions still open.
      }
    }
    if (!_isMutationScopeCurrent(scope)) return;
    if (syncAppliedIds.containsAll(targetIds)) {
      _finishBulkCloseFromSync(targetIds: targetIds, scope: scope);
      return;
    }

    await _retryCommittedBulkCloseHistory(
      targetIds: targetIds,
      commandSucceededIds: commandSucceededIds,
      operationIds: operationIds,
      fallback: before,
      minimumBootstrapVersion: before.bootstrap.version,
      scope: scope,
    );
  }

  void _finishBulkCloseFromSync({
    required Set<String> targetIds,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    _groupedClosePositionIds.removeAll(targetIds);
    _optimisticHiddenPositionIds.removeAll(targetIds);
    if (_groupedClosePositionIds.isEmpty) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(clearLockedAccountMetrics: true));
      }
    }
    _flushDeferredRefresh();
  }

  Future<void> _retryCommittedBulkCloseHistory({
    required Set<String> targetIds,
    required Set<String> commandSucceededIds,
    required Set<String> operationIds,
    required ExV2AccountViewState fallback,
    required int minimumBootstrapVersion,
    required _AccountMutationScope scope,
  }) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1600),
    ];
    final repository = ref.read(exV2RepositoryProvider);
    ExV2AccountViewState? latestCore;
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!_isMutationScopeCurrent(scope)) return;
      try {
        final core = await _loadCore(applyOptimisticHides: false);
        if (!_isMutationScopeCurrent(scope)) return;
        final current = state.value;
        if (current == null ||
            core.bootstrap.account.id != scope.accountId ||
            core.bootstrap.summary.accountId != scope.accountId ||
            core.bootstrap.version < minimumBootstrapVersion ||
            core.bootstrap.version < current.bootstrap.version) {
          continue;
        }
        latestCore = core;
        final snapshot = await _loadTradingHistorySnapshot(repository);
        if (!_isMutationScopeCurrent(scope)) return;
        final latestCurrent = state.value;
        if (latestCurrent == null ||
            core.bootstrap.version < latestCurrent.bootstrap.version) {
          continue;
        }
        if (!_historySnapshotHasReached(snapshot, core.bootstrap.version)) {
          continue;
        }
        final openIds = core.positions.map((position) => position.id).toSet();
        final closedIds = targetIds.difference(openIds);
        final successfulCommandsAreClosed = commandSucceededIds.every(
          closedIds.contains,
        );
        final closedHistoryIsReady = closedIds.every(
          (positionId) =>
              _hasResolvedClosedHistory(snapshot.positions, positionId),
        );
        if (!successfulCommandsAreClosed || !closedHistoryIsReady) continue;

        _publishCommittedBulkClose(
          core: core,
          snapshot: snapshot,
          targetIds: targetIds,
          operationIds: operationIds,
          scope: scope,
        );
        return;
      } catch (_) {
        // Mutations are never resent. Retry only the canonical GET snapshot.
      }
    }

    _finishBulkCloseWithoutCompleteHistory(
      targetIds: targetIds,
      commandSucceededIds: commandSucceededIds,
      operationIds: operationIds,
      fallback: fallback,
      latestCore: latestCore,
      scope: scope,
    );
  }

  void _publishCommittedBulkClose({
    required ExV2AccountViewState core,
    required _TradingHistorySnapshot snapshot,
    required Set<String> targetIds,
    required Set<String> operationIds,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value;
    if (current == null) return;
    ++_loadGeneration;
    _groupedClosePositionIds.removeAll(targetIds);
    _optimisticHiddenPositionIds.removeAll(targetIds);
    for (final operationId in operationIds) {
      _pendingCloseCommandMetadata.remove(operationId);
    }
    final historyPositions = <DemoHistoryPosition>[
      ...snapshot.positions,
      ...current.historyPositions.where(
        (position) => position.id.startsWith('wallet-'),
      ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    final settledCurrent = current.copyWith(
      pendingCloseValuationPositions: current.pendingCloseValuationPositions
          .where((position) => !targetIds.contains(position.id))
          .toList(growable: false),
      pendingOperationIds: {
        ...current.pendingOperationIds.where(
          (operationId) => !operationIds.contains(operationId),
        ),
      },
      clearLockedAccountMetrics: _groupedClosePositionIds.isEmpty,
    );
    state = AsyncData(
      _applyOptimisticOverlay(
        _mergeCoreWithHydrated(
          core,
          settledCurrent,
          deals: snapshot.deals,
          historyPositions: historyPositions,
          historySummary: snapshot.summary,
        ),
        settledCurrent,
      ),
    );
    _flushDeferredRefresh();
  }

  void _finishBulkCloseWithoutCompleteHistory({
    required Set<String> targetIds,
    required Set<String> commandSucceededIds,
    required Set<String> operationIds,
    required ExV2AccountViewState fallback,
    required ExV2AccountViewState? latestCore,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value ?? fallback;
    ++_loadGeneration;
    final confirmedClosedIds = latestCore == null
        ? commandSucceededIds
        : targetIds.difference(
            latestCore.positions.map((position) => position.id).toSet(),
          );
    final stillOpenIds = targetIds.difference(confirmedClosedIds);
    _groupedClosePositionIds.removeAll(targetIds);
    _optimisticHiddenPositionIds.removeAll(stillOpenIds);
    _optimisticHiddenPositionIds.addAll(confirmedClosedIds);
    for (final operationId in operationIds) {
      _pendingCloseCommandMetadata.remove(operationId);
    }
    final settledCurrent = current.copyWith(
      positions: latestCore == null
          ? [
              ...current.positions,
              for (final position in fallback.positions)
                if (stillOpenIds.contains(position.id) &&
                    !current.positions.any((item) => item.id == position.id))
                  position,
            ]
          : current.positions,
      pendingCloseValuationPositions: current.pendingCloseValuationPositions
          .where((position) => !targetIds.contains(position.id))
          .toList(growable: false),
      pendingOperationIds: {
        ...current.pendingOperationIds.where(
          (operationId) => !operationIds.contains(operationId),
        ),
      },
      clearLockedAccountMetrics: _groupedClosePositionIds.isEmpty,
    );
    state = AsyncData(
      latestCore == null
          ? settledCurrent
          : _applyOptimisticOverlay(
              _mergeCoreWithHydrated(latestCore, settledCurrent),
              settledCurrent,
            ),
    );
    _deferredRefreshRequested = false;
    unawaited(refresh(queueAfterInFlight: true));
  }

  void _flushDeferredRefresh() {
    if (!_deferredRefreshRequested || !ref.mounted) return;
    _deferredRefreshRequested = false;
    unawaited(refresh(queueAfterInFlight: true));
  }

  Future<bool> _reconcileMissingPosition({
    required String positionId,
    required String operationId,
    required _AccountMutationScope scope,
  }) async {
    try {
      if (!_isMutationScopeCurrent(scope)) return false;
      final core = await _loadCore(applyOptimisticHides: false);
      if (!_isMutationScopeCurrent(scope)) return false;
      final current = state.value;
      if (current == null ||
          core.bootstrap.account.id != scope.accountId ||
          core.bootstrap.summary.accountId != scope.accountId ||
          core.bootstrap.version < current.bootstrap.version) {
        return false;
      }
      if (core.positions.any((position) => position.id == positionId)) {
        return false;
      }
      _optimisticHiddenPositionIds.remove(positionId);
      _pendingCloseCommandMetadata.remove(operationId);
      final settledCurrent = current.copyWith(
        pendingCloseValuationPositions: current.pendingCloseValuationPositions
            .where((position) => position.id != positionId)
            .toList(growable: false),
        pendingOperationIds: {
          ...current.pendingOperationIds.where((id) => id != operationId),
        },
      );
      final reconciled = _applyOptimisticOverlay(
        _mergeCoreWithHydrated(core, settledCurrent),
        settledCurrent,
      );
      if (ref.mounted) state = AsyncData(reconciled);
      unawaited(refresh());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DemoDeal?> _reconcileCommittedClose({
    required String positionId,
    required String operationId,
    required ExV2AccountViewState fallback,
    required bool isPartial,
    required double closeVolume,
    required double expectedRemainingVolume,
    required double baselineExitVolume,
    required double baselineExitProfit,
    required double baselineHistoryRealizedProfit,
    required int minimumBootstrapVersion,
    required ExV2CommandMetadata commandMetadata,
    required _AccountMutationScope scope,
  }) async {
    return _retryCommittedCloseHistory(
      positionId: positionId,
      operationId: operationId,
      fallback: fallback,
      isPartial: isPartial,
      closeVolume: closeVolume,
      expectedRemainingVolume: expectedRemainingVolume,
      baselineExitVolume: baselineExitVolume,
      baselineExitProfit: baselineExitProfit,
      baselineHistoryRealizedProfit: baselineHistoryRealizedProfit,
      minimumBootstrapVersion: minimumBootstrapVersion,
      commandMetadata: commandMetadata,
      scope: scope,
    );
  }

  Future<_TradingHistorySnapshot> _loadTradingHistorySnapshot(
    ExV2Repository repository,
  ) async {
    final results = await Future.wait<Object>([
      repository.historyDealsSnapshot(),
      repository.historyPositionsSnapshot(),
      repository.historySummarySnapshot(),
    ]);
    final dealsSnapshot = results[0] as ExV2HistoryRowsSnapshot;
    final positionsSnapshot = results[1] as ExV2HistoryRowsSnapshot;
    final summarySnapshot = results[2] as ExV2HistorySummarySnapshot;
    final dealRows = dealsSnapshot.items;
    final positionRows = positionsSnapshot.items;
    final versionMetadata = [
      dealsSnapshot.hasVersionMetadata,
      positionsSnapshot.hasVersionMetadata,
      summarySnapshot.hasVersionMetadata,
    ];
    final hasAnyVersionMetadata = versionMetadata.any((present) => present);
    final versions = [
      dealsSnapshot.snapshotVersion,
      positionsSnapshot.snapshotVersion,
      summarySnapshot.snapshotVersion,
    ];
    final hasCompleteVersionMetadata =
        versionMetadata.every((present) => present) &&
        versions.every((version) => version != null);
    final snapshotVersion = hasCompleteVersionMetadata
        ? versions.whereType<int>().reduce(
            (oldest, version) => version < oldest ? version : oldest,
          )
        : null;
    return (
      deals: _mapRows(dealRows, ExV2DemoMapper.historyDeal),
      positions: _mapRows(
        ExV2HistoryReconciler.enrichClosedPositions(positionRows, dealRows),
        ExV2DemoMapper.historyPosition,
      ),
      summary: summarySnapshot.summary,
      hasAnyVersionMetadata: hasAnyVersionMetadata,
      snapshotVersion: snapshotVersion,
    );
  }

  bool _historySnapshotHasReached(
    _TradingHistorySnapshot snapshot,
    int requiredVersion,
  ) {
    if (!snapshot.hasAnyVersionMetadata) return true;
    final snapshotVersion = snapshot.snapshotVersion;
    return snapshotVersion != null && snapshotVersion >= requiredVersion;
  }

  Future<DemoDeal?> _retryCommittedCloseHistory({
    required String positionId,
    required String operationId,
    required ExV2AccountViewState fallback,
    required bool isPartial,
    required double closeVolume,
    required double expectedRemainingVolume,
    required double baselineExitVolume,
    required double baselineExitProfit,
    required double baselineHistoryRealizedProfit,
    required int minimumBootstrapVersion,
    required ExV2CommandMetadata commandMetadata,
    required _AccountMutationScope scope,
  }) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 150),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ];
    final repository = ref.read(exV2RepositoryProvider);
    ExV2AccountViewState? latestAuthoritativeCore;
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!_isMutationScopeCurrent(scope)) return null;
      try {
        final core = await _loadCore(applyOptimisticHides: false);
        if (!_isMutationScopeCurrent(scope)) return null;
        final current = state.value;
        if (current == null) return null;
        final snapshotMatchesScope =
            core.bootstrap.account.id == scope.accountId &&
            core.bootstrap.summary.accountId == scope.accountId;
        final snapshotIsCurrent =
            core.bootstrap.version > minimumBootstrapVersion &&
            core.bootstrap.version >= current.bootstrap.version;
        if (!snapshotMatchesScope || !snapshotIsCurrent) {
          continue;
        }
        if (_isCoreCloseVisible(
          core: core,
          positionId: positionId,
          isPartial: isPartial,
          expectedRemainingVolume: expectedRemainingVolume,
        )) {
          latestAuthoritativeCore = core;
          _publishCommittedCloseCore(
            core: core,
            positionId: positionId,
            scope: scope,
          );
        }
        final snapshot = await _loadTradingHistorySnapshot(repository);
        if (!_isMutationScopeCurrent(scope)) return null;
        final latestCurrent = state.value;
        if (latestCurrent == null ||
            core.bootstrap.version < latestCurrent.bootstrap.version) {
          continue;
        }
        if (!_historySnapshotHasReached(snapshot, core.bootstrap.version)) {
          continue;
        }
        if (!_isCommittedCloseVisible(
          core: core,
          snapshot: snapshot,
          positionId: positionId,
          isPartial: isPartial,
          closeVolume: closeVolume,
          expectedRemainingVolume: expectedRemainingVolume,
          baselineExitVolume: baselineExitVolume,
          baselineExitProfit: baselineExitProfit,
          baselineHistoryRealizedProfit: baselineHistoryRealizedProfit,
        )) {
          continue;
        }
        final ownsPendingCommand = _pendingCloseCommandMatches(
          operationId,
          commandMetadata,
        );
        if (ownsPendingCommand) {
          _optimisticHiddenPositionIds.remove(positionId);
          _pendingCloseCommandMetadata.remove(operationId);
        }
        final settledCurrent = ownsPendingCommand
            ? latestCurrent.copyWith(
                pendingCloseValuationPositions: latestCurrent
                    .pendingCloseValuationPositions
                    .where((position) => position.id != positionId)
                    .toList(growable: false),
                pendingOperationIds: {
                  ...latestCurrent.pendingOperationIds.where(
                    (id) => id != operationId,
                  ),
                },
              )
            : latestCurrent;
        state = AsyncData(
          _applyOptimisticOverlay(
            _mergeCoreWithHydrated(
              core,
              settledCurrent,
              deals: snapshot.deals,
              historyPositions: snapshot.positions,
              historySummary: snapshot.summary,
            ),
            settledCurrent,
          ),
        );
        return _closingDeal(snapshot.deals, positionId);
      } catch (_) {
        // A committed close remains final; retry the canonical history read.
      }
    }
    if (!_isMutationScopeCurrent(scope)) return null;
    final latestCore = latestAuthoritativeCore;
    final current = state.value;
    if (latestCore != null &&
        current != null &&
        latestCore.bootstrap.version >= current.bootstrap.version) {
      final ownsPendingCommand = _pendingCloseCommandMatches(
        operationId,
        commandMetadata,
      );
      if (ownsPendingCommand) {
        _optimisticHiddenPositionIds.remove(positionId);
        _pendingCloseCommandMetadata.remove(operationId);
      }
      final settledCurrent = ownsPendingCommand
          ? current.copyWith(
              pendingCloseValuationPositions: current
                  .pendingCloseValuationPositions
                  .where((position) => position.id != positionId)
                  .toList(growable: false),
              pendingOperationIds: {
                ...current.pendingOperationIds.where((id) => id != operationId),
              },
            )
          : current;
      state = AsyncData(
        _applyOptimisticOverlay(
          _mergeCoreWithHydrated(latestCore, settledCurrent),
          settledCurrent,
        ),
      );
      unawaited(refresh());
      return null;
    }
    _finishCommittedCloseWithoutDeal(
      operationId,
      commandMetadata,
      fallback,
      scope,
    );
    return null;
  }

  void _publishCommittedCloseCore({
    required ExV2AccountViewState core,
    required String positionId,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value;
    if (current == null ||
        core.bootstrap.account.id != scope.accountId ||
        core.bootstrap.summary.accountId != scope.accountId ||
        core.bootstrap.version < current.bootstrap.version) {
      return;
    }
    final settledCurrent = current.copyWith(
      pendingCloseValuationPositions: current.pendingCloseValuationPositions
          .where((position) => position.id != positionId)
          .toList(growable: false),
    );
    final published = _applyOptimisticOverlay(
      _mergeCoreWithHydrated(core, settledCurrent),
      settledCurrent,
    );
    state = AsyncData(published);
  }

  bool _isCommittedCloseVisible({
    required ExV2AccountViewState core,
    required _TradingHistorySnapshot snapshot,
    required String positionId,
    required bool isPartial,
    required double closeVolume,
    required double expectedRemainingVolume,
    required double baselineExitVolume,
    required double baselineExitProfit,
    required double baselineHistoryRealizedProfit,
  }) {
    const tolerance = 0.000000001;
    final coreIsCurrent = _isCoreCloseVisible(
      core: core,
      positionId: positionId,
      isPartial: isPartial,
      expectedRemainingVolume: expectedRemainingVolume,
    );
    final historyIsCurrent =
        isPartial || _hasResolvedClosedHistory(snapshot.positions, positionId);
    final newExitVolume =
        _exitVolume(snapshot.deals, positionId) - baselineExitVolume;
    final expectedHistoryRealizedProfit =
        baselineHistoryRealizedProfit +
        (_exitProfit(snapshot.deals) - baselineExitProfit);
    final summaryIsCurrent =
        (snapshot.summary.realizedProfit - expectedHistoryRealizedProfit)
            .abs() <=
        tolerance;
    return coreIsCurrent &&
        historyIsCurrent &&
        newExitVolume + tolerance >= closeVolume &&
        summaryIsCurrent;
  }

  bool _isCoreCloseVisible({
    required ExV2AccountViewState core,
    required String positionId,
    required bool isPartial,
    required double expectedRemainingVolume,
  }) {
    const tolerance = 0.000000001;
    final normalizedId = positionId.trim().toLowerCase();
    final serverPosition = core.positions
        .where((position) => position.id.trim().toLowerCase() == normalizedId)
        .firstOrNull;
    return isPartial
        ? serverPosition != null &&
              (serverPosition.volume - expectedRemainingVolume).abs() <=
                  tolerance
        : serverPosition == null;
  }

  double _exitProfit(List<DemoDeal> deals) => deals
      .where((deal) => deal.entry == 'out')
      .fold<double>(0, (total, deal) => total + deal.profit);

  double _exitVolume(List<DemoDeal> deals, String positionId) {
    final normalizedId = positionId.trim().toLowerCase();
    return deals
        .where(
          (deal) =>
              deal.positionId.trim().toLowerCase() == normalizedId &&
              deal.entry == 'out',
        )
        .fold<double>(0, (total, deal) => total + deal.volume);
  }

  DemoDeal? _closingDeal(List<DemoDeal> deals, String positionId) {
    final normalizedId = positionId.trim().toLowerCase();
    return deals
        .where(
          (deal) =>
              deal.positionId.trim().toLowerCase() == normalizedId &&
              deal.entry == 'out',
        )
        .firstOrNull;
  }

  bool _hasResolvedClosedHistory(
    List<DemoHistoryPosition> positions,
    String positionId,
  ) {
    final normalizedId = positionId.trim().toLowerCase();
    return positions.any(
      (position) =>
          position.id.trim().toLowerCase() == normalizedId &&
          position.closePrice != null,
    );
  }

  void _finishCommittedCloseWithoutDeal(
    String operationId,
    ExV2CommandMetadata commandMetadata,
    ExV2AccountViewState fallback,
    _AccountMutationScope scope,
  ) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value ?? fallback;
    if (!_pendingCloseCommandMatches(operationId, commandMetadata)) {
      unawaited(refresh(queueAfterInFlight: true));
      return;
    }
    _pendingCloseCommandMetadata.remove(operationId);
    if (ref.mounted) {
      final positionId = operationId.startsWith('position:')
          ? operationId.substring('position:'.length)
          : '';
      state = AsyncData(
        current.copyWith(
          pendingCloseValuationPositions: current.pendingCloseValuationPositions
              .where((position) => position.id != positionId)
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
    }
    unawaited(refresh());
  }

  Future<void> cancelOrder(String orderId) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final originalIndex = before.pendingOrders.indexWhere(
      (order) => order.id == orderId,
    );
    if (originalIndex < 0) throw StateError('Order $orderId is not pending');
    final originalOrder = before.pendingOrders[originalIndex];
    final operationId = 'order:$orderId';
    if (before.pendingOperationIds.contains(operationId)) return;
    _optimisticHiddenOrderIds.add(orderId);
    state = AsyncData(
      before.copyWith(
        pendingOrders: before.pendingOrders
            .where((order) => order.id != orderId)
            .toList(growable: false),
        orders: [
          for (final order in before.orders)
            order.id == orderId ? order.copyWith(status: 'canceling') : order,
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .cancelOrder(orderId, metadata: ExV2CommandMetadata.create());
      if (!_isMutationScopeCurrent(scope)) return;
      final core = await _loadCore();
      if (!_isMutationScopeCurrent(scope)) return;
      _optimisticHiddenOrderIds.remove(orderId);
      final current = state.value ?? before;
      final confirmed = _mergeCoreWithHydrated(
        core,
        current,
        orders: [
          for (final order in current.orders)
            order.id == orderId ? order.copyWith(status: 'canceled') : order,
        ],
        pendingOperationIds: {
          ...current.pendingOperationIds.where((id) => id != operationId),
        },
      );
      if (ref.mounted) state = AsyncData(confirmed);
      unawaited(refresh());
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) rethrow;
      _optimisticHiddenOrderIds.remove(orderId);
      final current = state.value ?? before;
      final restored = [...current.pendingOrders];
      if (!restored.any((order) => order.id == orderId)) {
        restored.insert(originalIndex.clamp(0, restored.length), originalOrder);
      }
      state = AsyncData(
        current.copyWith(
          pendingOrders: restored,
          orders: [
            for (final order in current.orders)
              order.id == orderId ? order.copyWith(status: 'pending') : order,
          ],
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> updatePositionProtection({
    required String positionId,
    double? stopLoss,
    double? takeProfit,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
  }) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final index = before.positions.indexWhere(
      (position) => position.id == positionId,
    );
    if (index < 0) throw StateError('Position $positionId is not open');
    final operationId = 'protection:$positionId';
    final original = before.positions[index];
    final optimistic = original.copyWith(
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      clearStopLoss: clearStopLoss,
      clearTakeProfit: clearTakeProfit,
    );
    state = AsyncData(
      before.copyWith(
        positions: [
          for (final position in before.positions)
            position.id == positionId ? optimistic : position,
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .updateProtection(
            positionId: positionId,
            stopLoss: clearStopLoss ? null : stopLoss,
            takeProfit: clearTakeProfit ? null : takeProfit,
            rowVersion: before.positionRowVersion(positionId),
            metadata: ExV2CommandMetadata.create(),
          );
      if (!_isMutationScopeCurrent(scope)) return;
      final core = await _loadCore();
      if (!_isMutationScopeCurrent(scope)) return;
      final current = state.value ?? before;
      if (ref.mounted) {
        state = AsyncData(
          _mergeCoreWithHydrated(
            core,
            current,
            pendingOperationIds: {
              ...current.pendingOperationIds.where((id) => id != operationId),
            },
          ),
        );
      }
      unawaited(refresh());
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) rethrow;
      final current = state.value ?? before;
      state = AsyncData(
        current.copyWith(
          positions: [
            for (final position in current.positions)
              position.id == positionId ? original : position,
          ],
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> modifyPendingOrder({
    required String orderId,
    double? price,
    double? stopLoss,
    double? takeProfit,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
  }) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final index = before.pendingOrders.indexWhere(
      (order) => order.id == orderId,
    );
    if (index < 0) throw StateError('Order $orderId is not pending');
    final original = before.pendingOrders[index];
    final operationId = 'modify-order:$orderId';
    final optimistic = original.copyWith(
      price: price,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      clearStopLoss: clearStopLoss,
      clearTakeProfit: clearTakeProfit,
    );
    state = AsyncData(
      before.copyWith(
        pendingOrders: [
          for (final order in before.pendingOrders)
            order.id == orderId ? optimistic : order,
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .modifyOrder(
            orderId: orderId,
            requestedPrice: optimistic.price,
            stopLoss: optimistic.stopLoss,
            takeProfit: optimistic.takeProfit,
            rowVersion: before.orderRowVersion(orderId),
            metadata: ExV2CommandMetadata.create(),
          );
      if (!_isMutationScopeCurrent(scope)) return;
      final core = await _loadCore();
      if (!_isMutationScopeCurrent(scope)) return;
      final current = state.value ?? before;
      if (ref.mounted) {
        state = AsyncData(
          _mergeCoreWithHydrated(
            core,
            current,
            pendingOperationIds: {
              ...current.pendingOperationIds.where((id) => id != operationId),
            },
          ),
        );
      }
      unawaited(refresh());
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) rethrow;
      final current = state.value ?? before;
      state = AsyncData(
        current.copyWith(
          pendingOrders: [
            for (final order in current.pendingOrders)
              order.id == orderId ? original : order,
          ],
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> closeBy(String positionId, String oppositePositionId) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final ids = {positionId, oppositePositionId};
    final originals = before.positions
        .where((position) => ids.contains(position.id))
        .toList(growable: false);
    if (originals.length != 2) {
      throw StateError('Close-by positions are missing');
    }
    final first = originals.firstWhere((position) => position.id == positionId);
    final second = originals.firstWhere(
      (position) => position.id == oppositePositionId,
    );
    if (first.symbol != second.symbol || first.side == second.side) {
      throw StateError(
        'Close-by positions must be opposite sides of one symbol',
      );
    }
    final matchedVolume = first.volume < second.volume
        ? first.volume
        : second.volume;
    final fullyClosedIds = {
      if (first.volume <= matchedVolume) first.id,
      if (second.volume <= matchedVolume) second.id,
    };
    final operationId = 'close-by:$positionId:$oppositePositionId';
    _optimisticHiddenPositionIds.addAll(fullyClosedIds);
    state = AsyncData(
      before.copyWith(
        positions: [
          for (final position in before.positions)
            if (!fullyClosedIds.contains(position.id))
              if (ids.contains(position.id))
                position.copyWith(
                  volume: position.volume - matchedVolume,
                  profit:
                      position.profit *
                      (position.volume - matchedVolume) /
                      position.volume,
                )
              else
                position,
        ],
        pendingCloseValuationPositions: [
          ...originals,
          ...before.pendingCloseValuationPositions.where(
            (position) => !ids.contains(position.id),
          ),
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      ExV2CloseByResponse? commandResponse;
      final metadata = ExV2CommandMetadata.create();
      _pendingCloseCommandMetadata[operationId] = metadata;
      await _runSerializedCloseCommand<void>(() async {
        if (!_isMutationScopeCurrent(scope)) return;
        commandResponse = await ref
            .read(exV2RepositoryProvider)
            .closeBy(
              positionId: positionId,
              oppositePositionId: oppositePositionId,
              metadata: metadata,
            );
      });
      if (!_isMutationScopeCurrent(scope)) return;
      final closeSync = commandResponse?.sync;
      if (closeSync != null &&
          _closeSyncMatchesCommand(
            sync: closeSync,
            metadata: metadata,
            mode: 'close_by',
            positionIds: ids,
          )) {
        final applyResult = _applyCloseSync(
          sync: closeSync,
          scope: scope,
          completedOperationIds: {operationId},
          affectedRequestIds: ids,
        );
        if (applyResult.accepted) return;
      }
      await _retryCommittedCloseByHistory(
        positionIds: ids,
        expectedRemainingVolumes: {
          first.id: first.volume - matchedVolume,
          second.id: second.volume - matchedVolume,
        },
        matchedVolume: matchedVolume,
        baselineExitVolumes: {
          first.id: _exitVolume(before.deals, first.id),
          second.id: _exitVolume(before.deals, second.id),
        },
        baselineExitProfit: _exitProfit(before.deals),
        baselineHistoryRealizedProfit: before.historySummary.realizedProfit,
        operationId: operationId,
        fallback: before,
        minimumBootstrapVersion: before.bootstrap.version,
        scope: scope,
      );
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) rethrow;
      _optimisticHiddenPositionIds.removeAll(fullyClosedIds);
      _pendingCloseCommandMetadata.remove(operationId);
      final current = state.value ?? before;
      if (current.bootstrap.version > before.bootstrap.version) {
        final settledCurrent = current.copyWith(
          pendingCloseValuationPositions: current.pendingCloseValuationPositions
              .where((position) => !ids.contains(position.id))
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        );
        final latestCore = ExV2AccountViewState.fromBootstrap(
          current.bootstrap,
          presentation: current.presentation,
        );
        state = AsyncData(
          _applyOptimisticOverlay(
            _mergeCoreWithHydrated(latestCore, settledCurrent),
            settledCurrent,
          ),
        );
        unawaited(refresh(queueAfterInFlight: true));
        rethrow;
      }
      state = AsyncData(
        current.copyWith(
          positions: before.positions,
          pendingCloseValuationPositions: current.pendingCloseValuationPositions
              .where((position) => !ids.contains(position.id))
              .toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> _retryCommittedCloseByHistory({
    required Set<String> positionIds,
    required Map<String, double> expectedRemainingVolumes,
    required double matchedVolume,
    required Map<String, double> baselineExitVolumes,
    required double baselineExitProfit,
    required double baselineHistoryRealizedProfit,
    required String operationId,
    required ExV2AccountViewState fallback,
    required int minimumBootstrapVersion,
    required _AccountMutationScope scope,
  }) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1600),
    ];
    const tolerance = 0.000000001;
    final repository = ref.read(exV2RepositoryProvider);
    ExV2AccountViewState? latestCore;
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!_isMutationScopeCurrent(scope)) return;
      try {
        final core = await _loadCore(applyOptimisticHides: false);
        if (!_isMutationScopeCurrent(scope)) return;
        final current = state.value;
        if (current == null ||
            core.bootstrap.account.id != scope.accountId ||
            core.bootstrap.summary.accountId != scope.accountId ||
            core.bootstrap.version <= minimumBootstrapVersion ||
            core.bootstrap.version < current.bootstrap.version) {
          continue;
        }
        latestCore = core;
        final snapshot = await _loadTradingHistorySnapshot(repository);
        if (!_isMutationScopeCurrent(scope)) return;
        final latestCurrent = state.value;
        if (latestCurrent == null ||
            core.bootstrap.version < latestCurrent.bootstrap.version) {
          continue;
        }
        if (!_historySnapshotHasReached(snapshot, core.bootstrap.version)) {
          continue;
        }
        final coreMatches = expectedRemainingVolumes.entries.every((entry) {
          final normalizedId = _normalizedId(entry.key);
          final serverPosition = core.positions
              .where((position) => _normalizedId(position.id) == normalizedId)
              .firstOrNull;
          return entry.value <= tolerance
              ? serverPosition == null
              : serverPosition != null &&
                    (serverPosition.volume - entry.value).abs() <= tolerance;
        });
        final dealsMatch = positionIds.every((positionId) {
          final baseline = baselineExitVolumes[positionId] ?? 0;
          return _exitVolume(snapshot.deals, positionId) -
                  baseline +
                  tolerance >=
              matchedVolume;
        });
        final closedHistoryMatches = expectedRemainingVolumes.entries
            .where((entry) => entry.value <= tolerance)
            .every(
              (entry) =>
                  _hasResolvedClosedHistory(snapshot.positions, entry.key),
            );
        final expectedHistoryRealizedProfit =
            baselineHistoryRealizedProfit +
            (_exitProfit(snapshot.deals) - baselineExitProfit);
        final summaryMatches =
            (snapshot.summary.realizedProfit - expectedHistoryRealizedProfit)
                .abs() <=
            tolerance;
        if (!coreMatches ||
            !dealsMatch ||
            !closedHistoryMatches ||
            !summaryMatches) {
          continue;
        }

        _publishCommittedCloseBy(
          core: core,
          snapshot: snapshot,
          positionIds: positionIds,
          operationId: operationId,
          scope: scope,
        );
        return;
      } catch (_) {
        // The close-by mutation is already committed. Retry GET snapshots only.
      }
    }
    _finishCommittedCloseByWithoutCompleteHistory(
      positionIds: positionIds,
      operationId: operationId,
      fallback: fallback,
      latestCore: latestCore,
      scope: scope,
    );
  }

  void _publishCommittedCloseBy({
    required ExV2AccountViewState core,
    required _TradingHistorySnapshot snapshot,
    required Set<String> positionIds,
    required String operationId,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value;
    if (current == null || core.bootstrap.version < current.bootstrap.version) {
      return;
    }
    ++_loadGeneration;
    _optimisticHiddenPositionIds.removeAll(positionIds);
    _pendingCloseCommandMetadata.remove(operationId);
    final historyPositions = <DemoHistoryPosition>[
      ...snapshot.positions,
      ...current.historyPositions.where(
        (position) => position.id.startsWith('wallet-'),
      ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    final settledCurrent = current.copyWith(
      pendingCloseValuationPositions: current.pendingCloseValuationPositions
          .where((position) => !positionIds.contains(position.id))
          .toList(growable: false),
      pendingOperationIds: {
        ...current.pendingOperationIds.where((id) => id != operationId),
      },
    );
    state = AsyncData(
      _applyOptimisticOverlay(
        _mergeCoreWithHydrated(
          core,
          settledCurrent,
          deals: snapshot.deals,
          historyPositions: historyPositions,
          historySummary: snapshot.summary,
        ),
        settledCurrent,
      ),
    );
  }

  void _finishCommittedCloseByWithoutCompleteHistory({
    required Set<String> positionIds,
    required String operationId,
    required ExV2AccountViewState fallback,
    required ExV2AccountViewState? latestCore,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value ?? fallback;
    ++_loadGeneration;
    _pendingCloseCommandMetadata.remove(operationId);
    if (latestCore != null) {
      _optimisticHiddenPositionIds.removeAll(positionIds);
    }
    final settledCurrent = current.copyWith(
      pendingCloseValuationPositions: current.pendingCloseValuationPositions
          .where((position) => !positionIds.contains(position.id))
          .toList(growable: false),
      pendingOperationIds: {
        ...current.pendingOperationIds.where((id) => id != operationId),
      },
    );
    state = AsyncData(
      latestCore == null
          ? settledCurrent
          : _applyOptimisticOverlay(
              _mergeCoreWithHydrated(latestCore, settledCurrent),
              settledCurrent,
            ),
    );
    unawaited(refresh(queueAfterInFlight: true));
  }

  Future<void> createWalletRequest({
    required bool isDeposit,
    required double amount,
    required String note,
  }) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    final metadata = ExV2CommandMetadata.create();
    final operationId = 'wallet:${metadata.idempotencyKey}';
    final placeholder = <String, dynamic>{
      'id': metadata.idempotencyKey,
      'type': isDeposit ? 'deposit' : 'withdrawal',
      'amount': amount,
      'currency': before.wallet.currency,
      'status': 'sending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'reference': note,
    };
    if (!isDeposit) {
      _walletRequestOverlays[operationId] = (
        accountId: scope.accountId,
        isDeposit: false,
        row: placeholder,
        minimumDepositTotal: null,
      );
    }
    final optimisticDeposits = isDeposit ? before.deposits : before.deposits;
    final optimisticWithdrawals = isDeposit
        ? before.withdrawals
        : [placeholder, ...before.withdrawals];
    state = AsyncData(
      before.copyWith(
        historyPositions: _historyWithWalletRequests(
          before,
          deposits: optimisticDeposits,
          withdrawals: optimisticWithdrawals,
        ),
        deposits: optimisticDeposits,
        withdrawals: optimisticWithdrawals,
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      final repository = ref.read(exV2RepositoryProvider);
      late final JsonMap confirmed;
      if (isDeposit) {
        final deposit = await _createDepositWithTransportRetry(
          repository: repository,
          amount: amount,
          currency: before.wallet.currency,
          method: 'demo',
          reference: note,
          metadata: metadata,
        );
        if (_normalizedId(deposit.accountId) !=
            _normalizedId(scope.accountId)) {
          throw const FormatException(
            'Deposit response belongs to another account',
          );
        }
        confirmed = deposit.toJson();
      } else {
        confirmed = await repository.createWithdrawal(
          amount: amount,
          currency: before.wallet.currency,
          bankName: '',
          bankAccount: '',
          accountHolder: note,
          metadata: metadata,
        );
      }
      if (!_isMutationScopeCurrent(scope)) return;
      final current = state.value ?? before;
      final row = <String, dynamic>{
        ...confirmed,
        'type': isDeposit ? 'deposit' : 'withdrawal',
      };
      final nextDeposits = isDeposit
          ? [
              row,
              ...current.deposits.where(
                (item) =>
                    item['id'] != metadata.idempotencyKey &&
                    !_sameWalletRequest(item, row),
              ),
            ]
          : current.deposits;
      final nextWithdrawals = isDeposit
          ? current.withdrawals
          : [
              row,
              ...current.withdrawals.where(
                (item) => item['id'] != metadata.idempotencyKey,
              ),
            ];
      final nextHistorySummary = current.historySummary;
      _walletRequestOverlays.remove(operationId);
      final overlayKey = _walletOverlayKey(
        accountId: scope.accountId,
        isDeposit: isDeposit,
        row: row,
        fallback: metadata.idempotencyKey,
      );
      _walletRequestOverlays[overlayKey] = (
        accountId: scope.accountId,
        isDeposit: isDeposit,
        row: row,
        minimumDepositTotal: null,
      );
      final nextBootstrap = isDeposit
          ? current.bootstrap.copyWith(
              version:
                  (row['snapshotVersion'] as int) > current.bootstrap.version
                  ? row['snapshotVersion'] as int
                  : current.bootstrap.version,
              recentDeposits: nextDeposits
                  .map(ExV2Deposit.fromJson)
                  .toList(growable: false),
            )
          : current.bootstrap;
      state = AsyncData(
        current.copyWith(
          bootstrap: nextBootstrap,
          historyPositions: _historyWithWalletRequests(
            current,
            deposits: nextDeposits,
            withdrawals: nextWithdrawals,
          ),
          historySummary: nextHistorySummary,
          deposits: nextDeposits,
          withdrawals: nextWithdrawals,
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      if (!isDeposit) unawaited(refresh());
    } catch (_) {
      if (!_isMutationScopeCurrent(scope)) rethrow;
      _walletRequestOverlays.remove(operationId);
      final current = state.value ?? before;
      JsonMap failed(JsonMap item) => item['id'] == metadata.idempotencyKey
          ? {...item, 'status': 'failed'}
          : item;
      final failedDeposits = isDeposit
          ? current.deposits
                .where((item) => item['id'] != metadata.idempotencyKey)
                .toList(growable: false)
          : current.deposits.map(failed).toList(growable: false);
      final failedWithdrawals = current.withdrawals
          .map(failed)
          .toList(growable: false);
      state = AsyncData(
        current.copyWith(
          historyPositions: _historyWithWalletRequests(
            current,
            deposits: failedDeposits,
            withdrawals: failedWithdrawals,
          ),
          deposits: failedDeposits,
          withdrawals: failedWithdrawals,
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<ExV2Deposit> _createDepositWithTransportRetry({
    required ExV2Repository repository,
    required double amount,
    required String currency,
    required String method,
    required String reference,
    required ExV2CommandMetadata metadata,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await repository.createDeposit(
          amount: amount,
          currency: currency,
          method: method,
          reference: reference,
          metadata: metadata,
        );
      } on ExV2RequestFailure catch (error) {
        final retryable =
            error.statusCode == null ||
            (error.statusCode != null && error.statusCode! >= 500);
        if (!retryable || attempt == 1) rethrow;
      }
    }
    throw StateError('Deposit retry loop completed without a result');
  }

  Future<void> markNotificationRead(String notificationId) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    state = AsyncData(
      before.copyWith(
        notifications: [
          for (final item in before.notifications)
            if (item['id']?.toString() == notificationId)
              {...item, 'isRead': true, 'read': true}
            else
              item,
        ],
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .markNotificationRead(
            notificationId,
            metadata: ExV2CommandMetadata.create(),
          );
    } catch (_) {
      if (_isMutationScopeCurrent(scope)) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> markAllNotificationsRead() async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    state = AsyncData(
      before.copyWith(
        notifications: [
          for (final item in before.notifications)
            {...item, 'isRead': true, 'read': true},
        ],
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .markAllNotificationsRead(metadata: ExV2CommandMetadata.create());
    } catch (_) {
      if (_isMutationScopeCurrent(scope)) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> updateSettings(JsonMap patch) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    final scope = _captureMutationScope(before);
    state = AsyncData(
      before.copyWith(settings: {...before.settings, ...patch}),
    );
    try {
      final confirmed = await ref.read(exV2RepositoryProvider).updateSettings({
        ...before.settings,
        ...patch,
      }, metadata: ExV2CommandMetadata.create());
      if (!_isMutationScopeCurrent(scope)) return;
      final current = state.value ?? before;
      state = AsyncData(current.copyWith(settings: confirmed));
    } catch (_) {
      if (_isMutationScopeCurrent(scope)) state = AsyncData(before);
      rethrow;
    }
  }

  List<T> _mapRows<T>(List<JsonMap> rows, T Function(JsonMap) mapper) {
    final result = <T>[];
    for (final row in rows) {
      try {
        result.add(mapper(row));
      } catch (_) {
        // Legacy rows with integrity warnings are omitted, never replaced by
        // synthetic financial values.
      }
    }
    return result;
  }

  Future<void> refresh({
    bool allowDuringGroupedClose = false,
    bool queueAfterInFlight = false,
  }) {
    if (!ref.read(exV2EnabledProvider)) return Future<void>.value();
    if (!allowDuringGroupedClose && _groupedClosePositionIds.isNotEmpty) {
      _deferredRefreshRequested = true;
      return Future<void>.value();
    }
    final existing = _refreshInFlight;
    if (existing != null) {
      if (allowDuringGroupedClose || queueAfterInFlight) {
        _refreshAfterInFlightQueued = true;
        _queuedRefreshAllowsAccountSwitch |= allowDuringGroupedClose;
      }
      return existing;
    }
    late final Future<void> operation;
    operation =
        _performRefresh(
          authoritativeAccountSwitch: allowDuringGroupedClose,
        ).whenComplete(() {
          if (!identical(_refreshInFlight, operation)) return;
          _refreshInFlight = null;
          if (_refreshAfterInFlightQueued && ref.mounted) {
            final allowsAccountSwitch = _queuedRefreshAllowsAccountSwitch;
            _refreshAfterInFlightQueued = false;
            _queuedRefreshAllowsAccountSwitch = false;
            unawaited(refresh(allowDuringGroupedClose: allowsAccountSwitch));
          }
        });
    _refreshInFlight = operation;
    return operation;
  }

  Future<void> _performRefresh({
    required bool authoritativeAccountSwitch,
  }) async {
    final generation = ++_loadGeneration;
    if (state.value == null) {
      state = const AsyncLoading<ExV2AccountViewState?>();
    }
    try {
      final core = await _loadCore(
        applyOptimisticHides: !authoritativeAccountSwitch,
      );
      if (!ref.mounted) return;
      if (generation != _loadGeneration) {
        if (authoritativeAccountSwitch) {
          _refreshAfterInFlightQueued = true;
          _queuedRefreshAllowsAccountSwitch = true;
        }
        return;
      }
      final current = state.value;
      if (current != null) {
        final sameIdentity =
            core.bootstrap.account.id == current.bootstrap.account.id &&
            core.bootstrap.summary.accountId ==
                current.bootstrap.summary.accountId;
        if (!sameIdentity) {
          if (!authoritativeAccountSwitch) return;
          _accountGeneration += 1;
          _publishedActivationAuthority = 0;
          _refreshDebounce?.cancel();
          _deferredRefreshRequested = false;
          _optimisticHiddenPositionIds.clear();
          _groupedClosePositionIds.clear();
          _optimisticHiddenOrderIds.clear();
          _pendingCloseCommandMetadata.clear();
          _clearCloseSyncDeduplication();
          _walletRequestOverlays.clear();
          state = AsyncData(core);
          await _hydrateAndPublish(core, generation);
          return;
        }
        if (core.bootstrap.version < current.bootstrap.version) return;
      }
      final overlaid = _applyOptimisticOverlay(core, current);
      final staged = current == null
          ? overlaid
          : _mergeCoreWithHydrated(overlaid, current);
      state = AsyncData(staged);
      await _hydrateAndPublish(staged, generation);
    } catch (error, stackTrace) {
      if (ref.mounted &&
          generation == _loadGeneration &&
          (!authoritativeAccountSwitch || state.value == null)) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  ExV2BootstrapPublication publishBootstrap(
    ExV2Bootstrap bootstrap, {
    int operationAuthority = 0,
    bool authoritativeAccountSwitch = false,
    ExV2AccountPresentation? presentation,
  }) {
    final current = state.value;
    if (current != null) {
      final currentVersion = current.bootstrap.version;
      final sameIdentity =
          bootstrap.account.id == current.bootstrap.account.id &&
          bootstrap.summary.accountId == current.bootstrap.summary.accountId;
      if (!sameIdentity && authoritativeAccountSwitch) {
        if (operationAuthority > 0 &&
            operationAuthority <= _publishedActivationAuthority) {
          return ExV2BootstrapPublication.rejectedStale;
        }
      } else {
        if (bootstrap.version < currentVersion) {
          return ExV2BootstrapPublication.rejectedStale;
        }
        if (bootstrap.version == currentVersion) {
          if (!sameIdentity ||
              operationAuthority < _publishedActivationAuthority) {
            return ExV2BootstrapPublication.rejectedStale;
          }
          _publishedActivationAuthority = operationAuthority;
          if (presentation != null) {
            state = AsyncData(current.copyWith(presentation: presentation));
          }
          return ExV2BootstrapPublication.idempotentReplay;
        }
      }
    }
    _accountGeneration += 1;
    _publishedActivationAuthority = operationAuthority;
    final generation = ++_loadGeneration;
    _refreshDebounce?.cancel();
    _deferredRefreshRequested = false;
    _optimisticHiddenPositionIds.clear();
    _groupedClosePositionIds.clear();
    _optimisticHiddenOrderIds.clear();
    _pendingCloseCommandMetadata.clear();
    _clearCloseSyncDeduplication();
    _walletRequestOverlays.clear();
    _automaticStopOutAccountId = null;
    final replacement = ExV2AccountViewState.fromBootstrap(
      bootstrap,
      presentation: presentation,
    );
    state = AsyncData(replacement);
    unawaited(_hydrateAndPublish(replacement, generation));
    return ExV2BootstrapPublication.committed;
  }

  void _scheduleOrderReconciliation() {
    if (_orderReconciliationInFlight != null) {
      _orderReconciliationQueued = true;
      return;
    }
    late final Future<void> operation;
    operation = _refreshAfterMutation().whenComplete(() {
      if (!identical(_orderReconciliationInFlight, operation)) return;
      _orderReconciliationInFlight = null;
      if (!_orderReconciliationQueued || !ref.mounted) return;
      _orderReconciliationQueued = false;
      _scheduleOrderReconciliation();
    });
    _orderReconciliationInFlight = operation;
  }

  Future<void> _refreshAfterMutation() async {
    if (!ref.read(exV2EnabledProvider)) return;
    final generation = ++_loadGeneration;
    try {
      final core = await _loadCore();
      if (!ref.mounted || generation != _loadGeneration) return;
      final current = state.value;
      if (current != null &&
          core.bootstrap.version < current.bootstrap.version) {
        return;
      }
      final overlaid = _applyOptimisticOverlay(core, current);
      final staged = current == null
          ? overlaid
          : _mergeCoreWithHydrated(overlaid, current);
      state = AsyncData(staged);
      await _hydrateAndPublish(staged, generation);
    } catch (_) {
      // The mutation is already committed. Keep the last confirmed state and
      // let the next realtime invalidation or manual refresh reconcile it.
    }
  }

  void updateMarketPrice({
    required String symbol,
    required double bid,
    required double ask,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.withMarketPrice(symbol: symbol, bid: bid, ask: ask);
    state = AsyncData(_applyAutomaticStopOutDisplay(updated));
    _maybeTriggerAutomaticStopOut(updated);
  }
}
