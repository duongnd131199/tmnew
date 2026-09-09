import 'package:trading_mobile/core/utils/trading_price_precision.dart';

String formatTradeVolume(double volume) =>
    volume >= 1 ? volume.toStringAsFixed(0) : volume.toStringAsFixed(2);

int tradePriceDigitsForSymbol(String symbol) =>
    goldAwarePriceFractionDigits(symbol, fallback: 2);

String formatTradePrice(String symbol, double value) =>
    value.toStringAsFixed(tradePriceDigitsForSymbol(symbol));

String formatPositionBulkOpenPrice(String symbol, double value) {
  final fixed = formatTradePrice(symbol, value);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
