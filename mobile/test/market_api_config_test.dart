import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';

void main() {
  test('market API is opt-in and normalizes its server origin', () {
    expect(const MarketApiConfig().enabled, isFalse);

    const configured = MarketApiConfig(baseUrl: ' https://api.example.com/// ');
    expect(configured.enabled, isTrue);
    expect(configured.normalizedBaseUrl, 'https://api.example.com');
  });

  test('production app defaults to the public market feed', () {
    expect(MarketApiConfig.production.normalizedBaseUrl, 'https://trochoi.top');
  });
}
