import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

void main() {
  const plotWidth = 400.0;
  const candleCount = 100;

  group('ChartViewport', () {
    test('defaults to MT5 28 spacing and 8 right padding', () {
      const viewport = ChartViewport();

      expect(viewport.barSpacing, 28);
      expect(viewport.scrollOffset, 0);
      expect(viewport.rightPadding, 8);
    });

    test('scale updates clamp bar spacing to 4 through 48', () {
      final controller = ChartViewportController();

      controller.beginScale(
        viewport: const ChartViewport(scrollOffset: 1000),
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final minimum = controller.updateScale(
        scale: .001,
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      controller.beginScale(
        viewport: const ChartViewport(scrollOffset: 1000),
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final maximum = controller.updateScale(
        scale: 1000,
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      expect(minimum.barSpacing, 4);
      expect(maximum.barSpacing, 48);
    });

    test('newest candle keeps 8 logical pixels of right padding', () {
      const viewport = ChartViewport();

      expect(
        viewport.candleCenterX(
          candleIndex: candleCount - 1,
          plotWidth: plotWidth,
          candleCount: candleCount,
        ),
        392,
      );
    });

    test('pinch keeps the focal candle stable within one candle slot', () {
      final controller = ChartViewportController();
      const viewport = ChartViewport(scrollOffset: 1000);
      const focalPoint = 137.0;
      final focalIndexBefore = viewport.candleIndexAt(
        focalPoint,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      controller.beginScale(
        viewport: viewport,
        focalPoint: focalPoint,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final scaled = controller.updateScale(
        scale: 1.4,
        focalPoint: focalPoint,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final focalIndexAfter = scaled.candleIndexAt(
        focalPoint,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      expect((focalIndexAfter - focalIndexBefore).abs(), lessThanOrEqualTo(1));
    });

    test('pan and inertial endPan stay within oldest and newest data', () {
      final controller = ChartViewportController();
      const viewport = ChartViewport();
      final maximum = viewport.maxScrollOffset(
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      final pastNewest = controller.panBy(
        viewport: viewport,
        delta: -100000,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final pastOldest = controller.panBy(
        viewport: viewport,
        delta: 100000,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final inertialPastNewest = controller.endPan(
        viewport: const ChartViewport(scrollOffset: 100),
        velocity: -100000,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final inertialPastOldest = controller.endPan(
        viewport: const ChartViewport(scrollOffset: 100),
        velocity: 100000,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      expect(pastNewest.scrollOffset, 0);
      expect(pastOldest.scrollOffset, maximum);
      expect(inertialPastNewest.scrollOffset, 0);
      expect(inertialPastOldest.scrollOffset, maximum);
    });

    test('reset restores spacing padding and offset', () {
      final controller = ChartViewportController();

      final reset = controller.reset();

      expect(reset, const ChartViewport());
    });

    test('zero and one candle calculations remain finite', () {
      final controller = ChartViewportController();

      for (final count in const [0, 1]) {
        const viewport = ChartViewport(
          barSpacing: 48,
          scrollOffset: 999,
          rightPadding: 20,
        );
        controller.beginScale(
          viewport: viewport,
          focalPoint: 200,
          plotWidth: plotWidth,
          candleCount: count,
        );
        final scaled = controller.updateScale(
          scale: 0,
          focalPoint: 200,
          plotWidth: plotWidth,
          candleCount: count,
        );
        final panned = controller.panBy(
          viewport: scaled,
          delta: double.infinity,
          plotWidth: plotWidth,
          candleCount: count,
        );
        final ended = controller.endPan(
          viewport: panned,
          velocity: double.nan,
          plotWidth: plotWidth,
          candleCount: count,
        );

        expect(
          viewport
              .maxScrollOffset(plotWidth: plotWidth, candleCount: count)
              .isFinite,
          isTrue,
        );
        expect(
          viewport
              .candleIndexAt(200, plotWidth: plotWidth, candleCount: count)
              .isFinite,
          isTrue,
        );
        expect(
          viewport
              .candleCenterX(
                candleIndex: 0,
                plotWidth: plotWidth,
                candleCount: count,
              )
              .isFinite,
          isTrue,
        );
        expect(ended.barSpacing.isFinite, isTrue);
        expect(ended.scrollOffset.isFinite, isTrue);
        expect(ended.rightPadding.isFinite, isTrue);
      }
    });
  });
}
