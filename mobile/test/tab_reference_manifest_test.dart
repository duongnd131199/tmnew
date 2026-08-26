import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'test_support/tab_reference_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seven canonical references are 590x1280 and map to unique states',
    () async {
      expect(tabReferenceCases, hasLength(7));
      expect(tabReferenceCases.map((item) => item.id).toSet(), hasLength(7));
      expect(tabReferenceLogicalSize.width, closeTo(393.3333333333, .0001));
      expect(tabReferenceLogicalSize.height, closeTo(853.3333333333, .0001));
      expect(tabReferenceDevicePixelRatio, 1.5);
      for (final item in tabReferenceCases) {
        final codec = await ui.instantiateImageCodec(
          await File(item.referencePath).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 590, reason: item.id);
        expect(frame.image.height, 1280, reason: item.id);
      }
    },
  );

  test('production declares deterministic reference font assets', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    for (final token in <String>[
      'family: Mt5Roboto',
      'family: Mt5RobotoCondensed',
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
      'assets/fonts/RobotoCondensed-Regular.ttf',
      'assets/fonts/RobotoCondensed-Medium.ttf',
      'assets/fonts/RobotoCondensed-Bold.ttf',
    ]) {
      expect(yaml, contains(token), reason: token);
    }
  });

  test(
    'every reference audits the complete bottom navigation and body text',
    () {
      const navigationRegions = {
        'navigation-prices-label',
        'navigation-chart-label',
        'navigation-trade-label',
        'navigation-history-label',
        'navigation-settings-label',
      };

      for (final item in tabReferenceCases) {
        final names = item.staticTextRegions
            .map((region) => region.name)
            .toSet();
        expect(
          names,
          containsAll(navigationRegions),
          reason: '${item.id} must cover all five navigation labels',
        );
        expect(
          item.staticTextRegions.length,
          greaterThanOrEqualTo(8),
          reason: '${item.id} needs body/header coverage beyond navigation',
        );
      }
    },
  );

  test('reference audit covers secondary text and both content columns', () {
    const requiredRegions = <TabReferenceState, Set<String>>{
      TabReferenceState.prices: {
        'quote-corner',
        'first-quote-bid',
        'first-quote-ask',
        'second-quote-bid',
        'second-quote-ask',
        'second-quote-time',
        'second-quote-low',
        'second-quote-high',
        'first-quote-time',
        'first-quote-low',
        'first-quote-high',
      },
      TabReferenceState.chart: {
        'ticket-sell-price',
        'ticket-buy-price',
        'plot-symbol',
        'plot-subtitle',
      },
      TabReferenceState.trade: {
        'header-profit',
        'metric-value',
        'position-secondary',
        'position-profit',
      },
      TabReferenceState.historyPositions: {
        'selected-segment-surface',
        'balance-value',
        'position-action',
        'position-secondary',
        'position-profit',
        'position-timestamp',
        'summary-value',
      },
      TabReferenceState.historyOrders: {
        'selected-segment-surface',
        'order-action',
        'order-secondary',
        'order-status',
        'order-timestamp',
      },
      TabReferenceState.historyOrdersSummary: {
        'selected-segment-surface',
        'order-action',
        'order-secondary',
        'order-status',
        'order-timestamp',
        'summary-value',
      },
      TabReferenceState.historyDeals: {
        'selected-segment-surface',
        'deal-action',
        'deal-secondary',
        'deal-timestamp',
        'summary-value',
      },
    };

    for (final item in tabReferenceCases) {
      final names = item.staticTextRegions.map((region) => region.name).toSet();
      expect(
        names,
        containsAll(requiredRegions[item.state]!),
        reason: '${item.id} must measure both columns and secondary roles',
      );
    }
  });

  test('history selected surfaces use isolated color-component audits', () {
    final historyCases = tabReferenceCases.where(
      (item) => item.state.name.startsWith('history'),
    );
    for (final item in historyCases) {
      final surface = item.staticTextRegions.singleWhere(
        (region) => region.name == 'selected-segment-surface',
      );
      expect(surface.geometryColorTolerance, 10, reason: item.id);
      expect(surface.semanticColorTolerance, 6, reason: item.id);
      expect(surface.measureLargestGeometryComponent, isTrue, reason: item.id);
    }
  });

  test('every reference case declares a bounded seven-state visual audit', () {
    const canvasWidth = 590;
    const canvasHeight = 1280;
    for (final item in tabReferenceCases) {
      final referenceCase = item;
      expect(referenceCase.route, isNotEmpty, reason: '${item.id} route');
      expect(referenceCase.selectedTab, isNotNull, reason: '${item.id} tab');
      expect(
        referenceCase.captureState.description,
        isNotEmpty,
        reason: '${item.id} capture state',
      );

      final auditRect = referenceCase.staticAuditRegion;
      expect(auditRect.left, 0, reason: '${item.id} audit left');
      expect(auditRect.top, 0, reason: '${item.id} audit top');
      expect(auditRect.width, canvasWidth, reason: '${item.id} audit width');
      expect(auditRect.height, canvasHeight, reason: '${item.id} audit height');

      final visualRegionTypes = referenceCase.visualRegions
          .map((ReferenceVisualRegion region) => region.type)
          .toSet();
      expect(
        visualRegionTypes,
        containsAll(const <ReferenceVisualRegionType>{
          ReferenceVisualRegionType.system,
          ReferenceVisualRegionType.content,
          ReferenceVisualRegionType.header,
          ReferenceVisualRegionType.body,
          ReferenceVisualRegionType.bottomNavigation,
        }),
        reason: '${item.id} visual regions',
      );
      if (referenceCase.captureState.hasVisibleScrollbar) {
        expect(
          visualRegionTypes,
          contains(ReferenceVisualRegionType.scrollbar),
          reason: '${item.id} visible scrollbar',
        );
      }

      for (final mask in referenceCase.dynamicMaskRegions) {
        expect(mask.reason, isNotEmpty, reason: '${item.id} mask reason');
        final rect = mask.rect;
        expect(rect.left, greaterThanOrEqualTo(0), reason: '${item.id} mask');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '${item.id} mask');
        expect(
          rect.right,
          lessThanOrEqualTo(canvasWidth),
          reason: '${item.id} mask',
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(canvasHeight),
          reason: '${item.id} mask',
        );
        for (final staticControl in referenceCase.staticControlRegions) {
          final controlRect = staticControl.rect;
          final overlaps =
              rect.left < controlRect.right &&
              rect.right > controlRect.left &&
              rect.top < controlRect.bottom &&
              rect.bottom > controlRect.top;
          expect(
            overlaps,
            isFalse,
            reason:
                '${item.id} dynamic mask ${mask.reason} overlaps '
                '${staticControl.name}',
          );
        }
      }
    }
  });
}
