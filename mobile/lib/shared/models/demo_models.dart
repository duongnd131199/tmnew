class DemoQuote {
  const DemoQuote({
    required this.symbol,
    required this.name,
    required this.bid,
    required this.ask,
    required this.changePercent,
    this.sourceTimestamp,
    this.previousClose,
    this.dailyLow,
    this.dailyHigh,
  });

  final String symbol;
  final String name;
  final double bid;
  final double ask;
  final double changePercent;
  final DateTime? sourceTimestamp;
  final double? previousClose;
  final double? dailyLow;
  final double? dailyHigh;

  bool get isUp => changePercent >= 0;
}

class DemoPosition {
  const DemoPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.profit,
    this.stopLoss,
    this.takeProfit,
    this.openedAt = '',
  });

  final String id;
  final String symbol;
  final String side;
  final double volume;
  final double openPrice;
  final double currentPrice;
  final double profit;
  final double? stopLoss;
  final double? takeProfit;
  final String openedAt;

  DemoPosition copyWith({
    String? id,
    String? symbol,
    String? side,
    double? volume,
    double? openPrice,
    double? currentPrice,
    double? profit,
    double? stopLoss,
    double? takeProfit,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
    String? openedAt,
  }) {
    return DemoPosition(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      volume: volume ?? this.volume,
      openPrice: openPrice ?? this.openPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      profit: profit ?? this.profit,
      stopLoss: clearStopLoss ? null : (stopLoss ?? this.stopLoss),
      takeProfit: clearTakeProfit ? null : (takeProfit ?? this.takeProfit),
      openedAt: openedAt ?? this.openedAt,
    );
  }
}

class DemoPendingOrder {
  const DemoPendingOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.volume,
    required this.price,
    required this.createdAt,
    this.status = 'pending',
    this.stopLoss,
    this.takeProfit,
  });

  final String id;
  final String symbol;
  final String side;
  final String type;
  final double volume;
  final double price;
  final String createdAt;
  final String status;
  final double? stopLoss;
  final double? takeProfit;

  bool get isLimit => type.toLowerCase().contains('limit');

  DemoPendingOrder copyWith({
    double? volume,
    double? price,
    double? stopLoss,
    double? takeProfit,
    String? status,
    bool clearStopLoss = false,
    bool clearTakeProfit = false,
  }) {
    return DemoPendingOrder(
      id: id,
      symbol: symbol,
      side: side,
      type: type,
      volume: volume ?? this.volume,
      price: price ?? this.price,
      createdAt: createdAt,
      status: status ?? this.status,
      stopLoss: clearStopLoss ? null : (stopLoss ?? this.stopLoss),
      takeProfit: clearTakeProfit ? null : (takeProfit ?? this.takeProfit),
    );
  }
}

class DemoOrder {
  const DemoOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.volume,
    required this.requestedPrice,
    required this.status,
    required this.time,
    this.executedPrice,
  });

  final String id;
  final String symbol;
  final String side;
  final String type;
  final double volume;
  final double requestedPrice;
  final double? executedPrice;
  final String status;
  final String time;

  DemoOrder copyWith({
    double? requestedPrice,
    double? executedPrice,
    String? status,
    String? time,
  }) {
    return DemoOrder(
      id: id,
      symbol: symbol,
      side: side,
      type: type,
      volume: volume,
      requestedPrice: requestedPrice ?? this.requestedPrice,
      executedPrice: executedPrice ?? this.executedPrice,
      status: status ?? this.status,
      time: time ?? this.time,
    );
  }
}

class DemoDeal {
  const DemoDeal({
    required this.id,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.profit,
    required this.time,
    this.price = 0,
    this.status = 'filled',
    this.entry = 'in',
    this.orderId = '',
    this.positionId = '',
  });

  final String id;
  final String symbol;
  final String side;
  final double volume;
  final double profit;
  final String time;
  final double price;
  final String status;
  final String entry;
  final String orderId;
  final String positionId;
}

class DemoHistoryPosition {
  const DemoHistoryPosition({
    required this.id,
    required this.title,
    required this.profit,
    required this.time,
    this.side,
    this.volume,
    this.openPrice,
    this.closePrice,
    this.subtitle,
    this.referenceIsAuthoritative = false,
  });

  final String id;
  final String title;
  final String? side;
  final double? volume;
  final double? openPrice;
  final double? closePrice;
  final double profit;
  final String time;
  final String? subtitle;
  final bool referenceIsAuthoritative;

  bool get isBalance => side == null;
}
