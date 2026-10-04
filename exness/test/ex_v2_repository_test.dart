import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exness/features/account/data/ex_v2_api_client.dart';
import 'package:exness/features/account/data/ex_v2_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history fails rather than returning a truncated profit period',
    () async {
      final adapter = _HistoryAdapter(lastPage: 101);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final repository = ExV2Repository(
        ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token'),
      );

      await expectLater(
        repository.historyDeals(pageSize: 50),
        throwsA(isA<StateError>()),
      );
      expect(adapter.reads, 101);
    },
  );

  test(
    'history accepts exactly 100 full pages followed by an empty page',
    () async {
      final adapter = _HistoryAdapter(lastPage: 100);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final repository = ExV2Repository(
        ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token'),
      );

      final rows = await repository.historyDeals(pageSize: 50);
      expect(rows.length, 5000);
      expect(adapter.reads, 101);
    },
  );
}

final class _HistoryAdapter implements HttpClientAdapter {
  _HistoryAdapter({required this.lastPage});

  final int lastPage;
  int reads = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    reads++;
    final page = int.parse(options.uri.queryParameters['page']!);
    final pageSize = int.parse(options.uri.queryParameters['pageSize']!);
    final rows = page <= lastPage
        ? [
            for (var index = 0; index < pageSize; index++)
              {'id': '$page-$index', 'profit': 1},
          ]
        : const <Map<String, Object>>[];
    return ResponseBody.fromString(
      jsonEncode(rows),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
