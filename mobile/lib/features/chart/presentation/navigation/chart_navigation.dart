String defaultChartTimeframe(String symbol) {
  final normalized = symbol.endsWith('+')
      ? symbol.substring(0, symbol.length - 1)
      : symbol;
  return normalized == 'BTCUSD' ? 'H1' : 'H4';
}

String chartLocationForSymbol(String symbol, {String? timeframe}) {
  final selectedTimeframe = timeframe ?? defaultChartTimeframe(symbol);
  return '/chart?symbol=${Uri.encodeQueryComponent(symbol)}'
      '&timeframe=${Uri.encodeQueryComponent(selectedTimeframe)}';
}
