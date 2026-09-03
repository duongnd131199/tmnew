import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_hit_targets.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/chart_render_snapshot.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_objects_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/chart/presentation/theme/chart_reference_theme.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/mock_quote_service.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_edit_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_search_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

import 'test_support/video_reference_fixtures.dart';

Mt5CandlePainter _viewportInvariantPainter({
  required ChartViewport viewport,
  List<MarketCandle> candles = const <MarketCandle>[],
  bool useRealtimeCandles = false,
  String symbol = 'XAUEUR',
  String timeframe = 'M1',
  double referencePrice = 3566.07,
  double? currentPrice,
  bool showHistoryBadge = false,
  double? pendingOrderPrice,
  bool oneClickTrading = false,
  bool h4ExpandedScaleSeen = false,
}) {
  final snapshot = ChartRenderSnapshot.evolve(
    history: candles,
    liveTail: const <MarketCandle>[],
    resolvedCandles: candles,
    historyRevision: 0,
    liveCandleRevision: 0,
    viewport: viewport,
    overlayValues: <Object?>[
      pendingOrderPrice,
      oneClickTrading,
      h4ExpandedScaleSeen,
      showHistoryBadge,
    ],
    theme: ChartReferenceTheme.light,
  );
  return Mt5CandlePainter(
    snapshot: snapshot,
    symbol: symbol,
    referencePrice: referencePrice,
    currentPrice: currentPrice ?? referencePrice,
    tickTime: DateTime(2026, 8, 1, 10, 3),
    crosshairEnabled: false,
    crosshairPosition: null,
    measurementStart: null,
    measurementEnd: null,
    timeframe: timeframe,
    positions: const <DemoPosition>[],
    pendingOrders: const <DemoPendingOrder>[],
    indicators: const <String>{},
    chartObjects: const <DemoChartObject>[],
    pendingOrderType: null,
    pendingOrderPrice: pendingOrderPrice,
    pendingOrderVolume: .2,
    pendingStopLoss: null,
    pendingTakeProfit: null,
    focusedChartPrice: null,
    loadingPlaceholder: false,
    oneClickTrading: oneClickTrading,
    h4ExpandedScaleSeen: h4ExpandedScaleSeen,
    showHistoryBadge: showHistoryBadge,
    useRealtimeCandles: useRealtimeCandles,
    hitTargets: ChartHitTargets(),
  );
}

void _paintViewportPainter(Mt5CandlePainter painter) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(384, 600));
  recorder.endRecording();
}

Map<String, Object> _rendererCharacterization(Mt5CandlePainter painter) {
  final resolved = painter.debugResolvedCandles;
  final chartWidth = painter.hitTargets.chartWidth;
  return <String, Object>{
    'painterType': painter.runtimeType.toString(),
    'priceAxisRect': painter.priceAxisRect,
    'bottomAxisRect': painter.timeAxisRect,
    'firstResolvedTimestamp': resolved.first.time.toUtc(),
    'lastResolvedTimestamp': resolved.last.time.toUtc(),
    'visibleCandleCount': painter.visibleCandleCount,
    'currentPriceBadgeRect': painter.debugCurrentPriceBadgeRect!,
    'hitTargetMapping': <int>[
      painter.hitTargets.visibleCandleIndex(0.0),
      painter.hitTargets.visibleCandleIndex(chartWidth / 2),
      painter.hitTargets.visibleCandleIndex(chartWidth - 1),
    ],
  };
}

List<Override> _videoReferenceOverridesWith(Override replacement) => [
  for (final defaultOverride in videoReferenceOverrides)
    if (!identical(replacement.origin, defaultOverride.origin)) defaultOverride,
  replacement,
];

