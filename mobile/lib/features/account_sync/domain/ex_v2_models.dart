typedef JsonMap = Map<String, dynamic>;

final class ExV2Bootstrap {
  const ExV2Bootstrap({
    required this.serverTime,
    required this.version,
    required this.device,
    required this.account,
    required this.summary,
    required this.positions,
    required this.pendingOrders,
    required this.recentDeals,
    required this.wallet,
    required this.performance,
    required this.connection,
    required this.integrityWarnings,
    this.recentDeposits = const [],
    this.historySummary = const ExV2HistorySummary.empty(),
  });

  factory ExV2Bootstrap.fromJson(JsonMap json) {
    final summary = ExV2AccountSummary.fromJson(_map(json, 'summary'));
    final account = ExV2Account.fromJson(
      _map(json, 'activeAccount'),
      fallbackCurrency: summary.currency,
    );
    if (account.id != summary.accountId) {
      throw const FormatException(
        'EX V2 summary account must match the active account',
      );
    }
    return ExV2Bootstrap(
      serverTime: _date(json, 'serverTime'),
      version: _integer(json, 'version'),
      device: ExV2Device.fromJson(_map(json, 'device')),
      account: account,
      summary: summary,
      positions: _list(json, 'positions', ExV2Position.fromJson),
      pendingOrders: _list(json, 'pendingOrders', ExV2Order.fromJson),
      recentDeals: _list(json, 'recentDeals', ExV2Deal.fromJson),
      wallet: ExV2Wallet.fromJson(
        _map(json, 'wallet'),
        fallbackCurrency: summary.currency,
      ),
      performance: ExV2Performance.fromJson(_map(json, 'performance')),
      connection: ExV2Connection.fromJson(_map(json, 'connection')),
      integrityWarnings: _integer(json, 'integrityWarnings'),
      recentDeposits: _list(json, 'recentDeposits', ExV2Deposit.fromJson),
      historySummary: json['historySummary'] == null
          ? const ExV2HistorySummary.empty()
          : ExV2HistorySummary.fromJson(_map(json, 'historySummary')),
    );
  }

  final DateTime serverTime;
  final int version;
  final ExV2Device device;
  final ExV2Account account;
  final ExV2AccountSummary summary;
  final List<ExV2Position> positions;
  final List<ExV2Order> pendingOrders;
  final List<ExV2Deal> recentDeals;
  final ExV2Wallet wallet;
  final ExV2Performance performance;
  final ExV2Connection connection;
  final int integrityWarnings;
  final List<ExV2Deposit> recentDeposits;
  final ExV2HistorySummary historySummary;

  ExV2Bootstrap copyWith({
    DateTime? serverTime,
    int? version,
    ExV2AccountSummary? summary,
    List<ExV2Position>? positions,
    List<ExV2Deal>? recentDeals,
    List<ExV2Deposit>? recentDeposits,
    ExV2HistorySummary? historySummary,
  }) => ExV2Bootstrap(
    serverTime: serverTime ?? this.serverTime,
    version: version ?? this.version,
    device: device,
    account: account,
    summary: summary ?? this.summary,
    positions: positions ?? this.positions,
    pendingOrders: pendingOrders,
    recentDeals: recentDeals ?? this.recentDeals,
    wallet: wallet,
    performance: performance,
    connection: connection,
    integrityWarnings: integrityWarnings,
    recentDeposits: recentDeposits ?? this.recentDeposits,
    historySummary: historySummary ?? this.historySummary,
  );
}

final class ExV2Device {
  const ExV2Device({required this.id, required this.name});

  factory ExV2Device.fromJson(JsonMap json) => ExV2Device(
    id: _string(json, 'id'),
    name: _stringOr(json, 'name', 'Thiết bị'),
  );

  final String id;
  final String name;
}

final class ExV2Account {
  const ExV2Account({
    required this.id,
    required this.accountCode,
    required this.name,
    required this.currency,
    required this.status,
  });

