import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

final class SecureChartViewSessionStore implements ChartViewSessionStore {
  const SecureChartViewSessionStore(this._storage);

  static const storageKey = 'chart_view_session_v1';
  static const _version = 1;

  final FlutterSecureStorage _storage;

  @override
  Future<ChartViewSessionState> read() async {
    try {
      final encoded = await _storage.read(key: storageKey);
      if (encoded == null || encoded.isEmpty) {
        return ChartViewSessionState.empty;
      }
      final json = jsonDecode(encoded);
      if (json is! Map<String, dynamic> || json['version'] != _version) {
        throw const FormatException('Unsupported chart session');
      }
      final activeSymbol = json['activeSymbol'];
      final encodedViews = json['views'];
      if (activeSymbol != null && activeSymbol is! String) {
        throw const FormatException('Invalid active chart symbol');
      }
      if (encodedViews is! List) {
        throw const FormatException('Invalid chart session views');
      }
      final views = <String, ChartViewSnapshot>{};
      for (final encodedView in encodedViews) {
        if (encodedView is! Map) {
          throw const FormatException('Invalid chart view');
        }
        final view = _viewFromJson(encodedView.cast<String, dynamic>());
        views[chartSymbolKey(view.symbol)] = view;
      }
      return ChartViewSessionState(
        activeSymbol: activeSymbol as String?,
        views: views,
      );
    } on Object {
      return ChartViewSessionState.empty;
    }
  }

  @override
  Future<void> write(ChartViewSessionState value) => _storage.write(
    key: storageKey,
    value: jsonEncode({
      'version': _version,
      'activeSymbol': value.activeSymbol,
      'views': value.views.values.map(_viewToJson).toList(growable: false),
    }),
  );

  static Map<String, Object?> _viewToJson(ChartViewSnapshot value) => {
    'symbol': value.symbol,
    'timeframe': value.timeframe,
    'barSpacing': value.viewport.barSpacing,
    'scrollOffset': value.viewport.scrollOffset,
    'rightPadding': value.viewport.rightPadding,
    'priceCenter': value.priceViewport.centerPrice,
    'priceRange': value.priceViewport.range,
  };

  static ChartViewSnapshot _viewFromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'];
    final timeframe = json['timeframe'];
    if (symbol is! String ||
        symbol.trim().isEmpty ||
        timeframe is! String ||
        timeframe.trim().isEmpty) {
      throw const FormatException('Invalid chart view identity');
    }
    final barSpacing = _finiteDouble(json['barSpacing'], 'barSpacing');
    final scrollOffset = _finiteDouble(json['scrollOffset'], 'scrollOffset');
    final rightPadding = _finiteDouble(json['rightPadding'], 'rightPadding');
    final priceCenter = _nullableFiniteDouble(
      json['priceCenter'],
      'priceCenter',
    );
    final priceRange = _nullableFiniteDouble(json['priceRange'], 'priceRange');
    if ((priceCenter == null) != (priceRange == null) ||
        (priceRange != null && priceRange <= 0)) {
      throw const FormatException('Invalid chart price viewport');
    }
    return ChartViewSnapshot(
      symbol: symbol,
      timeframe: timeframe,
      viewport: ChartViewport(
        barSpacing: barSpacing,
        scrollOffset: scrollOffset,
        rightPadding: rightPadding,
      ),
      priceViewport: priceCenter == null
          ? const ChartPriceViewport.auto()
          : ChartPriceViewport.manual(
              centerPrice: priceCenter,
              range: priceRange!,
            ),
    );
  }

  static double _finiteDouble(Object? value, String field) {
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Invalid $field');
    }
    return value.toDouble();
  }

  static double? _nullableFiniteDouble(Object? value, String field) =>
      value == null ? null : _finiteDouble(value, field);
}
