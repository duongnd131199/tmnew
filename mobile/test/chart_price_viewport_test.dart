import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/chart/presentation/viewport/chart_price_viewport.dart';

void main() {
  const automatic = ChartPriceRange(minPrice: 77000, maxPrice: 78000);

  group('ChartPriceViewportController', () {
    test('upward drag zooms in and preserves the price under the pointer', () {
      final controller = ChartPriceViewportController();
      controller.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 300,
        priceTop: 20,
        priceHeight: 700,
        displayedRange: automatic,
      );

      final next = controller.updateDrag(deltaY: -213.333333);
      final resolved = next.resolve(automatic);

      expect(next.isAuto, isFalse);
      expect(resolved.range, closeTo(800, 2));
      expect(
        resolved.priceAt(y: 300, priceTop: 20, priceHeight: 700),
        closeTo(77600, .01),
      );
    });

    test('downward drag expands the displayed price range', () {
      final controller = ChartPriceViewportController();
      controller.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 400,
        priceTop: 20,
        priceHeight: 700,
        displayedRange: automatic,
      );

      final next = controller.updateDrag(deltaY: 213.333333);

      expect(next.resolve(automatic).range, closeTo(1250, 3));
    });

    test('equal opposite drags round trip the displayed range', () {
      final controller = ChartPriceViewportController();
      controller.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 400,
        priceTop: 20,
        priceHeight: 700,
        displayedRange: automatic,
      );
      final zoomed = controller.updateDrag(deltaY: -160);
      final zoomedRange = zoomed.resolve(automatic);

      controller.beginDrag(
        viewport: zoomed,
        focalY: 400,
        priceTop: 20,
        priceHeight: 700,
        displayedRange: zoomedRange,
      );
      final restored = controller.updateDrag(deltaY: 160).resolve(automatic);

      expect(restored.range, closeTo(automatic.range, .001));
    });

    test('reset returns to automatic scaling', () {
      final controller = ChartPriceViewportController();

      expect(controller.reset(), const ChartPriceViewport.auto());
      expect(controller.reset().resolve(automatic), automatic);
    });

    test('non-finite input keeps output finite and positive', () {
      final controller = ChartPriceViewportController();
      controller.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: double.nan,
        priceTop: double.infinity,
        priceHeight: 0,
        displayedRange: const ChartPriceRange(
          minPrice: double.nan,
          maxPrice: double.infinity,
        ),
      );

      final resolved = controller
          .updateDrag(deltaY: double.nan)
          .resolve(automatic);

      expect(resolved.minPrice.isFinite, isTrue);
      expect(resolved.maxPrice.isFinite, isTrue);
      expect(resolved.range, greaterThan(0));
    });

    test('extreme drags clamp to safe finite ranges', () {
      final controller = ChartPriceViewportController();
      controller.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 300,
        priceTop: 20,
        priceHeight: 700,
        displayedRange: automatic,
      );

      final tiny = controller.updateDrag(deltaY: -double.maxFinite);
      final huge = controller.updateDrag(deltaY: double.maxFinite);

      expect(tiny.range, ChartPriceViewportController.minimumRange);
      expect(huge.range, ChartPriceViewportController.maximumRange);
      expect(tiny.centerPrice!.isFinite, isTrue);
      expect(huge.centerPrice!.isFinite, isTrue);
    });

    test('automatic extrema resolve to finite ranges and prices', () {
      final resolved = const ChartPriceViewport.auto().resolve(
        const ChartPriceRange(
          minPrice: -double.maxFinite,
          maxPrice: double.maxFinite,
        ),
      );

      expect(resolved.minPrice.isFinite, isTrue);
      expect(resolved.maxPrice.isFinite, isTrue);
      expect(resolved.range.isFinite, isTrue);
      expect(resolved.range, greaterThan(0));
      for (final y in <double>[0, 50, 100]) {
        expect(
          resolved.priceAt(y: y, priceTop: 0, priceHeight: 100).isFinite,
          isTrue,
        );
      }
    });

    test('equal huge prices retain a finite center near the source value', () {
      final resolved = const ChartPriceViewport.auto().resolve(
        const ChartPriceRange(
          minPrice: double.maxFinite,
          maxPrice: double.maxFinite,
        ),
      );

      expect(resolved.centerPrice.isFinite, isTrue);
      expect(resolved.centerPrice, greaterThan(1e300));
      expect(resolved.range.isFinite, isTrue);
      expect(resolved.range, greaterThan(0));
    });

    test('range saturation preserves bottom and top price anchors', () {
      const bound = ChartPriceViewportController.maximumAbsolutePrice;

      final bottomController = ChartPriceViewportController();
      const upperRange = ChartPriceRange(
        minPrice: bound - 1000,
        maxPrice: bound,
      );
      bottomController.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 100,
        priceTop: 0,
        priceHeight: 100,
        displayedRange: upperRange,
      );
      final expandedUpper = bottomController
          .updateDrag(deltaY: double.maxFinite)
          .resolve(upperRange);
      expect(
        expandedUpper.priceAt(y: 100, priceTop: 0, priceHeight: 100),
        closeTo(upperRange.minPrice, 1),
      );

      final topController = ChartPriceViewportController();
      const lowerRange = ChartPriceRange(
        minPrice: -bound,
        maxPrice: -bound + 1000,
      );
      topController.beginDrag(
        viewport: const ChartPriceViewport.auto(),
        focalY: 0,
        priceTop: 0,
        priceHeight: 100,
        displayedRange: lowerRange,
      );
      final expandedLower = topController
          .updateDrag(deltaY: double.maxFinite)
          .resolve(lowerRange);
      expect(
        expandedLower.priceAt(y: 0, priceTop: 0, priceHeight: 100),
        closeTo(lowerRange.maxPrice, 1),
      );
    });
  });
}
