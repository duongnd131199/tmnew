import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/load_test_fonts.dart';

void main() {
  setUpAll(loadMt5TestFonts);

  testWidgets('Prices exposes the exact reference copy', (tester) async {
    await _pumpPrices(tester, brightness: Brightness.light);

    expect(find.text('Gia'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('market-symbol-XAUUSD+')));
    await tester.pumpAndSettle();

    expect(find.text('Giao dich'), findsOneWidget);
    expect(find.text('Bieu do'), findsOneWidget);
  });

  testWidgets('reference profile controls every visible Prices color role', (
    tester,
  ) async {
    await _pumpPrices(tester, brightness: Brightness.dark);

    const primary = Color(0xFFEEEEEE);
    const secondary = Color(0xFF969696);
    const positive = Color(0xFF007CFF);
    const negative = Color(0xFFE42D30);

    expect(tester.widget<Text>(_pricesTitleFinder()).style?.color, primary);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-symbol-XAUUSD+')))
          .style
          ?.color,
      primary,
    );

    final xauChange = _textSpans(
      tester,
      const ValueKey('market-change-XAUUSD+'),
    );
    expect(xauChange[0].style?.color, secondary);
    expect(xauChange[1].style?.color, negative);

    final btcChange = _textSpans(
      tester,
      const ValueKey('market-change-BTCUSD'),
    );
    expect(btcChange[0].style?.color, secondary);
    expect(btcChange[1].style?.color, positive);

    for (final key in const <ValueKey<String>>[
      ValueKey('market-time-XAUUSD+'),
      ValueKey('market-spread-XAUUSD+'),
      ValueKey('market-low-label-XAUUSD+'),
      ValueKey('market-low-XAUUSD+'),
      ValueKey('market-high-label-XAUUSD+'),
      ValueKey('market-high-XAUUSD+'),
    ]) {
      expect(tester.widget<Text>(find.byKey(key)).style?.color, secondary);
    }

    for (final span in _textSpans(
      tester,
      const ValueKey('market-bid-XAUUSD+'),
    )) {
      expect(span.style?.color, negative);
    }
    for (final span in _textSpans(
      tester,
      const ValueKey('market-bid-BTCUSD'),
    )) {
      expect(span.style?.color, positive);
    }
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-bid-pipette-EURUSD')))
          .style
          ?.color,
      positive,
    );
  });

  testWidgets('Prices preserves measured XAU BTC and other price variants', (
    tester,
  ) async {
    await _pumpPrices(tester, brightness: Brightness.light);

    final title = tester.widget<Text>(_pricesTitleFinder());
    _expectStyle(
      title.style,
      family: 'Mt5ReferenceRoboto',
      size: 16,
      weight: FontWeight.w700,
    );

    final symbol = tester.widget<Text>(
      find.byKey(const ValueKey('market-symbol-XAUUSD+')),
    );
    _expectStyle(
      symbol.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 16,
      weight: FontWeight.w700,
    );

    final xauMajor = _textSpans(
      tester,
      const ValueKey('market-bid-XAUUSD+'),
    )[0];
    _expectStyle(
      xauMajor.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 16,
      weight: FontWeight.w400,
      letterSpacing: .85,
    );

    final xauMinor = _textSpans(
      tester,
      const ValueKey('market-bid-XAUUSD+'),
    )[1];
    _expectStyle(
      xauMinor.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 27,
      weight: FontWeight.w700,
      letterSpacing: .85,
    );

    final btcMajor = _textSpans(tester, const ValueKey('market-bid-BTCUSD'))[0];
    _expectStyle(
      btcMajor.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 16,
      weight: FontWeight.w400,
      letterSpacing: 0,
    );

    final btcMinor = _textSpans(tester, const ValueKey('market-bid-BTCUSD'))[1];
    _expectStyle(
      btcMinor.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 27,
      weight: FontWeight.w700,
      letterSpacing: .85,
    );

    final pipette = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-pipette-EURUSD')),
    );
    _expectStyle(
      pipette.style,
      family: 'Mt5ReferenceRobotoCondensed',
      size: 14.5,
      weight: FontWeight.w700,
      letterSpacing: 0,
    );
  });
}

