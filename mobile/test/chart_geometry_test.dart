import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/geometry/chart_geometry.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_viewport.dart';

void main() {
  test('canonical geometry reproduces measured MT5 physical spacing', () {
    const geometry = ChartGeometry.canonical;

    expect(geometry.priceAxisWidth * 1.5, closeTo(114, .01));
    expect(geometry.targetGridPitch * 1.5, closeTo(42, .01));
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
  });

  test('invalid total widths cannot produce negative or non-finite plots', () {
    for (final width in <double>[-1, 0, double.nan, double.infinity]) {
      final plotWidth = ChartGeometry.canonical.plotWidthFor(width);

      expect(plotWidth, 0);
      expect(plotWidth.isFinite, isTrue);
    }
  });
}