void main() {
  testWidgets('reference typography preserves chart frame geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const media = MediaQueryData(
      size: Size(393.3333333333, 853.3333333333),
      devicePixelRatio: 1.5,
      padding: EdgeInsets.only(top: 24, bottom: 79),
      viewPadding: EdgeInsets.only(top: 24, bottom: 79),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _videoReferenceOverridesWith(
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ),
        child: const MaterialApp(
          home: MediaQuery(
            data: media,
            child: ChartScreen(
              symbol: 'XAUUSD+',
              initialTimeframe: 'M1',
              layoutProfile: ChartLayoutProfile.tabReferenceCapture,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final canvasFinder = find.byKey(const Key('chart-canvas'));
    final canvasRect = tester.getRect(canvasFinder);
    expect(canvasRect.left, closeTo(0, .001));
    expect(canvasRect.top, closeTo(94.6666666667, .001));
    expect(canvasRect.width, closeTo(393.3333333333, .001));
    expect(canvasRect.height, closeTo(689.6666666666, .001));
    final timeframe = tester.widget<Text>(
      find.byKey(const Key('chart-toolbar-timeframe')),
    );
    expect(timeframe.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(timeframe.style?.fontSize, AppTypography.chartToolbar.fontSize);
    expect(timeframe.style?.fontWeight, FontWeight.w700);
    expect(timeframe.style?.color, ChartReferenceTheme.light.toolbarInk);
    expect(timeframe.style?.fontVariations, isNull);

    final painter =
        tester.widget<CustomPaint>(canvasFinder).painter! as Mt5CandlePainter;
    expect(painter.referenceTextFamily, AppTypography.referencePlainFamily);
    expect(
      painter.debugTimeAxisTextStyle.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(painter.debugTimeAxisTextStyle.fontWeight, FontWeight.w400);
    expect(painter.debugTimeAxisTextStyle.fontVariations, isNull);
    expect(painter.priceGridRect.top * 1.5, closeTo(118, .01));
    final plotTitleRect = tester.getRect(
      find.byKey(const Key('chart-plot-title')),
    );
    final plotTitle = tester.widget<Text>(
      find.byKey(const Key('chart-plot-title')),
    );
    final plotTitleSpan = plotTitle.textSpan! as TextSpan;
    final plotSymbolSpan = plotTitleSpan.children!.first as TextSpan;
    expect(
      plotSymbolSpan.style?.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(plotSymbolSpan.style?.fontWeight, FontWeight.w700);
    expect(plotSymbolSpan.style?.fontVariations, isNull);
    final upperPositionLabel = painter.hitTargets.positionLabelRects.reduce(
      (left, right) => left.top < right.top ? left : right,
    );
    expect(
      upperPositionLabel.shift(canvasRect.topLeft).overlaps(plotTitleRect),
      isFalse,
      reason: 'The upper M1 order annotation must clear the plot title.',
    );

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    expect(tester.getRect(canvasFinder), canvasRect);
    final volume = tester.widget<Text>(
      find.byKey(const Key('chart-one-click-volume-text')),
    );
    expect(volume.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(volume.style?.fontSize, 16.5);
    expect(volume.style?.fontWeight, FontWeight.w700);
    expect(volume.style?.fontVariations, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('chart-plot-subtitle'))).style,
      AppTypography.chartAnnotation.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        letterSpacing: .4,
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('chart-plot-subtitle'))).data,
      'Gold vs US Dollar',
    );
    final symbolArrow = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('chart-symbol-chevron')),
        matching: find.byType(Icon),
      ),
    );
    expect(symbolArrow.icon, CupertinoIcons.arrowtriangle_down_fill);
    expect(symbolArrow.color, ChartReferenceTheme.light.plotTitleBlue);
    expect(symbolArrow.size, 5.5);
  });

  testWidgets('XAUUSD chart corner uses the Prices positive blue', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _videoReferenceOverridesWith(
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ),
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M30'),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(
      find.byKey(const Key('chart-plot-title')),
    );
    final titleSpan = title.textSpan! as TextSpan;
    final symbolSpan = titleSpan.children!.first as TextSpan;
    final symbolArrow = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('chart-symbol-chevron')),
        matching: find.byType(Icon),
      ),
    );

    expect(symbolSpan.style?.color, const Color(0xFF007AFF));
    expect(symbolArrow.color, const Color(0xFF007AFF));
  });

  for (final testCase
      in <
        ({
          String symbol,
          String timeframe,
          MarketCandle candle,
          String expectedSuffix,
        })
      >[
        (
          symbol: 'XAUUSD+',
          timeframe: 'H4',
          candle: MarketCandle(
            time: DateTime.utc(2026, 9, 1, 8),
            open: 4436.516,
            high: 4437.821,
            low: 4428.431,
            close: 4429.610,
          ),
          expectedSuffix: 'H4, 4436.516 4437.821 4428.431 4429.610 0',
        ),
        (
          symbol: 'BTCUSD',
          timeframe: 'M15',
          candle: MarketCandle(
            time: DateTime.utc(2026, 9, 1, 8),
            open: 65120.25,
            high: 65220.75,
            low: 65080.50,
            close: 65175.98,
            volume: 1234,
          ),
          expectedSuffix: 'M15, 65120.25 65220.75 65080.50 65175.98 1234',
        ),
      ]) {
    testWidgets(
      '${testCase.symbol} plot title shows active OHLCV with symbol precision',
      (tester) async {
        final quote = DemoQuote(
          symbol: testCase.symbol,
          name: testCase.symbol.startsWith('XAU')
              ? 'Gold US Dollar'
              : 'Bitcoin',
          bid: testCase.candle.close,
          ask: testCase.candle.close + .01,
          changePercent: 0,
          sourceTimestamp: testCase.candle.time,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              marketApiConfigProvider.overrideWithValue(
                const MarketApiConfig(baseUrl: 'https://market.example.com'),
              ),
              marketCandlesProvider.overrideWith(
                (ref, request) => Stream.value([testCase.candle]),
              ),
              realtimeCandleProvider.overrideWith(
                (ref, request) => const Stream<MarketCandle>.empty(),
              ),
              demoQuoteProvider.overrideWith(
                (ref, symbol) => Stream.value(quote),
              ),
              marketClockProvider.overrideWithValue(() => testCase.candle.time),
            ],
            child: MaterialApp(
              home: ChartScreen(
                symbol: testCase.symbol,
                initialTimeframe: testCase.timeframe,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final title = tester.widget<Text>(
          find.byKey(const Key('chart-plot-title')),
        );
        expect(title.maxLines, 1);
        expect(title.softWrap, isFalse);
        expect(
          find.ancestor(
            of: find.byKey(const Key('chart-plot-title')),
            matching: find.byKey(const Key('chart-ohlcv-fit')),
          ),
          findsOneWidget,
          reason: 'Long gold and BTC OHLCV values must scale into one line.',
        );
        expect(
          title.textSpan!.toPlainText(includeSemanticsLabels: false),
          contains(testCase.expectedSuffix),
        );

        final canvasFinder = find.byKey(const Key('chart-canvas'));
        final canvasRect = tester.getRect(canvasFinder);
        final painter =
            tester.widget<CustomPaint>(canvasFinder).painter!
                as Mt5CandlePainter;
        final titleRect = tester.getRect(
          find.byKey(const Key('chart-plot-title')),
        );
        final fittedTitleRect = tester.getRect(
          find.byKey(const Key('chart-ohlcv-fit')),
        );
        final priceAxisLeft = canvasRect.left + painter.priceAxisRect.left;
        expect(
          titleRect.right,
          lessThanOrEqualTo(priceAxisLeft + .01),
          reason: 'The complete OHLCV line must clear the price axis.',
        );
        expect(
          priceAxisLeft - fittedTitleRect.right,
          greaterThanOrEqualTo(10),
          reason: 'The OHLCV line keeps the trailing air visible in the video.',
        );

        await tester.tap(find.byKey(const Key('chart-crosshair-button')));
        await tester.pump();

        final crosshairTitle = tester.widget<Text>(
          find.byKey(const Key('chart-plot-title')),
        );
        expect(
          crosshairTitle.textSpan!.toPlainText(includeSemanticsLabels: false),
          isNot(contains('Di chuyển con trỏ')),
        );
        expect(crosshairTitle.maxLines, 1);
        expect(crosshairTitle.softWrap, isFalse);
        expect(
          find.ancestor(
            of: find.byKey(const Key('chart-plot-title')),
            matching: find.byKey(const Key('chart-ohlcv-fit')),
          ),
          findsOneWidget,
          reason: 'Crosshair OHLCV must retain the initial one-line fit.',
        );
        final crosshairTitleRect = tester.getRect(
          find.byKey(const Key('chart-plot-title')),
        );
        expect(
          crosshairTitleRect.right,
          lessThanOrEqualTo(priceAxisLeft + .01),
          reason: 'Crosshair OHLCV must not overflow into the price axis.',
        );
      },
    );
  }

  test('current price tag is centered on the active candle close', () {
    const currentPrice = 100.0;
    final painter = _viewportInvariantPainter(
      viewport: const ChartViewport(),
      timeframe: 'M30',
      referencePrice: currentPrice,
      candles: [
        MarketCandle(
          time: DateTime(2026, 8, 24, 16),
          open: 98,
          high: 102,
          low: 97,
          close: currentPrice,
        ),
      ],
      useRealtimeCandles: true,
    );

    _paintViewportPainter(painter);

    final targets = painter.hitTargets;
    final candleCloseY =
        targets.priceTop +
        (targets.maxPrice - currentPrice) /
            (targets.maxPrice - targets.minPrice) *
            targets.priceHeight;
    expect(
      painter.debugCurrentPriceBadgeRect!.center.dy,
      closeTo(candleCloseY, .01),
    );
  });

  test('H1 price tag is centered on the active candle close', () {
    const currentPrice = 4104.09;
    final painter = _viewportInvariantPainter(
      viewport: const ChartViewport(),
      symbol: 'XAUUSD+',
      timeframe: 'H1',
      referencePrice: currentPrice,
      candles: [
        MarketCandle(
          time: DateTime(2026, 8, 24, 16),
          open: 4098,
          high: 4110,
          low: 4090,
          close: currentPrice,
        ),
      ],
      useRealtimeCandles: true,
    );

    _paintViewportPainter(painter);

    final targets = painter.hitTargets;
    final candleCloseY =
        targets.priceTop +
        (targets.maxPrice - currentPrice) /
            (targets.maxPrice - targets.minPrice) *
            targets.priceHeight;
    expect(
      painter.debugCurrentPriceBadgeRect!.center.dy,
      closeTo(candleCloseY, .01),
    );
  });

  test('historical horizontal pan centers auto scale on visible candles', () {
    final candles = <MarketCandle>[
      for (var index = 0; index < 19; index++)
        MarketCandle(
          time: DateTime.utc(2026, 8, 1, index),
          open: 99,
          high: 110,
          low: 90,
          close: 101,
        ),
      MarketCandle(
        time: DateTime.utc(2026, 8, 2),
        open: 1000,
        high: 1000,
        low: 1000,
        close: 1000,
      ),
    ];
    final painter = _viewportInvariantPainter(
      viewport: const ChartViewport(scrollOffset: 10000),
      candles: candles,
      referencePrice: 1000,
      currentPrice: 1000,
    );

    _paintViewportPainter(painter);

    final visible = painter.hitTargets.visibleCandles;
    expect(visible, isNot(contains(candles.last)));
    expect(
      (painter.chartMinPrice + painter.chartMaxPrice) / 2,
      closeTo(100, 1e-9),
    );
    expect(painter.currentPrice, greaterThan(painter.chartMaxPrice));
  });

  test('viewport spacing does not reshape the resolved candle series', () {
    Object candleValue(MarketCandle candle) => (
      time: candle.time,
      open: candle.open,
      high: candle.high,
      low: candle.low,
      close: candle.close,
      volume: candle.volume,
    );

    for (final fixture in const [
      (
        symbol: 'XAUEUR',
        timeframe: 'M1',
        price: 3566.07,
        pending: null,
        oneClick: false,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'M5',
        price: 4104.09,
        pending: null,
        oneClick: false,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H1',
        price: 4104.09,
        pending: null,
        oneClick: false,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H4',
        price: 4104.09,
        pending: 4200.0,
        oneClick: false,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H4',
        price: 4104.09,
        pending: null,
        oneClick: true,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H4',
        price: 4104.09,
        pending: null,
        oneClick: false,
        h4Expanded: true,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H2',
        price: 4104.09,
        pending: null,
        oneClick: false,
        h4Expanded: false,
      ),
      (
        symbol: 'XAUUSD+',
        timeframe: 'H6',
        price: 4104.09,
        pending: null,
        oneClick: false,
        h4Expanded: false,
      ),
    ]) {
      final compact = _viewportInvariantPainter(
        viewport: const ChartViewport(barSpacing: 12),
        symbol: fixture.symbol,
        timeframe: fixture.timeframe,
        referencePrice: fixture.price,
        pendingOrderPrice: fixture.pending,
        oneClickTrading: fixture.oneClick,
        h4ExpandedScaleSeen: fixture.h4Expanded,
      ).debugResolvedCandles;
      final expanded = _viewportInvariantPainter(
        viewport: const ChartViewport(barSpacing: 48),
        symbol: fixture.symbol,
        timeframe: fixture.timeframe,
        referencePrice: fixture.price,
        pendingOrderPrice: fixture.pending,
        oneClickTrading: fixture.oneClick,
        h4ExpandedScaleSeen: fixture.h4Expanded,
      ).debugResolvedCandles;

      expect(
        compact.map(candleValue).toList(),
        expanded.map(candleValue).toList(),
        reason: '${fixture.symbol}/${fixture.timeframe}',
      );
    }
  });

  test('painter has no viewport-dependent data synthesis helpers', () {
    final source = File(
      'lib/features/chart/presentation/rendering/mt5_candle_painter.dart',
    ).readAsStringSync();
    for (final forbidden in const [
      '_barSpacingScale',
      '_video2SpacingOutProgress',
      '_video2ScaledStep',
      '_xauEurM1Step',
      '_goldPriceStep',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'time-axis semantics use only supplied candle times at every spacing',
    () {
      final candles = List<MarketCandle>.generate(4, (index) {
        final price = 3565.0 + index;
        return MarketCandle(
          time: DateTime(2026, 8, 1, 10, index),
          open: price,
          high: price + .5,
          low: price - .5,
          close: price + .2,
          volume: 10 + index.toDouble(),
        );
      });
      final compact = _viewportInvariantPainter(
        viewport: const ChartViewport(barSpacing: 12),
        candles: candles,
        useRealtimeCandles: true,
      );
      final expanded = _viewportInvariantPainter(
        viewport: const ChartViewport(barSpacing: 48),
        candles: candles,
        useRealtimeCandles: true,
      );

      _paintViewportPainter(compact);
      _paintViewportPainter(expanded);

      final expectedTimes = candles.map((candle) => candle.time).toSet();
      expect(
        compact.hitTargets.timeAxisLabelAnchors.map(
          (anchor) => anchor.candleTime,
        ),
        everyElement(isIn(expectedTimes)),
      );
      expect(
        expanded.hitTargets.timeAxisLabelAnchors.map(
          (anchor) => anchor.candleTime,
        ),
        everyElement(isIn(expectedTimes)),
      );
    },
  );

  test('time-axis labels use the candle hit at each rendered label x', () {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String expectedLabel(DateTime time, String timeframe, int labelIndex) {
      final month = months[time.month - 1];
      if (timeframe == 'MN') return '$month ${time.year}';
      if (const {'D1', 'W1'}.contains(timeframe) || labelIndex.isOdd) {
        return '${time.day} $month';
      }
      String two(int value) => value.toString().padLeft(2, '0');
      return '${two(time.hour)}:${two(time.minute)}';
    }

    for (final timeframe in const ['M5', 'D1', 'W1', 'MN']) {
      final candles = List<MarketCandle>.generate(80, (index) {
        final time = timeframe == 'MN'
            ? DateTime(2020, index + 1)
            : DateTime(2026, 1, 1).add(switch (timeframe) {
                'M5' => Duration(minutes: index * 5),
                'D1' => Duration(days: index),
                'W1' => Duration(days: index * 7),
                _ => Duration.zero,
              });
        final price = 3560.0 + index;
        return MarketCandle(
          time: time,
          open: price,
          high: price + .7,
          low: price - .6,
          close: price + .2,
          volume: 100 + index.toDouble(),
        );
      });
      for (final viewport in const [
        ChartViewport(barSpacing: 8, scrollOffset: 180),
        ChartViewport(barSpacing: 40, scrollOffset: 640),
      ]) {
        final painter = _viewportInvariantPainter(
          viewport: viewport,
          candles: candles,
          useRealtimeCandles: true,
          symbol: 'TEST',
          timeframe: timeframe,
          referencePrice: candles.last.close,
        );

        _paintViewportPainter(painter);

        final visible = painter.hitTargets.visibleCandles;
        final anchors = painter.hitTargets.timeAxisLabelAnchors;
        expect(anchors, isNotEmpty, reason: '$timeframe $viewport');
        for (var anchorIndex = 0; anchorIndex < anchors.length; anchorIndex++) {
          final anchor = anchors[anchorIndex];
          final expectedCandle =
              visible[painter.hitTargets.visibleCandleIndex(anchor.x)];
          expect(
            anchor.candleTime,
            expectedCandle.time,
            reason: '$timeframe $viewport at ${anchor.x}',
          );
          expect(
            anchor.text,
            expectedLabel(expectedCandle.time, timeframe, anchorIndex),
            reason: '$timeframe $viewport at ${anchor.x}',
          );
        }
        expect(
          painter.hitTargets.timeAxisLabels,
          anchors.map((anchor) => anchor.text).toList(),
        );
      }
    }
  });

  test('chart does not render the legacy history badges', () {
    final hourlyCandles = List<MarketCandle>.generate(6, (index) {
      return MarketCandle(
        time: DateTime(2026, 8, 1, 10 + index),
        open: 4100 + index.toDouble(),
        high: 4101 + index.toDouble(),
        low: 4099 + index.toDouble(),
        close: 4100.5 + index,
      );
    });
    final dailyCandles = List<MarketCandle>.generate(6, (index) {
      return MarketCandle(
        time: DateTime(2026, 8, 1 + index),
        open: 3560 + index.toDouble(),
        high: 3561 + index.toDouble(),
        low: 3559 + index.toDouble(),
        close: 3560.5 + index,
      );
    });
    final hourly = _viewportInvariantPainter(
      viewport: const ChartViewport(),
      candles: hourlyCandles,
      useRealtimeCandles: true,
      symbol: 'XAUUSD+',
      timeframe: 'H1',
      referencePrice: hourlyCandles.last.close,
      showHistoryBadge: true,
    );
    final daily = _viewportInvariantPainter(
      viewport: const ChartViewport(),
      candles: dailyCandles,
      useRealtimeCandles: true,
      symbol: 'XAUEUR',
      timeframe: 'D1',
      referencePrice: dailyCandles.last.close,
    );

    _paintViewportPainter(hourly);
    _paintViewportPainter(daily);

    expect(hourly.hitTargets.historyBadgeLabel, isNull);
    expect(daily.hitTargets.historyBadgeLabel, isNull);
  });

  test('M30 reference keeps 17 fixed price marks on a 58px grid', () {
    final candles = List<MarketCandle>.generate(
      100,
      (index) => MarketCandle(
        time: DateTime.utc(2026, 8, 23, 8).add(Duration(minutes: index * 5)),
        open: 77000 + index * 4,
        high: 77030 + index * 4,
        low: 76970 + index * 4,
        close: 77010 + index * 4,
        volume: (100 + index).toDouble(),
      ),
    );
    final painter = _viewportInvariantPainter(
      viewport: const ChartViewport(),
      candles: candles,
      useRealtimeCandles: true,
      symbol: 'XAUUSD+',
      timeframe: 'M30',
      referencePrice: candles.last.close,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(590 / 1.5, 700));
    recorder.endRecording();

    expect(painter.priceAxisRect.width * 1.5, closeTo(105, 1));
    expect(painter.priceAxisRect.left * 1.5, closeTo(485, 1));
    expect(painter.hitTargets.candleWidth * 1.5, closeTo(42, 1));
    expect(painter.hitTargets.candleBodyWidth * 1.5, closeTo(42 * .64, 1));
    expect(painter.hitTargets.horizontalGridYs.length, greaterThan(10));
    expect(painter.hitTargets.verticalGridXs.length, greaterThan(5));
    for (final positions in <List<double>>[
      painter.hitTargets.horizontalGridYs,
      painter.hitTargets.verticalGridXs,
    ]) {
      for (var index = 1; index < positions.length; index++) {
        expect((positions[index] - positions[index - 1]) * 1.5, closeTo(58, 1));
      }
    }
    expect(painter.hitTargets.priceAxisLabels, hasLength(17));
    expect(painter.hitTargets.horizontalGridYs, hasLength(17));
    for (
      var index = 0;
      index < painter.hitTargets.priceAxisLabels.length;
      index++
    ) {
      expect(
        painter.hitTargets.priceAxisLabels[index].y,
        closeTo(
          painter.hitTargets.priceTop +
              painter.hitTargets.priceHeight * index / 17,
          .01,
        ),
      );
      expect(
        painter.hitTargets.priceAxisLabels[index].y,
        closeTo(painter.hitTargets.horizontalGridYs[index], .01),
      );
    }
    expect(painter.hitTargets.timeAxisLabelAnchors.length, greaterThan(5));
    for (
      var index = 0;
      index < painter.hitTargets.timeAxisLabelAnchors.length;
      index++
    ) {
      final label = painter.hitTargets.timeAxisLabelAnchors[index].text;
      if (index.isEven) {
        expect(label, matches(RegExp(r'^\d{2}:\d{2}$')));
      } else {
        expect(label, matches(RegExp(r'^\d{1,2} [A-Z][a-z]{2}$')));
      }
      if (index == 0) continue;
      expect(
        painter.hitTargets.timeAxisLabelAnchors[index].x -
            painter.hitTargets.timeAxisLabelAnchors[index - 1].x,
        closeTo(42, 1),
      );
    }
    expect(
      painter.hitTargets.firstCandleCenterX +
          painter.hitTargets.candleWidth *
              (painter.hitTargets.visibleCandles.length - 1),
      closeTo(
        painter.hitTargets.chartWidth - painter.hitTargets.candleWidth,
        .01,
      ),
    );
  });

  for (final testCase in [
    (
      symbol: 'BTCUSD',
      timeframe: 'M5',
      quote: 65175.98,
      start: DateTime.utc(2026, 7, 1),
      interval: const Duration(minutes: 5),
      count: 80,
      expected: <String, Object>{
        'painterType': 'Mt5CandlePainter',
        'priceAxisRect': const Rect.fromLTWH(
          316 + 2 / 3,
          0,
          67 + 1 / 3,
          755 + 1 / 3,
        ),
        'bottomAxisRect': const Rect.fromLTWH(0, 755 + 1 / 3, 384, 22),
        'firstResolvedTimestamp': DateTime.utc(2026, 7, 1),
        'lastResolvedTimestamp': DateTime.utc(2026, 7, 1, 6, 35),
        'visibleCandleCount': 11,
        'currentPriceBadgeRect': const Rect.fromLTWH(
          318 + 2 / 3,
          361.4906547618431,
          67,
          20,
        ),
        'hitTargetMapping': const <int>[0, 5, 10],
      },
    ),
    (
      symbol: 'XAUUSD+',
      timeframe: 'H4',
      quote: 4104.09,
      start: DateTime.utc(2026, 7, 1),
      interval: const Duration(hours: 4),
      count: 40,
      expected: <String, Object>{
        'painterType': 'Mt5CandlePainter',
        'priceAxisRect': const Rect.fromLTWH(
          316 + 2 / 3,
          0,
          67 + 1 / 3,
          755 + 1 / 3,
        ),
        'bottomAxisRect': const Rect.fromLTWH(0, 755 + 1 / 3, 384, 22),
        'firstResolvedTimestamp': DateTime.utc(2026, 7, 1),
        'lastResolvedTimestamp': DateTime.utc(2026, 7, 7, 12),
        'visibleCandleCount': 11,
        'currentPriceBadgeRect': const Rect.fromLTWH(
          318 + 2 / 3,
          209.90654761906865,
          67,
          20,
        ),
        'hitTargetMapping': const <int>[0, 5, 10],
      },
    ),
  ]) {
    testWidgets(
      '${testCase.symbol}/${testCase.timeframe} renderer characterization',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(384, 848));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final history = List<MarketCandle>.generate(testCase.count, (index) {
          final open = testCase.quote + (index - testCase.count) * .25;
          return MarketCandle(
            time: testCase.start.add(testCase.interval * index),
            open: open,
            high: open + .18,
            low: open - .11,
            close: open + .07,
            volume: 1000 + index.toDouble(),
          );
        });
        final quote = DemoQuote(
          symbol: testCase.symbol,
          name: testCase.symbol,
          bid: history.last.close,
          ask: history.last.close + .13,
          changePercent: .1,
          sourceTimestamp: history.last.time.toUtc(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              marketApiConfigProvider.overrideWithValue(
                const MarketApiConfig(baseUrl: 'https://market.example.com'),
              ),
              marketCandlesProvider.overrideWith(
                (ref, request) => Stream.value(history),
              ),
              realtimeCandleProvider.overrideWith(
                (ref, request) => const Stream<MarketCandle>.empty(),
              ),
              demoQuoteProvider.overrideWith(
                (ref, symbol) => Stream.value(quote),
              ),
              marketClockProvider.overrideWithValue(
                () => history.last.time.toUtc(),
              ),
            ],
            child: MaterialApp(
              home: ChartScreen(
                symbol: testCase.symbol,
                initialTimeframe: testCase.timeframe,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final painter = tester
            .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
            .painter;
        expect(painter, isA<Mt5CandlePainter>());
        final snapshot = _rendererCharacterization(
          painter! as Mt5CandlePainter,
        );
        expect(snapshot['painterType'], testCase.expected['painterType']);
        final priceAxis = snapshot['priceAxisRect']! as Rect;
        final expectedPriceAxis = testCase.expected['priceAxisRect']! as Rect;
        expect(priceAxis.left, closeTo(expectedPriceAxis.left, .001));
        expect(priceAxis.top, closeTo(expectedPriceAxis.top, .001));
        expect(priceAxis.width, closeTo(expectedPriceAxis.width, .001));
        expect(priceAxis.height, closeTo(expectedPriceAxis.height, .001));
        final bottomAxis = snapshot['bottomAxisRect']! as Rect;
        final expectedBottomAxis = testCase.expected['bottomAxisRect']! as Rect;
        expect(bottomAxis.left, closeTo(expectedBottomAxis.left, .001));
        expect(bottomAxis.top, closeTo(expectedBottomAxis.top, .001));
        expect(bottomAxis.width, closeTo(expectedBottomAxis.width, .001));
        expect(bottomAxis.height, closeTo(expectedBottomAxis.height, .001));
        expect(
          snapshot['firstResolvedTimestamp'],
          testCase.expected['firstResolvedTimestamp'],
        );
        expect(
          snapshot['lastResolvedTimestamp'],
          testCase.expected['lastResolvedTimestamp'],
        );
        expect(
          snapshot['visibleCandleCount'],
          testCase.expected['visibleCandleCount'],
        );
        final badge = snapshot['currentPriceBadgeRect']! as Rect;
        final expectedBadge =
            testCase.expected['currentPriceBadgeRect']! as Rect;
        expect(badge.left, closeTo(expectedBadge.left, .05));
        expect(badge.top, closeTo(expectedBadge.top, .05));
        expect(badge.width, closeTo(expectedBadge.width, .05));
        expect(badge.height, closeTo(expectedBadge.height, .05));
        expect(
          snapshot['hitTargetMapping'],
          testCase.expected['hitTargetMapping'],
        );
      },
    );
  }

  testWidgets('price scale ignores highs and lows outside the visible window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final start = DateTime.utc(2026, 8, 23);
    final history = List<MarketCandle>.generate(80, (index) {
      final price = 100 + index * .05;
      return MarketCandle(
        time: start.add(Duration(minutes: index * 5)),
        open: price,
        high: index == 0 ? 1000000 : price + .2,
        low: index == 0 ? -1000000 : price - .2,
        close: price + .05,
        volume: 1000,
      );
    });
    final quote = DemoQuote(
      symbol: 'TEST',
      name: 'Test',
      bid: history.last.close,
      ask: history.last.close + .01,
      changePercent: 0,
      sourceTimestamp: history.last.time,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(history),
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(quote)),
          marketClockProvider.overrideWithValue(() => history.last.time),
        ],
        child: const MaterialApp(home: ChartScreen(symbol: 'TEST')),
      ),
    );
    await tester.pump();
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.visibleCandleCount, 11);
    expect(painter.chartMinPrice, greaterThan(90));
    expect(painter.chartMaxPrice, lessThan(120));
  });

  testWidgets('realtime chart renders API candles without demo reshaping', (
    tester,
  ) async {
    final history = List<MarketCandle>.generate(40, (index) {
      final open = 4100 + index * .25;
      return MarketCandle(
        time: DateTime.utc(2026, 7, 1).add(Duration(hours: index * 4)),
        open: open,
        high: open + .18,
        low: open - .11,
        close: open + .07,
        volume: 1000 + index.toDouble(),
      );
    });
    final quote = DemoQuote(
      symbol: 'XAUUSD+',
      name: 'Gold US Dollar',
      bid: history.last.close,
      ask: history.last.close + .13,
      changePercent: .1,
      sourceTimestamp: history.last.time.toUtc(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketApiConfigProvider.overrideWithValue(
            const MarketApiConfig(baseUrl: 'https://market.example.com'),
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(history),
          ),
          realtimeCandleProvider.overrideWith(
            (ref, request) => const Stream<MarketCandle>.empty(),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(quote)),
          marketClockProvider.overrideWithValue(
            () => history.last.time.toUtc(),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final resolved = List<MarketCandle>.from(
      painter.debugResolvedCandles as Iterable,
    );

    expect(painter.useRealtimeCandles, isTrue);
    expect(resolved, hasLength(history.length));
    expect(resolved.first.time, history.first.time);
    expect(resolved.first.high, history.first.high);
    expect(resolved.last.time, history.last.time);
    expect(resolved.last.low, history.last.low);
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      lessThan(30),
    );
  });

  test('chart indicator state can add and remove indicators', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(chartIndicatorsProvider.notifier).toggle('Moving Average');
    expect(container.read(chartIndicatorsProvider), contains('Moving Average'));

    container.read(chartIndicatorsProvider.notifier).toggle('Moving Average');
    expect(container.read(chartIndicatorsProvider), isEmpty);

    expect(container.read(chartIndicatorsVisibilityProvider), isTrue);
    container.read(chartIndicatorsVisibilityProvider.notifier).toggle();
    expect(container.read(chartIndicatorsVisibilityProvider), isFalse);
  });

  test('market symbols can be added, removed and reordered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(marketSymbolsProvider.notifier);

    expect(
      container.read(marketSymbolsProvider),
      equals(['XAUUSD+', 'BTCUSD']),
    );
    controller.add('AUDNOK');
    expect(container.read(marketSymbolsProvider), contains('AUDNOK'));
    controller.remove('AUDNOK');
    expect(container.read(marketSymbolsProvider), isNot(contains('AUDNOK')));

    final first = container.read(marketSymbolsProvider).first;
    controller.reorder(0, 2);
    expect(container.read(marketSymbolsProvider)[1], first);

    controller.removeAll(['BTCUSD']);
    expect(container.read(marketSymbolsProvider), isNot(contains('BTCUSD')));
  });

  test('market columns and chart objects persist editing actions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final columns = container.read(marketColumnsProvider.notifier);
    columns.add('Spread');
    expect(container.read(marketColumnsProvider), contains('Spread'));
    columns.reorder(3, 1);
    expect(container.read(marketColumnsProvider)[1], 'Spread');
    columns.remove('Spread');
    expect(container.read(marketColumnsProvider), isNot(contains('Spread')));

    final objects = container.read(chartObjectsProvider.notifier);
    objects.add('Đường thẳng');
    objects.add('Hình chữ nhật');
    expect(container.read(chartObjectsProvider), hasLength(2));
    objects.setAllVisible(false);
    expect(
      container.read(chartObjectsProvider).every((item) => !item.visible),
      isTrue,
    );
    objects.setAllLocked(true);
    expect(
      container.read(chartObjectsProvider).every((item) => item.locked),
      isTrue,
    );
    objects.remove(container.read(chartObjectsProvider).first.id);
    expect(container.read(chartObjectsProvider), hasLength(1));
  });

  testWidgets('symbol deletion requires selection and trash confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(marketSymbolsProvider.notifier).add('AUDNOK');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: SymbolEditScreen(),
          ),
        ),
      ),
    );

    expect(container.read(marketSymbolsProvider), contains('AUDNOK'));
    expect(find.byIcon(CupertinoIcons.circle), findsNWidgets(2));
    expect(find.byKey(const ValueKey('symbol-select-XAUUSD+')), findsNothing);
    expect(find.byKey(const ValueKey('symbol-select-BTCUSD')), findsOneWidget);
    expect(tester.getCenter(find.text('XAUUSD')).dy, closeTo(137, .75));
    expect(tester.getCenter(find.text('BTCUSD')).dy, closeTo(203, .75));
    expect(tester.getCenter(find.text('AUDNOK')).dy, closeTo(269, .75));
    expect(
      tester.getCenter(find.byKey(const ValueKey('symbol-select-AUDNOK'))).dx,
      closeTo(29, .75),
    );

    await tester.tap(find.byKey(const ValueKey('symbol-select-AUDNOK')));
    await tester.pump();
    expect(container.read(marketSymbolsProvider), contains('AUDNOK'));
    expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    expect(find.byKey(const Key('symbol-edit-delete')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('symbol-edit-delete'))).dx,
      closeTo(230, .75),
    );

    await tester.tap(find.byKey(const Key('symbol-edit-delete')));
    await tester.pump();
    expect(container.read(marketSymbolsProvider), isNot(contains('AUDNOK')));
    expect(
      container.read(marketSymbolsProvider),
      equals(['XAUUSD+', 'BTCUSD']),
    );
  });

  testWidgets('symbol deletion policy stays with the symbol after reorder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final symbols = container.read(marketSymbolsProvider.notifier);
    symbols.add('AUDNOK');
    symbols.reorder(1, 3);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: SymbolEditScreen(),
          ),
        ),
      ),
    );

    expect(container.read(marketSymbolsProvider), [
      'XAUUSD+',
      'AUDNOK',
      'BTCUSD',
    ]);
    expect(find.byKey(const ValueKey('symbol-select-XAUUSD+')), findsNothing);
    expect(find.byKey(const ValueKey('symbol-select-BTCUSD')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('symbol-select-BTCUSD')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('symbol-edit-delete')));
    await tester.pump();

    expect(container.read(marketSymbolsProvider), ['XAUUSD+', 'AUDNOK']);
  });

  testWidgets('global symbol search follows the grouped video results', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SymbolSearchScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('0 / 126'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.byKey(const Key('symbol-search-close')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'u');
    await tester.pump();
    expect(find.text('Nasdaq|Stock'), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
    expect(tester.getTopLeft(find.text('U')).dy, lessThan(130));

    await tester.enterText(find.byType(TextField), 'us');
    await tester.pump();
    expect(find.text('USA'), findsOneWidget);
    expect(tester.getTopLeft(find.text('USA')).dy, lessThan(140));

    await tester.tap(find.byKey(const ValueKey('symbol-info-USA')));
    await tester.pumpAndSettle();
    expect(find.text('Chào mua'), findsOneWidget);
    expect(find.text('Chào bán'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('USA'));
    await tester.pump();
    expect(container.read(marketSymbolsProvider), contains('USA'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus ??
          false,
      isFalse,
    );
  });

  testWidgets('market header toggles detailed and compact quote modes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: videoReferenceOverrides,
        child: const MaterialApp(
          home: MediaQuery(
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

    expect(find.text('Cặp ngoại tệ'), findsNothing);
    expect(find.byKey(const Key('market-manage-edit-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('market-bid-XAUUSD+')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-bid-XAUUSD+')))
          .style
          ?.color,
      AppColors.primary,
    );

    await tester.tap(find.byKey(const Key('market-toggle-view')));
    await tester.pump();
    expect(find.text('Cặp ngoại tệ'), findsOneWidget);
    expect(find.text('Chào mua'), findsOneWidget);
    expect(find.text('Chào bán'), findsOneWidget);
    expect(find.text('Ngày %'), findsOneWidget);
    expect(find.byKey(const Key('market-manage-grid-icon')), findsOneWidget);
    expect(tester.getTopRight(find.text('Chào mua')).dx, closeTo(204, 1.5));
    expect(tester.getTopRight(find.text('Chào bán')).dx, closeTo(295, 1.5));
    expect(tester.getTopRight(find.text('Ngày %')).dx, closeTo(380, 1.5));
    expect(
      tester.widget<Text>(find.text('4104.09')).style?.color,
      AppColors.textPrimary,
    );
    final unchangedPercentLabels = tester.widgetList<Text>(find.text('0.00%'));
    expect(unchangedPercentLabels, isNotEmpty);
    expect(
      unchangedPercentLabels.every(
        (label) => label.style?.color == AppColors.primary,
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('market-toggle-view')));
    await tester.pump();
    expect(find.text('Cặp ngoại tệ'), findsNothing);
    expect(find.byKey(const Key('market-manage-edit-icon')), findsOneWidget);
  });

  testWidgets('one-click defaults to the current symbol position volume', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    container
        .read(activeDemoAccountIdProvider.notifier)
        .select(videoLargeAccountId);
    expect(container.read(demoPositionsProvider).first.volume, 179);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H1'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('chart-one-click-volume-text')))
          .data,
      '179',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('chart-one-click-volume-text')))
          .style
          ?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('crosshair hint disappears after three seconds', (tester) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H1'),
        ),
      ),
    );
    await tester.pump();

    const hintKey = Key('chart-crosshair-hint');
    expect(find.byKey(hintKey), findsNothing);

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();

    expect(find.byKey(hintKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(hintKey)).data,
      'Di chuyển con trỏ hoặc nhấn vào biểu đồ để chuyển sang\nmột loại thước',
    );
    expect(tester.widget<Text>(find.byKey(hintKey)).style?.fontSize, 11.5);
    expect(
      (tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter)
          .crosshairEnabled,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.byKey(hintKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(hintKey), findsNothing);
    expect(
      (tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter)
          .crosshairEnabled,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    expect(find.byKey(hintKey), findsNothing);
    expect(
      (tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter)
          .crosshairEnabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    expect(find.byKey(hintKey), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    expect(find.byKey(hintKey), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(hintKey), findsNothing);
  });

  testWidgets('chart volume and timeframe controls update', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith((ref, request) {
            final now = DateTime(2026, 7, 17, 12);
            return Stream.value(
              List.generate(
                40,
                (index) => MarketCandle(
                  time: now.add(Duration(minutes: index * 15)),
                  open: 1.14 + index * .00001,
                  high: 1.1402 + index * .00001,
                  low: 1.1398 + index * .00001,
                  close: 1.1401 + index * .00001,
                ),
              ),
            );
          }),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(home: ChartScreen()),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('chart-toolbar-timeframe')))
          .style
          ?.color,
      ChartReferenceTheme.light.toolbarInk,
    );

    expect(
      tester.getCenter(find.byKey(const Key('chart-one-click-toggle'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const Key('chart-windows-button'))).dx,
      ),
      reason:
          'The video maps one-click trading to the two-window icon at the '
          'far-right edge.',
    );

    expect(find.byKey(const Key('chart-one-click-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('chart-one-click-panel')), findsOneWidget);
    expect(find.text('0.25'), findsOneWidget);
    final oneClickPanel = find.byKey(const Key('chart-one-click-panel'));
    final downChevron = find.descendant(
      of: oneClickPanel,
      matching: find.byKey(const Key('chart-one-click-volume-down-chevron')),
    );
    final upChevron = find.descendant(
      of: oneClickPanel,
      matching: find.byKey(const Key('chart-one-click-volume-up-chevron')),
    );
    expect(tester.getSize(downChevron), const Size(14, 12));
    expect(tester.getSize(upChevron), const Size(14, 12));
    expect(tester.getCenter(downChevron).dy, tester.getCenter(upChevron).dy);
    await tester.tap(find.byKey(const Key('chart-one-click-volume-field')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-numeric-keypad-sheet')), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    await tester.tap(find.byKey(const Key('chart-keypad-backspace')));
    await tester.tap(find.byKey(const Key('chart-keypad-backspace')));
    await tester.tap(find.byKey(const Key('chart-keypad-5')));
    await tester.tap(find.byKey(const Key('chart-keypad-0')));
    await tester.pump();
    expect(find.text('0.50'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-numeric-keypad-sheet')), findsNothing);
    expect(find.byKey(const Key('chart-one-click-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    expect(find.text('0.50'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('chart-one-click-volume-up-chevron')),
    );
    await tester.pump();
    expect(find.text('0.51'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('chart-one-click-panel')), findsNothing);

    await tester.tap(find.text('H4').first);
    await tester.pump();
    expect(find.text('H1'), findsOneWidget);
    for (final period in const <String>[
      'M1',
      'M5',
      'M15',
      'M30',
      'H1',
      'H4',
      'D1',
      'W1',
      'MN',
    ]) {
      final label = tester.widgetList<Text>(find.text(period)).first;
      expect(
        label.style?.fontFamily,
        AppTypography.referencePlainFamily,
        reason: period,
      );
      expect(label.style?.fontWeight, FontWeight.w700, reason: period);
      expect(label.style?.fontVariations, isNull, reason: period);
    }
    await tester.tap(find.text('H1'));
    await tester.pump();
    expect(find.text('H1'), findsWidgets);

    await tester.tap(find.text('H1').first);
    await tester.pump();
    await tester.tap(find.text('•••').last);
    await tester.pumpAndSettle();
    expect(find.text('Phút'), findsOneWidget);
    expect(find.text('M2'), findsOneWidget);
    await tester.tap(find.text('M2'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('M2'), findsWidgets);

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    final chartRect = tester.getRect(
      find.byKey(const Key('chart-gesture-area')),
    );
    final firstPointer = await tester.startGesture(
      Offset(chartRect.left + 70, chartRect.top + 160),
      pointer: 11,
    );
    await tester.pump();
    final secondPointer = await tester.startGesture(
      Offset(chartRect.left + 220, chartRect.top + 300),
      pointer: 12,
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementStart, isNotNull);
    expect(painter.measurementEnd, isNotNull);

    await secondPointer.moveBy(const Offset(20, -30));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementEnd, isNotNull);
    final retainedMeasurementStart = painter.measurementStart as Offset;
    final retainedMeasurementEnd = painter.measurementEnd as Offset;
    final retainedCrosshairPosition = painter.crosshairPosition as Offset;

    await secondPointer.up();
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementStart, retainedMeasurementStart);
    expect(painter.measurementEnd, retainedMeasurementEnd);
    expect(painter.crosshairPosition, retainedCrosshairPosition);

    await firstPointer.up();
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementStart, retainedMeasurementStart);
    expect(painter.measurementEnd, retainedMeasurementEnd);
    expect(painter.crosshairPosition, retainedCrosshairPosition);

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementStart, isNull);
    expect(painter.measurementEnd, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart numeric keypad matches the video two iOS geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 853.3333333333));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-one-click-volume-field')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('chart-numeric-keypad-sheet'));
    expect(
      tester.getRect(sheet),
      const Rect.fromLTWH(0, 556, 384, 297.3333333333),
    );
    expect(
      find.byKey(const Key('chart-one-click-volume-caret')),
      findsOneWidget,
    );
    expect(find.text('A B C'), findsOneWidget);
    expect(find.text('P Q R S'), findsOneWidget);

    final firstKey = find.byKey(const Key('chart-keypad-1'));
    final firstRect = tester.getRect(firstKey);
    expect(firstRect.left, closeTo(4.6666666667, .01));
    expect(firstRect.top, closeTo(579.3333333333, .01));
    expect(firstRect.width, closeTo(120.8888888889, .01));
    expect(firstRect.height, closeTo(46.6666666667, .01));
    expect(tester.widget<Material>(firstKey).color?.toARGB32(), 0xFFE0E0E0);

    final zeroRect = tester.getRect(find.byKey(const Key('chart-keypad-0')));
    expect(zeroRect.top, closeTo(739.3333333333, .01));
    expect(zeroRect.height, closeTo(46.6666666667, .01));
    expect(
      tester
          .widget<Material>(find.byKey(const Key('chart-keypad-decimal')))
          .color,
      Colors.transparent,
    );

    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.byKey(const Key('chart-one-click-panel')), findsNothing);
  });

  testWidgets('video two BTC chart follows the live quote instead of history', (
    tester,
  ) async {
    final quoteController = StreamController<DemoQuote>();
    addTearDown(quoteController.close);
    const initialQuote = DemoQuote(
      symbol: 'BTCUSD',
      name: 'Bitcoin',
      bid: 65175.98,
      ask: 65193.10,
      changePercent: .82,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoQuotesProvider.overrideWithValue(const [initialQuote]),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => quoteController.stream,
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value([
              MarketCandle(
                time: DateTime(2026, 7, 27, 4),
                open: 12000,
                high: 12100,
                low: 11900,
                close: 12050,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.currentPrice, initialQuote.bid);

    await tester.pump();
    quoteController.add(
      const DemoQuote(
        symbol: 'BTCUSD',
        name: 'Bitcoin',
        bid: 65120.12,
        ask: 65137.24,
        changePercent: .81,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.currentPrice, 65120.12);
  });

  testWidgets('video two timeframe dialog uses the anchored light geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(home: ChartScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('H4').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-timeframe-more')));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('chart-timeframe-dialog'));
    final dialogRect = tester.getRect(dialog);
    expect(dialogRect.left, closeTo(69, 1));
    expect(dialogRect.top, closeTo(81, 1));
    expect(dialogRect.width, closeTo(306.6666666667, 1));
    expect(dialogRect.height, closeTo(444, 12));
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      ChartReferenceTheme.light.background,
    );
    final h4Rect = tester.getRect(
      find.byKey(const ValueKey('chart-timeframe-H4')),
    );
    expect(h4Rect.width, closeTo(58, .5));
    expect(h4Rect.height, closeTo(32, .5));
    expect(
      find.text(
        'Nhấn và giữ một khung thời\n'
        'gian để thêm hoặc xóa nó\n'
        'khỏi menu biểu đồ',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('chart-timeframe-hint-close')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('chart long press maps its touch y coordinate to order price', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    dynamic chartState = tester.state(find.byType(ChartScreen));
    chartState.setState(() => chartState.volume = .50);
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    final rect = tester.getRect(chart);
    const verticalFraction = .72;
    final touchLocalY = rect.height * verticalFraction;
    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final priceTop = painter.hitTargets.priceTop as double;
    final priceHeight = painter.hitTargets.priceHeight as double;
    final expected = double.parse(
      ((painter.chartMaxPrice as double) -
              ((touchLocalY.clamp(
                            priceTop,
                            painter.hitTargets.chartHeight as double,
                          ) -
                          priceTop) /
                      priceHeight) *
                  ((painter.chartMaxPrice as double) -
                      (painter.chartMinPrice as double)))
          .toStringAsFixed(2),
    );
    final gesture = await tester.startGesture(
      Offset(rect.left + 100, rect.top + touchLocalY),
      pointer: 41,
    );
    await tester.pump(const Duration(milliseconds: 560));
    await tester.pump();

    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.pendingOrderType, 'Buy Limit');
    expect(painter.pendingOrderPrice as double, closeTo(expected, .02));
    expect(painter.pendingOrderVolume as double, .50);
    expect(
      painter.pendingOrderPrice as double,
      lessThan((painter.currentPrice as double) - 50),
    );
    await gesture.up();
  });

  testWidgets(
    'transient pending draft drags price, keeps SL TP and restores subtitle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
          ),
        ),
      );
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      await tester.longPress(chart);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hien thi muc do giao dich'), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
      expect(container.read(demoPendingOrdersProvider), isEmpty);
      final pendingSheetRect = tester.getRect(
        find.byKey(const Key('chart-transient-pending-sheet')),
      );
      final pendingPillRect = tester.getRect(
        find.byKey(const Key('chart-pending-order-pill')),
      );
      expect(pendingSheetRect.left, 0);
      expect(pendingSheetRect.right, 384);
      expect(pendingSheetRect.height, 81);
      final pendingGrabber = tester.widget<Container>(
        find.byKey(const Key('chart-pending-grabber')),
      );
      expect(pendingGrabber.constraints?.maxWidth, 32);
      expect(pendingGrabber.constraints?.maxHeight, 4);
      expect(
        tester.getSize(find.byKey(const Key('chart-pending-grabber'))).height,
        closeTo(18.6666666667, .01),
      );
      expect(pendingPillRect.left, 16);
      expect(pendingPillRect.size, const Size(179, 34));

      final chartRect = tester.getRect(chart);
      await tester.longPressAt(
        Offset(chartRect.left + 48, chartRect.top + 120),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);

      dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final initialPrice = painter.pendingOrderPrice as double;
      final initialY = painter.pendingOrderY as double;
      final initialViewport = painter.viewport as ChartViewport;
      final drag = await tester.startGesture(
        Offset(
          chartRect.left + (painter.hitTargets.chartWidth as double) / 2,
          chartRect.top + initialY,
        ),
        pointer: 42,
      );
      await tester.pump();
      await drag.moveBy(const Offset(36, -60));
      await tester.pump();
      await drag.up();
      await tester.pump();

      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final draggedPrice = painter.pendingOrderPrice as double;
      final draggedY = painter.pendingOrderY as double;
      final unfocusedMaxPrice = painter.chartMaxPrice as double;
      expect(draggedPrice, greaterThan(initialPrice));
      expect(draggedY, lessThan(initialY));
      expect(painter.viewport, initialViewport);
      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chart-pending-jump')));
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final focusedMiddle =
          (painter.hitTargets.priceTop as double) +
          (painter.hitTargets.priceHeight as double) * .5;
      expect(painter.pendingOrderPrice, draggedPrice);
      expect(
        painter.chartMaxPrice as double,
        isNot(closeTo(unfocusedMaxPrice, .01)),
      );
      expect(painter.pendingOrderY as double, closeTo(focusedMiddle, .02));

      await tester.tap(find.byKey(const Key('chart-pending-jump')));
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.pendingOrderPrice, draggedPrice);
      expect(painter.chartMaxPrice as double, closeTo(unfocusedMaxPrice, .01));
      expect(painter.pendingOrderY as double, closeTo(draggedY, .02));

      await tester.tap(find.byKey(const Key('chart-pending-sl')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3900.50');
      await tester.tap(find.text('XONG'));
      await tester.pumpAndSettle();

      dynamic chartState = tester.state(find.byType(ChartScreen));
      expect(chartState.pendingStopLoss, 3900.50);
      expect(container.read(demoPendingOrdersProvider), isEmpty);
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.pendingStopLoss, 3900.50);
      expect(painter.pendingTakeProfit, isNull);
      await tester.tap(find.byKey(const Key('chart-pending-sl')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '3900.50',
      );
      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chart-pending-tp')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4200.75');
      await tester.tap(find.text('XONG'));
      await tester.pumpAndSettle();

      chartState = tester.state(find.byType(ChartScreen));
      expect(chartState.pendingStopLoss, 3900.50);
      expect(chartState.pendingTakeProfit, 4200.75);
      expect(container.read(demoPendingOrdersProvider), isEmpty);
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.pendingStopLoss, 3900.50);
      expect(painter.pendingTakeProfit, 4200.75);
      await tester.tap(find.byKey(const Key('chart-pending-tp')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '4200.75',
      );
      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.textContaining('Gold vs US Dollar'), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
      expect(painter.pendingOrderPrice, draggedPrice);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.byKey(const Key('chart-transient-pending-sheet')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byKey(const Key('chart-transient-pending-sheet')),
        findsOneWidget,
      );
      expect(
        tester
            .getRect(find.byKey(const Key('chart-transient-pending-sheet')))
            .top,
        greaterThan(pendingSheetRect.top),
      );
      await tester.pump(const Duration(milliseconds: 121));
      await tester.pump();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);
      expect(
        find.byKey(const Key('chart-transient-pending-sheet')),
        findsNothing,
      );
      expect(find.byKey(const Key('chart-pending-jump')), findsNothing);
      expect(find.byType(ChartScreen), findsOneWidget);
    },
  );

  testWidgets(
    'connected pending pill places the dragged draft with SL and TP',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(container.read(demoQuoteProvider('XAUUSD+')).hasValue, isTrue);

      await tester.longPress(find.byKey(const Key('chart-gesture-area')));
      await tester.pumpAndSettle();
      dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final draftPrice = painter.pendingOrderPrice as double;
      dynamic chartState = tester.state(find.byType(ChartScreen));
      chartState.setState(() {
        chartState.pendingStopLoss = 3900.50;
        chartState.pendingTakeProfit = 4200.75;
      });
      await tester.pump();

      await tester.tap(find.byKey(const Key('chart-pending-order-pill')));
      await tester.pump();

      final orders = container.read(demoPendingOrdersProvider);
      expect(orders, hasLength(1));
      expect(orders.single.type, 'Buy Limit');
      expect(orders.single.price, draftPrice);
      expect(orders.single.stopLoss, 3900.50);
      expect(orders.single.takeProfit, 4200.75);
      expect(
        find.byKey(const Key('chart-pending-no-connection')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 241));
      await tester.pump();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);

      container
          .read(demoTradingProvider.notifier)
          .placePendingOrder(
            symbol: 'XAUUSD+',
            type: 'Sell Limit',
            volume: .10,
            price: 4150,
            stopLoss: 4175,
            takeProfit: 4125,
          );
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.pendingOrders, hasLength(2));
    },
  );

  testWidgets('pending confirmation only reports no connection on feed error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
        demoQuoteProvider.overrideWith(
          (ref, symbol) =>
              Stream<DemoQuote>.error(StateError('feed disconnected')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(container.read(demoQuoteProvider('XAUUSD+')).hasError, isTrue);

    await tester.longPress(find.byKey(const Key('chart-gesture-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-pending-order-pill')));
    await tester.pump();

    expect(
      find.byKey(const Key('chart-pending-no-connection')),
      findsOneWidget,
    );
    expect(container.read(demoPendingOrdersProvider), isEmpty);
  });

  testWidgets('chart price follows live high and low ticks', (tester) async {
    final quoteController = StreamController<DemoQuote>();
    addTearDown(quoteController.close);
    final tickAt = DateTime(2026, 7, 30, 10, 5);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          marketClockProvider.overrideWithValue(() => tickAt),
          demoQuoteProvider.overrideWith(
            (ref, symbol) => quoteController.stream,
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    quoteController.add(
      const DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4104.09,
        ask: 4104.22,
        changePercent: 1.24,
      ),
    );
    await tester.pump();
    await tester.pump();
    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.currentPrice, 4104.09);

    quoteController.add(
      const DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4115.25,
        ask: 4115.38,
        changePercent: 1.5,
      ),
    );
    await tester.pump();
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.currentPrice, 4115.25);

    quoteController.add(
      const DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4090.50,
        ask: 4090.63,
        changePercent: -.2,
      ),
    );
    await tester.pump();
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.currentPrice, 4090.50);
  });

  testWidgets('chart pinch, pan and double tap update the video viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
        ),
      ),
    );
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chart);
    final chartLeft = tester.getTopLeft(chart).dx;
    final initialPainter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    final initialFocalCandle = initialPainter.viewport.candleIndexAt(
      center.dx - chartLeft,
      plotWidth: initialPainter.hitTargets.chartWidth,
      candleCount: initialPainter.debugResolvedCandles.length,
    );
    final first = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 21,
    );
    await tester.pump();
    final second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 22,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(100, 0));
    await second.moveTo(center + const Offset(100, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 60));
    final firstScalePainter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    final firstScaledFocal = firstScalePainter.viewport.candleIndexAt(
      center.dx - chartLeft,
      plotWidth: firstScalePainter.hitTargets.chartWidth,
      candleCount: firstScalePainter.debugResolvedCandles.length,
    );
    expect(
      (firstScaledFocal - initialFocalCandle).abs(),
      lessThanOrEqualTo(1),
      reason:
          'first pinch moved focal candle from $initialFocalCandle to '
          '$firstScaledFocal with ${firstScalePainter.viewport}',
    );

    final third = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 23,
    );
    await tester.pump();
    final fourth = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 24,
    );
    await tester.pump();
    await third.moveTo(center - const Offset(100, 0));
    await fourth.moveTo(center + const Offset(100, 0));
    await tester.pump();
    await third.up();
    await fourth.up();
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport.barSpacing as double, 48);
    final scaledFocalCandle = (painter.viewport as ChartViewport).candleIndexAt(
      center.dx - chartLeft,
      plotWidth: painter.hitTargets.chartWidth as double,
      candleCount: (painter.debugResolvedCandles as List).length,
    );
    expect(
      (scaledFocalCandle - initialFocalCandle).abs(),
      lessThanOrEqualTo(1),
      reason:
          'focal candle moved from $initialFocalCandle to $scaledFocalCandle '
          'with ${painter.viewport}; first was ${firstScalePainter.viewport}',
    );
    final expandedViewport = painter.viewport as ChartViewport;

    final fifth = await tester.startGesture(
      center - const Offset(100, 0),
      pointer: 25,
    );
    await tester.pump();
    final sixth = await tester.startGesture(
      center + const Offset(100, 0),
      pointer: 26,
    );
    await tester.pump();
    await fifth.moveTo(center - const Offset(40, 0));
    await sixth.moveTo(center + const Offset(40, 0));
    await tester.pump();
    await fifth.up();
    await sixth.up();
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport.barSpacing as double, lessThan(48));
    expect(painter.viewport.barSpacing as double, greaterThanOrEqualTo(4));

    await tester.drag(chart, const Offset(-180, 0));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport, isNot(expandedViewport));
    expect(
      painter.viewport.scrollOffset as double,
      greaterThanOrEqualTo(painter.viewport.minScrollOffset as double),
    );

    await tester.tap(chart);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(chart);
    await tester.pump(const Duration(milliseconds: 350));
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport, const ChartViewport());

    Future<void> verifyCrosshairAtVisibleIndices() async {
      var currentPainter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      final visible = currentPainter.hitTargets.visibleCandles;
      final candidateIndices = <int>{
        0,
        visible.length ~/ 2,
        visible.length - 1,
      };
      for (final candidateIndex in candidateIndices) {
        final candidateX =
            currentPainter.hitTargets.firstCandleCenterX +
            currentPainter.hitTargets.candleWidth * candidateIndex;
        final localX = candidateX.clamp(
          1.0,
          currentPainter.hitTargets.chartWidth - 1,
        );
        final index = currentPainter.hitTargets.visibleCandleIndex(localX);
        await tester.tapAt(
          tester.getTopLeft(chart) +
              Offset(localX, center.dy - tester.getTopLeft(chart).dy),
        );
        await tester.pump();
        currentPainter =
            tester
                    .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                    .painter!
                as Mt5CandlePainter;
        final candle = visible[index];
        final expectedOhlc =
            '${candle.open.toStringAsFixed(3)} '
            '${candle.high.toStringAsFixed(3)} '
            '${candle.low.toStringAsFixed(3)} '
            '${candle.close.toStringAsFixed(3)}';
        final time = candle.time.isUtc ? candle.time.toLocal() : candle.time;
        String two(int value) => value.toString().padLeft(2, '0');
        final expectedTime =
            '${two(time.day)}.${two(time.month)}.${time.year} '
            '${two(time.hour)}:${two(time.minute)}';
        expect(find.textContaining(expectedOhlc), findsOneWidget);
        expect(currentPainter.hitTargets.crosshairTimeLabel, expectedTime);
      }
    }

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    await verifyCrosshairAtVisibleIndices();
    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump(const Duration(milliseconds: 60));

    final seventh = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 27,
    );
    final eighth = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 28,
    );
    await tester.pump();
    await seventh.moveTo(center - const Offset(100, 0));
    await eighth.moveTo(center + const Offset(100, 0));
    await tester.pump();
    await seventh.up();
    await eighth.up();
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    await verifyCrosshairAtVisibleIndices();
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets(
    'same-gesture left pan and return restores the initial newest candle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
            demoQuoteProvider.overrideWith((ref, symbol) {
              final quote = ref
                  .read(demoQuotesProvider)
                  .firstWhere(
                    (item) =>
                        item.symbol.replaceAll('+', '') ==
                        symbol.replaceAll('+', ''),
                    orElse: () => ref.read(demoQuotesProvider).first,
                  );
              return Stream.value(quote);
            }),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
          ),
        ),
      );
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      final initialPainter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      final initialCandleCount = initialPainter.debugResolvedCandles.length;
      final initialNewestTime = initialPainter.debugResolvedCandles.last.time;
      final initialNewestCenter = initialPainter.viewport.candleCenterX(
        candleIndex: initialCandleCount - 1,
        plotWidth: initialPainter.hitTargets.chartWidth,
        candleCount: initialCandleCount,
      );
      expect(initialPainter.viewport.scrollOffset, 0);
      expect(
        initialPainter.hitTargets.chartWidth - initialNewestCenter,
        closeTo(28, .001),
      );

      final gesture = await tester.startGesture(tester.getCenter(chart));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();

      var painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      expect(painter.viewport.scrollOffset, -84);

      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();

      painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      expect(painter.viewport.scrollOffset, 0);
      expect(painter.viewport.barSpacing, 28);
      expect(painter.viewport.rightPadding, 28);
      expect(painter.debugResolvedCandles.last.time, initialNewestTime);
      final newestCenter = painter.viewport.candleCenterX(
        candleIndex: painter.debugResolvedCandles.length - 1,
        plotWidth: painter.hitTargets.chartWidth,
        candleCount: painter.debugResolvedCandles.length,
      );
      expect(newestCenter, closeTo(initialNewestCenter, .001));
      expect(painter.hitTargets.chartWidth - newestCenter, closeTo(28, .001));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 60));
    },
  );

  testWidgets('continuous 2-1-2 gesture rebases its focal candle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
        ),
      ),
    );
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chart);
    final chartLeft = tester.getTopLeft(chart).dx;
    final first = await tester.startGesture(
      center - const Offset(80, 0),
      pointer: 31,
    );
    final second = await tester.startGesture(
      center + const Offset(80, 0),
      pointer: 32,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(40, 0));
    await second.moveTo(center + const Offset(40, 0));
    await tester.pump();

    await second.up();
    await tester.pump();
    await first.moveTo(center - const Offset(60, 0));
    await tester.pump();
    final third = await tester.startGesture(
      center + const Offset(60, 0),
      pointer: 33,
    );
    await tester.pump();

    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    final focalX = center.dx - chartLeft;
    final focalBeforeSecondPinch = painter.viewport.candleIndexAt(
      focalX,
      plotWidth: painter.hitTargets.chartWidth,
      candleCount: painter.debugResolvedCandles.length,
    );

    await first.moveTo(center - const Offset(100, 0));
    await third.moveTo(center + const Offset(100, 0));
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    final viewport = painter.viewport;
    final focalAfterSecondPinch = viewport.candleIndexAt(
      focalX,
      plotWidth: painter.hitTargets.chartWidth,
      candleCount: painter.debugResolvedCandles.length,
    );

    expect(
      (focalAfterSecondPinch - focalBeforeSecondPinch).abs(),
      lessThanOrEqualTo(1),
    );
    expect(viewport.barSpacing.isFinite, isTrue);
    expect(viewport.scrollOffset.isFinite, isTrue);
    expect(
      viewport.barSpacing,
      inInclusiveRange(
        ChartViewport.minimumBarSpacing,
        ChartViewport.maximumBarSpacing,
      ),
    );
    expect(
      viewport.scrollOffset,
      greaterThanOrEqualTo(viewport.minScrollOffset),
    );
    expect(
      viewport.scrollOffset,
      lessThanOrEqualTo(
        viewport.maxScrollOffset(
          plotWidth: painter.hitTargets.chartWidth,
          candleCount: painter.debugResolvedCandles.length,
        ),
      ),
    );

    await third.up();
    await first.up();
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets(
    'one-finger vertical plot drag follows the finger without changing range',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
            demoQuoteProvider.overrideWith((ref, symbol) {
              final quote = ref
                  .read(demoQuotesProvider)
                  .firstWhere(
                    (item) =>
                        item.symbol.replaceAll('+', '') ==
                        symbol.replaceAll('+', ''),
                    orElse: () => ref.read(demoQuotesProvider).first,
                  );
              return Stream.value(quote);
            }),
          ],
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
          ),
        ),
      );
      await tester.pump();

      Mt5CandlePainter painter() =>
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;

      final chart = find.byKey(const Key('chart-gesture-area'));
      final canvasTopLeft = tester.getTopLeft(
        find.byKey(const Key('chart-canvas')),
      );
      final before = painter();
      final rangeBefore = before.chartMaxPrice - before.chartMinPrice;
      final centerBefore = (before.chartMaxPrice + before.chartMinPrice) / 2;
      final start =
          canvasTopLeft +
          Offset(
            before.hitTargets.chartWidth / 2,
            before.hitTargets.priceTop + before.hitTargets.priceHeight / 2,
          );
      const dragDistance = 100.0;

      await tester.dragFrom(start, const Offset(0, dragDistance));
      await tester.pump();

      final dragged = painter();
      final rangeAfter = dragged.chartMaxPrice - dragged.chartMinPrice;
      final centerAfter = (dragged.chartMaxPrice + dragged.chartMinPrice) / 2;
      expect(dragged.priceViewport.isAuto, isFalse);
      expect(rangeAfter, closeTo(rangeBefore, rangeBefore * .000001));
      expect(
        centerAfter - centerBefore,
        closeTo(
          rangeBefore * dragDistance / before.hitTargets.priceHeight,
          rangeBefore * .01,
        ),
        reason:
            'The reference video moves chart content by the same screen-space '
            'distance as the finger.',
      );
      expect(
        tester.getRect(chart).contains(start),
        isTrue,
        reason:
            'The gesture must begin inside the plot, not on the price axis.',
      );
      await tester.pump(const Duration(milliseconds: 60));
    },
  );

  testWidgets('horizontal plot drag ignores small vertical finger jitter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
        ),
      ),
    );
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    await tester.drag(chart, const Offset(-140, 5));
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.priceViewport, const ChartPriceViewport.auto());
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets('price axis drag scales vertically and double tap resets it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUEUR', initialTimeframe: 'M1'),
        ),
      ),
    );
    await tester.pump();

    Mt5CandlePainter painter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;

    final canvasTopLeft = tester.getTopLeft(
      find.byKey(const Key('chart-canvas')),
    );
    final before = painter();
    final axisPoint = canvasTopLeft + before.priceAxisRect.center;
    final horizontalBefore = before.viewport;
    final rangeBefore = before.chartMaxPrice - before.chartMinPrice;

    await tester.dragFrom(axisPoint, const Offset(0, -160));
    await tester.pump();

    final scaled = painter();
    expect(scaled.priceViewport.isAuto, isFalse);
    expect(scaled.chartMaxPrice - scaled.chartMinPrice, lessThan(rangeBefore));
    expect(scaled.viewport, horizontalBefore);

    await tester.tapAt(axisPoint);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(axisPoint);
    await tester.pump(const Duration(milliseconds: 350));

    final reset = painter();
    expect(reset.priceViewport, const ChartPriceViewport.auto());
    expect(reset.viewport, horizontalBefore);

    await tester.flingFrom(axisPoint, const Offset(80, -120), 2000);
    await tester.pumpAndSettle();
    expect(
      painter().viewport,
      horizontalBefore,
      reason: 'a diagonal price-axis release cannot start horizontal inertia',
    );

    final staleAxis = await tester.startGesture(axisPoint, pointer: 7101);
    await staleAxis.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(painter().priceViewport.isAuto, isFalse);

    await tester.tap(find.text('M1').first);
    await tester.pump();
    await tester.tap(find.text('M5').first);
    await tester.pump();
    expect(painter().priceViewport, const ChartPriceViewport.auto());

    await staleAxis.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(
      painter().priceViewport,
      const ChartPriceViewport.auto(),
      reason: 'an old axis pointer cannot overwrite a timeframe reset',
    );
    await staleAxis.up();
    await tester.pump(const Duration(milliseconds: 60));

    final horizontalBeforeMixedPointers = painter().viewport;
    final mixedAxis = await tester.startGesture(axisPoint, pointer: 72);
    final mixedPlot = await tester.startGesture(
      canvasTopLeft + const Offset(120, 360),
      pointer: 73,
    );
    await mixedAxis.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(painter().priceViewport.isAuto, isFalse);
    expect(painter().viewport, horizontalBeforeMixedPointers);

    await mixedAxis.up();
    await mixedPlot.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(
      painter().viewport,
      horizontalBeforeMixedPointers,
      reason: 'axis ownership lasts until every pointer in its sequence ends',
    );
    await mixedPlot.up();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      painter().viewport,
      horizontalBeforeMixedPointers,
      reason: 'axis-owned release cannot start horizontal inertia',
    );
  });

  testWidgets('chart indicator, object and window buttons all respond', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/chart',
      routes: [
        GoRoute(
          path: '/chart',
          builder: (context, state) => ChartScreen(
            symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
            initialTimeframe: state.uri.queryParameters['timeframe'] ?? 'H4',
          ),
        ),
        GoRoute(
          path: '/chart-indicators',
          builder: (context, state) => Scaffold(
            body: Text(
              'INDICATORS ${state.uri.queryParameters['symbol']} '
              '${state.uri.queryParameters['timeframe']}',
            ),
          ),
        ),
        GoRoute(
          path: '/chart-objects',
          builder: (context, state) => Scaffold(
            body: Text(
              'OBJECTS ${state.uri.queryParameters['symbol']} '
              '${state.uri.queryParameters['timeframe']}',
            ),
          ),
        ),
        GoRoute(
          path: '/symbols',
          builder: (context, state) => SymbolSearchScreen(
            selectForChart: state.uri.queryParameters['mode'] == 'chart',
            chartTimeframe: state.uri.queryParameters['timeframe'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-indicators-button')));
    await tester.pumpAndSettle();
    expect(find.text('INDICATORS XAUUSD+ H4'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-objects-button')));
    await tester.pumpAndSettle();
    expect(find.text('OBJECTS XAUUSD+ H4'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-windows-button')));
    await tester.pumpAndSettle();
    expect(find.text('Biểu đồ'), findsOneWidget);
    expect(find.text('XAUUSD, H4'), findsOneWidget);
    expect(find.text('Mở biểu đồ mới'), findsOneWidget);
    final activeWindowTile = find.ancestor(
      of: find.text('XAUUSD, H4'),
      matching: find.byType(ListTile),
    );
    final pickerLeadingPaint = find.descendant(
      of: activeWindowTile,
      matching: find.byType(CustomPaint),
    );
    expect(pickerLeadingPaint, findsOneWidget);
    expect(
      tester.getSize(pickerLeadingPaint),
      const Size(20.6666666667, 14.6666666667),
      reason: 'toolbar-only icon geometry must not leak into picker rows',
    );

    await tester.tap(find.text('Mở biểu đồ mới'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['mode'], 'chart');
    expect(router.state.uri.queryParameters['timeframe'], 'H4');

    await tester.tap(find.text('Nasdaq'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('symbol-chart-BTCUSD')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/chart');
    expect(router.state.uri.queryParameters['symbol'], 'BTCUSD');
    expect(router.state.uri.queryParameters['timeframe'], 'H4');
  });

  testWidgets('quick chart object buttons create real objects', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartObjectsScreen(symbol: 'XAUUSD', timeframe: 'M1'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chart-object-Đường ngang')));
    await tester.pump();

    expect(container.read(chartObjectsProvider), hasLength(1));
    expect(container.read(chartObjectsProvider).single.type, 'Đường ngang');
  });

  testWidgets('visible chart objects are passed to the chart renderer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        marketCandlesProvider.overrideWith(
          (ref, request) => Stream.value(const <MarketCandle>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(chartObjectsProvider.notifier).add('Đường ngang');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChartScreen()),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.chartObjects, hasLength(1));

    container.read(chartObjectsProvider.notifier).setAllVisible(false);
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.chartObjects, isEmpty);
  });

  testWidgets('chart receives live ticks without re-centering its reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockQuoteServiceProvider.overrideWithValue(
            const MockQuoteService(tickInterval: Duration(milliseconds: 20)),
          ),
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(home: ChartScreen()),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final firstPrice = painter.currentPrice as double;
    final referencePrice = painter.referencePrice as double;

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.currentPrice, isNot(firstPrice));
    expect(painter.referencePrice, referencePrice);
  });

  testWidgets('Chart toolbar icon ink matches the measured references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: RepaintBoundary(
            key: Key('chart-icon-reference-capture'),
            child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
          ),
        ),
      ),
    );
    await tester.pump();

    final expectedBounds = <Key, Rect>{
      const Key('chart-crosshair-button'): const Rect.fromLTRB(
        10.3333333333,
        13.3333333333,
        29.3333333333,
        31.3333333333,
      ),
      const Key('chart-indicators-button'): const Rect.fromLTRB(
        14,
        15.3333333333,
        26,
        30.3333333333,
      ),
      const Key('chart-objects-button'): const Rect.fromLTRB(8, 14, 25, 31),
      const Key('chart-windows-button'): const Rect.fromLTRB(9, 11, 29, 27),
      const Key('chart-one-click-toggle'): const Rect.fromLTRB(9, 12, 29, 26),
    };
    final actualMetrics = <Key, ({Rect bounds, int baseRed})>{};
    for (final key in expectedBounds.keys) {
      final metrics = await _chartButtonInkMetrics(tester, key);
      actualMetrics[key] = metrics;
    }
    for (final entry in expectedBounds.entries) {
      final metrics = actualMetrics[entry.key]!;
      _expectChartIconBounds(
        metrics.bounds,
        entry.value,
        reason: '${entry.key}; all=$actualMetrics',
      );
      if (entry.key == const Key('chart-crosshair-button') ||
          entry.key == const Key('chart-indicators-button') ||
          entry.key == const Key('chart-objects-button')) {
        expect(
          metrics.baseRed,
          closeTo(AppColors.textSecondary.r * 255, 2),
          reason: '${entry.key} must use the locked chart secondary ink',
        );
      }
    }
  });

  testWidgets(
    'Chart colored toolbar icons use the supplied muted reference palette',
    (tester) async {
      tester.view.physicalSize = const Size(384, 848);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('chart-icon-reference-capture'),
              child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
            ),
          ),
        ),
      );
      await tester.pump();

      final chartMode = await _chartButtonColorMetrics(
        tester,
        const Key('chart-windows-button'),
      );
      final windows = await _chartButtonColorMetrics(
        tester,
        const Key('chart-one-click-toggle'),
      );

      for (final metrics in [chartMode, windows]) {
        expect(
          metrics.redCore,
          const Color(0xFFD65647),
          reason: '$metrics red must match the supplied toolbar sample',
        );
        expect(
          metrics.blueCore,
          const Color(0xFF3D87EA),
          reason: '$metrics blue must match the supplied toolbar sample',
        );
      }
      expect(
        chartMode.lightNeutralPixels,
        greaterThanOrEqualTo(20),
        reason: '$chartMode must use the light center hand from the sample',
      );
      expect(
        windows.lightNeutralPixels,
        greaterThanOrEqualTo(20),
        reason: '$windows must use the light center link from the sample',
      );
      expect(
        chartMode.coloredBounds.width,
        60,
        reason: '$chartMode must match the supplied DPR 3 toolbar crop',
      );
      expect(
        chartMode.coloredBounds.height,
        48,
        reason: '$chartMode must preserve the supplied contour height',
      );
      expect(
        windows.coloredBounds.width,
        closeTo(60, 1),
        reason: '$windows must match the mapped supplied JPEG contour width',
      );
      expect(
        windows.coloredBounds.height,
        42,
        reason: '$windows must match the mapped supplied JPEG contour height',
      );
      expect(
        chartMode.neutralCore,
        const Color(0xFFB3BDBF),
        reason: '$chartMode must use the measured light-gray center hand',
      );
      expect(
        windows.neutralCore,
        const Color(0xFFB3BDBF),
        reason: '$windows must use the measured light-gray center link',
      );
      expect(
        chartMode.firstWideOpeningFromTop,
        lessThanOrEqualTo(9),
        reason:
            '$chartMode ring must open vertically as early as the supplied '
            '3x reference',
      );
    },
  );

  testWidgets(
    'Chart top-right icons match the supplied DPR 3 crop without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const media = MediaQueryData(
        size: Size(402, 874),
        devicePixelRatio: 3,
        padding: EdgeInsets.only(top: 20, bottom: 34),
        viewPadding: EdgeInsets.only(top: 20, bottom: 34),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('chart-icon-reference-capture'),
              child: MediaQuery(
                data: media,
                child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M30'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final chartMode = await _chartButtonColorMetrics(
        tester,
        const Key('chart-windows-button'),
      );
      final windows = await _chartButtonColorMetrics(
        tester,
        const Key('chart-one-click-toggle'),
      );

      expect(chartMode.coloredBounds.size, const Size(60, 48));
      expect(chartMode.redBounds.size, const Size(29, 48));
      expect(chartMode.blueBounds.size, const Size(29, 48));
      expect(
        chartMode.redBounds.topLeft - chartMode.coloredBounds.topLeft,
        Offset.zero,
      );
      expect(
        chartMode.blueBounds.topLeft - chartMode.coloredBounds.topLeft,
        const Offset(31, 0),
      );

      expect(
        windows.coloredBounds.size,
        const Size(60, 42),
        reason: '$windows',
      );
      expect(windows.redBounds.size, const Size(29, 42));
      expect(windows.blueBounds.size, const Size(29, 42));
      expect(
        windows.redBounds.topLeft - windows.coloredBounds.topLeft,
        Offset.zero,
      );
      expect(
        windows.blueBounds.topLeft - windows.coloredBounds.topLeft,
        const Offset(31, 0),
      );

      Offset globalColoredCenter(Key key, Rect coloredBounds) {
        final button = tester.getRect(find.byKey(key));
        return Offset(
          button.left * 3 + 12 + coloredBounds.center.dx,
          button.top * 3 + 12 + coloredBounds.center.dy,
        );
      }

      expect(
        globalColoredCenter(
          const Key('chart-windows-button'),
          chartMode.coloredBounds,
        ).dy,
        globalColoredCenter(
          const Key('chart-one-click-toggle'),
          windows.coloredBounds,
        ).dy,
      );
    },
  );

  testWidgets(
    'Chart colored toolbar rasterization matches the mapped sample at device DPR',
    (tester) async {
      tester.view.physicalSize = const Size(590, 1280);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const media = MediaQueryData(
        size: Size(393.3333333333, 853.3333333333),
        devicePixelRatio: 1.5,
        padding: EdgeInsets.only(top: 24, bottom: 79),
        viewPadding: EdgeInsets.only(top: 24, bottom: 79),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('chart-icon-reference-capture'),
              child: MediaQuery(
                data: media,
                child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final chartMode = await _chartButtonColorMetrics(
        tester,
        const Key('chart-windows-button'),
        pixelRatio: 1.5,
      );
      final windows = await _chartButtonColorMetrics(
        tester,
        const Key('chart-one-click-toggle'),
        pixelRatio: 1.5,
      );

      expect(chartMode.coloredBounds.width, 30, reason: '$chartMode');
      expect(chartMode.coloredBounds.height, 23, reason: '$chartMode');
      expect(
        chartMode.redBounds.size,
        const Size(15, 23),
        reason: '$chartMode',
      );
      expect(
        chartMode.blueBounds.size,
        const Size(15, 23),
        reason: '$chartMode',
      );
      expect(
        chartMode.redBounds.topLeft - chartMode.coloredBounds.topLeft,
        Offset.zero,
      );
      expect(
        chartMode.blueBounds.topLeft - chartMode.coloredBounds.topLeft,
        const Offset(15, 0),
      );
      expect(chartMode.coloredPixels, closeTo(341, 12));
      expect(chartMode.coloredRowWidths, hasLength(23), reason: '$chartMode');
      expect(chartMode.neutralBounds.width, inInclusiveRange(5, 6));
      expect(chartMode.neutralBounds.height, inInclusiveRange(10, 11));
      expect(
        chartMode.neutralBounds.topLeft - chartMode.coloredBounds.topLeft,
        const Offset(14, 6),
      );
      _expectColoredContourRows(
        chartMode.coloredRowWidths,
        const <int, int>{
          0: 12,
          1: 17,
          4: 15,
          8: 14,
          11: 14,
          14: 14,
          18: 14,
          20: 19,
          22: 13,
        },
        tolerance: 2,
        reason: 'chartMode contour mapped from the supplied DPR 3 crop',
      );
      expect(
        chartMode.coreColorPixels / chartMode.coloredPixels,
        greaterThanOrEqualTo(.65),
        reason: '$chartMode must retain solid color instead of soft scaling',
      );
      expect(windows.coloredBounds.width, 31, reason: '$windows');
      expect(windows.coloredBounds.height, 21);
      expect(windows.redBounds.size, const Size(15, 21), reason: '$windows');
      expect(windows.blueBounds.size, const Size(15, 21));
      expect(
        windows.redBounds.topLeft - windows.coloredBounds.topLeft,
        Offset.zero,
      );
      expect(
        windows.blueBounds.topLeft - windows.coloredBounds.topLeft,
        const Offset(16, 0),
      );
      expect(windows.coloredPixels, closeTo(500, 20));
      expect(windows.coloredRowWidths, hasLength(21));
      expect(windows.neutralBounds.width, inInclusiveRange(9, 10));
      expect(windows.neutralBounds.height, 5);
      expect(
        windows.darkNeutralPixels,
        lessThan(5),
        reason: 'The center bridge must remain white instead of dark ink.',
      );
      expect(
        windows.backgroundOpeningPixels,
        greaterThanOrEqualTo(50),
        reason: 'The center bridge must retain the white reference opening.',
      );
      expect(
        windows.neutralBounds.topLeft - windows.coloredBounds.topLeft,
        const Offset(11, 8),
      );
      _expectColoredContourRows(
        windows.coloredRowWidths,
        const <int, int>{
          0: 26,
          1: 28,
          4: 30,
          6: 18,
          8: 16,
          10: 16,
          12: 16,
          15: 30,
          19: 28,
          20: 26,
        },
        tolerance: 2,
        reason: 'windows contour mapped from the supplied DPR 3 crop',
      );
      expect(
        windows.coreColorPixels / windows.coloredPixels,
        greaterThanOrEqualTo(.75),
        reason: '$windows must retain solid color instead of soft scaling',
      );
    },
  );

  testWidgets('Chart neutral toolbar ink derives from the injected theme', (
    tester,
  ) async {
    const alternateTheme = ChartReferenceTheme(
      background: Color(0xFFFFF4D6),
      foreground: Color(0xFF5B217A),
      grid: Color(0xFFC8A96A),
      bullish: Color(0xFF147D64),
      bearish: Color(0xFFB61F48),
      tradeBlue: Color(0xFF7257D7),
      tradeRed: Color(0xFFCE3A26),
      plotTitleBlue: Color(0xFF684FC9),
      ticketBlue: Color(0xFF0A6CE0),
      axisBorder: Color(0xFF8E6F9E),
      axisText: Color(0xFF5B217A),
      plotSubtitleText: Color(0xFF5B217A),
      priceLine: Color(0xFF0F6D99),
    );
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: RepaintBoundary(
            key: Key('chart-icon-reference-capture'),
            child: ChartScreen(
              symbol: 'XAUUSD+',
              initialTimeframe: 'M1',
              theme: alternateTheme,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final expectedInk = alternateTheme.toolbarInk;
    final expectedRed = (expectedInk.toARGB32() >> 16) & 0xff;
    for (final key in const <Key>[
      Key('chart-crosshair-button'),
      Key('chart-indicators-button'),
      Key('chart-objects-button'),
    ]) {
      final metrics = await _chartButtonInkMetrics(tester, key);
      expect(
        metrics.baseRed,
        closeTo(expectedRed, 1),
        reason: '$key must use the injected neutral toolbar role',
      );
    }
  });

  testWidgets('Chart toolbar ink matches the supplied 590px device reference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const media = MediaQueryData(
      size: Size(393.3333333333, 853.3333333333),
      devicePixelRatio: 1.5,
      padding: EdgeInsets.only(top: 24, bottom: 79),
      viewPadding: EdgeInsets.only(top: 24, bottom: 79),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: RepaintBoundary(
            key: Key('chart-icon-reference-capture'),
            child: MediaQuery(
              data: media,
              child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'M1'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final expectedGlobalInk = <Key, Rect>{
      const Key('chart-crosshair-button'): const Rect.fromLTRB(
        223,
        100,
        251,
        127,
      ),
      const Key('chart-indicators-button'): const Rect.fromLTRB(
        286,
        103,
        303,
        126,
      ),
      const Key('chart-objects-button'): const Rect.fromLTRB(
        339,
        101,
        364,
        127,
      ),
      const Key('chart-windows-button'): const Rect.fromLTRB(
        482,
        100,
        512,
        123,
      ),
      const Key('chart-one-click-toggle'): const Rect.fromLTRB(
        540,
        101,
        571,
        122,
      ),
    };
    final actualGlobalInk = <Key, Rect>{};
    for (final entry in expectedGlobalInk.entries) {
      final localInk = await _chartButtonInkMetrics(
        tester,
        entry.key,
        pixelRatio: 1.5,
      );
      final logicalButton = tester.getRect(find.byKey(entry.key));
      final physicalButtonOrigin = Offset(
        logicalButton.left * 1.5,
        logicalButton.top * 1.5,
      );
      actualGlobalInk[entry.key] = localInk.bounds.shift(physicalButtonOrigin);
    }
    for (final entry in expectedGlobalInk.entries) {
      if (entry.key == const Key('chart-windows-button') ||
          entry.key == const Key('chart-one-click-toggle')) {
        expect(
          actualGlobalInk[entry.key],
          entry.value,
          reason: '${entry.key} exact mapped 590px reference ink',
        );
        continue;
      }
      _expectChartIconBounds(
        actualGlobalInk[entry.key]!,
        entry.value,
        reason: '${entry.key} global 590px reference ink; all=$actualGlobalInk',
      );
    }
    expect(
      actualGlobalInk[const Key('chart-windows-button')]!.center.dy,
      actualGlobalInk[const Key('chart-one-click-toggle')]!.center.dy,
      reason: 'the two colored top-right icons must share one visual center',
    );
  });

  testWidgets('video two chart frame respects shell and safe-area geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(576, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const media = MediaQueryData(
      size: Size(384, 853.3333333333),
      devicePixelRatio: 1.5,
      padding: EdgeInsets.only(top: 24, bottom: 79),
      viewPadding: EdgeInsets.only(top: 24, bottom: 79),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
          demoQuoteProvider.overrideWith((ref, symbol) {
            final quote = ref
                .read(demoQuotesProvider)
                .firstWhere(
                  (item) =>
                      item.symbol.replaceAll('+', '') ==
                      symbol.replaceAll('+', ''),
                  orElse: () => ref.read(demoQuotesProvider).first,
                );
            return Stream.value(quote);
          }),
        ],
        child: const MaterialApp(
          home: RepaintBoundary(
            key: Key('chart-icon-reference-capture'),
            child: MediaQuery(
              data: media,
              child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final canvas = tester.getRect(find.byKey(const Key('chart-canvas')));
    final crosshair = tester.getRect(
      find.byKey(const Key('chart-crosshair-button')),
    );
    Rect physical(Rect logical) => Rect.fromLTRB(
      logical.left * 1.5,
      logical.top * 1.5,
      logical.right * 1.5,
      logical.bottom * 1.5,
    );
    Rect painterRectOnScreen(Rect local) =>
        physical(local.shift(canvas.topLeft));
    void expectRect(
      Rect actual, {
      required double left,
      required double top,
      required double right,
      required double bottom,
    }) {
      expect(actual.left, closeTo(left, .01));
      expect(actual.top, closeTo(top, .01));
      expect(actual.right, closeTo(right, .01));
      expect(actual.bottom, closeTo(bottom, .01));
    }

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expectRect(physical(canvas), left: 0, top: 142, right: 576, bottom: 1161.5);
    expectRect(
      physical(crosshair),
      left: 202,
      top: 80.5,
      right: 259,
      bottom: 140.5,
    );
    final expectedIconBounds = <Key, Rect>{
      const Key('chart-crosshair-button'): const Rect.fromLTRB(
        16,
        19.5,
        44,
        46.5,
      ),
      const Key('chart-indicators-button'): const Rect.fromLTRB(
        22,
        22.5,
        39,
        45.5,
      ),
      const Key('chart-objects-button'): const Rect.fromLTRB(
        11.5,
        21.5,
        36.5,
        46.5,
      ),
      const Key('chart-windows-button'): const Rect.fromLTRB(
        13.5,
        17.5,
        43.5,
        40.5,
      ),
      const Key('chart-one-click-toggle'): const Rect.fromLTRB(
        13.5,
        18.5,
        43.5,
        39.5,
      ),
    };
    final actualMetrics15 = <Key, ({Rect bounds, int baseRed})>{};
    for (final key in expectedIconBounds.keys) {
      final metrics = await _chartButtonInkMetrics(
        tester,
        key,
        pixelRatio: 1.5,
      );
      actualMetrics15[key] = metrics;
    }
    for (final entry in expectedIconBounds.entries) {
      final metrics = actualMetrics15[entry.key]!;
      _expectChartIconBounds(
        metrics.bounds,
        entry.value,
        reason: '${entry.key} at DPR 1.5; all=$actualMetrics15',
      );
    }
    // The compact tab bar removes the unused 36 physical pixels above the
    // tabs while keeping the chart/time-axis bottom anchored.
    expectRect(
      painterRectOnScreen(painter.chartFrameRect as Rect),
      left: 0,
      top: 142,
      right: 475,
      bottom: 1128.5,
    );
    expectRect(
      painterRectOnScreen(painter.priceGridRect as Rect),
      left: 0,
      top: 174,
      right: 475,
      bottom: 1128.5,
    );
    expectRect(
      painterRectOnScreen(painter.priceAxisRect as Rect),
      left: 475,
      top: 142,
      right: 576,
      bottom: 1128.5,
    );
    expectRect(
      painterRectOnScreen(painter.timeAxisRect as Rect),
      left: 0,
      top: 1128.5,
      right: 576,
      bottom: 1161.5,
    );
    expect(
      (painter.hitTargets.horizontalGridYs[1] as double) * 1.5 -
          (painter.hitTargets.horizontalGridYs[0] as double) * 1.5,
      closeTo(59.65625, 1),
    );
    final originalChartFrame = painter.chartFrameRect as Rect;
    final originalPriceGrid = painter.priceGridRect as Rect;
    final originalPriceAxis = painter.priceAxisRect as Rect;
    final originalTimeAxis = painter.timeAxisRect as Rect;
    final originalPriceHeight = painter.hitTargets.priceHeight as double;

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final oneClick = physical(
      tester.getRect(find.byKey(const Key('chart-one-click-panel'))),
    );
    final shiftedCanvas = physical(
      tester.getRect(find.byKey(const Key('chart-canvas'))),
    );
    expect(oneClick.height, closeTo(63, .01));
    expect(oneClick.top, closeTo(142, .01));
    expect(oneClick.bottom, closeTo(205, .01));
    expect(shiftedCanvas.top, closeTo(142, .01));
    expect(shiftedCanvas.bottom, 1161.5);
    expect(shiftedCanvas, physical(canvas));
    expect(painter.chartFrameRect, originalChartFrame);
    expect(painter.priceGridRect, originalPriceGrid);
    expect(painter.priceAxisRect, originalPriceAxis);
    expect(painter.timeAxisRect, originalTimeAxis);
    expect(painter.hitTargets.priceHeight, originalPriceHeight);

    final panel = find.byKey(const Key('chart-one-click-panel'));
    expect(
      tester.widget<Material>(find.byKey(const Key('chart-ticket-sell'))).color,
      ChartReferenceTheme.light.ticketBlue,
    );
    expect(
      tester.widget<Material>(find.byKey(const Key('chart-ticket-buy'))).color,
      ChartReferenceTheme.light.ticketBlue,
    );
    final buyLabel = find.descendant(of: panel, matching: find.text('Buy'));
    final buyLabelWidget = tester.widget<Text>(buyLabel);
    expect(
      buyLabelWidget.style?.fontFamily,
      AppTypography.referenceCondensedFamily,
    );
    expect(buyLabelWidget.style?.fontSize, 10);
    expect(buyLabelWidget.style?.fontWeight, FontWeight.w700);
    expect(buyLabelWidget.style?.fontVariations, isNull);
    expect(buyLabelWidget.style?.color, Colors.white);
    expect(buyLabelWidget.style?.letterSpacing, 1.2);
    final sellLabel = find.descendant(of: panel, matching: find.text('SELL'));
    final sellLabelWidget = tester.widget<Text>(sellLabel);
    expect(
      sellLabelWidget.style?.fontFamily,
      AppTypography.referenceCondensedFamily,
    );
    expect(sellLabelWidget.style?.fontSize, 10);
    expect(sellLabelWidget.style?.fontWeight, FontWeight.w700);
    expect(sellLabelWidget.style?.fontVariations, isNull);
    expect(sellLabelWidget.style?.color, Colors.white);
    expect(sellLabelWidget.style?.letterSpacing, .42);
    expect(
      physical(tester.getRect(buyLabel)).left,
      closeTo(407, .01),
      reason: 'The 177px Buy ticket uses the measured 8px label inset.',
    );
    expect(physical(tester.getRect(buyLabel)).top, closeTo(146.5, .01));
    final volumeUp = find.descendant(
      of: panel,
      matching: find.byKey(const Key('chart-one-click-volume-up-chevron')),
    );
    expect(volumeUp, findsOneWidget);
    await tester.tap(volumeUp);
    await tester.pump();
    expect(
      find.descendant(of: panel, matching: find.text('0.26')),
      findsOneWidget,
    );
  });

  testWidgets('every timeframe keeps the canonical video two chart chrome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const timeframes = <String>{
      'M1',
      'M2',
      'M3',
      'M4',
      'M5',
      'M6',
      'M10',
      'M12',
      'M15',
      'M20',
      'M30',
      'H1',
      'H2',
      'H3',
      'H4',
      'H6',
      'H8',
      'H12',
      'D1',
      'W1',
      'MN',
    };

    for (final timeframe in timeframes) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _videoReferenceOverridesWith(
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ),
          child: MaterialApp(
            home: ChartScreen(
              key: ValueKey('standard-chrome-$timeframe'),
              symbol: 'XAUUSD+',
              initialTimeframe: timeframe,
            ),
          ),
        ),
      );
      await tester.pump();

      final dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final chartHeader = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().startsWith('XAUUSD'),
        ),
      );
      final titleText = tester.widget<Text>(
        find.byKey(const Key('chart-plot-title')),
      );
      final titleSpan = titleText.textSpan! as TextSpan;
      final symbolSpan = titleSpan.children!.first as TextSpan;
      expect(
        symbolSpan.style?.color,
        ChartReferenceTheme.light.plotTitleBlue,
        reason: '$timeframe XAUUSD uses the source-locked plot-title blue',
      );
      expect(
        symbolSpan.style?.fontWeight,
        FontWeight.w700,
        reason: '$timeframe XAUUSD title weight',
      );
      expect(
        symbolSpan.style?.fontVariations,
        isNull,
        reason: '$timeframe XAUUSD static-font weight',
      );
      final symbolArrow = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('chart-symbol-chevron')),
          matching: find.byType(Icon),
        ),
      );
      expect(
        symbolArrow.color,
        ChartReferenceTheme.light.plotTitleBlue,
        reason: '$timeframe XAUUSD chevron matches the plot-title blue',
      );
      final renderedTimeframe = timeframe;
      expect(
        chartHeader.text.toPlainText(),
        contains('$renderedTimeframe,'),
        reason: timeframe,
      );
      final priceAxis = painter.priceAxisRect as Rect;
      final timeAxis = painter.timeAxisRect as Rect;
      expect(priceAxis.width, closeTo(67 + 1 / 3, .01), reason: timeframe);
      expect(
        painter.hitTargets.priceTop as double,
        closeTo(timeframe == 'M1' ? 78 + 2 / 3 : 64 / 3, .01),
        reason: timeframe,
      );
      expect(timeAxis.height, closeTo(22, .01), reason: timeframe);
      expect(
        (painter.hitTargets.visibleCandles as List).isNotEmpty,
        isTrue,
        reason: timeframe,
      );
      final resolved = List<MarketCandle>.from(
        painter.debugResolvedCandles as Iterable,
      );
      final visible = List<MarketCandle>.from(
        painter.hitTargets.visibleCandles as Iterable,
      );
      final visibleLow = visible.map((candle) => candle.low).reduce(math.min);
      final visibleHigh = visible.map((candle) => candle.high).reduce(math.max);
      final chartMin = painter.chartMinPrice as double;
      final chartMax = painter.chartMaxPrice as double;
      final chartRange = chartMax - chartMin;
      expect(
        visibleHigh,
        lessThanOrEqualTo(chartMax),
        reason: '$timeframe candle highs must remain inside the viewport',
      );
      expect(
        visibleLow,
        greaterThanOrEqualTo(chartMin),
        reason: '$timeframe candle lows must remain inside the viewport',
      );
      expect(painter.viewport, const ChartViewport(), reason: timeframe);
      expect(painter.hitTargets.candleWidth, 28, reason: timeframe);
      final newestCenter =
          (painter.hitTargets.firstCandleCenterX as double) +
          (visible.length - 1) * (painter.hitTargets.candleWidth as double);
      expect(
        newestCenter,
        closeTo(
          (painter.hitTargets.chartWidth as double) -
              (painter.hitTargets.candleWidth as double),
          .01,
        ),
        reason: '$timeframe newest candle right padding',
      );
      final currentPriceY =
          (painter.hitTargets.priceTop as double) +
          (chartMax - (painter.currentPrice as double)) /
              chartRange *
              (painter.hitTargets.priceHeight as double);
      final tagY = currentPriceY - (timeframe == 'H1' ? 1 + 1 / 3 : 0);
      expect(tagY - 10, greaterThanOrEqualTo(0), reason: timeframe);
      expect(
        tagY + 10,
        lessThanOrEqualTo((painter.timeAxisRect as Rect).top + .01),
        reason: '$timeframe single-line price tag must remain visible',
      );
      expect(
        resolved.every(
          (candle) =>
              MarketDataService.bucketStart(candle.time, timeframe) ==
              candle.time,
        ),
        isTrue,
        reason: '$timeframe candles must start on timeframe boundaries',
      );
      if (timeframe == 'MN') {
        expect(
          resolved.every((candle) => candle.time.day == 1),
          isTrue,
          reason: 'MN candles must start on calendar month boundaries',
        );
        for (var index = 1; index < resolved.length; index++) {
          final previous = resolved[index - 1].time;
          final current = resolved[index].time;
          final previousMonth = previous.year * 12 + previous.month;
          final currentMonth = current.year * 12 + current.month;
          expect(currentMonth - previousMonth, 1);
        }
      }
    }
  });

  testWidgets('XAU H4 viewport is stable across chart overlays', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport, const ChartViewport());
    expect(painter.visibleCandleCount, 11);

    final chart = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chart);
    final first = await tester.startGesture(
      center - const Offset(100, 0),
      pointer: 71,
    );
    final second = await tester.startGesture(
      center + const Offset(100, 0),
      pointer: 72,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(25, 0));
    await second.moveTo(center + const Offset(25, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    final contractedViewport = painter.viewport as ChartViewport;
    expect(contractedViewport.barSpacing, closeTo(11.2, .01));
    expect(painter.h4ExpandedScaleSeen, isFalse);

    await tester.tap(find.text('H4').first);
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.h4ExpandedScaleSeen, isTrue);
    expect(painter.viewport, contractedViewport);
    await tester.tap(find.text('H4').first);
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.oneClickTrading, isTrue);
    expect(painter.viewport, contractedViewport);

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.oneClickTrading, isFalse);
    expect(painter.viewport, contractedViewport);

    await tester.longPressAt(tester.getCenter(chart));
    await tester.pumpAndSettle();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.pendingOrderPrice, isNotNull);
    expect(painter.viewport, contractedViewport);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'reselecting the active timeframe preserves viewport and H1 badge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: _videoReferenceOverridesWith(
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ),
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
          ),
        ),
      );
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      final center = tester.getCenter(chart);
      final first = await tester.startGesture(
        center - const Offset(100, 0),
        pointer: 91,
      );
      final second = await tester.startGesture(
        center + const Offset(100, 0),
        pointer: 92,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(25, 0));
      await second.moveTo(center + const Offset(25, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();
      await tester.drag(chart, const Offset(72, 0));
      await tester.pump();

      dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final retainedViewport = painter.viewport as ChartViewport;
      expect(retainedViewport, isNot(const ChartViewport()));

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('H4').first);
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.viewport, retainedViewport);

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('chart-timeframe-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chart-timeframe-H4')));
      await tester.pumpAndSettle();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.viewport, retainedViewport);

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('H1').first);
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final timeframeResetViewport = ChartViewport(
        barSpacing: retainedViewport.barSpacing,
      );
      expect(painter.viewport, timeframeResetViewport);
      expect(painter.showHistoryBadge, isTrue);
      expect(painter.priceAxisRect.width as double, closeTo(67 + 1 / 3, .01));

      await tester.drag(chart, const Offset(12, 0));
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.showHistoryBadge, isFalse);

      await tester.tap(find.text('H1').first);
      await tester.pump();
      await tester.tap(find.text('H4').first);
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.viewport, timeframeResetViewport);
      expect(painter.h4ExpandedScaleSeen, isFalse);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('timeframe reset survives an in-flight inertial pan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _videoReferenceOverridesWith(
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ),
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    final chart = find.byKey(const Key('chart-gesture-area'));
    await tester.fling(chart, const Offset(140, 0), 2800);
    await tester.pump(const Duration(milliseconds: 20));
    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.viewport, isNot(const ChartViewport()));

    await tester.tap(find.text('H4').first);
    await tester.pump();
    await tester.tap(find.text('H1').first);
    await tester.pump();
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.viewport, const ChartViewport());

    await tester.pump(const Duration(milliseconds: 400));
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.viewport, const ChartViewport());
    expect(painter.timeframe, 'H1');
  });

  testWidgets('BTC H4 uses canonical axis width and focal viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketCandlesProvider.overrideWith(
            (ref, request) => Stream.value(const <MarketCandle>[]),
          ),
        ],
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.priceAxisRect.width as double, closeTo(67 + 1 / 3, .01));
    expect(painter.viewport, const ChartViewport());
    expect(painter.visibleCandleCount, 11);

    final chart = find.byKey(const Key('chart-gesture-area'));
    final center = tester.getCenter(chart);
    final first = await tester.startGesture(
      center - const Offset(100, 0),
      pointer: 81,
    );
    final second = await tester.startGesture(
      center + const Offset(100, 0),
      pointer: 82,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(25, 0));
    await second.moveTo(center + const Offset(25, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.viewport.barSpacing as double, closeTo(11.2, .01));
    expect(painter.priceAxisRect.width as double, closeTo(67 + 1 / 3, .01));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('BTC H1 shows visible candles as soon as history arrives', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final h1History = StreamController<List<MarketCandle>>();
    addTearDown(h1History.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _videoReferenceOverridesWith(
          marketCandlesProvider.overrideWith((ref, request) {
            if (request.timeframe == 'H1') return h1History.stream;
            return Stream.value([
              MarketCandle(
                time: DateTime(2026, 7, 27, 4),
                open: 65125.54,
                high: 65240.44,
                low: 64898.09,
                close: 65170.12,
              ),
            ]);
          }),
        ),
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'H1'),
        ),
      ),
    );
    await tester.pump();

    dynamic painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.loadingPlaceholder, isFalse);

    h1History.add([
      MarketCandle(
        time: DateTime(2026, 7, 27, 4),
        open: 65125.54,
        high: 65240.44,
        low: 64898.09,
        close: 65170.12,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.loadingPlaceholder, isFalse);
    final resolved = List<MarketCandle>.from(
      painter.debugResolvedCandles as Iterable,
    );
    expect(resolved.length, greaterThanOrEqualTo(20));
    expect(
      resolved.map((candle) => candle.time).toSet().length,
      greaterThan(4),
    );
    expect(painter.currentPrice, greaterThan(60000));
  });
}

