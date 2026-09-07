import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  test(
    'bootstrap sends the device token without duplicating the api path',
    () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final client = ExV2ApiClient(
        dio: dio,
        tokenReader: () async => 'test-device-token',
      );

      await client.getJson('/mobile/bootstrap');

      expect(adapter.options!.uri.path, '/ex/v2/api/mobile/bootstrap');
      expect(adapter.options!.headers['X-Device-Token'], 'test-device-token');
      expect(adapter.options!.headers['X-Correlation-Id'], isNotEmpty);
      expect(adapter.options!.headers['Accept'], 'application/json');
    },
  );

  test('a mutation keeps caller supplied idempotency metadata', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final client = ExV2ApiClient(
      dio: dio,
      tokenReader: () async => 'test-device-token',
    );
    const metadata = ExV2CommandMetadata(
      idempotencyKey: 'idem-1',
      correlationId: 'corr-1',
    );

    await client.postJson(
      '/orders',
      body: const {'symbol': 'XAUUSD+'},
      metadata: metadata,
    );

    expect(adapter.options!.headers['Idempotency-Key'], 'idem-1');
    expect(adapter.options!.headers['X-Correlation-Id'], 'corr-1');
    expect(adapter.options!.headers['Accept'], 'application/json');
    expect(adapter.options!.headers['Content-Type'], 'application/json');
  });

  test('empty server failure becomes a short actionable message', () async {
    final adapter = _RecordingAdapter(statusCode: 500, body: '');
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final client = ExV2ApiClient(
      dio: dio,
      tokenReader: () async => 'test-device-token',
    );

    await expectLater(
      client.postJson(
        '/orders',
        body: const {'symbol': 'XAUUSD+'},
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-500',
          correlationId: 'corr-500',
        ),
      ),
      throwsA(
        isA<ExV2RequestFailure>().having(
          (error) => error.message,
          'message',
          'Không thể kết nối',
        ),
      ),
    );
  });

  test('422 parses code, message, and correlationId', () async {
    final adapter = _RecordingAdapter(
      statusCode: 422,
      body: const {
        'code': 'invalid_credentials',
        'message': 'Unable to link this virtual account.',
        'correlationId': 'corr-safe-422',
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://trochoi.top/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final client = ExV2ApiClient(
      dio: dio,
      tokenReader: () async => 'test-device-token',
    );

    Object? caught;
    try {
      await client.postJson(
        '/mobile/accounts/link',
        body: const {
          'brokerId': 'yodo-demo',
          'serverId': 'yodo-demo-01',
          'login': '109740422',
          'password': 'sentinel-only',
          'savePassword': true,
        },
        metadata: const ExV2CommandMetadata(
          idempotencyKey: 'idem-safe-422',
          correlationId: 'corr-request-422',
        ),
      );
    } catch (error) {
      caught = error;
    }

    expect(caught, isA<ExV2RequestFailure>());
    final failure = caught! as ExV2RequestFailure;
    Object? correlationId;
    try {
      correlationId = (failure as dynamic).correlationId;
    } on NoSuchMethodError {
      correlationId = null;
    }
    expect(failure.statusCode, 422);
    expect(failure.code, 'invalid_credentials');
    expect(failure.message, 'Unable to link this virtual account.');
    expect(correlationId, 'corr-safe-422');
  });

  test('order failure diagnostics exclude server messages and secrets', () {
    const failure = ExV2RequestFailure(
      statusCode: 422,
      code: 'ORDER_REJECTED',
      message: 'sensitive-device-token-value',
      correlationId: 'order-correlation-1',
    );

    final diagnostic = safeOrderFailureDiagnostic(failure);

    expect(diagnostic, contains('status=422'));
    expect(diagnostic, contains('code=ORDER_REJECTED'));
    expect(diagnostic, contains('correlationId=order-correlation-1'));
    expect(diagnostic, isNot(contains('sensitive-device-token-value')));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body});

  final int statusCode;
  final Object? body;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      body is String
          ? body! as String
          : jsonEncode(body ?? <String, Object?>{}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
