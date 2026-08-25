import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

abstract final class ExV2DemoMapper {
  static DemoHistoryPosition historyPosition(JsonMap json) {
    final id = _firstString(json, const ['id', 'positionId']);
    final symbol = _firstString(json, const ['symbol', 'title']);
    final profit = _firstDouble(json, const ['profit', 'realizedProfit']);
    final time = _firstDate(json, const [
      'closedAt',
      'closedAtUtc',
      'createdAt',
      'createdAtUtc',
      'time',
      'updatedAt',
      'updatedAtUtc',
    ]);
    return DemoHistoryPosition(
      id: id,
      title: symbol,
      side: _optionalString(json, const ['side'])?.toUpperCase(),
      volume: _optionalDouble(json, const [
        'volume',
        'initialVolume',
        'remainingVolume',
      ]),
      openPrice: _optionalDouble(json, const ['openPrice', 'entryPrice']),
      closePrice: _optionalDouble(json, const ['closePrice', 'exitPrice']),
      profit: profit,
      time: dateLabel(time),
      subtitle: _optionalString(json, const ['description', 'subtitle']),
    );
  }

  static DemoOrder historyOrder(JsonMap json) {
    final openedAt = _firstDate(json, const [
      'openedAt',
      'createdAt',
      'createdAtUtc',
    ]);
    final openPrice = _firstDouble(json, const [
      'openPrice',
      'requestedPrice',
      'executedPrice',
    ]);
    final rawStatus = _firstString(json, const ['status']).toLowerCase();
    final status = switch (rawStatus) {
      'open' || 'closed' => 'filled',
      _ => rawStatus,
    };
    return DemoOrder(
      id: _firstString(json, const ['id', 'orderId']),
      symbol: _firstString(json, const ['symbol', 'title']),
      side: _firstString(json, const ['side']).toUpperCase(),
      type: _optionalString(json, const ['type', 'orderType']) ?? 'Market',
      volume: _firstDouble(json, const ['volume']),
      requestedPrice: openPrice,
      executedPrice: openPrice,
      status: status,
      time: dateLabel(openedAt),
    );
  }

  static DemoDeal historyDeal(JsonMap json) {
    final type = _firstString(json, const ['dealType', 'type']);
    return DemoDeal(
      id: _firstString(json, const ['id', 'dealId']),
      symbol: _firstString(json, const ['symbol', 'title']),
      side: _firstString(json, const ['side']).toUpperCase(),
      volume: _firstDouble(json, const ['volume']),
      price: _firstDouble(json, const ['price']),
      profit: _firstDouble(json, const ['profit']),
      time: dateLabel(
        _firstDate(json, const ['createdAt', 'createdAtUtc', 'time']),
      ),
      entry: _isExitDealType(type) ? 'out' : 'in',
      orderId: _optionalString(json, const ['orderId']) ?? '',
      positionId: _optionalString(json, const ['positionId']) ?? '',
    );
  }

  static DemoPosition position(ExV2Position value) => DemoPosition(
    id: value.id,
    symbol: value.symbol,
    side: value.side,
    volume: value.remainingVolume,
    openPrice: value.entryPrice,
    currentPrice: value.entryPrice,
    profit: 0,
    stopLoss: value.stopLoss,
    takeProfit: value.takeProfit,
    openedAt: dateLabel(value.createdAt),
  );

  static DemoPendingOrder pendingOrder(ExV2Order value) {
    final price = value.requestedPrice;
    if (price == null) {
      throw FormatException('Pending order ${value.id} has no requestedPrice');
    }
    return DemoPendingOrder(
      id: value.id,
      symbol: value.symbol,
      side: value.side,
      type: orderType(value),
      volume: value.volume,
      price: price,
      createdAt: dateLabel(value.createdAt),
      status: value.status,
      stopLoss: value.stopLoss,
      takeProfit: value.takeProfit,
    );
  }

  static DemoOrder order(ExV2Order value) => DemoOrder(
    id: value.id,
    symbol: value.symbol,
    side: value.side,
    type: orderType(value),
    volume: value.volume,
    requestedPrice: value.requestedPrice ?? value.executedPrice ?? 0,
    executedPrice: value.executedPrice,
    status: value.status,
    time: dateLabel(value.createdAt),
  );

  static DemoDeal deal(ExV2Deal value) => DemoDeal(
    id: value.id,
    symbol: value.symbol,
    side: value.side,
    volume: value.volume,
    price: value.price,
    profit: value.profit,
    time: dateLabel(value.createdAt),
    entry: _isExitDealType(value.type) ? 'out' : 'in',
    positionId: value.positionId,
  );

  static String orderType(ExV2Order value) {
    final raw = value.type.trim().toLowerCase();
    if (raw.contains('buy') || raw.contains('sell')) {
      return raw.split(RegExp(r'\s+')).map(_capitalize).join(' ');
    }
    if (raw == 'market') return 'Market';
    return '${_capitalize(value.side.toLowerCase())} ${_capitalize(raw)}';
  }

  static String dateLabel(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static String _capitalize(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

  static bool _isExitDealType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[_-]+'),
      ' ',
    );
    return normalized.contains('close') || normalized.contains('out');
  }

  static String _firstString(JsonMap json, List<String> keys) {
    final value = _optionalString(json, keys);
    if (value != null && value.isNotEmpty) return value;
    throw FormatException('EX V2 history field ${keys.join('/')} is missing');
  }

  static String? _optionalString(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String) return value;
    }
    return null;
  }

  static double _firstDouble(JsonMap json, List<String> keys) {
    final value = _optionalDouble(json, keys);
    if (value != null) return value;
    throw FormatException('EX V2 history field ${keys.join('/')} is missing');
  }

  static double? _optionalDouble(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static DateTime _firstDate(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toUtc();
      }
    }
    throw FormatException('EX V2 history date ${keys.join('/')} is missing');
  }
}