void _expectChartIconBounds(
  Rect actual,
  Rect expected, {
  required String reason,
}) {
  expect(actual.left, closeTo(expected.left, 1.01), reason: '$reason left');
  expect(actual.top, closeTo(expected.top, 1.01), reason: '$reason top');
  expect(actual.right, closeTo(expected.right, 1.01), reason: '$reason right');
  expect(
    actual.bottom,
    closeTo(expected.bottom, 1.01),
    reason: '$reason bottom',
  );
}

Future<({Rect bounds, int baseRed})> _chartButtonInkMetrics(
  WidgetTester tester,
  Key buttonKey, {
  double pixelRatio = 1,
}) async {
  final buttonRect = tester.getRect(find.byKey(buttonKey));
  final physicalButtonRect = Rect.fromLTRB(
    buttonRect.left * pixelRatio,
    buttonRect.top * pixelRatio,
    buttonRect.right * pixelRatio,
    buttonRect.bottom * pixelRatio,
  );
  final iconSearchRect = physicalButtonRect.deflate(2 * pixelRatio);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('chart-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read Chart toolbar pixels');
  }

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  final redValues = <int>[];
  for (
    var y = iconSearchRect.top.floor();
    y < iconSearchRect.bottom.ceil();
    y++
  ) {
    for (
      var x = iconSearchRect.left.floor();
      x < iconSearchRect.right.ceil();
      x++
    ) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128 || (red + green + blue) / 3 >= 210) continue;
      redValues.add(red);
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No Chart icon ink found for $buttonKey');
  }
  redValues.sort();
  return (
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ).shift(-physicalButtonRect.topLeft),
    baseRed: redValues.first,
  );
}

