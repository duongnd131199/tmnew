import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

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
    final adapter = _JsonAdapter(_depositJson, statusCode: 201);
    final client = ExV2ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter,
      tokenReader: () async => 'test-token',
    );

    final result = await ExV2Repository(client).createDeposit(
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
    expect(result, isNot(isA<Map>()));
  });

  test('deposit rejects a non-canonical success payload', () async {
    final adapter = _JsonAdapter(<String, Object?>{
      'id': 'deposit-1',
    }, statusCode: 201);
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = adapter,
        tokenReader: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.createDeposit(
        amount: 500,
        currency: 'USD',
        method: 'demo',
        reference: 'mobile',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-1',
          correlationId: 'corr-1',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('deposit requires the canonical HTTP 201 response', () async {
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = _JsonAdapter(_depositJson),
        tokenReader: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.createDeposit(
        amount: 500,
        currency: 'USD',
        method: 'demo',
        reference: 'mobile',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-1',
          correlationId: 'corr-1',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('create order sends the full 175 lot volume to EX V2', () async {
    final adapter = _JsonAdapter(<String, Object?>{
      'id': 'order-175',
      'clientOrderId': 'client-175',
      'symbol': 'XAUUSD+',
      'type': 'market',
      'side': 'BUY',
      'volume': 175.0,
      'requestedPrice': null,
      'executedPrice': 4397.25,
      'stopLoss': null,
      'takeProfit': null,
      'status': 'filled',
      'createdAt': '2026-10-04T08:00:00Z',
      'version': 2,
      'rowVersion': 'row-version-175',
    });
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = adapter,
        tokenReader: () async => 'test-token',
      ),
    );

    final order = await repository.createOrder(
      clientOrderId: 'client-175',
      symbol: 'XAUUSD+',
      type: 'market',
      side: 'BUY',
      volume: 175,
      metadata: const ExV2CommandMetadata(
        idempotencyKey: 'client-175',
        correlationId: 'corr-175',
      ),
    );

    expect(adapter.options!.uri.path, '/ex/v2/api/orders');
    expect(adapter.options!.data, containsPair('volume', 175.0));
    expect(order.volume, 175.0);
  });

  test('deposit list rejects non-canonical rows after restart', () async {
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = _PagedHistoryAdapter({
            1: const [
              {'id': 'deposit-without-contract'},
            ],
          }),
        tokenReader: () async => 'test-token',
      ),
    );

    await expectLater(
      repository.deposits(pageSize: 2),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'partial close uses its canonical endpoint and typed response',
    () async {
      final adapter = _JsonAdapter({
        ..._closedPositionJson,
        'sync': _closeSyncJson,
      });
      final repository = ExV2Repository(
        ExV2ApiClient(
          dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
            ..httpClientAdapter = adapter,
          tokenReader: () async => 'test-token',
        ),
      );

      final response = await repository.partialClose(
        positionId: 'position-1',
        volume: 0.01,
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-close-1',
          correlationId: 'corr-close-1',
        ),
      );

      expect(
        adapter.options!.uri.path,
        '/ex/v2/api/positions/position-1/partial-close',
      );
      expect(response.position.id, 'position-1');
      expect(response.sync?.operation.mode, ExV2CloseMode.partial);
    },
  );

  test('history deals load every page required for reconciliation', () async {
    final adapter = _PagedHistoryAdapter({
      1: const [
        {'id': 'deal-1'},
        {'id': 'deal-2'},
      ],
      2: const [
        {'id': 'deal-3'},
      ],
    });
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = adapter,
        tokenReader: () async => 'test-token',
      ),
    );

    final deals = await repository.historyDeals(pageSize: 2);

    expect(deals.map((deal) => deal['id']), ['deal-1', 'deal-2', 'deal-3']);
    expect(adapter.requestedPages, [1, 2]);
  });

  test(
    'history page preserves the oldest snapshot version across pages',
    () async {
      final adapter = _PagedHistoryAdapter(
        {
          1: const [
            {'id': 'deal-1'},
            {'id': 'deal-2'},
          ],
          2: const [
            {'id': 'deal-3'},
          ],
        },
        snapshotVersions: const {1: 12, 2: 13},
      );
      final repository = ExV2Repository(
        ExV2ApiClient(
          dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
            ..httpClientAdapter = adapter,
          tokenReader: () async => 'test-token',
        ),
      );

      final page = await repository.historyDealsSnapshot(pageSize: 2);

      expect(page.items.map((deal) => deal['id']), [
        'deal-1',
        'deal-2',
        'deal-3',
      ]);
      expect(page.hasVersionMetadata, isTrue);
      expect(page.snapshotVersion, 12);
    },
  );

  test('history pagination stops when a server repeats a full page', () async {
    final adapter = _PagedHistoryAdapter({
      1: const [
        {'id': 'deal-1'},
        {'id': 'deal-2'},
      ],
    }, repeatFirstPage: true);
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = adapter,
        tokenReader: () async => 'test-token',
      ),
    );

    final deals = await repository.historyDeals(pageSize: 2);

    expect(deals.map((deal) => deal['id']), ['deal-1', 'deal-2']);
    expect(adapter.requestedPages, [1, 2]);
  });

  test('wallet history reads every page from each canonical source', () async {
    Future<List<Map<String, dynamic>>> load(
      Future<List<Map<String, dynamic>>> Function(ExV2Repository repository)
      read,
    ) {
      final adapter = _PagedHistoryAdapter({
        1: const [
          {'id': 'wallet-1'},
          {'id': 'wallet-2'},
        ],
        2: const [
          {'id': 'wallet-3'},
        ],
      });
      final repository = ExV2Repository(
        ExV2ApiClient(
          dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
            ..httpClientAdapter = adapter,
          tokenReader: () async => 'test-token',
        ),
      );
      return read(repository);
    }

    final transactions = await load(
      (repository) => repository.historyTransactions(pageSize: 2),
    );
    final walletTransactions = await load(
      (repository) => repository.walletTransactions(pageSize: 2),
    );
    final withdrawals = await load(
      (repository) => repository.withdrawals(pageSize: 2),
    );

    expect(transactions.map((row) => row['id']), [
      'wallet-1',
      'wallet-2',
      'wallet-3',
    ]);
    expect(walletTransactions.map((row) => row['id']), [
      'wallet-1',
      'wallet-2',
      'wallet-3',
    ]);
    expect(withdrawals.map((row) => row['id']), [
      'wallet-1',
      'wallet-2',
      'wallet-3',
    ]);
  });

  test('canonical deposits load every requested page', () async {
    Map<String, Object?> deposit(String id, int version) => {
      ..._depositJson,
      'id': id,
      'snapshotVersion': version,
    };
    final repository = ExV2Repository(
      ExV2ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
          ..httpClientAdapter = _PagedHistoryAdapter({
            1: [deposit('deposit-1', 1), deposit('deposit-2', 2)],
            2: [deposit('deposit-3', 3)],
          }),
        tokenReader: () async => 'test-token',
      ),
    );

    final deposits = await repository.deposits(pageSize: 2);

    expect(deposits.map((row) => row['id']), [
      'deposit-1',
      'deposit-2',
      'deposit-3',
    ]);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body, {this.statusCode = 200});

  final Object body;
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PagedHistoryAdapter implements HttpClientAdapter {
  _PagedHistoryAdapter(
    this.pages, {
    this.repeatFirstPage = false,
    this.snapshotVersions = const {},
  });

  final Map<int, List<Map<String, Object?>>> pages;
  final bool repeatFirstPage;
  final Map<int, int> snapshotVersions;
  final List<int> requestedPages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse(options.uri.queryParameters['page']!);
    requestedPages.add(page);
    final items =
        pages[page] ??
        (repeatFirstPage ? pages[1]! : const <Map<String, Object?>>[]);
    return ResponseBody.fromString(
      jsonEncode({
        'page': page,
        'pageSize': options.uri.queryParameters['pageSize'],
        'total': pages.values.fold<int>(0, (sum, rows) => sum + rows.length),
        'items': items,
        'snapshotVersion': ?snapshotVersions[page],
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

final _depositJson = <String, Object?>{
  'id': '11111111-1111-4111-8111-111111111111',
  'accountId': 'acct_1',
  'amount': 500,
  'currency': 'USD',
  'method': 'demo',
  'reference': 'mobile',
  'status': 'pending',
  'createdAtUtc': '2026-09-01T10:00:00Z',
  'updatedAtUtc': '2026-09-01T10:00:00Z',
  'approvedAtUtc': null,
  'rejectedAtUtc': null,
  'transactionId': null,
  'snapshotVersion': 2,
};

final _closedPositionJson = <String, Object?>{
  'id': 'position-1',
  'symbol': 'XAUUSD+',
  'side': 'buy',
  'initialVolume': 0.02,
  'remainingVolume': 0.01,
  'entryPrice': 4397.125,
  'stopLoss': null,
  'takeProfit': null,
  'realizedProfit': -0.26,
  'status': 'open',
  'createdAt': '2026-09-01T09:59:00Z',
  'closedAt': null,
  'rowVersion': 'row-version-1',
};

final _closeSyncJson = <String, Object?>{
  'accountId': 'account-1',
  'version': 2,
  'committedAtUtc': '2026-09-01T10:00:00Z',
  'operation': {
    'mode': 'partial',
    'idempotencyKey': 'idem-close-1',
    'correlationId': 'corr-close-1',
  },
  'affectedPositions': [_closedPositionJson],
  'closedPositions': <Object?>[],
  'orders': <Object?>[],
  'deals': [
    {
      'id': 'deal-1',
      'orderId': 'order-1',
      'positionId': 'position-1',
      'type': 'out',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.01,
      'price': 4397.385,
      'profit': -0.26,
      'createdAtUtc': '2026-09-01T10:00:00Z',
    },
  ],
  'accountSummary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 4999.74,
    'equity': 4999.74,
    'profit': 0,
    'margin': 0,
    'freeMargin': 4999.74,
    'marginLevel': 0,
    'updatedAt': '2026-09-01T10:00:00Z',
  },
  'historySummary': {
    'deposit': 0,
    'withdrawal': 0,
    'realizedProfit': -0.26,
    'swap': 0,
    'commission': 0,
    'netChange': -0.26,
  },
};
