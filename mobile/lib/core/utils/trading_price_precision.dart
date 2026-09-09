const int goldPriceFractionDigits = 3;

final RegExp _goldCurrencyPairPattern = RegExp(r'^XAU[A-Z]{3}');

bool isGoldTradingSymbol(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  return normalized == 'XAU' || _goldCurrencyPairPattern.hasMatch(normalized);
}

int goldAwarePriceFractionDigits(String symbol, {required int fallback}) =>
    isGoldTradingSymbol(symbol) ? goldPriceFractionDigits : fallback;
