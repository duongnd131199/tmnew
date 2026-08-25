import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  late _AccountLinkAdapter adapter;
  late AccountLinkRepository repository;

  setUp(() {
    adapter = _AccountLinkAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    repository = AccountLinkRepository(
      ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token-1'),
    );
  });

  test('broker discovery uses the exact mobile path and query', () async {
    adapter.responses['GET /ex/v2/api/mobile/brokers'] = [
      {
        'id': 'broker-1',
        'name': 'Example Markets',
        'companyName': 'Example Markets Ltd',
        'description': null,
        'logoUrl': 42,
      },
    ];

    final result = await repository.brokers(query: 'example');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/ex/v2/api/mobile/brokers');
    expect(request.uri.queryParameters, {'query': 'example'});
    expect(request.headers['X-Device-Token'], 'device-token-1');
    expect(request.headers['X-Correlation-Id'], isNotEmpty);
    expect(request.headers['Idempotency-Key'], isNull);
    expect(result.single.id, 'broker-1');
    expect(result.single.name, 'Example Markets');
    expect(result.single.companyName, 'Example Markets Ltd');
    expect(result.single.description, isNull);
    expect(result.single.logoUrl, isNull);
  });

  test('server discovery scopes and escapes the broker id', () async {
    adapter.responses['GET /ex/v2/api/mobile/brokers/broker%2Fone/servers'] = [
      {
        'id': 'server-1',
        'name': 'Example-Demo',
        'brokerId': 'broker/one',
        'accountType': 'demo',
      },
    ];

    final result = await repository.servers('broker/one', query: 'demo');

    final request = adapter.requests.single;
    expect(request.uri.path, '/ex/v2/api/mobile/brokers/broker%2Fone/servers');
    expect(request.uri.queryParameters, {'query': 'demo'});
    expect(request.headers['X-Device-Token'], 'device-token-1');
    expect(request.headers['X-Correlation-Id'], isNotEmpty);
    expect(request.headers['Idempotency-Key'], isNull);
    expect(result.single.id, 'server-1');
    expect(result.single.name, 'Example-Demo');
  });

  test('linked accounts never deserialize credential fields', () async {
    adapter.responses['GET /ex/v2/api/mobile/accounts'] = [
      {
        'id': 'account-1',
        'brokerId': 'broker-1',
        'brokerName': 'Example Markets',
        'serverId': 'server-1',
        'serverName': 'Example-Demo',
        'login': '100001',
        'displayName': 'Demo account',
        'currency': 'USD',
        'isActive': true,
        'password': 'must-not-escape',
        'reconnectGrant': 'must-not-escape',
      },
    ];

    final result = await repository.accounts();

    final request = adapter.requests.single;
    expect(request.uri.path, '/ex/v2/api/mobile/accounts');
    expect(request.headers['X-Device-Token'], 'device-token-1');
    expect(request.headers['X-Correlation-Id'], isNotEmpty);
    expect(request.headers['Idempotency-Key'], isNull);
    final account = result.single;
    expect(account.id, 'account-1');
    expect(account.isActive, isTrue);
    expect(account.toJson(), isNot(contains('password')));
    expect(account.toJson(), isNot(contains('reconnectGrant')));
  });

  test('link sends exact JSON and command headers', () async {
    adapter.responses['POST /ex/v2/api/mobile/accounts/link'] = {
      'account': _linkedAccountJson,
      'reconnectGrant': 'opaque-grant-1',
      'alreadyLinked': false,
      'password': 'must-not-escape',
    };
    const metadata = ExV2CommandMetadata(
      idempotencyKey: 'idem-link-1',
      correlationId: 'corr-link-1',
    );

    final result = await repository.link(
      const LinkAccountRequest(
        brokerId: 'broker-1',
        serverId: 'server-1',
        login: '100001',
        password: 'transient-password',
        savePassword: true,
      ),
      metadata: metadata,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/ex/v2/api/mobile/accounts/link');
    expect(request.headers['X-Device-Token'], 'device-token-1');
    expect(request.headers['Idempotency-Key'], 'idem-link-1');
    expect(request.headers['X-Correlation-Id'], 'corr-link-1');
    expect(request.data, {
      'brokerId': 'broker-1',
      'serverId': 'server-1',
      'login': '100001',
      'password': 'transient-password',
      'savePassword': true,
    });
    expect(result.account.toJson().containsKey('password'), isFalse);
    expect(result.account.toJson().containsKey('reconnectGrant'), isFalse);
    expect(result.reconnectGrant, 'opaque-grant-1');
  });

  test(
    'production link preserves credential characters and public URL',
    () async {
      final productionAdapter = _AccountLinkAdapter();
      final productionDio = Dio(
        BaseOptions(baseUrl: 'https://trochoi.top/ex/v2/api'),
      )..httpClientAdapter = productionAdapter;
      final productionRepository = AccountLinkRepository(
        ExV2ApiClient(
          dio: productionDio,
          tokenReader: () async => 'device-token-sentinel',
        ),
      );
      productionAdapter.responses['POST /ex/v2/api/mobile/accounts/link'] = {
        'account': {
          ..._linkedAccountJson,
          'brokerId': 'yodo-demo',
          'brokerName': 'YODO Demo Markets',
          'serverId': 'yodo-demo-01',
          'serverName': 'YODO-Demo-01',
          'login': '109740422',
        },
        'reconnectGrant': 'opaque-grant-sentinel',
        'alreadyLinked': false,
      };

      await productionRepository.link(
        const LinkAccountRequest(
          brokerId: 'yodo-demo',
          serverId: 'yodo-demo-01',
          login: '109740422',
          password: ' Test-Pass_123! ',
          savePassword: true,
        ),
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-link-sentinel',
          correlationId: 'corr-link-sentinel',
        ),
      );

      final request = productionAdapter.requests.single;
      expect(
        request.uri.toString(),
        'https://trochoi.top/ex/v2/api/mobile/accounts/link',
      );
      expect(request.data, {
        'brokerId': 'yodo-demo',
        'serverId': 'yodo-demo-01',
        'login': '109740422',
        'password': ' Test-Pass_123! ',
        'savePassword': true,
      });
      expect(request.data['login'], isNot('2022'));
      expect(request.data['brokerId'], isNot('YODO Demo Markets'));
      expect(request.data['serverId'], isNot('YODO-Demo-01'));
      expect(request.headers['X-Device-Token'], 'device-token-sentinel');
      expect(request.headers['X-Correlation-Id'], 'corr-link-sentinel');
      expect(request.headers['Idempotency-Key'], 'idem-link-sentinel');
      expect(request.contentType, Headers.jsonContentType);
    },
  );

  test(
    'activate uses exact path, empty JSON body, and parses bootstrap',
    () async {
      adapter
          .responses['PUT /ex/v2/api/mobile/accounts/account%2Fone/activate'] = {
        'account': _linkedAccountJson,
        'bootstrap': _bootstrapJson,
      };
      const metadata = ExV2CommandMetadata(
        idempotencyKey: 'idem-activate-1',
        correlationId: 'corr-activate-1',
      );

      final result = await repository.activate(
        'account/one',
        metadata: metadata,
      );

      final request = adapter.requests.single;
      expect(
        request.uri.path,
        '/ex/v2/api/mobile/accounts/account%2Fone/activate',
      );
      expect(request.method, 'PUT');
      expect(request.data, isEmpty);
      expect(request.headers['X-Device-Token'], 'device-token-1');
      expect(request.headers['Idempotency-Key'], 'idem-activate-1');
      expect(request.headers['X-Correlation-Id'], 'corr-activate-1');
      expect(result.bootstrap.account.id, 'account-1');
      expect(result.bootstrap.summary.accountId, 'account-1');
    },
  );

  test('catalog models reject missing required ids and names', () {
    expect(
      () => MobileBroker.fromJson(const {'id': '', 'name': 'Broker'}),
      throwsFormatException,
    );
    expect(
      () => MobileTradingServer.fromJson(const {'id': 'server-1'}),
      throwsFormatException,
    );
  });

  test('server brokerId is required and strictly typed', () {
    for (final value in <Object?>[null, '', 42, false]) {
      expect(
        () => MobileTradingServer.fromJson({
          'id': 'server-1',
          'name': 'Example-Demo',
          'brokerId': ?value,
        }),
        throwsFormatException,
        reason: 'brokerId=$value must be rejected',
      );
    }
  });

  test('linked-account isActive is required and strictly typed', () {
    expect(
      () => LinkedTradingAccount.fromJson(
        <String, Object?>{..._linkedAccountJson}..remove('isActive'),
      ),
      throwsFormatException,
    );
    for (final value in <Object?>[null, '', 0, 'true']) {
      final json = <String, Object?>{
        ..._linkedAccountJson,
        if (value == null) ...{'isActive': null} else 'isActive': value,
      };
      expect(
        () => LinkedTradingAccount.fromJson(json),
        throwsFormatException,
        reason: 'isActive=$value must be rejected',
      );
    }
  });

  test('link alreadyLinked is required and strictly typed', () {
    expect(
      () => LinkAccountResult.fromJson({
        'account': _linkedAccountJson,
        'reconnectGrant': 'opaque-grant-1',
      }),
      throwsFormatException,
    );
    for (final value in <Object?>[null, '', 0, 'false']) {
      final json = <String, Object?>{
        'account': _linkedAccountJson,
        'reconnectGrant': 'opaque-grant-1',
        if (value == null) ...{
          'alreadyLinked': null,
        } else
          'alreadyLinked': value,
      };
      expect(
        () => LinkAccountResult.fromJson(json),
        throwsFormatException,
        reason: 'alreadyLinked=$value must be rejected',
      );
    }
  });

  test('link reconnectGrant is required, string, and non-empty', () {
    for (final value in <Object?>[null, '', '   ', 42, false]) {
      final json = <String, Object?>{
        'account': _linkedAccountJson,
        'reconnectGrant': ?value,
        'alreadyLinked': false,
      };
      expect(
        () => LinkAccountResult.fromJson(json),
        throwsFormatException,
        reason: 'reconnectGrant=$value must be rejected',
      );
    }
  });

  test('activate rejects a linked account id mismatch', () {
    final account = <String, Object?>{..._linkedAccountJson, 'id': 'account-x'};

    expect(
      () => ActivateLinkedAccountResult.fromJson({
        'account': account,
        'bootstrap': _bootstrapJson,
      }),
      throwsFormatException,
    );
  });

  test('activate rejects an active bootstrap account id mismatch', () {
    final bootstrap = _bootstrapWith(
      activeAccountId: 'account-x',
      summaryAccountId: 'account-1',
    );

    expect(
      () => ActivateLinkedAccountResult.fromJson({
        'account': _linkedAccountJson,
        'bootstrap': bootstrap,
      }),
      throwsFormatException,
    );
  });

  test('activate rejects a bootstrap summary account id mismatch', () {
    final bootstrap = _bootstrapWith(
      activeAccountId: 'account-1',
      summaryAccountId: 'account-x',
    );

    expect(
      () => ActivateLinkedAccountResult.fromJson({
        'account': _linkedAccountJson,
        'bootstrap': bootstrap,
      }),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _bootstrapWith({
  required String activeAccountId,
  required String summaryAccountId,
}) => <String, Object?>{
  ..._bootstrapJson,
  'activeAccount': {
    ..._bootstrapJson['activeAccount']! as Map<String, Object?>,
    'id': activeAccountId,
  },
  'summary': {
    ..._bootstrapJson['summary']! as Map<String, Object?>,
    'accountId': summaryAccountId,
  },
};

final class _AccountLinkAdapter implements HttpClientAdapter {
  final Map<String, Object?> responses = <String, Object?>{};
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    final body = responses[key];
    if (!responses.containsKey(key)) {
      return ResponseBody.fromString('missing fixture for $key', 500);
    }
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

const _linkedAccountJson = <String, Object?>{
  'id': 'account-1',
  'brokerId': 'broker-1',
  'brokerName': 'Example Markets',
  'serverId': 'server-1',
  'serverName': 'Example-Demo',
  'login': '100001',
  'displayName': 'Demo account',
  'currency': 'USD',
  'isActive': true,
};

const _bootstrapJson = <String, Object?>{
  'serverTime': '2026-08-15T08:00:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': '100001',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 0,
    'equity': 0,
    'profit': 0,
    'margin': 0,
    'freeMargin': 0,
    'marginLevel': 0,
    'updatedAt': '2026-08-15T08:00:00Z',
  },
  'positions': <Object?>[],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 0,
    'lockedBalance': 0,
    'totalBalance': 0,
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
