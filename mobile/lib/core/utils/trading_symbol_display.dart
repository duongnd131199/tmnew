String displayTradingSymbol(String symbol) => switch (symbol) {
  'XAUUSD+' => 'XAUUSD',
  'BTCUSD' => 'BTCUSDT',
  _ => symbol,
};

String displayTradingSymbolText(String text) => text
    .replaceAll('XAUUSD+', 'XAUUSD')
    .replaceAll(RegExp(r'\bBTCUSD\b'), 'BTCUSDT');

String displayMarketWatchSymbol(String symbol) =>
    symbol == 'XAUUSD+' ? 'XAUUSD' : symbol;
