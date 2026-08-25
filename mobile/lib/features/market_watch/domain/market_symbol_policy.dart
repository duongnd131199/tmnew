String normalizeMarketSymbol(String symbol) {
  return symbol.endsWith('+') ? symbol.substring(0, symbol.length - 1) : symbol;
}

bool isProtectedMarketSymbol(String symbol) {
  return normalizeMarketSymbol(symbol) == 'XAUUSD';
}

bool canRemoveMarketSymbol(String symbol) {
  return !isProtectedMarketSymbol(symbol);
}

bool supportsDepthOfMarket(String symbol) {
  return normalizeMarketSymbol(symbol).startsWith('XAU');
}
