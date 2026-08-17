import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';

abstract final class ExV2HistoryReconciler {
  static List<JsonMap> enrichClosedPositions(
    List<JsonMap> positions,
    List<JsonMap> deals,
  ) => [
    for (final position in positions)
      if (_isClosed(position)) _enrich(position, deals),
  ];

  static JsonMap _enrich(JsonMap position, List<JsonMap> deals) {
    final enriched = <String, dynamic>{...position};
    final price = closePrice(position, deals);
    if (price != null) enriched['closePrice'] = price;
    return enriched;
  }

  static double? closePrice(JsonMap position, List<JsonMap> deals) {
    final directPrice = _number(position, const ['closePrice', 'exitPrice']);
    if (directPrice != null) return directPrice;

    final positionId = _normalizedString(position, const ['id', 'positionId']);
    if (positionId != null) {
      return _weightedPrice(
        deals.where(
          (deal) =>
              _isExitDeal(deal) &&
              _normalizedString(deal, const ['positionId']) == positionId,
        ),
      );
    }

    final symbol = _normalizedString(position, const ['symbol']);
    final closedAt = _date(position, const ['closedAt', 'closedAtUtc']);
    if (symbol == null || closedAt == null) return null;
    final candidates = deals.where((deal) {
      if (!_isExitDeal(deal)) return false;
      if (_normalizedString(deal, const ['symbol']) != symbol) return false;
      return _date(
            deal,
            const ['createdAt', 'createdAtUtc', 'time'],
          ) ==
          closedAt;
    }).toList(growable: false);
    final groupIds = candidates
        .map((deal) => _normalizedString(deal, const ['positionId']))
        .whereType<String>()
        .toSet();
    if (candidates.length == 1) return _weightedPrice(candidates);
    if (groupIds.length != 1 ||
        candidates.any(
          (deal) =>
              _normalizedString(deal, const ['positionId']) == null,
        )) {
      return null;
    }
    return _weightedPrice(candidates);
  }

  static double? _weightedPrice(Iterable<JsonMap> exits) {
    var weightedPrice = 0.0;
    var totalVolume = 0.0;
    for (final deal in exits) {
      final price = _number(deal, const ['price']);
      final volume = _number(deal, const ['volume']);
      if (price == null || volume == null || volume <= 0) return null;
      weightedPrice += price * volume;
      totalVolume += volume;
    }
    return totalVolume > 0 ? weightedPrice / totalVolume : null;
  }

  static bool _isClosed(JsonMap position) =>
      position['status']?.toString().trim().toLowerCase() == 'closed';

  static bool _isExitDeal(JsonMap deal) {
    final value = (deal['dealType'] ?? deal['type'] ?? deal['entry'])
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ');
    if (value == null) return false;
    return value == 'out' ||
        value == 'out by' ||
        value.contains('close') ||
        value.contains('exit');
  }

  static String? _normalizedString(JsonMap row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim().toLowerCase();
      }
    }
    return null;
  }

  static double? _number(JsonMap row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static DateTime? _date(JsonMap row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is! String) continue;
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }
}
