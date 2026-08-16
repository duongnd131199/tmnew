import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/data/market_data_service.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_objects_screen.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/mock_quote_service.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_edit_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/symbol_search_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void _expectVideoReferenceWindow(
  dynamic painter, {
  required int candleCount,
  required double firstBodyRise,
}) {
  final resolved = List<MarketCandle>.from(
    painter.debugResolvedCandles as Iterable,
  );
  final firstReferenceIndex = resolved.indexWhere(
    (candle) => ((candle.close - candle.open) - firstBodyRise).abs() < .000001,
  );
  expect(firstReferenceIndex, greaterThanOrEqualTo(0));
  // Quote-built tail candles are appended after the deterministic contour.
  // mergeLiveTail keeps the list capped, so exclude that live suffix when
  // measuring how many reference candles remain.
  final liveTailCount = (painter.liveTail as List).length;
  expect(resolved.length - firstReferenceIndex - liveTailCount, candleCount);
}

void main() {
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
      find.textContaining('H4, 4109.75 4109.93 4109.64 4109.82 1039'),
      findsOneWidget,
    );
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
    expect(tester.getCenter(find.text('XAUUSD+')).dy, closeTo(137, .75));
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
    expect(find.text('4104.09'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('4104.09')).style?.color,
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
    expect(
      tester.widget<Text>(find.text('1.26%')).style?.color,
      AppColors.primary,
    );

    await tester.tap(find.byKey(const Key('market-toggle-view')));
    await tester.pump();
    expect(find.text('Cặp ngoại tệ'), findsNothing);
    expect(find.byKey(const Key('market-manage-edit-icon')), findsOneWidget);
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

    final windowsIconScale = tester.widget<Transform>(
      find.byKey(const Key('chart-windows-icon-scale')),
    );
    expect(windowsIconScale.transform.storage[0], 1.09);
    expect(windowsIconScale.transform.storage[5], 1);
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
    final downChevron = tester.widget<Icon>(
      find.byIcon(CupertinoIcons.chevron_down),
    );
    final upChevron = tester.widget<Icon>(
      find.byIcon(CupertinoIcons.chevron_up),
    );
    expect(downChevron.color, Colors.white);
    expect(upChevron.color, Colors.white);
    expect(downChevron.size, 12);
    expect(upChevron.size, 12);
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
    await tester.tap(find.byIcon(CupertinoIcons.chevron_up));
    await tester.pump();
    expect(find.text('0.51'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('chart-one-click-panel')), findsNothing);

    await tester.tap(find.text('H4').first);
    await tester.pump();
    expect(find.text('H1'), findsOneWidget);
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

    await secondPointer.up();
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.measurementStart, isNull);
    expect(painter.measurementEnd, isNull);
    await firstPointer.up();
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
    expect(tester.widget<Material>(firstKey).color, const Color(0xFF343436));

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
    expect(find.textContaining('65175.98 0'), findsOneWidget);

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
    expect(find.textContaining('65120.12 0'), findsOneWidget);
  });

  testWidgets('video two timeframe dialog uses the anchored dark geometry', (
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
      const Color(0xFF1C1C1E),
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
      final initialZoom = painter.zoom as double;
      final initialPan = painter.horizontalPan as double;
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
      expect(painter.zoom, initialZoom);
      expect(painter.horizontalPan, initialPan);
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
      expect(find.textContaining('Gold US Dollar'), findsOneWidget);
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

  testWidgets('video baseline OHLC expands with live high and low ticks', (
    tester,
  ) async {
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

    String chartHeader() => tester
        .widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().startsWith('XAUUSD+'),
          ),
        )
        .text
        .toPlainText();

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
    expect(chartHeader(), contains('H4, 4100.75 4112.52 4096.96 4104.09 0'));

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
    expect(chartHeader(), contains('H4, 4100.75 4115.25 4096.96 4115.25 0'));

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
    expect(chartHeader(), contains('H4, 4100.75 4115.25 4090.50 4090.50 0'));
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
    expect(painter.zoom as double, greaterThan(2));
    expect(painter.horizontalPan as double, closeTo(1, .05));

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
    expect(painter.zoom as double, closeTo(1.2, .08));

    await tester.drag(chart, const Offset(-180, 0));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.horizontalPan as double, closeTo(2, .05));

    await tester.tap(chart);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(chart);
    await tester.pump(const Duration(milliseconds: 350));
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.zoom as double, 1);
    expect(painter.horizontalPan as double, 1);

    await tester.tap(find.byKey(const Key('chart-crosshair-button')));
    await tester.pump();
    expect(
      find.textContaining('3566.99 3567.39 3565.68 3566.07'),
      findsOneWidget,
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
    expect(find.text('XAUUSD+, H4'), findsOneWidget);
    expect(find.text('Mở biểu đồ mới'), findsOneWidget);

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
          home: MediaQuery(
            data: media,
            child: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
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
    expectRect(physical(canvas), left: 0, top: 120, right: 576, bottom: 1161.5);
    expectRect(
      physical(crosshair),
      left: 202,
      top: 56.5,
      right: 259,
      bottom: 116.5,
    );
    // The compact tab bar removes the unused 36 physical pixels above the
    // tabs while keeping the chart/time-axis bottom anchored.
    expectRect(
      painterRectOnScreen(painter.chartFrameRect as Rect),
      left: 0,
      top: 120,
      right: 475,
      bottom: 1138,
    );
    expectRect(
      painterRectOnScreen(painter.priceGridRect as Rect),
      left: 0,
      top: 159,
      right: 475,
      bottom: 1138,
    );
    expectRect(
      painterRectOnScreen(painter.priceAxisRect as Rect),
      left: 475,
      top: 120,
      right: 576,
      bottom: 1138,
    );
    expectRect(
      painterRectOnScreen(painter.timeAxisRect as Rect),
      left: 0,
      top: 1138,
      right: 576,
      bottom: 1161.5,
    );
    expect(
      (painter.hitTargets.priceHeight as double) / 17 * 1.5,
      closeTo(61.1875, .01),
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
    expect(oneClick.height, 63);
    expect(oneClick.top, 120);
    expect(oneClick.bottom, 183);
    expect(shiftedCanvas.top, 120);
    expect(shiftedCanvas.bottom, 1161.5);
    expect(shiftedCanvas, physical(canvas));
    expect(painter.chartFrameRect, originalChartFrame);
    expect(painter.priceGridRect, originalPriceGrid);
    expect(painter.priceAxisRect, originalPriceAxis);
    expect(painter.timeAxisRect, originalTimeAxis);
    expect(painter.hitTargets.priceHeight, originalPriceHeight);

    final panel = find.byKey(const Key('chart-one-click-panel'));
    final volumeUp = find.descendant(
      of: panel,
      matching: find.byIcon(CupertinoIcons.chevron_up),
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

    const expectedPriceSteps = <String, double>{
      'M1': 4.08,
      'M2': 4.08,
      'M3': 4.08,
      'M4': 4.08,
      'M5': 6.37,
      'M6': 6.37,
      'M10': 6.37,
      'M12': 6.37,
      'M15': 9.04,
      'M20': 9.04,
      'M30': 10.32,
      'H1': 12.95,
      'H2': 18.72,
      'H3': 18.72,
      'H4': 34.45,
      'H6': 37.64,
      'H8': 37.64,
      'H12': 37.64,
      'D1': 47.23,
      'W1': 94.09,
      'MN': 188.18,
    };
    const normalisedContourTimeframes = <String>{
      'M1',
      'M2',
      'M3',
      'M4',
      'M5',
      'M6',
      'M10',
      'M12',
      'H2',
      'H3',
      'H6',
      'H8',
      'H12',
    };

    for (final timeframe in expectedPriceSteps.keys) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...videoReferenceOverrides,
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(const <MarketCandle>[]),
            ),
          ],
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
              widget.text.toPlainText().startsWith('XAUUSD+'),
        ),
      );
      TextSpan? ohlcSpan;
      final renderedTimeframe = timeframe;
      chartHeader.text.visitChildren((span) {
        if (span is TextSpan &&
            (span.text?.startsWith(' $renderedTimeframe, ') ?? false)) {
          ohlcSpan = span;
          return false;
        }
        return true;
      });
      expect(
        ohlcSpan?.style?.letterSpacing,
        timeframe == 'H1' ? -.13 : -.11,
        reason: timeframe,
      );
      final priceAxis = painter.priceAxisRect as Rect;
      final timeAxis = painter.timeAxisRect as Rect;
      expect(
        priceAxis.width,
        closeTo(timeframe == 'H1' ? 63 + 1 / 3 : 67 + 1 / 3, .01),
        reason: timeframe,
      );
      expect(
        painter.hitTargets.priceTop as double,
        closeTo(26, .01),
        reason: timeframe,
      );
      expect(timeAxis.height, closeTo(15 + 2 / 3, .01), reason: timeframe);
      expect(
        (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
        closeTo(
          expectedPriceSteps[timeframe]! * (timeframe == 'D1' ? 18 : 17),
          .02,
        ),
        reason: timeframe,
      );
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
      if (normalisedContourTimeframes.contains(timeframe)) {
        expect(
          (visibleHigh - visibleLow) / chartRange,
          inInclusiveRange(.60, .72),
          reason: '$timeframe contour must fill the shared chart viewport',
        );
      }
      if (timeframe == 'H1') {
        final highestWickY =
            (painter.hitTargets.priceTop as double) +
            (chartMax - visibleHigh) /
                chartRange *
                (painter.hitTargets.priceHeight as double);
        expect(
          highestWickY,
          inInclusiveRange(16, 20),
          reason:
              'H1 canonical wick must extend into the internal header strip',
        );
      } else {
        expect(
          visibleHigh,
          lessThanOrEqualTo(chartMax),
          reason: '$timeframe candle highs must remain inside the viewport',
        );
      }
      expect(
        visibleLow,
        greaterThanOrEqualTo(chartMin),
        reason: '$timeframe candle lows must remain inside the viewport',
      );
      final currentPriceY =
          (painter.hitTargets.priceTop as double) +
          (chartMax - (painter.currentPrice as double)) /
              chartRange *
              (painter.hitTargets.priceHeight as double);
      final tagY = currentPriceY - (timeframe == 'H1' ? 1 + 1 / 3 : 0);
      expect(tagY - 8, greaterThanOrEqualTo(0), reason: timeframe);
      expect(
        tagY + 24,
        lessThanOrEqualTo((painter.timeAxisRect as Rect).top + .01),
        reason: '$timeframe price/countdown tag must remain visible',
      );
      if (timeframe != 'H1' && timeframe != 'H4') {
        final latest = resolved.reversed.firstWhere(
          (candle) =>
              candle.high != candle.low ||
              candle.open != candle.close ||
              candle.high != candle.open,
          orElse: () => resolved.last,
        );
        final expectedHeaderOhlc =
            '$timeframe, '
            '${latest.open.toStringAsFixed(2)} '
            '${latest.high.toStringAsFixed(2)} '
            '${latest.low.toStringAsFixed(2)} '
            '${latest.close.toStringAsFixed(2)} 0';
        expect(
          chartHeader.text.toPlainText(),
          contains(expectedHeaderOhlc),
          reason: '$timeframe header must describe the rendered candle',
        );
      }
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

  testWidgets('video two opens XAU H4 at the canonical minimum scale', (
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
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(34.45 * 17, .02),
    );
    expect(painter.zoom as double, closeTo(.64, .01));
    _expectVideoReferenceWindow(painter, candleCount: 138, firstBodyRise: 9.1);

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
    expect(painter.zoom as double, closeTo(.64, .01));
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(34.45 * 17, .02),
    );
    expect(painter.h4ExpandedScaleSeen, isFalse);
    _expectVideoReferenceWindow(painter, candleCount: 138, firstBodyRise: 9.1);

    await tester.tap(find.text('H4').first);
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.h4ExpandedScaleSeen, isTrue);
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(35.80 * 17, .02),
    );
    await tester.tap(find.text('H4').first);
    await tester.pump();

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.oneClickTrading, isTrue);
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(41.20 * 17, .02),
    );

    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.oneClickTrading, isFalse);
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(35.80 * 17, .02),
    );

    await tester.longPressAt(tester.getCenter(chart));
    await tester.pumpAndSettle();
    painter = tester
        .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
        .painter;
    expect(painter.pendingOrderPrice, isNotNull);
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(37.35 * 17, .02),
    );
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
          overrides: [
            ...videoReferenceOverrides,
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
      final retainedZoom = painter.zoom as double;
      final retainedPan = painter.horizontalPan as double;
      expect(retainedZoom, closeTo(.64, .01));
      expect(retainedPan, isNot(closeTo(1, .01)));

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('H4').first);
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.zoom, retainedZoom);
      expect(painter.horizontalPan, retainedPan);

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('chart-timeframe-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chart-timeframe-H4')));
      await tester.pumpAndSettle();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.zoom, retainedZoom);
      expect(painter.horizontalPan, retainedPan);

      await tester.tap(find.text('H4').first);
      await tester.pump();
      await tester.tap(find.text('H1').first);
      await tester.pump();
      painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      expect(painter.zoom, 1);
      expect(painter.horizontalPan, 1);
      expect(painter.showHistoryBadge, isTrue);
      expect(painter.priceAxisRect.width as double, closeTo(63 + 1 / 3, .01));
      expect(painter.chartMaxPrice as double, closeTo(4163.80, .01));
      _expectVideoReferenceWindow(
        painter,
        candleCount: 160,
        firstBodyRise: 3.36,
      );

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
      expect(painter.zoom, closeTo(.64, .01));
      expect(painter.horizontalPan, 1);
      expect(painter.h4ExpandedScaleSeen, isFalse);
      expect(
        (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
        closeTo(34.45 * 17, .02),
      );
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('BTC H4 opens with the canonical axis width and price scale', (
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
    expect(painter.priceAxisRect.width as double, closeTo(72, .01));
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(834.05 * 17, .02),
    );
    expect(painter.zoom as double, closeTo(.64, .01));

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
    expect(painter.zoom as double, closeTo(.64, .01));
    expect(painter.priceAxisRect.width as double, closeTo(72, .01));
    expect(
      (painter.chartMaxPrice as double) - (painter.chartMinPrice as double),
      closeTo(834.05 * 17, .02),
    );
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
        overrides: [
          ...videoReferenceOverrides,
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
        ],
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
    expect(find.textContaining('65198.39 65240.44 65145.47'), findsOneWidget);

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