Future<
  ({
    Color redCore,
    Color blueCore,
    Rect redBounds,
    Rect blueBounds,
    Rect coloredBounds,
    int coloredPixels,
    int coreColorPixels,
    int lightNeutralPixels,
    int darkNeutralPixels,
    int backgroundOpeningPixels,
    Color neutralCore,
    Rect neutralBounds,
    int firstWideOpeningFromTop,
    List<int> coloredRowWidths,
  })
>
_chartButtonColorMetrics(
  WidgetTester tester,
  Key buttonKey, {
  double pixelRatio = 3,
}) async {
  final buttonRect = tester.getRect(find.byKey(buttonKey));
  final searchRect = Rect.fromLTRB(
    buttonRect.left * pixelRatio,
    buttonRect.top * pixelRatio,
    buttonRect.right * pixelRatio,
    buttonRect.bottom * pixelRatio,
  ).deflate(4 * pixelRatio);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('chart-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = (width: image.width, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read colored Chart toolbar pixels');
  }

  final redFrequency = <int, int>{};
  final blueFrequency = <int, int>{};
  final neutralFrequency = <int, int>{};
  final lastRedByY = <int, int>{};
  final firstBlueByY = <int, int>{};
  final coloredCountByY = <int, int>{};
  var minX = captured.width;
  var minY = captured.bytes!.lengthInBytes;
  var maxX = -1;
  var maxY = -1;
  var minRedX = captured.width;
  var minRedY = captured.bytes!.lengthInBytes;
  var maxRedX = -1;
  var maxRedY = -1;
  var minBlueX = captured.width;
  var minBlueY = captured.bytes!.lengthInBytes;
  var maxBlueX = -1;
  var maxBlueY = -1;
  var coloredPixels = 0;
  var lightNeutralPixels = 0;
  var darkNeutralPixels = 0;
  var minNeutralX = captured.width;
  var minNeutralY = captured.bytes!.lengthInBytes;
  var maxNeutralX = -1;
  var maxNeutralY = -1;
  for (var y = searchRect.top.floor(); y < searchRect.bottom.ceil(); y++) {
    for (var x = searchRect.left.floor(); x < searchRect.right.ceil(); x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128) continue;
      final argb = Color.fromARGB(alpha, red, green, blue).toARGB32();
      if (red - blue > 45 && red - green > 30) {
        coloredPixels++;
        coloredCountByY.update(y, (count) => count + 1, ifAbsent: () => 1);
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        minRedX = math.min(minRedX, x);
        minRedY = math.min(minRedY, y);
        maxRedX = math.max(maxRedX, x);
        maxRedY = math.max(maxRedY, y);
        redFrequency.update(argb, (count) => count + 1, ifAbsent: () => 1);
        lastRedByY[y] = math.max(lastRedByY[y] ?? -1, x);
      } else if (blue - red > 45 && blue - green > 25) {
        coloredPixels++;
        coloredCountByY.update(y, (count) => count + 1, ifAbsent: () => 1);
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        minBlueX = math.min(minBlueX, x);
        minBlueY = math.min(minBlueY, y);
        maxBlueX = math.max(maxBlueX, x);
        maxBlueY = math.max(maxBlueY, y);
        blueFrequency.update(argb, (count) => count + 1, ifAbsent: () => 1);
        firstBlueByY[y] = math.min(firstBlueByY[y] ?? captured.width, x);
      } else {
        final spread =
            math.max(red, math.max(green, blue)) -
            math.min(red, math.min(green, blue));
        final neutralDistanceSquared =
            math.pow(red - 184, 2) +
            math.pow(green - 184, 2) +
            math.pow(blue - 189, 2);
        if (neutralDistanceSquared < 8 * 8) {
          minNeutralX = math.min(minNeutralX, x);
          minNeutralY = math.min(minNeutralY, y);
          maxNeutralX = math.max(maxNeutralX, x);
          maxNeutralY = math.max(maxNeutralY, y);
          neutralFrequency.update(
            argb,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        if (spread <= 16 && red >= 145 && red < 245) {
          lightNeutralPixels++;
        } else if (spread <= 8 && red < 145) {
          darkNeutralPixels++;
        }
      }
    }
  }

  Color mostFrequent(Map<int, int> frequency, String role) {
    if (frequency.isEmpty) {
      throw StateError('No $role pixels found for $buttonKey');
    }
    final entry = frequency.entries.reduce(
      (best, candidate) => candidate.value > best.value ? candidate : best,
    );
    return Color(entry.key);
  }

  int mostFrequentCount(Map<int, int> frequency) =>
      frequency.values.reduce(math.max);

  final coreColorPixels =
      mostFrequentCount(redFrequency) + mostFrequentCount(blueFrequency);

  final wideOpeningThreshold = (4 * pixelRatio).round();
  final firstWideOpeningY = lastRedByY.keys
      .where(firstBlueByY.containsKey)
      .where(
        (y) => firstBlueByY[y]! - lastRedByY[y]! - 1 >= wideOpeningThreshold,
      )
      .fold<int?>(null, (first, y) => first == null ? y : math.min(first, y));
  if (firstWideOpeningY == null) {
    throw StateError('No wide center opening found for $buttonKey');
  }
  if (maxNeutralX < minNeutralX || maxNeutralY < minNeutralY) {
    throw StateError('No neutral center ink found for $buttonKey');
  }
  var backgroundOpeningPixels = 0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      if (red >= 248 && green >= 248 && blue >= 248) {
        backgroundOpeningPixels++;
      }
    }
  }

  return (
    redCore: mostFrequent(redFrequency, 'red'),
    blueCore: mostFrequent(blueFrequency, 'blue'),
    redBounds: Rect.fromLTRB(
      minRedX.toDouble(),
      minRedY.toDouble(),
      (maxRedX + 1).toDouble(),
      (maxRedY + 1).toDouble(),
    ).shift(-searchRect.topLeft),
    blueBounds: Rect.fromLTRB(
      minBlueX.toDouble(),
      minBlueY.toDouble(),
      (maxBlueX + 1).toDouble(),
      (maxBlueY + 1).toDouble(),
    ).shift(-searchRect.topLeft),
    coloredBounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ).shift(-searchRect.topLeft),
    coloredPixels: coloredPixels,
    coreColorPixels: coreColorPixels,
    lightNeutralPixels: lightNeutralPixels,
    darkNeutralPixels: darkNeutralPixels,
    backgroundOpeningPixels: backgroundOpeningPixels,
    neutralCore: mostFrequent(neutralFrequency, 'neutral'),
    neutralBounds: Rect.fromLTRB(
      minNeutralX.toDouble(),
      minNeutralY.toDouble(),
      (maxNeutralX + 1).toDouble(),
      (maxNeutralY + 1).toDouble(),
    ).shift(-searchRect.topLeft),
    firstWideOpeningFromTop: firstWideOpeningY - minY,
    coloredRowWidths: <int>[
      for (var y = minY; y <= maxY; y++) coloredCountByY[y] ?? 0,
    ],
  );
}

void _expectColoredContourRows(
  List<int> actual,
  Map<int, int> expected, {
  double tolerance = 3,
  required String reason,
}) {
  for (final entry in expected.entries) {
    expect(
      actual[entry.key],
      closeTo(entry.value, tolerance),
      reason: '$reason row ${entry.key}; rows=$actual',
    );
  }
}