  factory ExV2Account.fromJson(
    JsonMap json, {
    String fallbackCurrency = 'USD',
  }) {
    final id = _string(json, 'id');
    final accountCode = _stringOr(json, 'accountCode', id);
    return ExV2Account(
      id: id,
      accountCode: accountCode,
      name: _stringOr(json, 'name', accountCode),
      currency: _stringOr(json, 'currency', fallbackCurrency),
      status: _stringOr(json, 'status', 'unknown'),
    );
  }

  final String id;
  final String accountCode;
  final String name;
  final String currency;
  final String status;
}

final class ExV2AccountSummary {
  const ExV2AccountSummary({
    required this.accountId,
    required this.currency,
    required this.balance,
    required this.equity,
    required this.profit,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.updatedAt,
    this.positionValuations,
  });

  factory ExV2AccountSummary.fromJson(JsonMap json) => ExV2AccountSummary(
    accountId: _string(json, 'accountId'),
    currency: _string(json, 'currency'),
    balance: _double(json, 'balance'),
    equity: _double(json, 'equity'),
    profit: _double(json, 'profit'),
    margin: _double(json, 'margin'),
    freeMargin: _double(json, 'freeMargin'),
    marginLevel: _double(json, 'marginLevel'),
    updatedAt: _date(json, 'updatedAt'),
    positionValuations: _nullableList(
      json,
      'positionValuations',
      ExV2PositionValuation.fromJson,
    ),
  );

  final String accountId;
  final String currency;
  final double balance;
  final double equity;
  final double profit;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final DateTime updatedAt;
  final List<ExV2PositionValuation>? positionValuations;
}

final class ExV2PositionValuation {
  const ExV2PositionValuation({
    required this.positionId,
    required this.symbol,
    required this.currentPrice,
    required this.floatingProfit,
  });

  factory ExV2PositionValuation.fromJson(JsonMap json) => ExV2PositionValuation(
    positionId: _string(json, 'positionId'),
    symbol: _string(json, 'symbol'),
    currentPrice: _double(json, 'currentPrice'),
    floatingProfit: _double(json, 'floatingProfit'),
  );

  final String positionId;
  final String symbol;
  final double currentPrice;
  final double floatingProfit;
}

final class ExV2HistorySummary {
  const ExV2HistorySummary({
    required this.deposit,
    required this.withdrawal,
    required this.realizedProfit,
    required this.swap,
    required this.commission,
    required this.netChange,
  });

  const ExV2HistorySummary.empty()
    : deposit = 0,
      withdrawal = 0,
      realizedProfit = 0,
      swap = 0,
      commission = 0,
      netChange = 0;

  factory ExV2HistorySummary.fromJson(JsonMap json) => ExV2HistorySummary(
    deposit: _double(json, 'deposit'),
    withdrawal: _double(json, 'withdrawal'),
    realizedProfit: _double(json, 'realizedProfit'),
    swap: _double(json, 'swap'),
    commission: _double(json, 'commission'),
    netChange: _double(json, 'netChange'),
  );

  final double deposit;
  final double withdrawal;
  final double realizedProfit;
  final double swap;
  final double commission;
  final double netChange;
}

enum ExV2DepositStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const ExV2DepositStatus(this.wireName);

  factory ExV2DepositStatus.fromWireName(String value) =>
      switch (value.trim().toLowerCase()) {
        'pending' => ExV2DepositStatus.pending,
        'approved' => ExV2DepositStatus.approved,
        'rejected' => ExV2DepositStatus.rejected,
        _ => throw FormatException('Unsupported EX V2 deposit status: $value'),
      };

  final String wireName;
}

final class ExV2Deposit {
  const ExV2Deposit({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.reference,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.approvedAt,
    required this.rejectedAt,
    required this.transactionId,
    required this.snapshotVersion,
  });

