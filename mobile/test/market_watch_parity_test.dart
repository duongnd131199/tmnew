import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/load_test_fonts.dart';
import 'test_support/video_reference_fixtures.dart';

void main() {
  setUpAll(loadMt5TestFonts);

  Future<ProviderContainer> pumpMarket(
    WidgetTester tester, {
    ProviderContainer? container,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = container ?? createVideoReferenceContainer();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: RepaintBoundary(
              key: Key('market-icon-reference-capture'),
              child: MarketWatchScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return scope;
  }

  Future<ProviderContainer> pumpModernReference(WidgetTester tester) async {
    final quotes = <DemoQuote>[
      DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4413.456,
        ask: 4413.638,
        changePercent: 88.88,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
      ),
      DemoQuote(
        symbol: 'BTCUSD',
        name: 'Bitcoin',
        bid: 77480.31,
        ask: 77487.31,
        changePercent: 77.77,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 30),
      ),
    ];
    final dailyCandles = <String, List<MarketCandle>>{
      'XAUUSD+': [
        MarketCandle(
          time: DateTime.utc(2026, 8, 30),
          open: 4439,
          high: 4466,
          low: 4435,
          close: 4458.279,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 4458.301,
          high: 4472.462,
          low: 4396.372,
          close: 4413.456,
        ),
      ],
      'BTCUSD': [
        MarketCandle(
          time: DateTime.utc(2026, 8, 30),
          open: 78000,
          high: 79000,
          low: 77000,
          close: 77673.16,
        ),
        MarketCandle(
          time: DateTime.utc(2026, 8, 31),
          open: 77673.16,
          high: 78175.38,
          low: 77363.95,
          close: 77480.31,
        ),
      ],
    };
    final container = ProviderContainer(
      overrides: [
        demoQuotesProvider.overrideWithValue(quotes),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            quotes.firstWhere((quote) => quote.symbol == symbol),
          ),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(
            dailyCandles[request.symbol] ?? const <MarketCandle>[],
          ),
        ),
      ],
    );
    await pumpMarket(
      tester,
      container: container,
      platform: TargetPlatform.iOS,
    );
    await tester.pump();
    return container;
  }

  testWidgets('iOS quote change uses the static reference face and weight', (
    tester,
  ) async {
    await pumpMarket(tester, platform: TargetPlatform.iOS);

    final dailyChange = tester.widget<Text>(
      find.byKey(const ValueKey('market-change-XAUUSD+')),
    );
    final spans = (dailyChange.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .toList();

    expect(dailyChange.style?.fontFamily, 'Mt5ReferenceRoboto');
    expect(dailyChange.style?.fontWeight, FontWeight.w400);
    expect(dailyChange.style?.fontVariations, isNull);
    expect(spans[1].style?.fontWeight, FontWeight.w700);
    expect(spans[1].style?.fontVariations, isNull);
  });

  testWidgets('Quotes toolbar icon ink matches the measured references', (
    tester,
  ) async {
    await pumpMarket(tester);

    final list = await _buttonInkMetrics(
      tester,
      const Key('market-toggle-view'),
    );
    final edit = await _buttonInkMetrics(
      tester,
      const Key('market-manage-button'),
    );
    final search = await _buttonInkMetrics(
      tester,
      const Key('market-search-button'),
    );

    expect(list.bounds.width, closeTo(16, 1));
    expect(list.bounds.height, closeTo(14, 1));
    expect(list.pixels, inInclusiveRange(70, 105));
    expect(edit.bounds.width, closeTo(17, 1));
    expect(edit.bounds.height, closeTo(17, 1));
    expect(edit.pixels, inInclusiveRange(65, 100));
    expect(search.bounds.width, closeTo(22, 1));
    expect(search.bounds.height, closeTo(22, 1));
    expect(search.pixels, inInclusiveRange(100, 145));
  });

  double rowOffset(WidgetTester tester, String symbol) {
    final canonicalSymbol = symbol == 'XAUUSD' ? 'XAUUSD+' : symbol;
    final row = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byKey(ValueKey('market-symbol-$canonicalSymbol')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return row.transform?.storage[12] ?? 0;
  }

  testWidgets('header and split-price typography match the video geometry', (
    tester,
  ) async {
    await pumpMarket(tester);

    final toggleRect = tester.getRect(
      find.byKey(const Key('market-toggle-view')),
    );
    final manageRect = tester.getRect(
      find.byKey(const Key('market-manage-button')),
    );
    final searchRect = tester.getRect(
      find.byKey(const Key('market-search-button')),
    );

    expect(toggleRect.left, closeTo(16, .1));
    expect(toggleRect.top, closeTo(64, .1));
    expect(toggleRect.width, closeTo(44, .01));
    expect(toggleRect.height, closeTo(44, .01));
    expect(manageRect.left, closeTo(268, .1));
    expect(manageRect.top, closeTo(64, .1));
    expect(searchRect.left, closeTo(323.5, .1));
    expect(searchRect.top, closeTo(64, .1));
    expect(
      <Rect>[
        toggleRect,
        manageRect,
        searchRect,
      ].every((rect) => rect.width >= 44 && rect.height >= 44),
      isTrue,
      reason: 'Visual discs may shrink, but toolbar hit targets stay usable.',
    );

    final headerTitle = tester.widget<Text>(find.text('Gia'));
    expect(headerTitle.style, AppTypography.pricesToolbarTitle);
    final dailyChange = tester.widget<Text>(
      find.byKey(const ValueKey('market-change-XAUUSD+')),
    );
    expect(
      dailyChange.style,
      AppTypography.quoteChange.copyWith(color: const Color(0xFF3C3C43)),
    );
    final symbolFinder = find.byKey(const ValueKey('market-symbol-XAUUSD+'));
    final symbol = tester.widget<Text>(symbolFinder);
    expect(symbol.style, AppTypography.quoteSymbol);
    expect(symbol.style?.fontFamily, 'Mt5ReferenceRobotoCondensed');
    expect(symbol.style?.fontWeight, FontWeight.w700);
    expect(symbol.style?.fontVariations, isNull);
    final btcSymbolFinder = find.byKey(const ValueKey('market-symbol-BTCUSD'));
    final btcSymbol = tester.widget<Text>(btcSymbolFinder);
    expect(btcSymbol.data, 'BTCUSD');
    expect(btcSymbol.style, AppTypography.quoteSymbol);
    expect(btcSymbol.style?.fontVariations, isNull);
    expect(
      tester.getTopLeft(btcSymbolFinder).dy -
          tester.getTopLeft(symbolFinder).dy,
      closeTo(72, .01),
      reason: 'Modern Prices rows use the measured 216-physical-pixel pitch.',
    );
    expect(tester.getTopLeft(symbolFinder).dy, closeTo(143, .75));
    final tickTime = tester.widget<Text>(
      find.byKey(const ValueKey('market-time-XAUUSD+')),
    );
    expect(
      tickTime.style,
      AppTypography.quoteTimeMeta.copyWith(color: const Color(0xFF3C3C43)),
    );
    expect(tickTime.data, '04:32:31');
    expect(
      tickTime.style?.color,
      const Color(0xFF3C3C43),
      reason: 'Prices metadata uses the locked secondary reference ink.',
    );
    expect(tickTime.style?.fontWeight, FontWeight.w400);
    expect(tickTime.style?.fontVariations, isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('market-time-XAUUSD+'))).dy,
      closeTo(166.67, .1),
      reason: 'The metadata baseline starts one point above the old layout.',
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('market-time-XAUUSD+'))).dx,
      closeTo(7.33, .1),
      reason: 'The metadata ink starts at the measured reference inset.',
    );
    final spread = tester.widget<Text>(
      find.byKey(const ValueKey('market-spread-XAUUSD+')),
    );
    expect(
      spread.style,
      AppTypography.quoteSpreadMeta.copyWith(color: const Color(0xFF3C3C43)),
      reason:
          'The reference keeps only the spread glyph pale; its number uses '
          'the same secondary ink as the timestamp and range values.',
    );
    expect(spread.style?.fontVariations, isNull);
    final btcDelay = find.byKey(const ValueKey('market-delay-BTCUSD'));
    expect(btcDelay, findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-low-XAUUSD+')))
          .style,
      AppTypography.quoteRangeValue.copyWith(color: const Color(0xFF3C3C43)),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
          .style,
      AppTypography.quoteRangeValue.copyWith(color: const Color(0xFF3C3C43)),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-BTCUSD')))
          .style,
      AppTypography.quoteRangeValue.copyWith(color: const Color(0xFF3C3C43)),
      reason: 'Both modern quote rows use the same range geometry and style.',
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('market-low-label-XAUUSD+')))
          .dy,
      closeTo(167.67, .1),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-low-label-XAUUSD+')))
          .style
          ?.color,
      const Color(0xFF3C3C43),
    );
    for (final key in const <ValueKey<String>>[
      ValueKey('market-low-label-XAUUSD+'),
      ValueKey('market-low-XAUUSD+'),
      ValueKey('market-high-label-XAUUSD+'),
      ValueKey('market-high-XAUUSD+'),
    ]) {
      final rangeText = tester.widget<Text>(find.byKey(key));
      expect(rangeText.style?.fontWeight, FontWeight.w400, reason: '$key');
      expect(rangeText.style?.fontVariations, isNull, reason: '$key');
    }

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-low-label-XAUUSD+')))
          .data,
      'L:',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-label-XAUUSD+')))
          .data,
      'H:',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-low-XAUUSD+')))
          .data,
      '4104.090',
    );

    final xauBid = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-XAUUSD+')),
    );
    final bidSpans = (xauBid.textSpan! as TextSpan).children!;
    expect((bidSpans[0] as TextSpan).text, '4104.');
    expect((bidSpans[0] as TextSpan).style?.fontWeight, FontWeight.w400);
    expect((bidSpans[0] as TextSpan).style?.fontVariations, isNull);
    expect(bidSpans, hasLength(3));
    expect((bidSpans[1] as TextSpan).text, '09');
    expect(
      (bidSpans[1] as TextSpan).style,
      AppTypography.quotePriceMinor.copyWith(color: const Color(0xFF007AFF)),
    );
    expect(
      find.byKey(const ValueKey('market-bid-pipette-XAUUSD+')),
      findsOneWidget,
    );
    final xauPipette = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-pipette-XAUUSD+')),
    );
    expect(xauPipette.data, '0');
    expect(
      xauPipette.style,
      AppTypography.quotePricePipette.copyWith(color: const Color(0xFF007AFF)),
    );
    final xauBidTop = tester
        .getTopLeft(find.byKey(const ValueKey('market-bid-XAUUSD+')))
        .dy;
    final xauPipetteTop = tester
        .getTopLeft(find.byKey(const ValueKey('market-bid-pipette-XAUUSD+')))
        .dy;
    expect(
      xauPipetteTop - xauBidTop,
      inInclusiveRange(0, 2),
      reason:
          'The final gold digit should remain raised while staying inside '
          'the price line so its top edge is not clipped.',
    );

    final btcBid = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-BTCUSD')),
    );
    final btcSpans = (btcBid.textSpan! as TextSpan).children!;
    expect((btcSpans[0] as TextSpan).text, '65175.');
    expect(btcSpans, hasLength(2));
    expect((btcSpans[1] as TextSpan).text, '98');
    expect(
      find.byKey(const ValueKey('market-bid-pipette-BTCUSD')),
      findsNothing,
    );

    await tester.tap(find.text('XAUUSD'));
    await tester.pumpAndSettle();
    final menuRect = tester.getRect(
      find.byKey(const ValueKey('market-symbol-menu-XAUUSD+')),
    );
    final firstAction = find.byKey(const Key('market-menu-first-action'));
    final firstActionRect = tester.getRect(firstAction);
    expect(firstActionRect.top - menuRect.top, closeTo(69.3, 1));
    final actionMaterial = find
        .descendant(of: firstAction, matching: find.byType(Material))
        .first;
    expect(tester.getSize(actionMaterial).height, 47);
  });

  testWidgets(
    'modern reference renders UTC D1 statistics, precision and shared rows',
    (tester) async {
      await pumpModernReference(tester);

      expect(
        _plainText(tester, const ValueKey('market-change-XAUUSD+')),
        '-44823 -1.01%',
      );
      expect(
        _plainText(tester, const ValueKey('market-change-BTCUSD')),
        '-19285 -0.25%',
      );
      expect(find.text('XAUUSD'), findsOneWidget);
      expect(find.text('BTCUSD'), findsOneWidget);
      expect(find.text('BTC'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-time-XAUUSD+')))
            .data,
        '04:32:31',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-time-BTCUSD')))
            .data,
        '04:32:30',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-spread-XAUUSD+')))
            .data,
        '182',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-spread-BTCUSD')))
            .data,
        '700',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-low-XAUUSD+')))
            .data,
        '4396.372',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
            .data,
        '4472.462',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-low-BTCUSD')))
            .data,
        '77363.95',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-high-BTCUSD')))
            .data,
        '78175.38',
      );

      _expectPriceParts(
        tester,
        const ValueKey('market-bid-XAUUSD+'),
        leading: '4413.',
        emphasized: '45',
        pipetteKey: const ValueKey('market-bid-pipette-XAUUSD+'),
      );
      _expectPriceParts(
        tester,
        const ValueKey('market-ask-XAUUSD+'),
        leading: '4413.',
        emphasized: '63',
        pipetteKey: const ValueKey('market-ask-pipette-XAUUSD+'),
      );
      _expectPriceParts(
        tester,
        const ValueKey('market-bid-BTCUSD'),
        leading: '77480.',
        emphasized: '31',
      );
      _expectPriceParts(
        tester,
        const ValueKey('market-ask-BTCUSD'),
        leading: '77487.',
        emphasized: '31',
      );

      final bidRight = tester
          .getRect(find.byKey(const ValueKey('market-bid-XAUUSD+')))
          .right;
      final askRight = tester
          .getRect(find.byKey(const ValueKey('market-ask-XAUUSD+')))
          .right;
      expect(bidRight, closeTo(280.7, .75));
      expect(askRight, closeTo(376.7, .75));
      expect(askRight - bidRight, closeTo(96, 1));
      expect(
        await _rectContainsColoredInk(
          tester,
          Rect.fromLTWH(
            0,
            tester
                .getTopLeft(
                  find
                      .ancestor(
                        of: find.byKey(const ValueKey('market-symbol-XAUUSD+')),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .dy,
            8,
            10,
          ),
        ),
        isFalse,
        reason: 'The modern reference has no blue XAU corner marker.',
      );
      expect(find.byKey(const ValueKey('market-delay-BTCUSD')), findsNothing);
    },
  );

  testWidgets(
    'quote row follows drag, resists overscroll and snaps by threshold',
    (tester) async {
      await pumpMarket(tester);

      final xau = find.text('XAUUSD');
      final xauRowY = tester.getCenter(xau).dy;
      final drag = await tester.startGesture(Offset(180, xauRowY));
      await drag.moveBy(const Offset(-35, 0));
      await tester.pump();
      expect(rowOffset(tester, 'XAUUSD'), lessThan(-1));
      expect(rowOffset(tester, 'XAUUSD'), greaterThan(-80));
      expect(rowOffset(tester, 'XAUUSD'), isNot(-123));
      await drag.moveBy(const Offset(-45, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), -142);

      expect(
        find.byKey(const ValueKey('market-order-XAUUSD+')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('market-chart-XAUUSD+')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('market-delete-XAUUSD+')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('market-order-XAUUSD+'))),
        const Size(48, 48),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('market-order-XAUUSD+'))).left,
        closeTo(253, .1),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('market-chart-XAUUSD+'))).left,
        closeTo(329, .1),
      );

      final rebound = await tester.startGesture(Offset(180, xauRowY));
      await rebound.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await rebound.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), -142);

      final close = await tester.startGesture(Offset(180, xauRowY));
      await close.moveBy(const Offset(95, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await close.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), 0);

      final elastic = await tester.startGesture(Offset(180, xauRowY));
      await elastic.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(rowOffset(tester, 'XAUUSD'), greaterThan(0));
      expect(rowOffset(tester, 'XAUUSD'), lessThanOrEqualTo(24));
      await elastic.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), 0);

      await tester.drag(
        find.byKey(const ValueKey('market-symbol-BTCUSD')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'BTCUSD'), -117);
      expect(find.byKey(const ValueKey('market-order-BTCUSD')), findsNothing);
      expect(
        find.byKey(const ValueKey('market-delete-BTCUSD')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('market-chart-BTCUSD')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('market-chart-BTCUSD'))),
        const Size(48, 48),
      );
      expect(rowOffset(tester, 'XAUUSD'), 0);
    },
  );

  testWidgets('tick drives time, spread and price color but not daily color', (
    tester,
  ) async {
    final controllers = <String, StreamController<DemoQuote>>{
      'XAUUSD+': StreamController<DemoQuote>.broadcast(),
      'BTCUSD': StreamController<DemoQuote>.broadcast(),
    };
    addTearDown(() async {
      for (final controller in controllers.values) {
        await controller.close();
      }
    });
    final container = createVideoReferenceContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => controllers[symbol]!.stream,
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
      ],
    );
    await pumpMarket(tester, container: container);

    final initialTime = tester.widget<Text>(
      find.byKey(const ValueKey('market-time-XAUUSD+')),
    );
    expect(initialTime.data, isNot('05:23:45'));
    expect(initialTime.data, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-spread-XAUUSD+')))
          .data,
      '130',
    );

    controllers['XAUUSD+']!.add(
      DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4104.10,
        ask: 4104.21,
        changePercent: -1.24,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
        previousClose: 4155.62980963953,
        dailyLow: 4100,
        dailyHigh: 4160,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-spread-XAUUSD+')))
          .data,
      '110',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-bid-XAUUSD+')))
          .style
          ?.color,
      AppColors.primary,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-ask-XAUUSD+')))
          .style
          ?.color,
      AppColors.negative,
    );
    final dailyChange = tester.widget<Text>(
      find.byKey(const ValueKey('market-change-XAUUSD+')),
    );
    final dailySpans = (dailyChange.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .toList();
    expect(dailySpans[1].style?.color, const Color(0xFFE42D30));
    expect(dailyChange.textSpan!.toPlainText(), contains('-1.24%'));
  });

  testWidgets(
    'fallback receive time is stable across candle rebuilds and advances on a new tick',
    (tester) async {
      var clockCalls = 0;
      final quoteControllers = <String, StreamController<DemoQuote>>{
        'XAUUSD+': StreamController<DemoQuote>.broadcast(),
        'BTCUSD': StreamController<DemoQuote>.broadcast(),
      };
      final candleControllers = <String, StreamController<List<MarketCandle>>>{
        'XAUUSD+': StreamController<List<MarketCandle>>.broadcast(),
        'BTCUSD': StreamController<List<MarketCandle>>.broadcast(),
      };
      addTearDown(() async {
        for (final controller in quoteControllers.values) {
          await controller.close();
        }
        for (final controller in candleControllers.values) {
          await controller.close();
        }
      });
      final quotes = <DemoQuote>[
        const DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4104.09,
          ask: 4104.22,
          changePercent: 0,
          previousClose: 4104.09,
          dailyLow: 4104.09,
          dailyHigh: 4104.22,
        ),
        const DemoQuote(
          symbol: 'BTCUSD',
          name: 'Bitcoin',
          bid: 65175.98,
          ask: 65193.10,
          changePercent: 0,
          previousClose: 65175.98,
          dailyLow: 65175.98,
          dailyHigh: 65193.10,
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          demoQuotesProvider.overrideWithValue(quotes),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => quoteControllers[symbol]!.stream,
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => candleControllers[request.symbol]!.stream,
          ),
          marketClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 31, 4, 32, 10 + clockCalls++),
          ),
        ],
      );
      await pumpMarket(tester, container: container);

      final timeFinder = find.byKey(const ValueKey('market-time-XAUUSD+'));
      final initialTime = tester.widget<Text>(timeFinder).data;
      candleControllers['XAUUSD+']!.add(const <MarketCandle>[]);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(timeFinder).data, initialTime);

      await tester.tap(find.byKey(const Key('market-toggle-view')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('market-toggle-view')));
      await tester.pump();
      expect(tester.widget<Text>(timeFinder).data, initialTime);

      quoteControllers['XAUUSD+']!.add(
        const DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 4104.10,
          ask: 4104.23,
          changePercent: 0,
          previousClose: 4104.09,
          dailyLow: 4104.09,
          dailyHigh: 4104.23,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(timeFinder).data, isNot(initialTime));
    },
  );

  testWidgets('XAU shows the final pipette and three-digit ranges', (
    tester,
  ) async {
    await pumpModernReference(tester);

    expect(
      _plainText(tester, const ValueKey('market-bid-XAUUSD+')),
      '4413.456',
    );
    expect(
      _plainText(tester, const ValueKey('market-ask-XAUUSD+')),
      '4413.638',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-low-XAUUSD+')))
          .data,
      '4396.372',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
          .data,
      '4472.462',
    );
    expect(
      find.byKey(const ValueKey('market-bid-pipette-XAUUSD+')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('market-bid-pipette-BTCUSD')),
      findsNothing,
      reason: 'BTC keeps both decimal digits at full size and baseline.',
    );
  });

  testWidgets('last D1 statistics survive loading and error refresh states', (
    tester,
  ) async {
    final candleControllers = <String, StreamController<List<MarketCandle>>>{
      'XAUUSD+': StreamController<List<MarketCandle>>.broadcast(),
      'BTCUSD': StreamController<List<MarketCandle>>.broadcast(),
    };
    addTearDown(() async {
      for (final controller in candleControllers.values) {
        await controller.close();
      }
    });
    final quotes = <DemoQuote>[
      DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 100.100,
        ask: 100.200,
        changePercent: 99,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
      ),
      DemoQuote(
        symbol: 'BTCUSD',
        name: 'Bitcoin',
        bid: 60000,
        ask: 60010,
        changePercent: 99,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 30),
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        demoQuotesProvider.overrideWithValue(quotes),
        demoQuoteProvider.overrideWith(
          (ref, symbol) => Stream.value(
            quotes.firstWhere((quote) => quote.symbol == symbol),
          ),
        ),
        marketCandlesProvider.overrideWith(
          (ref, request) => candleControllers[request.symbol]!.stream,
        ),
      ],
    );
    await pumpMarket(tester, container: container);

    candleControllers['XAUUSD+']!.add([
      MarketCandle(
        time: DateTime.utc(2026, 8, 30),
        open: 101,
        high: 102,
        low: 100,
        close: 101,
      ),
      MarketCandle(
        time: DateTime.utc(2026, 8, 31),
        open: 101,
        high: 102,
        low: 99,
        close: 100.1,
      ),
    ]);
    candleControllers['BTCUSD']!.add(const <MarketCandle>[]);
    await tester.pump();
    await tester.pump();

    void expectRetainedStatistics() {
      expect(
        _plainText(tester, const ValueKey('market-change-XAUUSD+')),
        '-900 -0.89%',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-low-XAUUSD+')))
            .data,
        '99.000',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
            .data,
        '102.000',
      );
    }

    expectRetainedStatistics();
    const request = MarketDataRequest('XAUUSD+', 'D1');
    container.invalidate(marketCandlesProvider(request));
    await tester.pump();
    expectRetainedStatistics();

    candleControllers['XAUUSD+']!.addError(StateError('refresh failed'));
    await tester.pump();
    await tester.pump();
    expectRetainedStatistics();
  });

  testWidgets('live D1 extrema do not move backward between REST refreshes', (
    tester,
  ) async {
    final controller = StreamController<DemoQuote>.broadcast();
    addTearDown(controller.close);
    final initial = DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: 105,
      ask: 105.1,
      changePercent: 0,
      sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
    );
    final container = ProviderContainer(
      overrides: [
        demoQuotesProvider.overrideWithValue([initial]),
        demoQuoteProvider.overrideWith((ref, symbol) => controller.stream),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value([
            MarketCandle(
              time: DateTime.utc(2026, 8, 30),
              open: 99,
              high: 101,
              low: 98,
              close: 100,
            ),
            MarketCandle(
              time: DateTime.utc(2026, 8, 31),
              open: 100,
              high: 102,
              low: 99,
              close: 101,
            ),
          ]),
        ),
      ],
    );
    await pumpMarket(tester, container: container);
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
          .data,
      '105.100',
    );

    controller.add(
      DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 104,
        ask: 104.1,
        changePercent: 0,
        sourceTimestamp: DateTime.utc(2026, 8, 31, 12, 0, 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
          .data,
      '105.100',
    );

    await tester.tap(find.byKey(const Key('market-toggle-view')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('market-toggle-view')));
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-high-XAUUSD+')))
          .data,
      '105.100',
      reason:
          'The live session high must survive replacing detailed rows with '
          'compact rows and back.',
    );
  });

  testWidgets(
    'zero catalog quote renders an unavailable row without crashing',
    (tester) async {
      const quote = DemoQuote(
        symbol: 'C',
        name: 'Citigroup Inc',
        bid: 0,
        ask: 0,
        changePercent: 0,
      );
      final container = ProviderContainer(
        overrides: [
          demoQuotesProvider.overrideWithValue(const [quote]),
          marketSymbolsProvider.overrideWith(
            () => _FixedMarketSymbolsController(const ['C']),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(quote)),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
      );

      await pumpMarket(tester, container: container);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_plainText(tester, const ValueKey('market-bid-C')), '--');
      expect(_plainText(tester, const ValueKey('market-ask-C')), '--');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('market-spread-C'))).data,
        '--',
      );
    },
  );

  testWidgets('five-digit FX keeps two terminal pips and one raised pipette', (
    tester,
  ) async {
    final quote = DemoQuote(
      symbol: 'EURUSD',
      name: 'Euro vs US Dollar',
      bid: 1.12345,
      ask: 1.12355,
      changePercent: 0,
      sourceTimestamp: DateTime.utc(2026, 8, 31, 12),
    );
    final container = ProviderContainer(
      overrides: [
        demoQuotesProvider.overrideWithValue([quote]),
        marketSymbolsProvider.overrideWith(
          () => _FixedMarketSymbolsController(const ['EURUSD']),
        ),
        demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(quote)),
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
      ],
    );
    await pumpMarket(tester, container: container);
    await tester.pump();

    _expectPriceParts(
      tester,
      const ValueKey('market-bid-EURUSD'),
      leading: '1.12',
      emphasized: '34',
      pipetteKey: const ValueKey('market-bid-pipette-EURUSD'),
    );
  });

  testWidgets(
    'missing session history is shown without fabricated statistics',
    (tester) async {
      final quotes = <DemoQuote>[
        DemoQuote(
          symbol: 'XAUUSD+',
          name: 'Gold US Dollar',
          bid: 3345.20,
          ask: 3345.65,
          changePercent: .42,
          sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 31),
        ),
        DemoQuote(
          symbol: 'BTCUSD',
          name: 'Bitcoin',
          bid: 60000,
          ask: 60010,
          changePercent: .82,
          sourceTimestamp: DateTime.utc(2026, 8, 31, 4, 32, 30),
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          demoQuotesProvider.overrideWithValue(quotes),
          demoQuoteProvider.overrideWith((ref, symbol) {
            return Stream.value(
              quotes.firstWhere((quote) => quote.symbol == symbol),
            );
          }),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
      );

      await pumpMarket(tester, container: container);

      final dailyChange = tester.widget<Text>(
        find.byKey(const ValueKey('market-change-BTCUSD')),
      );
      expect(dailyChange.textSpan!.toPlainText(), '-- --');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-low-BTCUSD')))
            .data,
        '--',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('market-high-BTCUSD')))
            .data,
        '--',
      );
    },
  );
}

