import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_realtime_service.dart';
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

final exV2EnabledProvider = Provider<bool>((ref) => false);
final exV2RealtimeEnabledProvider = Provider<bool>((ref) => false);

final exV2ConfigProvider = Provider<ExV2Config>((ref) => ExV2Config.production);

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
    );

final class ExV2AccountController extends AsyncNotifier<ExV2AccountViewState?> {
  StreamSubscription<ExV2RealtimeEvent>? _realtimeSubscription;
  ExV2RealtimeService? _realtimeService;
  Timer? _refreshDebounce;
  bool _realtimeStarted = false;
  int _loadGeneration = 0;
  final Set<String> _optimisticHiddenPositionIds = <String>{};
  final Set<String> _optimisticHiddenOrderIds = <String>{};

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
    final result = await _loadCore();
    unawaited(_hydrateAndPublish(result, generation));
    unawaited(_startRealtime());
    return result;
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

  void _onRealtimeEvent(ExV2RealtimeEvent event) {
    final current = state.value;
    if (event.name != 'ActiveAccountChanged' &&
        current != null &&
        event.version != null &&
        event.version! <= current.bootstrap.version) {
      return;
    }
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(refresh());
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
    final results = await Future.wait<Object>([
      _readOr(repository.historyOrders(), const <JsonMap>[]),
      _readOr(repository.historyDeals(), const <JsonMap>[]),
      _readOr(repository.historyPositions(), const <JsonMap>[]),
      _readOr(repository.historyTransactions(), const <JsonMap>[]),
      _readOr(repository.deposits(), const <JsonMap>[]),
      _readOr(repository.withdrawals(), const <JsonMap>[]),
      _readOr(repository.transfers(), const <JsonMap>[]),
      _readOr(repository.notifications(), const <JsonMap>[]),
      _readOr(repository.settings(), const <String, dynamic>{}),
      _readOr(repository.historySummary(), const ExV2HistorySummary.empty()),
    ]);
    final orderRows = results[0] as List<JsonMap>;
    final dealRows = results[1] as List<JsonMap>;
    final historyRows = results[2] as List<JsonMap>;
    return base.copyWith(
      orders: _mapRows(orderRows, ExV2DemoMapper.historyOrder),
      deals: _mapRows(dealRows, ExV2DemoMapper.historyDeal),
      historyPositions: _mapRows(
        historyRows
            .where((row) => row['status']?.toString().toLowerCase() == 'closed')
            .toList(growable: false),
        (row) {
          final closePrice = _historyClosePrice(row, dealRows);
          final enriched = <String, dynamic>{...row};
          if (closePrice != null) enriched['closePrice'] = closePrice;
          return ExV2DemoMapper.historyPosition(enriched);
        },
      ),
      historyTransactions: results[3] as List<JsonMap>,
      deposits: results[4] as List<JsonMap>,
      withdrawals: results[5] as List<JsonMap>,
      transfers: results[6] as List<JsonMap>,
      notifications: results[7] as List<JsonMap>,
      settings: results[8] as JsonMap,
      historySummary: results[9] as ExV2HistorySummary,
    );
  }

  Future<void> _hydrateAndPublish(
    ExV2AccountViewState base,
    int generation,
  ) async {
    final hydrated = await _hydrate(base);
    if (!ref.mounted || generation != _loadGeneration) return;
    state = AsyncData(_applyOptimisticOverlay(hydrated, state.value));
  }