  factory ExV2Deposit.fromJson(JsonMap json) => ExV2Deposit(
    id: _string(json, 'id'),
    accountId: _string(json, 'accountId'),
    amount: _double(json, 'amount'),
    currency: _string(json, 'currency'),
    method: _string(json, 'method'),
    reference: _nullableString(json, 'reference'),
    status: ExV2DepositStatus.fromWireName(_string(json, 'status')),
    createdAt: _date(json, 'createdAtUtc'),
    updatedAt: _date(json, 'updatedAtUtc'),
    approvedAt: _nullableDate(json, 'approvedAtUtc'),
    rejectedAt: _nullableDate(json, 'rejectedAtUtc'),
    transactionId: _nullableString(json, 'transactionId'),
    snapshotVersion: _integer(json, 'snapshotVersion'),
  );

  final String id;
  final String accountId;
  final double amount;
  final String currency;
  final String method;
  final String? reference;
  final ExV2DepositStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? transactionId;
  final int snapshotVersion;

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'accountId': accountId,
    'amount': amount,
    'currency': currency,
    'method': method,
    'reference': reference,
    'status': status.wireName,
    'createdAtUtc': createdAt.toIso8601String(),
    'updatedAtUtc': updatedAt.toIso8601String(),
    'approvedAtUtc': approvedAt?.toIso8601String(),
    'rejectedAtUtc': rejectedAt?.toIso8601String(),
    'transactionId': transactionId,
    'snapshotVersion': snapshotVersion,
  };
}

final class ExV2DepositTransaction {
  const ExV2DepositTransaction({
    required this.id,
    required this.depositRequestId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.snapshotVersion,
  });

  factory ExV2DepositTransaction.fromJson(JsonMap json) =>
      ExV2DepositTransaction(
        id: _string(json, 'id'),
        depositRequestId: _string(json, 'depositRequestId'),
        accountId: _string(json, 'accountId'),
        type: _string(json, 'type'),
        amount: _double(json, 'amount'),
        currency: _string(json, 'currency'),
        status: _string(json, 'status'),
        createdAt: _date(json, 'createdAtUtc'),
        snapshotVersion: _integer(json, 'snapshotVersion'),
      );

  final String id;
  final String depositRequestId;
  final String accountId;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final int snapshotVersion;

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'depositRequestId': depositRequestId,
    'accountId': accountId,
    'type': type,
    'amount': amount,
    'amountValue': amount,
    'currency': currency,
    'status': status,
    'createdAtUtc': createdAt.toIso8601String(),
    'timestamp': createdAt.toIso8601String(),
    'snapshotVersion': snapshotVersion,
  };
}

final class ExV2DepositDecision {
  const ExV2DepositDecision({
    required this.deposit,
    required this.transaction,
    required this.accountSummary,
    required this.historySummary,
    required this.version,
    required this.committedAt,
  });

  factory ExV2DepositDecision.fromJson(JsonMap json) => ExV2DepositDecision(
    deposit: ExV2Deposit.fromJson(_map(json, 'deposit')),
    transaction: json['transaction'] == null
        ? null
        : ExV2DepositTransaction.fromJson(_map(json, 'transaction')),
    accountSummary: ExV2AccountSummary.fromJson(_map(json, 'accountSummary')),
    historySummary: ExV2HistorySummary.fromJson(_map(json, 'historySummary')),
    version: _integer(json, 'version'),
    committedAt: _date(json, 'committedAtUtc'),
  );

  final ExV2Deposit deposit;
  final ExV2DepositTransaction? transaction;
  final ExV2AccountSummary accountSummary;
  final ExV2HistorySummary historySummary;
  final int version;
  final DateTime committedAt;
}

enum ExV2CloseMode {
  full('full'),
  partial('partial'),
  closeBy('close_by');

  const ExV2CloseMode(this.wireName);

