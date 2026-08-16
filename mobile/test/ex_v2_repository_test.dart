import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';

void main() {
  test('repository validates a device through the status endpoint', () async {
    final adapter = _JsonAdapter(<String, Object?>{
      'deviceId': 'device-1',
      'enabled': true,
    });
    final client = ExV2ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter,
      tokenReader: () async => 'test-token',
    );

    final status = await ExV2Repository(client).status();

    expect(adapter.options!.method, 'GET');
    expect(adapter.options!.uri.path, '/ex/v2/api/mobile/status');
    expect(adapter.options!.headers['X-Device-Token'], 'test-token');
    expect(status['enabled'], isTrue);
  });

  test('repository reads the canonical bootstrap endpoint', () async {
    final adapter = _JsonAdapter(_bootstrapJson);
    final client = ExV2ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter,
      tokenReader: () async => 'test-token',
    );

    final snapshot = await ExV2Repository(client).bootstrap();

    expect(adapter.options!.method, 'GET');
    expect(adapter.options!.uri.path, '/ex/v2/api/mobile/bootstrap');
    expect(snapshot.account.accountCode, 'TEST-100');
    expect(snapshot.summary.balance, 5000);
  });

  test('deposit writes the request to server with idempotency', () async {
    final adapter = _JsonAdapter(<String, Object?>{'id': 'deposit-1'});
    final client = ExV2ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter,
      tokenReader: () async => 'test-token',
    );

    await ExV2Repository(client).createDeposit(
      amount: 500,
      currency: 'USD',
      method: 'demo',
      reference: 'mobile',
      metadata: const ExV2CommandMetadata(
        idempotencyKey: 'idem-1',
        correlationId: 'corr-1',
      ),
    );

    expect(adapter.options!.method, 'POST');
    expect(adapter.options!.uri.path, '/ex/v2/api/deposits');
    expect(adapter.options!.headers['Idempotency-Key'], 'idem-1');
    expect(adapter.options!.data, {
      'amount': 500.0,
      'currency': 'USD',
      'method': 'demo',
      'reference': 'mobile',
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object body;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _bootstrapJson = <String, Object?>{
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
