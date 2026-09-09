import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/trade/presentation/trade_formatters.dart';

void main() {
  test('gold symbols with and without broker suffix keep three digits', () {
    expect(tradePriceDigitsForSymbol('XAUUSD'), 3);
    expect(tradePriceDigitsForSymbol('XAUUSD+'), 3);
    expect(formatTradePrice('XAUUSD+', 4377.441), '4377.441');
  });
}