  factory ExV2CloseMode.fromWireName(String value) => switch (value.trim()) {
    'full' => ExV2CloseMode.full,
    'partial' => ExV2CloseMode.partial,
    'close_by' => ExV2CloseMode.closeBy,
    _ => throw FormatException('Unsupported EX V2 close mode: $value'),
  };

  final String wireName;
}

final class ExV2ClosePositionResponse {
  const ExV2ClosePositionResponse({required this.position, this.sync});

  factory ExV2ClosePositionResponse.fromJson(JsonMap json) =>
      ExV2ClosePositionResponse(
        position: ExV2Position.fromJson(json),
        sync: _optionalCloseSync(json),
      );

  final ExV2Position position;
  final ExV2CloseSync? sync;
}

final class ExV2CloseByResponse {
  const ExV2CloseByResponse({
    required this.position,
    required this.oppositePosition,
    required this.closedVolume,
    required this.version,
    this.sync,
  });

  factory ExV2CloseByResponse.fromJson(JsonMap json) => ExV2CloseByResponse(
    position: ExV2Position.fromJson(_map(json, 'position')),
    oppositePosition: ExV2Position.fromJson(_map(json, 'oppositePosition')),
    closedVolume: _double(json, 'closedVolume'),
    version: _integer(json, 'version'),
    sync: _optionalCloseSync(json),
  );

  final ExV2Position position;
  final ExV2Position oppositePosition;
  final double closedVolume;
  final int version;
  final ExV2CloseSync? sync;
}

ExV2CloseSync? _optionalCloseSync(JsonMap json) {
  final value = json['sync'];
  if (value == null) return null;
  try {
    if (value is Map<String, dynamic>) return ExV2CloseSync.fromJson(value);
    if (value is Map) {
      return ExV2CloseSync.fromJson(value.cast<String, dynamic>());
    }
  } on FormatException {
    return null;
  }
  return null;
}

final class ExV2CloseSync {
  const ExV2CloseSync({
    required this.accountId,
    required this.version,
    required this.committedAt,
    required this.operation,
    required this.affectedPositions,
    required this.closedPositions,
    required this.orders,
    required this.deals,
    required this.accountSummary,
    required this.historySummary,
  });

  factory ExV2CloseSync.fromJson(JsonMap json) => ExV2CloseSync(
    accountId: _string(json, 'accountId'),
    version: _integer(json, 'version'),
    committedAt: _date(json, 'committedAtUtc'),
    operation: ExV2CloseOperation.fromJson(_map(json, 'operation')),
    affectedPositions: _list(json, 'affectedPositions', ExV2Position.fromJson),
    closedPositions: _mapList(json, 'closedPositions'),
    orders: _mapList(json, 'orders'),
    deals: _list(json, 'deals', ExV2Deal.fromJson),
    accountSummary: ExV2AccountSummary.fromJson(_map(json, 'accountSummary')),
    historySummary: ExV2HistorySummary.fromJson(_map(json, 'historySummary')),
  );

  final String accountId;
  final int version;
  final DateTime committedAt;
  final ExV2CloseOperation operation;
  final List<ExV2Position> affectedPositions;
  final List<JsonMap> closedPositions;
  final List<JsonMap> orders;
  final List<ExV2Deal> deals;
  final ExV2AccountSummary accountSummary;
  final ExV2HistorySummary historySummary;
}

final class ExV2CloseOperation {
  const ExV2CloseOperation({
    required this.mode,
    required this.idempotencyKey,
    required this.correlationId,
  });

  factory ExV2CloseOperation.fromJson(JsonMap json) => ExV2CloseOperation(
    mode: ExV2CloseMode.fromWireName(_string(json, 'mode')),
    idempotencyKey: _string(json, 'idempotencyKey'),
    correlationId: _string(json, 'correlationId'),
  );

  final ExV2CloseMode mode;
  final String idempotencyKey;
  final String correlationId;
}