const _quotes = <DemoQuote>[
  DemoQuote(
    symbol: 'XAUUSD+',
    name: 'Gold US Dollar',
    bid: 4104.09,
    ask: 4104.22,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'BTCUSD',
    name: 'Bitcoin',
    bid: 65175.98,
    ask: 65193.10,
    changePercent: 0,
  ),
  DemoQuote(
    symbol: 'EURUSD',
    name: 'Euro vs US Dollar',
    bid: 1.12345,
    ask: 1.12355,
    changePercent: 0,
  ),
];

final _dailyCandles = <String, List<MarketCandle>>{
  'XAUUSD+': [
    MarketCandle(
      time: DateTime.utc(2026, 8, 30),
      open: 4105.09,
      high: 4106,
      low: 4104.5,
      close: 4105.09,
    ),
    MarketCandle(
      time: DateTime.utc(2026, 8, 31),
      open: 4105.09,
      high: 4105.2,
      low: 4104,
      close: 4104.09,
    ),
  ],
  'BTCUSD': [
    MarketCandle(
      time: DateTime.utc(2026, 8, 30),
      open: 65175.98,
      high: 65220,
      low: 65080,
      close: 65175.98,
    ),
    MarketCandle(
      time: DateTime.utc(2026, 8, 31),
      open: 65175.98,
      high: 65193.10,
      low: 65175.98,
      close: 65175.98,
    ),
  ],
  'EURUSD': [
    MarketCandle(
      time: DateTime.utc(2026, 8, 30),
      open: 1.12345,
      high: 1.124,
      low: 1.123,
      close: 1.12345,
    ),
    MarketCandle(
      time: DateTime.utc(2026, 8, 31),
      open: 1.12345,
      high: 1.12355,
      low: 1.1234,
      close: 1.12345,
    ),
  ],
};

Future<void> _pumpPrices(
  WidgetTester tester, {
  required Brightness brightness,
}) async {
  tester.view.physicalSize = const Size(384, 848);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = ProviderContainer(
    overrides: [
      demoQuotesProvider.overrideWithValue(_quotes),
      marketSymbolsProvider.overrideWith(
        () => _FixedMarketSymbolsController(
          _quotes.map((quote) => quote.symbol).toList(growable: false),
        ),
      ),
      demoQuoteProvider.overrideWith(
        (ref, symbol) =>
            Stream.value(_quotes.firstWhere((quote) => quote.symbol == symbol)),
      ),
      marketCandlesProvider.overrideWith(
        (ref, request) => Stream.value(
          _dailyCandles[request.symbol] ?? const <MarketCandle>[],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  final baseTheme = ThemeData(
    brightness: brightness,
    platform: TargetPlatform.iOS,
    useMaterial3: true,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: withTypographyProfile(baseTheme, TypographyProfile.reference),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(384, 848),
            padding: EdgeInsets.only(top: 24),
          ),
          child: MarketWatchScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FixedMarketSymbolsController extends MarketSymbolsController {
  _FixedMarketSymbolsController(this.symbols);

  final List<String> symbols;

  @override
  List<String> build() => symbols;
}

List<TextSpan> _textSpans(WidgetTester tester, ValueKey<String> key) =>
    (tester.widget<Text>(find.byKey(key)).textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList(growable: false);

Finder _pricesTitleFinder() => find.text('Gia');

void _expectStyle(
  TextStyle? style, {
  required String family,
  required double size,
  required FontWeight weight,
  double? letterSpacing,
}) {
  expect(style?.fontFamily, family);
  expect(style?.fontSize, size);
  expect(style?.fontWeight, weight);
  expect(style?.fontVariations, isNull);
  if (letterSpacing != null) expect(style?.letterSpacing, letterSpacing);
}
