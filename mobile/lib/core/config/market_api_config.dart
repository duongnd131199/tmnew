class MarketApiConfig {
  static const publicBaseUrl = 'https://trochoi.top';

  static const production = MarketApiConfig(
    baseUrl: String.fromEnvironment(
      'MARKET_API_BASE_URL',
      defaultValue: publicBaseUrl,
    ),
  );

  const MarketApiConfig({
    this.baseUrl = const String.fromEnvironment('MARKET_API_BASE_URL'),
  });

  final String baseUrl;

  bool get enabled => normalizedBaseUrl.isNotEmpty;

  String get normalizedBaseUrl =>
      baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
}
