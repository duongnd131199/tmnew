import 'dart:convert';

import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

final class ExV2HistoryRowsSnapshot {
  const ExV2HistoryRowsSnapshot({
    required this.items,
    required this.hasVersionMetadata,
    required this.snapshotVersion,
  });

  final List<JsonMap> items;
  final bool hasVersionMetadata;
  final int? snapshotVersion;
}

final class ExV2HistorySummarySnapshot {
  const ExV2HistorySummarySnapshot({
    required this.summary,
    required this.hasVersionMetadata,
    required this.snapshotVersion,
  });

  final ExV2HistorySummary summary;
  final bool hasVersionMetadata;
  final int? snapshotVersion;
}

final class ExV2Repository {
  const ExV2Repository(this._client);

  final ExV2ApiClient _client;

  Future<JsonMap> status() => _client.getJson('/mobile/status');

  Future<ExV2Bootstrap> bootstrap() async =>
      ExV2Bootstrap.fromJson(await _client.getJson('/mobile/bootstrap'));

  Future<ExV2AccountSummary> accountSummary() async =>
      ExV2AccountSummary.fromJson(await _client.getJson('/account/summary'));

  Future<List<ExV2Order>> orders() async => _maps(
    await _client.getList('/orders'),
  ).map(ExV2Order.fromJson).toList(growable: false);

  Future<List<ExV2Position>> positions() async => _maps(
    await _client.getList('/positions'),
  ).map(ExV2Position.fromJson).toList(growable: false);

  Future<List<JsonMap>> historyDeals({int page = 1, int pageSize = 50}) async =>
      (await historyDealsSnapshot(page: page, pageSize: pageSize)).items;

