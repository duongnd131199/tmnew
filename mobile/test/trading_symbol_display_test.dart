import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';

void main() {
  test('trading surfaces display BTCUSD as BTCUSDT', () {
    expect(displayTradingSymbol('BTCUSD'), 'BTCUSDT');
    expect(displayTradingSymbol('BTCUSDT'), 'BTCUSDT');
    expect(
      displayTradingSymbolText('BTCUSD buy; BTCUSDT sell'),
      'BTCUSDT buy; BTCUSDT sell',
    );
  });

  test('trading surfaces continue hiding the XAUUSD suffix', () {
    expect(displayTradingSymbol('XAUUSD+'), 'XAUUSD');
    expect(displayTradingSymbolText('XAUUSD+ buy'), 'XAUUSD buy');
  });

  test('Price surfaces keep BTCUSD while hiding the XAUUSD suffix', () {
    expect(displayMarketWatchSymbol('BTCUSD'), 'BTCUSD');
    expect(displayMarketWatchSymbol('XAUUSD+'), 'XAUUSD');
  });
}
