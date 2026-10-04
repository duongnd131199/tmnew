import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/device_token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [401, 403]) {
    test('bootstrap $status clears the rejected device token', () async {
      final store = _MemoryTokenStore();
      final adapter = _BootstrapAdapter()..status = status;
      final container = _container(store, adapter);
      addTearDown(container.dispose);

      expect(await container.read(accountSessionProvider.future), isNull);
      expect(store.token, isNull);
      expect(store.deleteCalls, 1);
      expect(container.read(accountSessionProvider).value, isNull);
    });

    test('refresh $status clears previously visible account data', () async {
      final store = _MemoryTokenStore();
      final adapter = _BootstrapAdapter();
      final container = _container(store, adapter);
      addTearDown(container.dispose);

      expect(
        (await container.read(accountSessionProvider.future))?.account.id,
        'account-1',
      );
      adapter.status = status;
      await container.read(accountSessionProvider.notifier).refresh();

      expect(store.token, isNull);
      expect(store.deleteCalls, 1);
      expect(container.read(accountSessionProvider).value, isNull);
    });
  }

  test(
    'server failure preserves the last account and token for retry',
    () async {
      final store = _MemoryTokenStore();
      final adapter = _BootstrapAdapter();
      final container = _container(store, adapter);
      addTearDown(container.dispose);
      await container.read(accountSessionProvider.future);

      adapter.status = 500;
      await expectLater(
        container.read(accountSessionProvider.notifier).refresh(),
        throwsA(isA<Exception>()),
      );
      expect(store.token, 'device-token');
      expect(
        container.read(accountSessionProvider).value?.account.id,
        'account-1',
      );
    },
  );
}

ProviderContainer _container(
  _MemoryTokenStore store,
  _BootstrapAdapter adapter,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      deviceTokenStoreProvider.overrideWithValue(store),
      accountDioProvider.overrideWithValue(dio),
    ],
  );
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? token = 'device-token';
  int deleteCalls = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> delete() async {
    deleteCalls++;
    token = null;
  }
}

final class _BootstrapAdapter implements HttpClientAdapter {
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (status != 200) {
      return ResponseBody.fromString(
        jsonEncode({'code': 'device_token_invalid', 'message': 'Rejected'}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'serverTime': '2026-09-19T00:00:00Z',
        'version': 2,
        'device': {'id': 'device-1', 'name': 'Demo'},
        'activeAccount': {
          'id': 'account-1',
          'accountCode': '100000001',
          'name': 'Virtual account',
          'currency': 'USD',
          'status': 'active',
        },
        'summary': {
          'accountId': 'account-1',
          'currency': 'USD',
          'balance': 12.5,
          'equity': 12.5,
          'profit': 0,
          'margin': 0,
          'freeMargin': 12.5,
          'marginLevel': 0,
          'updatedAt': '2026-09-19T00:00:00Z',
        },
        'positions': [],
        'pendingOrders': [],
        'recentDeals': [],
        'wallet': {
          'currency': 'USD',
          'availableBalance': 2,
          'lockedBalance': 0,
          'totalBalance': 2,
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
        'connection': {
          'marketFeedStatus': 'connected',
          'lastMarketTickAt': null,
        },
        'integrityWarnings': 0,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
