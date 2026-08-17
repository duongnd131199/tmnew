import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_repository.dart';
import 'package:trading_mobile/features/account_login/domain/account_password_login_models.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  late _LoginAdapter adapter;
  late AccountPasswordLoginRepository repository;

  setUp(() {
    adapter = _LoginAdapter(_loginResponse);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://trochoi.top/ex/v2/api',
        contentType: Headers.jsonContentType,
      ),
    )..httpClientAdapter = adapter;
    repository = AccountPasswordLoginRepository(
      ExV2ApiClient(
        dio: dio,
        tokenReader: () => throw StateError('login must not read device token'),
      ),
    );
  });

  test(
    'login sends exact public URL, raw password, ids, and headers',
    () async {
      const request = AccountPasswordLoginRequest(
        brokerId: 'yodo-demo',
        serverId: 'yodo-demo-01',
        login: '109740422',
        password: ' Test-Pass_123! ',
      );

      final result = await repository.login(
        request,
        installationId: '11111111-1111-4111-8111-111111111111',
        metadata: const ExV2CommandMetadata(
          idempotencyKey: '22222222-2222-4222-8222-222222222222',
          correlationId: '33333333-3333-4333-8333-333333333333',
        ),
      );

      final sent = adapter.requests.single;
      expect(
        sent.uri.toString(),
        'https://trochoi.top/ex/v2/api/mobile/auth/login',
      );
      expect(sent.method, 'POST');
      expect(sent.headers['X-Device-Token'], isNull);
      expect(
        sent.headers['X-Installation-Id'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(
        sent.headers['X-Correlation-Id'],
        '33333333-3333-4333-8333-333333333333',
      );
      expect(
        sent.headers['Idempotency-Key'],
        '22222222-2222-4222-8222-222222222222',
      );
      expect(sent.contentType, Headers.jsonContentType);
      expect(sent.data, request.toJson());
      expect(sent.data['password'], ' Test-Pass_123! ');
      expect(sent.data['login'], '109740422');
      expect(sent.data['login'], isNot('2022'));
      expect(sent.data['brokerId'], 'yodo-demo');
      expect(sent.data['serverId'], 'yodo-demo-01');
      expect(result.deviceToken, 'opaque-test-token');
      expect(result.account.id, 'account-1');
      expect(result.bootstrap.account.id, 'account-1');
    },
  );

  test(
    'login result rejects account and bootstrap identity mismatch',
    () async {
      adapter.response = <String, Object?>{
        ..._loginResponse,
        'bootstrap': <String, Object?>{
          ..._bootstrapJson,
          'summary': <String, Object?>{
            ..._bootstrapJson['summary']! as Map<String, Object?>,
            'accountId': 'account-other',
          },
        },
      };

      await expectLater(
        repository.login(
          const AccountPasswordLoginRequest(
            brokerId: 'yodo-demo',
            serverId: 'yodo-demo-01',
            login: '109740422',
            password: 'synthetic-sentinel',
          ),
          installationId: '11111111-1111-4111-8111-111111111111',
          metadata: const ExV2CommandMetadata(
            idempotencyKey: '22222222-2222-4222-8222-222222222222',
            correlationId: '33333333-3333-4333-8333-333333333333',
          ),
        ),
        throwsFormatException,
      );
    },
  );
}

final class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.response);

  Object response;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _loginResponse = <String, Object?>{
  'deviceToken': 'opaque-test-token',
  'account': <String, Object?>{
    'id': 'account-1',
    'brokerId': 'yodo-demo',
    'brokerName': 'YODO Demo Markets',
    'serverId': 'yodo-demo-01',
    'serverName': 'YODO-Demo-01',
    'login': '109740422',
    'displayName': 'Virtual account',
    'currency': 'USD',
    'status': 'active',
    'isActive': true,
  },
  'bootstrap': _bootstrapJson,
};

const _bootstrapJson = <String, Object?>{
  'serverTime': '2026-08-17T00:00:00Z',
  'version': 1,
  'device': <String, Object?>{'id': 'device-1', 'name': 'Mobile device'},
  'activeAccount': <String, Object?>{
    'id': 'account-1',
    'accountCode': '109740422',
    'name': 'Virtual account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': <String, Object?>{
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 0,
    'equity': 0,
    'profit': 0,
    'margin': 0,
    'freeMargin': 0,
    'marginLevel': 0,
    'updatedAt': '2026-08-17T00:00:00Z',
  },
  'positions': <Object?>[],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': <String, Object?>{
    'currency': 'USD',
    'availableBalance': 0,
    'lockedBalance': 0,
    'totalBalance': 0,
  },
  'performance': <String, Object?>{
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': <String, Object?>{
    'marketFeedStatus': 'connected',
    'lastMarketTickAt': null,
  },
  'integrityWarnings': 0,
};
