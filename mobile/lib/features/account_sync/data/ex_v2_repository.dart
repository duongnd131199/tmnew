import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

final class ExV2Repository {
  const ExV2Repository(this._client);

  final ExV2ApiClient _client;

  Future<JsonMap> status() => _client.getJson('/mobile/status');

  Future<ExV2Bootstrap> bootstrap() async =>
      ExV2Bootstrap.fromJson(await _client.getJson('/mobile/bootstrap'));

  Future<List<ExV2Order>> orders() async => _maps(
    await _client.getList('/orders'),
  ).map(ExV2Order.fromJson).toList(growable: false);

  Future<List<ExV2Position>> positions() async => _maps(
    await _client.getList('/positions'),
  ).map(ExV2Position.fromJson).toList(growable: false);

  Future<List<JsonMap>> historyDeals({int page = 1, int pageSize = 50}) =>
      _readMaps('/history/deals', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyPositions({int page = 1, int pageSize = 50}) =>
      _readMaps('/history/positions', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyTransactions({
    int page = 1,
    int pageSize = 50,
  }) => _readMaps('/history/transactions', page: page, pageSize: pageSize);

  Future<List<JsonMap>> historyOrders() => _readMaps('/history/orders');

  Future<ExV2HistorySummary> historySummary() async =>
      ExV2HistorySummary.fromJson(await _client.getJson('/history/summary'));

  Future<List<JsonMap>> walletTransactions() =>
      _readMaps('/wallet/transactions');

  Future<List<JsonMap>> deposits() => _readMaps('/deposits');

  Future<List<JsonMap>> withdrawals() => _readMaps('/withdrawals');

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

  Future<void> closePosition({
    required String positionId,
    double? volume,
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.postJson(
      '/positions/$positionId/close',
      body: {'volume': volume},
      metadata: metadata,
    );
  }

  Future<void> partialClose({
    required String positionId,
    required double volume,
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.postJson(
      '/positions/$positionId/partial-close',
      body: {'volume': volume},
      metadata: metadata,
    );
  }

  Future<void> closeBy({
    required String positionId,
    required String oppositePositionId,
    required ExV2CommandMetadata metadata,
  }) async {
    await _client.postJson(
      '/positions/$positionId/close-by',
      body: {'oppositePositionId': oppositePositionId},
      metadata: metadata,
    );
  }

  Future<JsonMap> createDeposit({
    required double amount,
    required String currency,
    required String method,
    required String reference,
    required ExV2CommandMetadata metadata,
  }) => _client.postJson(
    '/deposits',
    body: {
      'amount': amount,
      'currency': currency,
      'method': method,
      'reference': reference,
    },
    metadata: metadata,
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
}

List<JsonMap> _maps(List<dynamic> values) => values
    .map((value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.cast<String, dynamic>();
      throw const FormatException('EX V2 list contains a non-object value');
    })
    .toList(growable: false);
