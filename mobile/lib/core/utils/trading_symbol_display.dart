String displayTradingSymbol(String symbol) =>
    symbol == 'XAUUSD+' ? 'XAUUSD' : symbol;

String displayTradingSymbolText(String text) =>
    text.replaceAll('XAUUSD+', 'XAUUSD');
