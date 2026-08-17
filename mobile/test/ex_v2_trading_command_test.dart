import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  test('create order waits for server and refreshes the position', () async {
    final adapter = _TradingAdapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final order = await container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);

    expect(order.id, 'server-order-1');
    expect(adapter.orderPosts, 1);
    for (
      var attempt = 0;
      attempt < 20 &&
          (container.read(exV2AccountProvider).value?.positions.isEmpty ??
              true);
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      container.read(exV2AccountProvider).value?.positions.single.id,
      'server-position-1',
    );
  });

  test('create order exposes a sending row before HTTP completes', () async {
    final adapter = _TradingAdapter()..orderGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final creating = container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);
    await Future<void>.delayed(Duration.zero);

    final optimistic = container.read(exV2AccountProvider).value!;
    expect(optimistic.orders.single.status, 'sending');
    expect(optimistic.pendingOperationIds, hasLength(1));
    await container.read(exV2AccountProvider.notifier).refresh();
    expect(
      container
          .read(exV2AccountProvider)
          .value
          ?.orders
          .where((order) => order.status == 'sending'),
      hasLength(1),
    );

    adapter.orderGate!.complete();
    await creating;
  });

  test(
    'rapid market commands remain independent while server is slow',
    () async {
      final adapter = _TradingAdapter()..orderGate = Completer<void>();
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final commands = List.generate(
        3,
        (_) => container
            .read(exV2AccountProvider.notifier)
            .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
      );
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(exV2AccountProvider).value!;
      expect(optimistic.orders, hasLength(3));
      expect(optimistic.orders.map((order) => order.id).toSet(), hasLength(3));
      expect(optimistic.pendingOperationIds, hasLength(3));
      for (var attempt = 0; attempt < 20 && adapter.orderPosts < 3; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(adapter.orderPosts, 3);
      expect(adapter.clientOrderIds.toSet(), hasLength(3));

      adapter.orderGate!.complete();
      await Future.wait(commands);
    },
  );

  test('failed optimistic create removes its sending row', () async {
    final adapter = _TradingAdapter(rejectOrder: true);
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
      throwsA(isA<ExV2RequestFailure>()),
    );

    final rolledBack = container.read(exV2AccountProvider).value!;
    expect(rolledBack.orders, isEmpty);
    expect(rolledBack.pendingOperationIds, isEmpty);
  });

  test('accepted order survives a failed follow-up bootstrap', () async {
    final adapter = _TradingAdapter(failBootstrapAfterAcceptedOrder: true);
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final accepted = await container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final current = container.read(exV2AccountProvider).value!;
    expect(accepted.id, 'server-order-1');
    expect(adapter.orderPosts, 1);
    expect(current.orders.single.id, 'server-order-1');
    expect(current.orders.single.status, 'filled');
    expect(current.pendingOperationIds, isEmpty);
  });

  test(
    'create order exposes server rejection and keeps state unchanged',
    () async {
      final adapter = _TradingAdapter(rejectOrder: true);
      final container = _container(adapter);
      addTearDown(container.dispose);
      final before = await container.read(exV2AccountProvider.future);

      await expectLater(
        container
            .read(exV2AccountProvider.notifier)
            .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
        throwsA(
          isA<ExV2RequestFailure>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.message, 'message', 'Order rejected'),
        ),
      );

      expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
      expect(
        container.read(exV2AccountProvider).value?.balance,
        before?.balance,
      );
    },
  );

  test('close position waits for server and refreshes it away', () async {
    final adapter = _TradingAdapter()..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    final before = await container.read(exV2AccountProvider.future);
    expect(before?.positions.single.id, 'server-position-1');
    adapter.onClosedHistoryRead = () {
      unawaited(container.read(exV2AccountProvider.notifier).refresh());
    };

    final closeDeal = await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    expect(adapter.closePosts, 1);
    expect(closeDeal?.positionId, 'server-position-1');
    expect(closeDeal?.price, 4365.28);
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
  });

  test('committed close publishes matching deals and closed history', () async {
    final refreshGate = Completer<void>();
    final adapter = _TradingAdapter()
      ..created = true
      ..postCloseRefreshGate = refreshGate;
    final container = _container(adapter);
    addTearDown(() {
      if (!refreshGate.isCompleted) refreshGate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    final state = container.read(exV2AccountProvider).value!;
    expect(state.positions, isEmpty);
    expect(state.deals.map((deal) => deal.id), [
      'close-deal-1',
      'close-deal-2',
    ]);
    expect(state.historyPositions.single.id.toLowerCase(), 'server-position-1');
    expect(
      state.historyPositions.single.closePrice,
      closeTo(4365.58, 0.000001),
    );
  });

  test(
    'close awaits matching balance history and summary without resending POST',
    () async {
      final adapter = _TradingAdapter(delayedClosedHistory: true)
        ..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(state.positions, isEmpty);
      expect(state.balance, closeTo(5306.525, 0.000001));
      expect(state.deals.map((deal) => deal.id), [
        'close-deal-1',
        'close-deal-2',
      ]);
      expect(state.historyPositions.single.closePrice, isNotNull);
      expect(state.historySummary.realizedProfit, closeTo(306.525, 0.000001));
      expect(state.historySummary.netChange, closeTo(306.525, 0.000001));
    },
  );

  test('close removes the position before the server responds', () async {
    final adapter = _TradingAdapter()..created = true;
    adapter.closeGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closing = container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      contains('position:server-position-1'),
    );
    await container.read(exV2AccountProvider.notifier).refresh();
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);

    adapter.closeGate!.complete();
    await closing;
  });

  test('partial close reduces volume instead of hiding the position', () async {
    final adapter = _TradingAdapter()..created = true;
    adapter.closeGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closing = container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1', volume: 0.004);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exV2AccountProvider).value?.positions.single.volume,
      closeTo(0.006, 0.000001),
    );
    adapter.closeGate!.complete();
    await closing;
    expect(adapter.lastCloseData?['volume'], 0.004);
    expect(
      container.read(exV2AccountProvider).value?.positions.single.volume,
      closeTo(0.006, 0.000001),
    );
  });

  test(
    'close by immediately preserves the larger position remainder',
    () async {
      final adapter = _TradingAdapter()
        ..created = true
        ..oppositeCreated = true
        ..closeByGate = Completer<void>();
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closeBy('server-position-1', 'server-position-2');
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(exV2AccountProvider).value!.positions;
      expect(optimistic, hasLength(1));
      expect(optimistic.single.id, 'server-position-1');
      expect(optimistic.single.volume, closeTo(.006, .000001));

      adapter.closeByGate!.complete();
      await closing;
      final committed = container.read(exV2AccountProvider).value!.positions;
      expect(committed, hasLength(1));
      expect(committed.single.id, 'server-position-1');
      expect(committed.single.volume, closeTo(.006, .000001));
      expect(adapter.closeByPosts, 1);
    },
  );

  test('failed optimistic close restores the position', () async {
    final adapter = _TradingAdapter(rejectClose: true)..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1'),
      throwsA(isA<ExV2RequestFailure>()),
    );

    expect(
      container.read(exV2AccountProvider).value?.positions.single.id,
      'server-position-1',
    );
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      isEmpty,
    );
  });

  test(
    'committed close stays removed while closing deal is still syncing',
    () async {
      final adapter = _TradingAdapter(omitClosedDeal: true)..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final closeDeal = await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      expect(closeDeal, isNull);
      expect(adapter.closePosts, 1);
      expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
      expect(
        container.read(exV2AccountProvider).value?.pendingOperationIds,
        isEmpty,
      );
    },
  );

  test('position not found removes a stale local position', () async {
    final adapter = _TradingAdapter(stalePositionOnClose: true)..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closeDeal = await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    expect(closeDeal, isNull);
    expect(adapter.closePosts, 1);
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      isEmpty,
    );
  });

  test('limit and stop UI orders use the server pending contract', () async {
    final adapter = _TradingAdapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .createOrder(
          symbol: 'XAUUSD+',
          side: 'buy',
          volume: 0.01,
          type: 'limit',
          requestedPrice: 1000,
        );

    expect(adapter.lastOrderData?['type'], 'pending');
    expect(adapter.lastOrderData?['requestedPrice'], 1000);
  });

  test('cancel removes a pending order before HTTP completes', () async {
    final adapter = _TradingAdapter()..pending = true;
    adapter.cancelGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final canceling = container
        .read(exV2AccountProvider.notifier)
        .cancelOrder('pending-order-1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exV2AccountProvider).value?.pendingOrders, isEmpty);
    adapter.cancelGate!.complete();
    await canceling;
  });

  test('failed optimistic cancel restores the pending order', () async {
    final adapter = _TradingAdapter(rejectCancel: true)..pending = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .cancelOrder('pending-order-1'),
      throwsA(isA<ExV2RequestFailure>()),
    );

    expect(
      container.read(exV2AccountProvider).value?.pendingOrders.single.id,
      'pending-order-1',
    );
  });
}

