import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/utils/trading_price_precision.dart';

void main() {
  test('recognises gold symbols without treating the XAUG ETF as gold', () {
    expect(isGoldTradingSymbol('XAU'), isTrue);
    expect(isGoldTradingSymbol('XAUUSD'), isTrue);
    expect(isGoldTradingSymbol(' XauUsd+ '), isTrue);
    expect(isGoldTradingSymbol('XAUEUR'), isTrue);

    expect(isGoldTradingSymbol('XAUG'), isFalse);
    expect(isGoldTradingSymbol('EURUSD'), isFalse);
  });

  test('gold-aware precision keeps the caller fallback for other symbols', () {
    expect(goldAwarePriceFractionDigits('XAUUSD+', fallback: 2), 3);
    expect(goldAwarePriceFractionDigits('EURUSD', fallback: 2), 2);
    expect(goldAwarePriceFractionDigits('EURUSD', fallback: 5), 5);
    expect(goldAwarePriceFractionDigits('XAUG', fallback: 2), 2);
  });
}