final class ExV2Position {
  const ExV2Position({
    required this.id,
    required this.symbol,
    required this.side,
    required this.initialVolume,
    required this.remainingVolume,
    required this.entryPrice,
    required this.realizedProfit,
    required this.status,
    required this.createdAt,
    this.stopLoss,
    this.takeProfit,
    this.closedAt,
    this.rowVersion,
  });

  factory ExV2Position.fromJson(JsonMap json) => ExV2Position(
    id: _string(json, 'id'),
    symbol: _string(json, 'symbol'),
    side: _string(json, 'side').toUpperCase(),
    initialVolume: _double(json, 'initialVolume'),
    remainingVolume: _double(json, 'remainingVolume'),
    entryPrice: _double(json, 'entryPrice'),
    stopLoss: _nullableDouble(json, 'stopLoss'),
    takeProfit: _nullableDouble(json, 'takeProfit'),
    realizedProfit: _double(json, 'realizedProfit'),
    status: _string(json, 'status'),
    createdAt: _date(json, 'createdAt'),
    closedAt: _nullableDate(json, 'closedAt'),
    rowVersion: _nullableString(json, 'rowVersion'),
  );

  final String id;
  final String symbol;
  final String side;
  final double initialVolume;
  final double remainingVolume;
  final double entryPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double realizedProfit;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;
  final String? rowVersion;
}

final class ExV2Order {
  const ExV2Order({
    required this.id,
    required this.clientOrderId,
    required this.symbol,
    required this.type,
    required this.side,
    required this.volume,
    required this.status,
    required this.createdAt,
    required this.version,
    this.requestedPrice,
    this.executedPrice,
    this.stopLoss,
    this.takeProfit,
    this.rowVersion,
  });

  factory ExV2Order.fromJson(JsonMap json) => ExV2Order(
    id: _string(json, 'id'),
    clientOrderId: _string(json, 'clientOrderId'),
    symbol: _string(json, 'symbol'),
    type: _string(json, 'type'),
    side: _string(json, 'side').toUpperCase(),
    volume: _double(json, 'volume'),
    requestedPrice: _nullableDouble(json, 'requestedPrice'),
    executedPrice: _nullableDouble(json, 'executedPrice'),
    stopLoss: _nullableDouble(json, 'stopLoss'),
    takeProfit: _nullableDouble(json, 'takeProfit'),
    status: _string(json, 'status'),
    createdAt: _date(json, 'createdAt'),
    version: _integer(json, 'version'),
    rowVersion: _nullableString(json, 'rowVersion'),
  );

  final String id;
  final String clientOrderId;
  final String symbol;
  final String type;
  final String side;
  final double volume;
  final double? requestedPrice;
  final double? executedPrice;
  final double? stopLoss;
  final double? takeProfit;
  final String status;
  final DateTime createdAt;
  final int version;
  final String? rowVersion;
}

final class ExV2Deal {
  const ExV2Deal({
    required this.id,
    required this.orderId,
    required this.positionId,
    required this.type,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.price,
    required this.profit,
    required this.createdAt,
  });

  factory ExV2Deal.fromJson(JsonMap json) => ExV2Deal(
    id: _string(json, 'id'),
    orderId: _nullableString(json, 'orderId'),
    positionId: _nullableString(json, 'positionId'),
    type: _string(json, 'type'),
    symbol: _string(json, 'symbol'),
    side: _string(json, 'side').toUpperCase(),
    volume: _double(json, 'volume'),
    price: _double(json, 'price'),
    profit: _double(json, 'profit'),
    createdAt: _date(json, 'createdAtUtc'),
  );

  final String id;
  final String? orderId;
  final String? positionId;
  final String type;
  final String symbol;
  final String side;
  final double volume;
  final double price;
  final double profit;
  final DateTime createdAt;
}