ProviderContainer _container(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      exV2EnabledProvider.overrideWithValue(true),
      exV2DioProvider.overrideWithValue(dio),
      deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
    ],
  );
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? token = 'test-token';

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

final class _TradingAdapter implements HttpClientAdapter {
  _TradingAdapter({
    this.rejectOrder = false,
    this.rejectClose = false,
    this.rejectCancel = false,
    this.omitClosedDeal = false,
    this.stalePositionOnClose = false,
    this.failBootstrapAfterAcceptedOrder = false,
    this.delayedClosedHistory = false,
  });

  final bool rejectOrder;
  final bool rejectClose;
  final bool rejectCancel;
  final bool omitClosedDeal;
  final bool stalePositionOnClose;
  final bool failBootstrapAfterAcceptedOrder;
  final bool delayedClosedHistory;
  int orderPosts = 0;
  int closePosts = 0;
  int closeByPosts = 0;
  int bootstrapVersion = 0;
  bool created = false;
  bool oppositeCreated = false;
  bool pending = false;
  bool closeCommitted = false;
  int closedHistoryDealReads = 0;
  int closedHistoryPositionReads = 0;
  int postCloseBootstrapReads = 0;
  Map<String, dynamic>? lastOrderData;
  final List<String> clientOrderIds = <String>[];
  Map<String, dynamic>? lastCloseData;
  double remainingVolume = 0.01;
  void Function()? onClosedHistoryRead;
  bool _concurrentRefreshTriggered = false;
  Completer<void>? closeGate;
  Completer<void>? closeByGate;
  Completer<void>? orderGate;
  Completer<void>? cancelGate;
  Completer<void>? postCloseRefreshGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/orders') && options.method == 'POST') {
      orderPosts++;
      lastOrderData = (options.data as Map).cast<String, dynamic>();
      clientOrderIds.add(lastOrderData!['clientOrderId'] as String);
      if (rejectOrder) {
        return _json({
          'code': 'ORDER_REJECTED',
          'message': 'Order rejected',
        }, statusCode: 422);
      }
      await orderGate?.future;
      created = true;
      return _json(_order);
    }
    if (path.endsWith('/positions/server-position-1/close') &&
        options.method == 'POST') {
      closePosts++;
      lastCloseData = (options.data as Map).cast<String, dynamic>();
      if (stalePositionOnClose) {
        created = false;
        return _json({
          'code': 'POSITION_NOT_FOUND',
          'message': 'Position not found',
        }, statusCode: 422);
      }
      if (rejectClose) {
        return _json({
          'code': 'CLOSE_REJECTED',
          'message': 'Close rejected',
        }, statusCode: 422);
      }
      await closeGate?.future;
      final requestedVolume = (lastCloseData?['volume'] as num?)?.toDouble();
      if (requestedVolume != null && requestedVolume < remainingVolume) {
        remainingVolume -= requestedVolume;
      } else {
        remainingVolume = 0;
        created = false;
      }
      closeCommitted = remainingVolume == 0;
      closedHistoryDealReads = 0;
      closedHistoryPositionReads = 0;
      postCloseBootstrapReads = 0;
      return _json({
        ..._bootstrapPosition,
        'remainingVolume': remainingVolume,
        'realizedProfit': 306.525,
        'status': 'closed',
        'closedAt': '2026-08-13T16:31:10Z',
      });
    }
    if (path.endsWith('/positions/server-position-1/close-by') &&
        options.method == 'POST') {
      closeByPosts++;
      await closeByGate?.future;
      remainingVolume -= 0.004;
      oppositeCreated = false;
      return _json(<String, Object?>{});
    }
    if (path.endsWith('/orders/pending-order-1') &&
        options.method == 'DELETE') {
      if (rejectCancel) {
        return _json({
          'code': 'CANCEL_REJECTED',
          'message': 'Cancel rejected',
        }, statusCode: 422);
      }
      await cancelGate?.future;
      pending = false;
      return _json(<String, Object?>{});
    }
    if (path.endsWith('/mobile/bootstrap')) {
      if (failBootstrapAfterAcceptedOrder && created) {
        return _json({
          'code': 'BOOTSTRAP_UNAVAILABLE',
          'message': 'Bootstrap unavailable',
        }, statusCode: 503);
      }
      if (closeCommitted && postCloseRefreshGate != null) {
        postCloseBootstrapReads++;
        if (postCloseBootstrapReads > 1) {
          await postCloseRefreshGate!.future;
        }
      }
      return _json(
        _bootstrap(
          version: ++bootstrapVersion,
          withPosition: created,
          withPending: pending,
          remainingVolume: remainingVolume,
          withOppositePosition: oppositeCreated,
        ),
      );
    }
    if (path.endsWith('/history/summary')) {
      return _json({
        'deposit': 0,
        'withdrawal': 0,
        'realizedProfit': closeCommitted ? 306.525 : 0,
        'swap': 0,
        'commission': 0,
        'netChange': closeCommitted ? 306.525 : 0,
      });
    }
    if (path.endsWith('/settings')) return _json(<String, Object?>{});
    if (path.endsWith('/history/deals')) {
      if (closeCommitted) closedHistoryDealReads++;
      if (closeCommitted && !_concurrentRefreshTriggered) {
        _concurrentRefreshTriggered = true;
        scheduleMicrotask(() => onClosedHistoryRead?.call());
      }
      if (closeCommitted &&
          delayedClosedHistory &&
          closedHistoryDealReads == 1) {
        return _json({
          'page': 1,
          'pageSize': 50,
          'total': 0,
          'items': <Object?>[],
        });
      }
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': !closeCommitted || omitClosedDeal ? 0 : 2,
        'items': !closeCommitted || omitClosedDeal
            ? <Object?>[]
            : [
                {
                  'id': 'close-deal-1',
                  'positionId': 'server-position-1',
                  'orderId': 'server-order-1',
                  'dealType': 'close',
                  'symbol': 'XAUUSD+',
                  'side': 'sell',
                  'volume': 0.004,
                  'price': 4365.28,
                  'profit': 120,
                  'createdAtUtc': '2026-08-13T16:30:10Z',
                },
                {
                  'id': 'close-deal-2',
                  'positionId': 'server-position-1',
                  'orderId': 'server-order-1',
                  'dealType': 'out_by',
                  'symbol': 'XAUUSD+',
                  'side': 'sell',
                  'volume': 0.006,
                  'price': 4365.78,
                  'profit': 186.525,
                  'createdAtUtc': '2026-08-13T16:31:10Z',
                },
              ],
      });
    }
    if (path.endsWith('/history/positions')) {
      if (closeCommitted) closedHistoryPositionReads++;
      final delayed =
          closeCommitted &&
          delayedClosedHistory &&
          closedHistoryPositionReads == 1;
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': closeCommitted && !delayed ? 1 : 0,
        'items': closeCommitted && !delayed
            ? [
                {
                  'positionId': 'SERVER-POSITION-1',
                  'symbol': 'XAUUSD+',
                  'side': 'buy',
                  'initialVolume': 0.01,
                  'remainingVolume': 0,
                  'entryPrice': 4373.72,
                  'realizedProfit': 306.525,
                  'status': 'closed',
                  'createdAtUtc': '2026-08-13T14:00:00Z',
                  'closedAtUtc': '2026-08-13T16:31:10Z',
                },
              ]
            : <Object?>[],
      });
    }
    return _json(<Object?>[]);
  }

  ResponseBody _json(Object body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

final _order = <String, Object?>{
  'id': 'server-order-1',
  'clientOrderId': 'client-order-1',
  'symbol': 'XAUUSD+',
  'type': 'market',
  'side': 'buy',
  'volume': 0.01,
  'requestedPrice': null,
  'executedPrice': 4373.72,
  'stopLoss': null,
  'takeProfit': null,
  'status': 'filled',
  'createdAt': '2026-08-13T14:00:00Z',
  'version': 2,
  'rowVersion': 'order-rv',
};

Map<String, Object?> _bootstrap({
  required int version,
  required bool withPosition,
  bool withPending = false,
  double remainingVolume = 0.01,
  bool withOppositePosition = false,
}) => {
  'serverTime': '2026-08-13T14:00:00Z',
  'version': version,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': 'TEST-100',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': withPosition ? 5000 : 5306.525,
    'equity': withPosition ? 5000 : 5306.525,
    'profit': 0,
    'margin': 0,
    'freeMargin': withPosition ? 5000 : 5306.525,
    'marginLevel': 0,
    'updatedAt': '2026-08-13T14:00:00Z',
  },
  'positions': withPosition
      ? [
          <String, Object?>{
            ..._bootstrapPosition,
            'remainingVolume': remainingVolume,
          },
          if (withOppositePosition) _oppositeBootstrapPosition,
        ]
      : <Object?>[],
  'pendingOrders': withPending ? [_pendingOrder] : <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 1000,
    'lockedBalance': 0,
    'totalBalance': 1000,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};

