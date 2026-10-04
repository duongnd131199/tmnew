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
  });

  factory ExV2Bootstrap.fromJson(JsonMap json) => ExV2Bootstrap(
    serverTime: _date(json, 'serverTime'),
    version: _integer(json, 'version'),
    device: ExV2Device.fromJson(_map(json, 'device')),
    account: ExV2Account.fromJson(_map(json, 'activeAccount')),
    summary: ExV2AccountSummary.fromJson(_map(json, 'summary')),
    positions: _list(json, 'positions', ExV2Position.fromJson),
    pendingOrders: _list(json, 'pendingOrders', ExV2Order.fromJson),
    recentDeals: _list(json, 'recentDeals', ExV2Deal.fromJson),
    wallet: ExV2Wallet.fromJson(_map(json, 'wallet')),
    performance: ExV2Performance.fromJson(_map(json, 'performance')),
    connection: ExV2Connection.fromJson(_map(json, 'connection')),
    integrityWarnings: _integer(json, 'integrityWarnings'),
  );

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
}

final class ExV2Device {
  const ExV2Device({required this.id, required this.name});

  factory ExV2Device.fromJson(JsonMap json) =>
      ExV2Device(id: _string(json, 'id'), name: _string(json, 'name'));

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

  factory ExV2Account.fromJson(JsonMap json) => ExV2Account(
    id: _string(json, 'id'),
    accountCode: _string(json, 'accountCode'),
    name: _string(json, 'name'),
    currency: _string(json, 'currency'),
    status: _string(json, 'status'),
  );

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
    required this.type,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.price,
    required this.profit,
    required this.createdAt,
    this.positionId = '',
  });

  factory ExV2Deal.fromJson(JsonMap json) => ExV2Deal(
    id: _string(json, 'id'),
    type: _string(json, 'type'),
    symbol: _string(json, 'symbol'),
    side: _string(json, 'side').toUpperCase(),
    volume: _double(json, 'volume'),
    price: _double(json, 'price'),
    profit: _double(json, 'profit'),
    createdAt: _date(json, 'createdAt'),
    positionId: _nullableString(json, 'positionId') ?? '',
  );

  final String id;
  final String type;
  final String symbol;
  final String side;
  final double volume;
  final double price;
  final double profit;
  final DateTime createdAt;
  final String positionId;
}

final class ExV2Wallet {
  const ExV2Wallet({
    required this.currency,
    required this.availableBalance,
    required this.lockedBalance,
    required this.totalBalance,
  });

  factory ExV2Wallet.fromJson(JsonMap json) => ExV2Wallet(
    currency: _string(json, 'currency'),
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
    marketFeedStatus: _string(json, 'marketFeedStatus'),
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

String _string(JsonMap json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('EX V2 field "$key" must be a non-empty string');
}

String? _nullableString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('EX V2 field "$key" must be a string or null');
}

double _double(JsonMap json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('EX V2 field "$key" must be numeric');
}

double? _nullableDouble(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
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
