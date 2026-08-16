import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('production loading never exposes offline fixture accounts', () {
    final gate = Completer<ExV2AccountViewState?>();
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild((ref, controller) => gate.future),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(demoAccountsProvider), isEmpty);
    expect(
      () => container.read(activeDemoAccountProvider),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('authorized server account'),
        ),
      ),
    );
  });

  test('production account provider starts from server bootstrap', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter();
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(exV2AccountProvider.future);

    expect(state, isNotNull);
    expect(state!.accountCode, 'TEST-100');
    expect(state.balance, 5000);
    final accounts = container.read(demoAccountsProvider);
    expect(accounts, hasLength(1));
    expect(accounts.single.id, 'TEST-100');
    expect(accounts.single.company, 'Exness Technologies Ltd');
    expect(accounts.single.server, 'Exness-MT5Real20');
    expect(accounts.single.accessPoint, 'Access Point #9');
  });

  test('bootstrap becomes visible before slower history endpoints', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter(
        historyDelay: const Duration(seconds: 1),
      );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container
        .read(exV2AccountProvider.future)
        .timeout(const Duration(milliseconds: 250));

    expect(state?.balance, 5000);
  });

  test('production paged history contracts hydrate all history tabs', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter(productionHistory: true);
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(exV2AccountProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final state = container.read(exV2AccountProvider).value!;

    expect(state.orders.single.id, 'history-order-1');
    expect(state.deals.single.id, 'history-deal-1');
    expect(state.deals.single.entry, 'out');
    expect(state.historyPositions.single.id, 'history-position-1');
    expect(state.historyPositions.single.volume, 0.01);
    expect(state.historyPositions.single.closePrice, 4369.55);
    expect(state.historyPositions.single.profit, -0.77);
    final profile = container.read(demoAccountsProvider).single;
    expect(profile.historyDeposit, 1200);
    expect(profile.historyWithdrawal, -300);
    expect(profile.historyProfit, -12.34);
    expect(profile.historySwap, -1.25);
    expect(profile.historyCommission, -2.5);
  });

  test('wallet request appears before the server responds', () async {
    final gate = Completer<void>();
    final adapter = _BootstrapAdapter(mutationGate: gate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final submitting = container
        .read(exV2AccountProvider.notifier)
        .createWalletRequest(isDeposit: true, amount: 500, note: 'demo');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exV2AccountProvider).value?.deposits.single['status'],
      'sending',
    );
    gate.complete();
    await submitting;
  });

  test('notification becomes read before the server responds', () async {
    final gate = Completer<void>();
    final adapter = _BootstrapAdapter(
      mutationGate: gate,
      includeNotification: true,
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final marking = container
        .read(exV2AccountProvider.notifier)
        .markNotificationRead('notification-1');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exV2AccountProvider).value?.notifications.single['isRead'],
      isTrue,
    );
    gate.complete();
    await marking;
  });

  test(
    'an in-flight mutation cannot publish into a replacement bootstrap',
    () async {
      final orderGate = Completer<void>();
      final adapter = _AccountSwitchAdapter(orderGate);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final controller = container.read(exV2AccountProvider.notifier);

      final creating = controller.createOrder(
        symbol: 'XAUUSD+',
        side: 'buy',
        volume: 0.01,
        commandMetadata: const ExV2CommandMetadata(
          idempotencyKey: 'old-account-order',
          correlationId: 'old-account-correlation',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      controller.publishBootstrap(
        ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
      );
      orderGate.complete();
      await creating;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(exV2AccountProvider).requireValue!;
      expect(state.bootstrap.account.id, 'account-2');
      expect(state.bootstrap.summary.accountId, 'account-2');
      expect(state.orders, isEmpty);
      expect(state.pendingOperationIds, isEmpty);
    },
  );

  test('stale hydration cannot overwrite a replacement bootstrap', () async {
    final historyGate = Completer<void>();
    final adapter = _HydrationSwitchAdapter(historyGate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    while (adapter.historyOrderCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
        );
    historyGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.account.id, 'account-2');
    expect(state.orders, isEmpty);
  });

  test('stale refresh cannot overwrite a replacement bootstrap', () async {
    final refreshGate = Completer<void>();
    final adapter = _RefreshSwitchAdapter(refreshGate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    final controller = container.read(exV2AccountProvider.notifier);

    final refreshing = controller.refresh();
    while (adapter.bootstrapCalls < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.publishBootstrap(
      ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
    );
    refreshGate.complete();
    await refreshing;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.account.id, 'account-2');
    expect(state.bootstrap.summary.accountId, 'account-2');
  });
}

final class _HydrationSwitchAdapter implements HttpClientAdapter {
  _HydrationSwitchAdapter(this.historyGate);

  final Completer<void> historyGate;
  int historyOrderCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/history/orders')) {
      historyOrderCalls += 1;
      if (historyOrderCalls == 1) {
        await historyGate.future;
        return _response([
          {
            'id': 'old-history-order',
            'accountCode': 'TEST-100',
            'symbol': 'XAUUSD+',
            'side': 'buy',
            'volume': 0.01,
            'openPrice': 4300,
            'profit': 1,
            'openedAt': '2026-08-16T08:00:00Z',
            'status': 'closed',
          },
        ]);
      }
      return _response(<Object?>[]);
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _RefreshSwitchAdapter implements HttpClientAdapter {
  _RefreshSwitchAdapter(this.refreshGate);

  final Completer<void> refreshGate;
  int bootstrapCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      bootstrapCalls += 1;
      if (bootstrapCalls > 1) await refreshGate.future;
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

final class _AccountSwitchAdapter implements HttpClientAdapter {
  _AccountSwitchAdapter(this.orderGate);

  final Completer<void> orderGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.uri.path.endsWith('/orders')) {
      await orderGate.future;
      return _jsonResponse({
        'id': 'server-order-old-account',
        'clientOrderId': 'old-account-order',
        'symbol': 'XAUUSD+',
        'type': 'market',
        'side': 'buy',
        'volume': 0.01,
        'requestedPrice': null,
        'executedPrice': 4300,
        'stopLoss': null,
        'takeProfit': null,
        'status': 'filled',
        'createdAt': '2026-08-16T08:00:00Z',
        'version': 1,
        'rowVersion': null,
      });
    }
    if (options.uri.path.endsWith('/mobile/bootstrap')) {
      return _jsonResponse(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (options.uri.path.endsWith('/settings')) {
      return _jsonResponse(<String, Object?>{});
    }
    return _jsonResponse(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _jsonResponse(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _bootstrapForAccount(String id, String code) => {
  ..._bootstrap,
  'activeAccount': {
    ..._bootstrap['activeAccount']! as Map<String, Object?>,
    'id': id,
    'accountCode': code,
  },
  'summary': {
    ..._bootstrap['summary']! as Map<String, Object?>,
    'accountId': id,
  },
};

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore(this.value);
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

final class _BootstrapAdapter implements HttpClientAdapter {
  _BootstrapAdapter({
    this.historyDelay = Duration.zero,
    this.productionHistory = false,
    this.mutationGate,
    this.includeNotification = false,
  });

  final Duration historyDelay;
  final bool productionHistory;
  final Completer<void>? mutationGate;
  final bool includeNotification;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/deposits') && options.method == 'POST') {
      await mutationGate?.future;
      return _jsonResponse({
        'id': 'deposit-1',
        'amount': 500,
        'currency': 'USD',
        'status': 'pending',
        'createdAt': '2026-08-13T08:01:00Z',
      });
    }
    if (path.endsWith('/notifications/notification-1/read') &&
        options.method == 'PUT') {
      await mutationGate?.future;
      return _jsonResponse(<String, Object?>{});
    }
    if (!options.uri.path.endsWith('/mobile/bootstrap')) {
      await Future<void>.delayed(historyDelay);
    }
    final historyPayload = productionHistory
        ? _productionHistoryPayload(options.uri.path)
        : null;
    if (includeNotification && path.endsWith('/notifications')) {
      return _jsonResponse([
        {'id': 'notification-1', 'title': 'Update', 'isRead': false},
      ]);
    }
    return ResponseBody.fromString(
      jsonEncode(
        options.uri.path.endsWith('/mobile/bootstrap')
            ? _bootstrap
            : options.uri.path.endsWith('/settings')
            ? <String, Object?>{}
            : historyPayload ?? <Object?>[],
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _jsonResponse(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Object? _productionHistoryPayload(String path) {
  Object paged(Object item) => {
    'page': 1,
    'pageSize': 50,
    'total': 1,
    'items': [item],
  };
  if (path.endsWith('/history/orders')) {
    return paged({
      'id': 'history-order-1',
      'accountCode': 'TEST-100',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.01,
      'openPrice': 4368.78,
      'closePrice': 4369.55,
      'profit': -0.77,
      'openedAt': '2026-08-13T15:22:00Z',
      'closedAt': '2026-08-13T15:24:00Z',
      'status': 'closed',
    });
  }
  if (path.endsWith('/history/deals')) {
    return paged({
      'id': 'history-deal-1',
      'type': 'out',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'volume': 0.01,
      'price': 4369.55,
      'profit': -0.77,
      'createdAtUtc': '2026-08-13T15:24:00Z',
    });
  }
  if (path.endsWith('/history/summary')) {
    return {
      'deposit': 1200,
      'withdrawal': -300,
      'realizedProfit': -12.34,
      'swap': -1.25,
      'commission': -2.5,
      'netChange': 883.91,
    };
  }
  if (path.endsWith('/history/positions')) {
    return {
      'page': 1,
      'pageSize': 50,
      'total': 2,
      'items': [
        {
          'id': 'history-position-1',
          'symbol': 'XAUUSD+',
          'side': 'sell',
          'initialVolume': 0.01,
          'remainingVolume': 0,
          'entryPrice': 4368.78,
          'realizedProfit': -0.77,
          'status': 'closed',
          'closedAtUtc': '2026-08-13T15:24:00Z',
          'createdAtUtc': '2026-08-13T15:22:00Z',
        },
        {
          'id': 'open-position-must-not-enter-history',
          'symbol': 'XAUUSD+',
          'side': 'buy',
          'initialVolume': 1,
          'remainingVolume': 1,
          'entryPrice': 4370,
          'realizedProfit': 0,
          'status': 'open',
          'closedAtUtc': null,
          'createdAtUtc': '2026-08-13T15:25:00Z',
        },
      ],
    };
  }
  return null;
}

final _bootstrap = <String, Object?>{
  'serverTime': '2026-08-13T08:00:00Z',
  'version': 1,
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
    'balance': 5000,
    'equity': 5000,
    'profit': 0,
    'margin': 0,
    'freeMargin': 5000,
    'marginLevel': 0,
    'updatedAt': '2026-08-13T08:00:00Z',
  },
  'positions': <Object?>[],
  'pendingOrders': <Object?>[],
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