  ExV2AccountViewState _applyOptimisticOverlay(
    ExV2AccountViewState incoming,
    ExV2AccountViewState? current,
  ) {
    if (current == null || current.pendingOperationIds.isEmpty) return incoming;
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
    return incoming.copyWith(
      positions: [
        for (final position in incoming.positions)
          if (protectionIds.contains(position.id))
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
      deposits: current.deposits,
      withdrawals: current.withdrawals,
      transfers: current.transfers,
      notifications: current.notifications,
      settings: current.settings,
      pendingOperationIds: current.pendingOperationIds,
    );
  }

  Future<T> _readOr<T>(Future<T> operation, T fallback) async {
    try {
      return await operation;
    } catch (_) {
      return fallback;
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
    } catch (_) {
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
    unawaited(_refreshAfterMutation());
    return order;
  }

  ExV2AccountViewState _mergeCoreWithHydrated(
    ExV2AccountViewState core,
    ExV2AccountViewState hydrated, {
    List<DemoOrder>? orders,
    List<DemoDeal>? deals,
    Set<String>? pendingOperationIds,
  }) => core.copyWith(
    orders: orders ?? hydrated.orders,
    deals: deals ?? hydrated.deals,
    historyPositions: hydrated.historyPositions,
    historyTransactions: hydrated.historyTransactions,
    deposits: hydrated.deposits,
    withdrawals: hydrated.withdrawals,
    transfers: hydrated.transfers,
    notifications: hydrated.notifications,
    settings: hydrated.settings,
    pendingOperationIds: pendingOperationIds ?? hydrated.pendingOperationIds,
  );

  Future<DemoDeal?> closePosition(String positionId, {double? volume}) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
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
    final closeVolume = volume ?? originalPosition.volume;
    final isPartial = closeVolume > 0 && closeVolume < originalPosition.volume;
    if (!isPartial) _optimisticHiddenPositionIds.add(positionId);
    state = AsyncData(
      before.copyWith(
        positions: [
          for (final position in before.positions)
            if (position.id != positionId)
              position
            else if (isPartial)
              position.copyWith(volume: position.volume - closeVolume),
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );

    var commandCommitted = false;
    try {
      try {
        await ref
            .read(exV2RepositoryProvider)
            .closePosition(
              positionId: positionId,
              volume: volume,
              metadata: ExV2CommandMetadata.create(),
            );
        commandCommitted = true;
      } on ExV2RequestFailure {
        if (await _reconcileMissingPosition(
          positionId: positionId,
          operationId: operationId,
          fallback: before,
        )) {
          return null;
        }
        rethrow;
      }

      return await _reconcileCommittedClose(
        positionId: positionId,
        operationId: operationId,
        fallback: before,
        isPartial: isPartial,
      );
    } catch (_) {
      if (commandCommitted) {
        _finishCommittedCloseWithoutDeal(operationId, before);
        return null;
      }
      _optimisticHiddenPositionIds.remove(positionId);
      final current = state.value ?? before;
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
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<bool> _reconcileMissingPosition({
    required String positionId,
    required String operationId,
    required ExV2AccountViewState fallback,
  }) async {
    try {
      final core = await _loadCore(applyOptimisticHides: false);
      if (core.positions.any((position) => position.id == positionId)) {
        return false;
      }
      _optimisticHiddenPositionIds.remove(positionId);
      final current = state.value ?? fallback;
      final reconciled = _mergeCoreWithHydrated(
        core,
        current,
        pendingOperationIds: {
          ...current.pendingOperationIds.where((id) => id != operationId),
        },
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
  }) async {
    final repository = ref.read(exV2RepositoryProvider);
    final serverCore = await _loadCore(applyOptimisticHides: false);
    final serverStillHasPosition = serverCore.positions.any(
      (position) => position.id == positionId,
    );
    if (!serverStillHasPosition || isPartial) {
      _optimisticHiddenPositionIds.remove(positionId);
    }
    final visibleCore = serverStillHasPosition && !isPartial
        ? serverCore.copyWith(
            positions: serverCore.positions
                .where((position) => position.id != positionId)
                .toList(growable: false),
          )
        : serverCore;
    var deals = serverCore.deals;
    try {
      final dealRows = await repository.historyDeals();
      deals = _mapRows(dealRows, ExV2DemoMapper.historyDeal);
    } catch (_) {
      // The command is already committed. History enrichment is best effort.
    }
    final closeDeal = deals
        .where((deal) => deal.positionId == positionId && deal.entry == 'out')
        .firstOrNull;
    final current = state.value ?? fallback;
    final confirmed = _mergeCoreWithHydrated(
      visibleCore,
      current,
      deals: deals.isEmpty ? current.deals : deals,
      pendingOperationIds: {
        ...current.pendingOperationIds.where((id) => id != operationId),
      },
    );
    if (ref.mounted) state = AsyncData(confirmed);
    unawaited(refresh());
    return closeDeal;
  }

  void _finishCommittedCloseWithoutDeal(
    String operationId,
    ExV2AccountViewState fallback,
  ) {
    final current = state.value ?? fallback;
    if (ref.mounted) {
      state = AsyncData(
        current.copyWith(
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
      final core = await _loadCore();
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
      final core = await _loadCore();
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
      final core = await _loadCore();
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
                position.copyWith(volume: position.volume - matchedVolume)
              else
                position,
        ],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      await ref
          .read(exV2RepositoryProvider)
          .closeBy(
            positionId: positionId,
            oppositePositionId: oppositePositionId,
            metadata: ExV2CommandMetadata.create(),
          );
      final core = await _loadCore(applyOptimisticHides: false);
      _optimisticHiddenPositionIds.removeAll(fullyClosedIds);
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
      _optimisticHiddenPositionIds.removeAll(fullyClosedIds);
      final current = state.value ?? before;
      state = AsyncData(
        current.copyWith(
          positions: before.positions,
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> createWalletRequest({
    required bool isDeposit,
    required double amount,
    required String note,
  }) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
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
    state = AsyncData(
      before.copyWith(
        deposits: isDeposit
            ? [placeholder, ...before.deposits]
            : before.deposits,
        withdrawals: isDeposit
            ? before.withdrawals
            : [placeholder, ...before.withdrawals],
        pendingOperationIds: {...before.pendingOperationIds, operationId},
      ),
    );
    try {
      final repository = ref.read(exV2RepositoryProvider);
      final confirmed = isDeposit
          ? await repository.createDeposit(
              amount: amount,
              currency: before.wallet.currency,
              method: 'demo',
              reference: note,
              metadata: metadata,
            )
          : await repository.createWithdrawal(
              amount: amount,
              currency: before.wallet.currency,
              bankName: '',
              bankAccount: '',
              accountHolder: note,
              metadata: metadata,
            );
      final current = state.value ?? before;
      final row = <String, dynamic>{
        ...confirmed,
        'type': isDeposit ? 'deposit' : 'withdrawal',
      };
      state = AsyncData(
        current.copyWith(
          deposits: isDeposit
              ? [
                  row,
                  ...current.deposits.where(
                    (item) => item['id'] != metadata.idempotencyKey,
                  ),
                ]
              : current.deposits,
          withdrawals: isDeposit
              ? current.withdrawals
              : [
                  row,
                  ...current.withdrawals.where(
                    (item) => item['id'] != metadata.idempotencyKey,
                  ),
                ],
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      unawaited(refresh());
    } catch (_) {
      final current = state.value ?? before;
      JsonMap failed(JsonMap item) => item['id'] == metadata.idempotencyKey
          ? {...item, 'status': 'failed'}
          : item;
      state = AsyncData(
        current.copyWith(
          deposits: current.deposits.map(failed).toList(growable: false),
          withdrawals: current.withdrawals.map(failed).toList(growable: false),
          pendingOperationIds: {
            ...current.pendingOperationIds.where((id) => id != operationId),
          },
        ),
      );
      rethrow;
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
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
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> markAllNotificationsRead() async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
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
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> updateSettings(JsonMap patch) async {
    final before = state.value;
    if (before == null) throw const ExV2TokenMissing();
    state = AsyncData(
      before.copyWith(settings: {...before.settings, ...patch}),
    );
    try {
      final confirmed = await ref.read(exV2RepositoryProvider).updateSettings({
        ...before.settings,
        ...patch,
      }, metadata: ExV2CommandMetadata.create());
      final current = state.value ?? before;
      state = AsyncData(current.copyWith(settings: confirmed));
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
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

  Future<void> refresh() async {
    if (!ref.read(exV2EnabledProvider)) return;
    final generation = ++_loadGeneration;
    if (state.value == null) {
      state = const AsyncLoading<ExV2AccountViewState?>();
    }
    try {
      final core = await _loadCore();
      if (!ref.mounted || generation != _loadGeneration) return;
      final overlaid = _applyOptimisticOverlay(core, state.value);
      state = AsyncData(overlaid);
      await _hydrateAndPublish(overlaid, generation);
    } catch (error, stackTrace) {
      if (ref.mounted && generation == _loadGeneration) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  void publishBootstrap(ExV2Bootstrap bootstrap) {
    final generation = ++_loadGeneration;
    _refreshDebounce?.cancel();
    _optimisticHiddenPositionIds.clear();
    _optimisticHiddenOrderIds.clear();
    final replacement = ExV2AccountViewState.fromBootstrap(bootstrap);
    state = AsyncData(replacement);
    unawaited(_hydrateAndPublish(replacement, generation));
  }

  Future<void> _refreshAfterMutation() async {
    if (!ref.read(exV2EnabledProvider)) return;
    final generation = ++_loadGeneration;
    try {
      final core = await _loadCore();
      if (!ref.mounted || generation != _loadGeneration) return;
      final overlaid = _applyOptimisticOverlay(core, state.value);
      state = AsyncData(overlaid);
      await _hydrateAndPublish(overlaid, generation);
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
    state = AsyncData(
      current.withMarketPrice(symbol: symbol, bid: bid, ask: ask),
    );
  }
}

double? _historyClosePrice(JsonMap position, List<JsonMap> deals) {
  final directPrice = position['closePrice'];
  if (directPrice is num) return directPrice.toDouble();

  final positionId = position['id'];
  if (positionId is String) {
    final linkedPrices = deals
        .where(
          (deal) =>
              deal['positionId'] == positionId && _isHistoryExitDeal(deal),
        )
        .map((deal) => deal['price'])
        .whereType<num>()
        .map((price) => price.toDouble())
        .toSet();
    if (linkedPrices.length == 1) return linkedPrices.single;
  }

  final closedAt = _historyDate(position, const ['closedAt', 'closedAtUtc']);
  if (closedAt == null) return null;
  final symbol = position['symbol']?.toString().toUpperCase();
  final timestampPrices = deals
      .where(_isHistoryExitDeal)
      .where((deal) {
        final dealSymbol = deal['symbol']?.toString().toUpperCase();
        if (symbol != null && dealSymbol != symbol) return false;
        final createdAt = _historyDate(deal, const [
          'createdAt',
          'createdAtUtc',
          'time',
        ]);
        return createdAt == closedAt;
      })
      .map((deal) => deal['price'])
      .whereType<num>()
      .map((price) => price.toDouble())
      .toSet();
  return timestampPrices.length == 1 ? timestampPrices.single : null;
}

bool _isHistoryExitDeal(JsonMap deal) {
  final value = (deal['dealType'] ?? deal['type'])?.toString().toLowerCase();
  if (value == null) return false;
  final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return normalized == 'out' ||
      normalized == 'out by' ||
      normalized.contains('close') ||
      normalized.contains('exit');
}

DateTime? _historyDate(JsonMap row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is! String) continue;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return null;
}