  Future<ExV2HistoryRowsSnapshot> historyDealsSnapshot({
    int page = 1,
    int pageSize = 50,
  }) => _readAllHistoryRows('/history/deals', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyPositions({
    int page = 1,
    int pageSize = 50,
  }) async =>
      (await historyPositionsSnapshot(page: page, pageSize: pageSize)).items;

  Future<ExV2HistoryRowsSnapshot> historyPositionsSnapshot({
    int page = 1,
    int pageSize = 50,
  }) =>
      _readAllHistoryRows('/history/positions', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyTransactions({
    int page = 1,
    int pageSize = 50,
  }) => _readAllMaps('/history/transactions', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyOrders({
    int page = 1,
    int pageSize = 50,
  }) async =>
      (await historyOrdersSnapshot(page: page, pageSize: pageSize)).items;

  Future<ExV2HistoryRowsSnapshot> historyOrdersSnapshot({
    int page = 1,
    int pageSize = 50,
  }) => _readAllHistoryRows('/history/orders', page: page, pageSize: pageSize);

  Future<ExV2HistorySummary> historySummary() async =>
      (await historySummarySnapshot()).summary;

  Future<ExV2HistorySummarySnapshot> historySummarySnapshot() async {
    final json = await _client.getJson('/history/summary');
    final hasVersionMetadata = json.containsKey('snapshotVersion');
    return ExV2HistorySummarySnapshot(
      summary: ExV2HistorySummary.fromJson(json),
      hasVersionMetadata: hasVersionMetadata,
      snapshotVersion: _snapshotVersion(json['snapshotVersion']),
    );
  }

  Future<List<JsonMap>> walletTransactions({int page = 1, int pageSize = 50}) =>
      _readAllMaps('/wallet/transactions', page: page, pageSize: pageSize);

  Future<List<JsonMap>> deposits({int page = 1, int pageSize = 200}) async =>
      (await _readAllMaps('/deposits', page: page, pageSize: pageSize))
          .map(ExV2Deposit.fromJson)
          .map((deposit) => deposit.toJson())
          .toList(growable: false);

  Future<List<JsonMap>> withdrawals({int page = 1, int pageSize = 50}) =>
      _readAllMaps('/withdrawals', page: page, pageSize: pageSize);

  Future<List<JsonMap>> transfers() => _readMaps('/transfers');

  Future<List<JsonMap>> notifications() => _readMaps('/notifications');

  Future<JsonMap> settings() => _client.getJson('/settings');

  Future<ExV2Order> createOrder({
    required String clientOrderId,
    required String symbol,
    required String type,
    required String side,
    required double volume,
    double? requestedPrice,
    double? stopLoss,
    double? takeProfit,
    required ExV2CommandMetadata metadata,
  }) async => ExV2Order.fromJson(
    await _client.postJson(
      '/orders',
      body: {
        'clientOrderId': clientOrderId,
        'symbol': symbol,
        'type': type,
        'side': side,
        'volume': volume,
        'requestedPrice': requestedPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
      },
      metadata: metadata,
    ),
  );

  Future<ExV2Order> modifyOrder({
    required String orderId,
    required double? requestedPrice,
    required double? stopLoss,
    required double? takeProfit,
    required String? rowVersion,
    required ExV2CommandMetadata metadata,
  }) async => ExV2Order.fromJson(
    await _client.putJson(
      '/orders/$orderId',
      body: {
        'requestedPrice': requestedPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'rowVersion': rowVersion,
      },
      metadata: metadata,
    ),
  );

  Future<void> cancelOrder(
    String orderId, {
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.deleteJson('/orders/$orderId', metadata: metadata);
  }

  Future<void> updateProtection({
    required String positionId,
    required double? stopLoss,
    required double? takeProfit,
    required String? rowVersion,
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.putJson(
      '/positions/$positionId/protection',
      body: {
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'rowVersion': rowVersion,
      },
      metadata: metadata,
    );
  }

  Future<ExV2ClosePositionResponse> closePosition({
    required String positionId,
    double? volume,
    required ExV2CommandMetadata metadata,
  }) async => ExV2ClosePositionResponse.fromJson(
    await _client.postJson(
      '/positions/$positionId/close',
      body: {'volume': volume},
      metadata: metadata,
    ),
  );

  Future<ExV2ClosePositionResponse> partialClose({
    required String positionId,
    required double volume,
    required ExV2CommandMetadata metadata,
  }) async => ExV2ClosePositionResponse.fromJson(
    await _client.postJson(
      '/positions/$positionId/partial-close',
      body: {'volume': volume},
      metadata: metadata,
    ),
  );

  Future<ExV2CloseByResponse> closeBy({
    required String positionId,
    required String oppositePositionId,
    required ExV2CommandMetadata metadata,
  }) async => ExV2CloseByResponse.fromJson(
    await _client.postJson(
      '/positions/$positionId/close-by',
      body: {'oppositePositionId': oppositePositionId},
      metadata: metadata,
    ),
  );

  Future<ExV2Deposit> createDeposit({
    required double amount,
    required String currency,
    required String method,
    required String reference,
    required ExV2CommandMetadata metadata,
  }) async => ExV2Deposit.fromJson(
    await _client.postCreatedJson(
      '/deposits',
      body: {
        'amount': amount,
        'currency': currency,
        'method': method,
        'reference': reference,
      },
      metadata: metadata,
    ),
  );

  Future<JsonMap> createWithdrawal({
    required double amount,
    required String currency,
    required String bankName,
    required String bankAccount,
    required String accountHolder,
    required ExV2CommandMetadata metadata,
  }) => _client.postJson(
    '/withdrawals',
    body: {
      'amount': amount,
      'currency': currency,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'accountHolder': accountHolder,
    },
    metadata: metadata,
  );

  Future<JsonMap> createTransfer({
    required double amount,
    required String currency,
    required String toAccount,
    required ExV2CommandMetadata metadata,
  }) => _client.postJson(
    '/transfers',
    body: {'amount': amount, 'currency': currency, 'toAccount': toAccount},
    metadata: metadata,
  );

  Future<void> markNotificationRead(
    String id, {
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.putJson(
      '/notifications/$id/read',
      body: const {},
      metadata: metadata,
    );
  }

  Future<void> markAllNotificationsRead({
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.putJson(
      '/notifications/read-all',
      body: const {},
      metadata: metadata,
    );
  }

  Future<JsonMap> updateSettings(
    JsonMap value, {
    required ExV2CommandMetadata metadata,
  }) => _client.putJson('/settings', body: value, metadata: metadata);

  Future<List<JsonMap>> _readMaps(
    String path, {
    int? page,
    int? pageSize,
  }) async => _maps(
    await _client.getList(
      path,
      queryParameters: {'page': ?page, 'pageSize': ?pageSize},
    ),
  );

  Future<List<JsonMap>> _readAllMaps(
    String path, {
    required int page,
    required int pageSize,
  }) async {
    const maximumPages = 100;
    final result = <JsonMap>[];
    final seenRows = <String>{};
    for (var offset = 0; offset < maximumPages; offset++) {
      final rows = await _readMaps(
        path,
        page: page + offset,
        pageSize: pageSize,
      );
      var added = 0;
      for (final row in rows) {
        if (seenRows.add(jsonEncode(row))) {
          result.add(row);
          added++;
        }
      }
      if (rows.length < pageSize || added == 0) break;
    }
    return result;
  }

  Future<ExV2HistoryRowsSnapshot> _readAllHistoryRows(
    String path, {
    required int page,
    required int pageSize,
  }) async {
    const maximumPages = 100;
    final result = <JsonMap>[];
    final seenRows = <String>{};
    var hasAnyVersionMetadata = false;
    var everyPageHasVersionMetadata = true;
    int? oldestSnapshotVersion;
    for (var offset = 0; offset < maximumPages; offset++) {
      final response = await _client.getJson(
        path,
        queryParameters: {'page': page + offset, 'pageSize': pageSize},
      );
      final rows = _maps(_pageItems(response));
      final hasPageVersion = response.containsKey('snapshotVersion');
      hasAnyVersionMetadata |= hasPageVersion;
      everyPageHasVersionMetadata &= hasPageVersion;
      final pageVersion = _snapshotVersion(response['snapshotVersion']);
      if (pageVersion != null &&
          (oldestSnapshotVersion == null ||
              pageVersion < oldestSnapshotVersion)) {
        oldestSnapshotVersion = pageVersion;
      }
      var added = 0;
      for (final row in rows) {
        if (seenRows.add(jsonEncode(row))) {
          result.add(row);
          added++;
        }
      }
      if (rows.length < pageSize || added == 0) break;
    }
    return ExV2HistoryRowsSnapshot(
      items: result,
      hasVersionMetadata: hasAnyVersionMetadata,
      snapshotVersion: hasAnyVersionMetadata && everyPageHasVersionMetadata
          ? oldestSnapshotVersion
          : null,
    );
  }
}

List<dynamic> _pageItems(JsonMap response) {
  for (final key in const ['items', 'data', 'results']) {
    final value = response[key];
    if (value is List) return value;
  }
  throw const FormatException('EX V2 response must contain a JSON list');
}

int? _snapshotVersion(Object? value) => switch (value) {
  int version => version,
  num version => version.toInt(),
  String version => int.tryParse(version),
  _ => null,
};

List<JsonMap> _maps(List<dynamic> values) => values
    .map((value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.cast<String, dynamic>();
      throw const FormatException('EX V2 list contains a non-object value');
    })
    .toList(growable: false);
