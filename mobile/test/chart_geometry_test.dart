import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/geometry/chart_geometry.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

void main() {
  test('canonical geometry reproduces measured MT5 physical spacing', () {
    const geometry = ChartGeometry.canonical;

    expect(geometry.priceAxisWidth * 1.5, closeTo(114, .01));
    expect(geometry.targetGridPitch * 1.5, closeTo(42, .01));
    expect(geometry.gridOriginInset * 1.5, closeTo(1, .01));
    expect(geometry.timeLabelInset * 1.5, closeTo(1, .01));
    expect(geometry.timeLabelPitch * 1.5, closeTo(63, .01));
    expect(geometry.m1PriceAxisWidth * 1.5, closeTo(83, .01));
    expect(geometry.m1HeaderHeight * 1.5, closeTo(118, .01));
    expect(geometry.m1TargetGridPitch * 1.5, closeTo(55, .01));
    expect(geometry.m1GridOriginInset * 1.5, closeTo(27, .01));
    expect(geometry.m1TimeLabelInset * 1.5, closeTo(28, .01));
    expect(geometry.m1TimeLabelPitch * 1.5, closeTo(132, .01));
    expect(geometry.m1AxisLabelInset * 1.5, closeTo(7, .01));
    expect(geometry.newestCandleRightPadding * 1.5, closeTo(12, .01));
    expect(geometry.candleBodyRatio, closeTo(.64, .001));
    expect(ChartViewport.defaultBarSpacing * 1.5, closeTo(42, .01));
    expect(ChartViewport.defaultRightPadding * 1.5, closeTo(12, .01));
  });

  test('geometry keeps a finite positive plot from 360 to 430 pixels', () {
    for (final width in <double>[360, 393.333333, 430]) {
      final plotWidth = ChartGeometry.canonical.plotWidthFor(width);

      expect(plotWidth, greaterThan(0));
      expect(
        plotWidth + ChartGeometry.canonical.priceAxisWidthFor(width),
        closeTo(width, .001),
      );
    }
  });

  test('price axis preserves both measured MT5 reference widths', () {
    expect(
      ChartGeometry.canonical.priceAxisWidthFor(384) * 1.5,
      closeTo(101, .01),
    );
    expect(
      ChartGeometry.canonical.priceAxisWidthFor(590 / 1.5) * 1.5,
      closeTo(114, .01),
    );
    expect(
      ChartGeometry.canonical.plotWidthFor(590 / 1.5) * 1.5,
      closeTo(476, .01),
    );
    expect(
      ChartGeometry.canonical.m1PriceAxisWidthFor(590 / 1.5) * 1.5,
      closeTo(83, .01),
    );
    expect(
      (590 / 1.5 - ChartGeometry.canonical.m1PriceAxisWidthFor(590 / 1.5)) *
          1.5,
      closeTo(507, .01),
    );
  });

  test('invalid total widths cannot produce negative or non-finite plots', () {
    for (final width in <double>[-1, 0, double.nan, double.infinity]) {
      final plotWidth = ChartGeometry.canonical.plotWidthFor(width);

      expect(plotWidth, 0);
      expect(plotWidth.isFinite, isTrue);
    }
  });
}
