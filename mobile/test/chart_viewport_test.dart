import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

void main() {
  const plotWidth = 400.0;
  const candleCount = 100;

  group('ChartViewport', () {
    test('defaults to one blank candle slot before the price axis', () {
      const viewport = ChartViewport();

      expect(viewport.barSpacing, 28);
      expect(viewport.scrollOffset, 0);
      expect(viewport.rightPadding, 28);
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

    test('newest candle keeps one blank slot before the price axis', () {
      const viewport = ChartViewport();

      expect(
        viewport.candleCenterX(
          candleIndex: candleCount - 1,
          plotWidth: plotWidth,
          candleCount: candleCount,
        ),
        372,
      );
    });

    test('real zoom preserves focal candle and pan allows four slots', () {
      final controller = ChartViewportController();
      const focalPoint = 137.0;

      for (final scale in <double>[40 / 28, .4]) {
        const start = ChartViewport(scrollOffset: 1000);
        final focalIndexBefore = start.candleIndexAt(
          focalPoint,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );
        controller.beginScale(
          viewport: start,
          focalPoint: focalPoint,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );

        final zoomed = controller.updateScale(
          scale: scale,
          focalPoint: focalPoint,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );

        expect(zoomed.rightPadding, closeTo(zoomed.barSpacing, .001));
        expect(
          zoomed.candleIndexAt(
            focalPoint,
            plotWidth: plotWidth,
            candleCount: candleCount,
          ),
          closeTo(focalIndexBefore, .001),
        );

        final newest = controller.panBy(
          viewport: zoomed,
          delta: -10000,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );
        final newestCenter = newest.candleCenterX(
          candleIndex: candleCount - 1,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );

        expect(newest.scrollOffset, closeTo(-3 * newest.barSpacing, .001));
        expect(plotWidth - newestCenter, closeTo(4 * newest.barSpacing, .001));
      }
    });

    test('pan exposes between one and four future candle slots', () {
      final controller = ChartViewportController();

      final halfway = controller.panBy(
        viewport: const ChartViewport(),
        delta: -42,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final maximum = controller.panBy(
        viewport: halfway,
        delta: -10000,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final reversed = controller.panBy(
        viewport: maximum,
        delta: 28,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      double trailingGap(ChartViewport viewport) =>
          plotWidth -
          viewport.candleCenterX(
            candleIndex: candleCount - 1,
            plotWidth: plotWidth,
            candleCount: candleCount,
          );

      expect(halfway.scrollOffset, -42);
      expect(trailingGap(halfway), 70);
      expect(maximum.scrollOffset, -84);
      expect(trailingGap(maximum), 112);
      expect(reversed.scrollOffset, -56);
      expect(trailingGap(reversed), 84);
    });

    test('pinch never expands the current future slot count', () {
      final controller = ChartViewportController();

      for (final slotCount in const <double>[1, 4]) {
        final start = ChartViewport(scrollOffset: -(slotCount - 1) * 28);
        controller.beginScale(
          viewport: start,
          focalPoint: 200,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );
        final scaled = controller.updateScale(
          scale: .1,
          focalPoint: 200,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );
        final newestCenter = scaled.candleCenterX(
          candleIndex: candleCount - 1,
          plotWidth: plotWidth,
          candleCount: candleCount,
        );

        final trailingGap = plotWidth - newestCenter;
        if (slotCount == 1) {
          expect(trailingGap, lessThanOrEqualTo(scaled.barSpacing));
        } else {
          expect(trailingGap, closeTo(slotCount * scaled.barSpacing, .001));
        }
      }
    });

    test('pinch from history cannot jump into future whitespace', () {
      final controller = ChartViewportController();
      const start = ChartViewport(scrollOffset: 100);
      controller.beginScale(
        viewport: start,
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      final scaled = controller.updateScale(
        scale: .5,
        focalPoint: 200,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );
      final newestCenter = scaled.candleCenterX(
        candleIndex: candleCount - 1,
        plotWidth: plotWidth,
        candleCount: candleCount,
      );

      expect(scaled.scrollOffset, greaterThanOrEqualTo(0));
      expect(plotWidth - newestCenter, lessThanOrEqualTo(scaled.barSpacing));
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

      expect(pastNewest.scrollOffset, -84);
      expect(pastOldest.scrollOffset, maximum);
      expect(inertialPastNewest.scrollOffset, -84);
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