final class ExV2Wallet {
  const ExV2Wallet({
    required this.currency,
    required this.availableBalance,
    required this.lockedBalance,
    required this.totalBalance,
  });

  factory ExV2Wallet.fromJson(
    JsonMap json, {
    String fallbackCurrency = 'USD',
  }) => ExV2Wallet(
    currency: _stringOr(json, 'currency', fallbackCurrency),
    availableBalance: _double(json, 'availableBalance'),
    lockedBalance: _double(json, 'lockedBalance'),
    totalBalance: _double(json, 'totalBalance'),
  );

  final String currency;
  final double availableBalance;
  final double lockedBalance;
  final double totalBalance;
}

final class ExV2Performance {
  const ExV2Performance({
    required this.netProfit,
    required this.grossProfit,
    required this.grossLoss,
    required this.floatingProfit,
    required this.tradingVolume,
    required this.integrityWarnings,
    this.updatedAt,
  });

  factory ExV2Performance.fromJson(JsonMap json) => ExV2Performance(
    netProfit: _double(json, 'netProfit'),
    grossProfit: _double(json, 'grossProfit'),
    grossLoss: _double(json, 'grossLoss'),
    floatingProfit: _double(json, 'floatingProfit'),
    tradingVolume: _double(json, 'tradingVolume'),
    updatedAt: _nullableDate(json, 'updatedAt'),
    integrityWarnings: _integer(json, 'integrityWarnings'),
  );

  final double netProfit;
  final double grossProfit;
  final double grossLoss;
  final double floatingProfit;
  final double tradingVolume;
  final DateTime? updatedAt;
  final int integrityWarnings;
}

final class ExV2Connection {
  const ExV2Connection({required this.marketFeedStatus, this.lastMarketTickAt});

  factory ExV2Connection.fromJson(JsonMap json) => ExV2Connection(
    marketFeedStatus: _stringOr(json, 'marketFeedStatus', 'unknown'),
    lastMarketTickAt: _nullableDate(json, 'lastMarketTickAt'),
  );

  final String marketFeedStatus;
  final DateTime? lastMarketTickAt;
}

JsonMap _map(JsonMap json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('EX V2 field "$key" must be an object');
}

List<T> _list<T>(JsonMap json, String key, T Function(JsonMap) parse) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('EX V2 field "$key" must be a list');
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) return parse(item);
        if (item is Map) return parse(item.cast<String, dynamic>());
        throw FormatException('EX V2 field "$key" contains a non-object value');
      })
      .toList(growable: false);
}

List<T>? _nullableList<T>(JsonMap json, String key, T Function(JsonMap) parse) {
  if (json[key] == null) return null;
  return _list(json, key, parse);
}

List<JsonMap> _mapList(JsonMap json, String key) =>
    _list<JsonMap>(json, key, (value) => Map.unmodifiable(value));

String _string(JsonMap json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('EX V2 field "$key" must be a non-empty string');
}

String _stringOr(JsonMap json, String key, String fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is String) return value.trim().isEmpty ? fallback : value;
  throw FormatException('EX V2 field "$key" must be a string or null');
}

String? _nullableString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('EX V2 field "$key" must be a string or null');
}

double _double(JsonMap json, String key) {
  final value = json[key];
  if (value is num) {
    final parsed = value.toDouble();
    if (parsed.isFinite) return parsed;
  }
  throw FormatException('EX V2 field "$key" must be numeric');
}

double? _nullableDouble(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) {
    final parsed = value.toDouble();
    if (parsed.isFinite) return parsed;
  }
  throw FormatException('EX V2 field "$key" must be numeric or null');
}

int _integer(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('EX V2 field "$key" must be an integer');
}

DateTime _date(JsonMap json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('EX V2 field "$key" is invalid');
  return parsed.toUtc();
}

DateTime? _nullableDate(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('EX V2 field "$key" must be a date string or null');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('EX V2 field "$key" is invalid');
  return parsed.toUtc();
}