class _FixedMarketSymbolsController extends MarketSymbolsController {
  _FixedMarketSymbolsController(this.symbols);

  final List<String> symbols;

  @override
  List<String> build() => symbols;
}

String _plainText(WidgetTester tester, ValueKey<String> key) =>
    tester.widget<Text>(find.byKey(key)).semanticsLabel ??
    tester
        .widget<Text>(find.byKey(key))
        .textSpan!
        .toPlainText(includeSemanticsLabels: false);

void _expectPriceParts(
  WidgetTester tester,
  ValueKey<String> priceKey, {
  required String leading,
  required String emphasized,
  ValueKey<String>? pipetteKey,
}) {
  final price = tester.widget<Text>(find.byKey(priceKey));
  final parts = (price.textSpan! as TextSpan).children!;
  expect(parts, hasLength(pipetteKey == null ? 2 : 3));
  expect((parts[0] as TextSpan).text, leading);
  expect((parts[1] as TextSpan).text, emphasized);
  if (pipetteKey != null) {
    expect(parts[2], isA<WidgetSpan>());
    expect(find.byKey(pipetteKey), findsOneWidget);
  }
}

Future<({Rect bounds, int pixels})> _buttonInkMetrics(
  WidgetTester tester,
  Key buttonKey,
) async {
  final buttonRect = tester.getRect(find.byKey(buttonKey));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('market-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read Quotes toolbar pixels');
  }

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  var pixels = 0;
  for (var y = buttonRect.top.floor(); y < buttonRect.bottom.ceil(); y++) {
    for (var x = buttonRect.left.floor(); x < buttonRect.right.ceil(); x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128 || (red + green + blue) / 3 >= 100) continue;
      pixels++;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No dark icon ink found for $buttonKey');
  }
  final origin = Offset(
    buttonRect.left.floorToDouble(),
    buttonRect.top.floorToDouble(),
  );
  return (
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ).shift(-origin),
    pixels: pixels,
  );
}

Future<bool> _rectContainsColoredInk(
  WidgetTester tester,
  Rect logicalRect,
) async {
  const pixelRatio = 3.0;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('market-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to inspect the quote row corner pixels');
  }
  final left = (logicalRect.left * pixelRatio).floor().clamp(0, captured.width);
  final top = (logicalRect.top * pixelRatio).floor().clamp(0, captured.height);
  final right = (logicalRect.right * pixelRatio).ceil().clamp(
    0,
    captured.width,
  );
  final bottom = (logicalRect.bottom * pixelRatio).ceil().clamp(
    0,
    captured.height,
  );
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha >= 128 && blue > red + 30 && blue > green + 15) return true;
    }
  }
  return false;
}
