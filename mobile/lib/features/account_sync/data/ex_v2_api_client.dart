import 'package:dio/dio.dart';
import 'package:trading_mobile/core/utils/uuid_v4.dart';

typedef DeviceTokenReader = Future<String?> Function();

final class ExV2CommandMetadata {
  const ExV2CommandMetadata({
    required this.idempotencyKey,
    required this.correlationId,
  });

  factory ExV2CommandMetadata.create() =>
      ExV2CommandMetadata(idempotencyKey: uuidV4(), correlationId: uuidV4());

  final String idempotencyKey;
  final String correlationId;
}

final class ExV2ApiClient {
  factory ExV2ApiClient({
    required Dio dio,
    required DeviceTokenReader tokenReader,
  }) => ExV2ApiClient._(dio, tokenReader);

  ExV2ApiClient._(this._dio, this._tokenReader);

  final Dio _dio;
  final DeviceTokenReader _tokenReader;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request<dynamic>(
      'GET',
      path,
      queryParameters: queryParameters,
    );
    final value = response.data;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('EX V2 response must be a JSON object');
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _request<dynamic>(
      'GET',
      path,
      queryParameters: queryParameters,
    );
    final value = response.data;
    if (value is List) return value;
    if (value is Map) {
      for (final key in const ['items', 'data', 'results']) {
        final items = value[key];
        if (items is List) return items;
      }
    }
    throw const FormatException('EX V2 response must contain a JSON list');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    required ExV2CommandMetadata metadata,
  }) => _mutation('POST', path, body, metadata);

  Future<Map<String, dynamic>> postCreatedJson(
    String path, {
    required Map<String, dynamic> body,
    required ExV2CommandMetadata metadata,
  }) => _mutation('POST', path, body, metadata, expectedStatusCode: 201);

  Future<Map<String, dynamic>> postLoginJson(
    String path, {
    required Map<String, dynamic> body,
    required String installationId,
    required ExV2CommandMetadata metadata,
  }) => _mutation(
    'POST',
    path,
    body,
    metadata,
    requiresDeviceToken: false,
    extraHeaders: <String, dynamic>{'X-Installation-Id': installationId},
  );

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    required ExV2CommandMetadata metadata,
  }) => _mutation('PUT', path, body, metadata);

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    required ExV2CommandMetadata metadata,
  }) => _mutation('DELETE', path, const {}, metadata);

  Future<Map<String, dynamic>> _mutation(
    String method,
    String path,
    Map<String, dynamic> body,
    ExV2CommandMetadata metadata, {
    bool requiresDeviceToken = true,
    Map<String, dynamic> extraHeaders = const <String, dynamic>{},
    int? expectedStatusCode,
  }) async {
    final response = await _request<dynamic>(
      method,
      path,
      data: body,
      metadata: metadata,
      requiresDeviceToken: requiresDeviceToken,
      extraHeaders: extraHeaders,
    );
    if (expectedStatusCode != null &&
        response.statusCode != expectedStatusCode) {
      throw FormatException(
        'EX V2 mutation expected HTTP $expectedStatusCode, '
        'received ${response.statusCode}',
      );
    }
    final value = response.data;
    if (value == null || value == '') return const {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('EX V2 mutation response must be JSON');
  }

  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    ExV2CommandMetadata? metadata,
    bool requiresDeviceToken = true,
    Map<String, dynamic> extraHeaders = const <String, dynamic>{},
  }) async {
    String? token;
    if (requiresDeviceToken) {
      token = (await _tokenReader())?.trim();
      if (token == null || token.isEmpty) throw const ExV2TokenMissing();
    }
    final correlationId = metadata?.correlationId ?? uuidV4();
    final headers = <String, dynamic>{
      ...extraHeaders,
      if (requiresDeviceToken) 'X-Device-Token': token,
      'X-Correlation-Id': correlationId,
      if (metadata != null) 'Idempotency-Key': metadata.idempotencyKey,
    };
    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (error) {
      throw ExV2RequestFailure(
        statusCode: error.response?.statusCode,
        code: _errorCode(error.response?.data),
        correlationId: _correlationId(
          error.response?.data,
          error.response?.headers,
        ),
        message:
            _message(error.response?.data) ??
            _httpMessage(error.response?.statusCode) ??
            error.message ??
            'Lỗi kết nối mạng',
      );
    }
  }
}

sealed class ExV2ClientFailure implements Exception {
  const ExV2ClientFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class ExV2TokenMissing extends ExV2ClientFailure {
  const ExV2TokenMissing() : super('Device token is missing');
}

final class ExV2RequestFailure extends ExV2ClientFailure {
  const ExV2RequestFailure({
    required this.statusCode,
    required String message,
    this.code,
    this.correlationId,
  }) : super(message);
  final int? statusCode;
  final String? code;
  final String? correlationId;

  String get safeDisplayMessage {
    final safeCode = _safeDiagnosticValue(code, maxLength: 64);
    final safeCorrelationId = _safeDiagnosticValue(
      correlationId,
      maxLength: 128,
    );
    return [
      message,
      if (safeCode != null) 'Mã lỗi: $safeCode',
      if (safeCorrelationId != null) 'Mã tra cứu: $safeCorrelationId',
    ].join('\n');
  }
}

String safeOrderFailureDiagnostic(Object error) {
  if (error is! ExV2RequestFailure) {
    return 'order_failed type=${error.runtimeType}';
  }
  final safeCode = _safeDiagnosticValue(error.code, maxLength: 64);
  final safeCorrelationId = _safeDiagnosticValue(
    error.correlationId,
    maxLength: 128,
  );
  return [
    'order_failed',
    if (error.statusCode case final statusCode?) 'status=$statusCode',
    if (safeCode != null) 'code=$safeCode',
    if (safeCorrelationId != null) 'correlationId=$safeCorrelationId',
  ].join(' ');
}

String? _errorCode(Object? data) {
  if (data is! Map) return null;
  final value = data['code'];
  return value is String && value.isNotEmpty ? value : null;
}

String? _message(Object? data) {
  if (data is Map) {
    for (final key in const ['message', 'error', 'detail', 'code']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
  }
  return null;
}

String? _correlationId(Object? data, Headers? headers) {
  if (data is Map) {
    final value = data['correlationId'];
    if (value is String && value.isNotEmpty) return value;
  }
  final value = headers?.value('X-Correlation-Id');
  return value == null || value.isEmpty ? null : value;
}

String? _safeDiagnosticValue(String? value, {required int maxLength}) {
  if (value == null || value.isEmpty || value.length > maxLength) return null;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value) ? value : null;
}

String? _httpMessage(int? statusCode) {
  if (statusCode != null && statusCode >= 500) {
    return 'Không thể kết nối';
  }
  return switch (statusCode) {
    400 => 'Yêu cầu không hợp lệ',
    401 => 'Mã thiết bị không hợp lệ',
    409 => 'Dữ liệu đã thay đổi, vui lòng thử lại',
    422 => 'Lệnh bị từ chối',
    _ => null,
  };
}
