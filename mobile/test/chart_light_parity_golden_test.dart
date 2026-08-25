import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

const _timeframes = <String, Duration>{
  'M1': Duration(minutes: 1),
  'M5': Duration(minutes: 5),
  'M15': Duration(minutes: 15),
  'M30': Duration(minutes: 30),
  'H1': Duration(hours: 1),
  'H4': Duration(hours: 4),
  'D1': Duration(days: 1),
  'W1': Duration(days: 7),
  'MN': Duration(days: 30),
};

enum _GoldenZoom { min, defaultZoom, max }

extension on _GoldenZoom {
  String get fileLabel => switch (this) {
    _GoldenZoom.min => 'min',
    _GoldenZoom.defaultZoom => 'default',
    _GoldenZoom.max => 'max',
  };

  double get expectedBarSpacing => switch (this) {
    _GoldenZoom.min => 4,
    _GoldenZoom.defaultZoom => 28,
    _GoldenZoom.max => 42,
  };
}

void main() {
  setUpAll(_loadGoldenFonts);

  for (final timeframe in _timeframes.keys) {
    for (final zoom in _GoldenZoom.values) {
      testWidgets(
        '$timeframe ${zoom.fileLabel} locks the complete light chart surface',
        (tester) async {
          tester.view.physicalSize = const Size(590, 1280);
          tester.view.devicePixelRatio = 1.5;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final candles = _candlesFor(timeframe);
          final now = candles.last.time.add(const Duration(seconds: 17));
          final quote = DemoQuote(
            symbol: 'BTCUSD',
            name: 'Bitcoin vs US Dollar',
            bid: candles.last.close,
            ask: candles.last.close + 19.65,
            changePercent: .12,
            sourceTimestamp: now,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                marketApiConfigProvider.overrideWithValue(
                  const MarketApiConfig(
                    baseUrl: 'https://golden.invalid.example',
                  ),
                ),
                marketCandlesProvider.overrideWith(
                  (ref, request) => Stream.value(candles),
                ),
                realtimeCandleProvider.overrideWith(
                  (ref, request) => const Stream<MarketCandle>.empty(),
                ),
                marketClockProvider.overrideWithValue(() => now),
                demoQuoteProvider.overrideWith(
                  (ref, symbol) => Stream.value(quote),
                ),
                demoPositionsProvider.overrideWithValue([
                  DemoPosition(
                    id: 'golden-position',
                    symbol: 'BTCUSD',
                    side: 'BUY',
                    volume: .25,
                    openPrice: candles.last.close - 24,
                    currentPrice: candles.last.close,
                    profit: 600,
                    openedAt: '2026.08.23 12:00:00',
                  ),
                ]),
                demoPendingOrdersProvider.overrideWithValue(const []),
              ],
              child: const RepaintBoundary(
                key: Key('golden-root'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M5'),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          if (timeframe != 'M5') {
            await _selectTimeframe(tester, timeframe);
          }
          await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
          await tester.pump();
          await _setZoom(tester, zoom);

          final painter =
              tester
                      .widget<CustomPaint>(
                        find.byKey(const Key('chart-canvas')),
                      )
                      .painter!
                  as Mt5CandlePainter;
          expect(painter.timeframe, timeframe);
          expect(
            painter.viewport.barSpacing,
            closeTo(zoom.expectedBarSpacing, .01),
          );
          expect(painter.positions, hasLength(1));
          expect(
            find.byKey(const Key('chart-one-click-panel')),
            findsOneWidget,
          );

          await expectLater(
            find.byKey(const Key('golden-root')),
            matchesGoldenFile(
              'goldens/chart/light/$timeframe-${zoom.fileLabel}.png',
            ),
          );
        },
      );
    }
  }
}

Future<void> _loadGoldenFonts() async {
  var directory = File(Platform.resolvedExecutable).parent;
  Directory? materialFontDirectory;
  while (directory.parent.path != directory.path) {
    final candidate = Directory('${directory.path}/artifacts/material_fonts');
    if (candidate.existsSync()) {
      materialFontDirectory = candidate;
      break;
    }
    directory = directory.parent;
  }
  if (materialFontDirectory == null) {
    throw StateError('Flutter Roboto test font was not found.');
  }
  final families = <String, String>{
    'Roboto': 'roboto-regular.ttf',
    'sans-serif': 'roboto-regular.ttf',
    'monospace': 'roboto-regular.ttf',
    'RobotoCondensed': 'robotocondensed-regular.ttf',
    'sans-serif-condensed': 'robotocondensed-regular.ttf',
  };
  for (final entry in families.entries) {
    final bytes = await File(
      '${materialFontDirectory.path}/${entry.value}',
    ).readAsBytes();
    final fontData = ByteData.sublistView(Uint8List.fromList(bytes));
    final loader = FontLoader(entry.key)..addFont(Future.value(fontData));
    await loader.load();
  }
}

List<MarketCandle> _candlesFor(String timeframe) {
  final step = _timeframes[timeframe]!;
  final start = DateTime.utc(2026, 1, 5, 0, 0);
  return List<MarketCandle>.generate(96, (index) {
    final wave = switch (index % 8) {
      0 => -18.0,
      1 => 9.0,
      2 => -6.0,
      3 => 24.0,
      4 => 12.0,
      5 => -15.0,
      6 => 5.0,
      _ => -3.0,
    };
    final open = 76420 + index * 4.25 + wave;
    final close = open + (index.isEven ? 17.5 : -13.75);
    return MarketCandle(
      time: start.add(step * index),
      open: open,
      high: (open > close ? open : close) + 12 + index % 5,
      low: (open < close ? open : close) - 10 - index % 4,
      close: close,
      volume: 900 + index * 11,
    );
  });
}

Future<void> _selectTimeframe(WidgetTester tester, String timeframe) async {
  await tester.tap(find.text('M5').first);
  await tester.pump();
  final direct = find.text(timeframe);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
  } else {
    await tester.tap(find.byKey(const Key('chart-timeframe-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('chart-timeframe-$timeframe')));
  }
  await tester.pump();
  await tester.pump();
}

Future<void> _setZoom(WidgetTester tester, _GoldenZoom zoom) async {
  if (zoom == _GoldenZoom.defaultZoom) return;
  final chart = find.byKey(const Key('chart-gesture-area'));
  final center = tester.getCenter(chart);
  final first = await tester.startGesture(
    center - const Offset(60, 0),
    pointer: 301,
  );
  final second = await tester.startGesture(
    center + const Offset(60, 0),
    pointer: 302,
  );
  await tester.pump();
  final distance = zoom == _GoldenZoom.min ? 1.0 : 180.0;
  await first.moveTo(center - Offset(distance, 0));
  await second.moveTo(center + Offset(distance, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