final _bootstrapPosition = <String, Object?>{
  'id': 'server-position-1',
  'symbol': 'XAUUSD+',
  'side': 'BUY',
  'initialVolume': 0.01,
  'remainingVolume': 0.01,
  'entryPrice': 4373.72,
  'realizedProfit': 0,
  'status': 'open',
  'createdAt': '2026-08-13T14:00:00Z',
};

final _oppositeBootstrapPosition = <String, Object?>{
  'id': 'server-position-2',
  'symbol': 'XAUUSD+',
  'side': 'SELL',
  'initialVolume': 0.004,
  'remainingVolume': 0.004,
  'entryPrice': 4374.1,
  'realizedProfit': 0,
  'status': 'open',
  'createdAt': '2026-08-13T14:00:10Z',
};

final _pendingOrder = <String, Object?>{
  'id': 'pending-order-1',
  'clientOrderId': 'pending-client-1',
  'symbol': 'XAUUSD+',
  'type': 'pending',
  'side': 'buy',
  'volume': 0.01,
  'requestedPrice': 4300.0,
  'executedPrice': null,
  'stopLoss': null,
  'takeProfit': null,
  'status': 'pending',
  'createdAt': '2026-08-13T14:00:00Z',
  'version': 1,
  'rowVersion': 'pending-rv',
};
