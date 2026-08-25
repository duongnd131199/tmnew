import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trading_mobile/app/app.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '10 second chart interaction stays inside the profile frame budget',
    (tester) async {
      final fixedNow = DateTime.utc(2026, 8, 23, 12, 0, 17);
      final quote = DemoQuote(
        symbol: 'BTCUSD',
        name: 'Bitcoin vs US Dollar',
        bid: 76807,
        ask: 76826.65,
        changePercent: .12,
        sourceTimestamp: fixedNow,
      );

      appRouter.go('/chart?symbol=BTCUSD&timeframe=M5');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketApiConfigProvider.overrideWithValue(
              const MarketApiConfig(
                baseUrl: 'https://benchmark.invalid.example',
              ),
            ),
            marketCandlesProvider.overrideWith(
              (ref, request) => Stream.value(_candlesFor(request.timeframe)),
            ),
            realtimeCandleProvider.overrideWith(
              (ref, request) => const Stream<MarketCandle>.empty(),
            ),
            marketClockProvider.overrideWithValue(() => fixedNow),
            demoQuoteProvider.overrideWith(
              (ref, symbol) => Stream.value(quote),
            ),
            demoPositionsProvider.overrideWithValue(const [
              DemoPosition(
                id: 'benchmark-position',
                symbol: 'BTCUSD',
                side: 'BUY',
                volume: .25,
                openPrice: 76783,
                currentPrice: 76807,
                profit: 600,
                openedAt: '2026.08.23 12:00:00',
              ),
            ]),
            demoPendingOrdersProvider.overrideWithValue(const []),
          ],
          child: const TradingApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MtBottomNavigationBar), findsOneWidget);
      expect(
        tester
            .widget<MtBottomNavigationBar>(find.byType(MtBottomNavigationBar))
            .selectedIndex,
        1,
      );
      for (final label in const [
        'Gia',
        'Bieu do',
        'Giao dich',
        'Lich su',
        'Cai dat',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Gia'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MtBottomNavigationBar>(find.byType(MtBottomNavigationBar))
            .selectedIndex,
        0,
      );
      await tester.tap(find.text('Bieu do'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MtBottomNavigationBar>(find.byType(MtBottomNavigationBar))
            .selectedIndex,
        1,
      );
      expect(
        tester.widget<ChartScreen>(find.byType(ChartScreen)).symbol,
        'BTCUSD',
      );
      await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
      await tester.pumpAndSettle();

      await binding.watchPerformance(
        () => _runTenSecondInteraction(tester),
        reportKey: 'chart_performance',
      );

      final summary = Map<String, dynamic>.from(
        binding.reportData!['chart_performance'] as Map,
      );
      final rawBuildMicros = List<int>.from(
        summary['frame_build_times'] as List,
      );
      final rawRasterMicros = List<int>.from(
        summary['frame_rasterizer_times'] as List,
      );
      final buildMicros = List<int>.from(rawBuildMicros)..sort();
      final rasterMicros = List<int>.from(rawRasterMicros)..sort();
      expect(buildMicros, isNotEmpty);
      expect(rasterMicros.length, buildMicros.length);

      final missedFrames = List<int>.generate(buildMicros.length, (index) {
        return rawBuildMicros[index] > 16700 || rawRasterMicros[index] > 16700
            ? 1
            : 0;
      }).fold<int>(0, (sum, value) => sum + value);
      final missedPercent = missedFrames * 100 / buildMicros.length;
      final metrics = <String, dynamic>{
        'frameCount': buildMicros.length,
        'buildP50Ms': _percentileMs(buildMicros, .50),
        'buildP95Ms': _percentileMs(buildMicros, .95),
        'buildP99Ms': _percentileMs(buildMicros, .99),
        'rasterP50Ms': _percentileMs(rasterMicros, .50),
        'rasterP95Ms': _percentileMs(rasterMicros, .95),
        'rasterP99Ms': _percentileMs(rasterMicros, .99),
        'missedFrames': missedFrames,
        'missedFramePercent': missedPercent,
      };
      binding.reportData!['chart_performance_metrics'] = metrics;
      debugPrint('CHART_PERF_JSON=${jsonEncode(metrics)}');

      expect(metrics['frameCount'], greaterThan(30));
      expect(metrics['buildP95Ms'], lessThanOrEqualTo(16.7));
      expect(metrics['rasterP95Ms'], lessThanOrEqualTo(16.7));
      expect(metrics['missedFramePercent'], lessThan(2));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _runTenSecondInteraction(WidgetTester tester) async {
  final stopwatch = Stopwatch()..start();
  var direction = 1.0;
  for (var cycle = 0; cycle < 4; cycle++) {
    await _pinch(tester, zoomIn: true);
    await _pinch(tester, zoomIn: false);
    await _dragWithDuration(
      tester,
      find.byKey(const Key('chart-gesture-area')),
      Offset(90 * direction, 0),
      const Duration(milliseconds: 260),
    );
    direction *= -1;
  }
  final chart = find.byKey(const Key('chart-gesture-area'));
  await tester.tap(chart);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(chart);
  await tester.pump(const Duration(milliseconds: 200));

  var current = 'M5';
  for (final target in const [
    'M1',
    'M5',
    'M15',
    'M30',
    'H1',
    'H4',
    'D1',
    'W1',
    'MN',
    'M5',
  ]) {
    await _switchTimeframe(tester, current: current, target: target);
    current = target;
  }

  await _continuousPanUntil(tester, stopwatch);
  stopwatch.stop();
}

Future<void> _continuousPanUntil(
  WidgetTester tester,
  Stopwatch stopwatch,
) async {
  final target = find.byKey(const Key('chart-gesture-area'));
  final center = tester.getCenter(target);
  final gesture = await tester.startGesture(center, pointer: 404);
  var offset = 0.0;
  var direction = 1.0;
  while (stopwatch.elapsed < const Duration(seconds: 10)) {
    offset += 6 * direction;
    if (offset.abs() >= 48) direction *= -1;
    await gesture.moveTo(center + Offset(offset, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

Future<void> _dragWithDuration(
  WidgetTester tester,
  Finder target,
  Offset delta,
  Duration duration,
) async {
  final start = tester.getCenter(target);
  final gesture = await tester.startGesture(start, pointer: 403);
  final steps = (duration.inMilliseconds / 16).ceil();
  for (var step = 1; step <= steps; step++) {
    await gesture.moveTo(start + delta * (step / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

Future<void> _pinch(WidgetTester tester, {required bool zoomIn}) async {
  final chart = find.byKey(const Key('chart-gesture-area'));
  final center = tester.getCenter(chart);
  final first = await tester.startGesture(
    center - const Offset(56, 0),
    pointer: 401,
  );
  final second = await tester.startGesture(
    center + const Offset(56, 0),
    pointer: 402,
  );
  await tester.pump(const Duration(milliseconds: 16));
  final distance = zoomIn ? 105.0 : 24.0;
  await first.moveTo(center - Offset(distance, 0));
  await second.moveTo(center + Offset(distance, 0));
  await tester.pump(const Duration(milliseconds: 160));
  await first.up();
  await second.up();
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _switchTimeframe(
  WidgetTester tester, {
  required String current,
  required String target,
}) async {
  await tester.tap(find.text(current).first);
  await tester.pump(const Duration(milliseconds: 80));
  final direct = find.text(target);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
  } else {
    await tester.tap(find.byKey(const Key('chart-timeframe-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('chart-timeframe-$target')));
  }
  await tester.pump(const Duration(milliseconds: 180));
}

List<MarketCandle> _candlesFor(String timeframe) {
  final step = _timeframes[timeframe]!;
  final start = DateTime.utc(2026, 1, 5);
  return List<MarketCandle>.generate(180, (index) {
    final open = 76040 + index * 4.25 + (index % 7 - 3) * 5.0;
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

double _percentileMs(List<int> sortedMicros, double percentile) {
  final index = ((sortedMicros.length - 1) * percentile).round();
  return sortedMicros[index] / 1000;
}
