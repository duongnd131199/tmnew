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
      expect(
        tabReferenceCases.map((item) => item.fileName).toSet(),
        hasLength(7),
      );
      expect(tabReferenceCases.map((item) => item.state).toSet(), hasLength(7));
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
        'second-quote-low-label',
        'second-quote-low-value',
        'second-quote-high-label',
        'second-quote-high-value',
        'first-quote-time',
        'first-quote-low-label',
        'first-quote-low-value',
        'first-quote-high-label',
        'first-quote-high-value',
      },
      TabReferenceState.chart: {
        'ticket-sell-price',
        'ticket-buy-price',
        'plot-symbol',
        'plot-subtitle',
      },
      TabReferenceState.trade: {
        'header-profit-value',
        'header-profit-currency',
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

  const expectedCaptureCases =
      <
        String,
        ({
          String route,
          String fileName,
          TabReferenceState state,
          ReferenceSelectedTab selectedTab,
          ReferenceScrollState scrollState,
          int scrollOffset,
          bool hasVisibleScrollbar,
          ReferencePixelRect? scrollbarRect,
        })
      >{
        'prices': (
          route: '/prices',
          fileName: 'photo_2026-08-25_22-30-10.jpg',
          state: TabReferenceState.prices,
          selectedTab: ReferenceSelectedTab.prices,
          scrollState: ReferenceScrollState.atTop,
          scrollOffset: 0,
          hasVisibleScrollbar: false,
          scrollbarRect: null,
        ),
        'chart': (
          route: '/chart',
          fileName: 'photo_2026-08-25_22-30-17.jpg',
          state: TabReferenceState.chart,
          selectedTab: ReferenceSelectedTab.chart,
          scrollState: ReferenceScrollState.atTop,
          scrollOffset: 0,
          hasVisibleScrollbar: false,
          scrollbarRect: null,
        ),
        'trade': (
          route: '/trade',
          fileName: 'photo_2026-08-25_22-30-20.jpg',
          state: TabReferenceState.trade,
          selectedTab: ReferenceSelectedTab.trade,
          scrollState: ReferenceScrollState.atTop,
          scrollOffset: 0,
          hasVisibleScrollbar: true,
          scrollbarRect: ReferencePixelRect(581, 318, 5, 790),
        ),
        'history-positions': (
          route: '/history/positions',
          fileName: 'photo_2026-08-25_22-30-23.jpg',
          state: TabReferenceState.historyPositions,
          selectedTab: ReferenceSelectedTab.history,
          scrollState: ReferenceScrollState.atTop,
          scrollOffset: 0,
          hasVisibleScrollbar: false,
          scrollbarRect: null,
        ),
        'history-orders': (
          route: '/history/orders',
          fileName: 'photo_2026-08-25_22-30-26.jpg',
          state: TabReferenceState.historyOrders,
          selectedTab: ReferenceSelectedTab.history,
          scrollState: ReferenceScrollState.offset,
          scrollOffset: 32,
          hasVisibleScrollbar: true,
          scrollbarRect: ReferencePixelRect(581, 177, 5, 687),
        ),
        'history-orders-summary': (
          route: '/history/orders',
          fileName: 'photo_2026-08-25_22-30-29.jpg',
          state: TabReferenceState.historyOrdersSummary,
          selectedTab: ReferenceSelectedTab.history,
          scrollState: ReferenceScrollState.atEnd,
          scrollOffset: 0,
          hasVisibleScrollbar: true,
          scrollbarRect: ReferencePixelRect(581, 474, 5, 688),
        ),
        'history-deals': (
          route: '/history/deals',
          fileName: 'photo_2026-08-25_22-30-34.jpg',
          state: TabReferenceState.historyDeals,
          selectedTab: ReferenceSelectedTab.history,
          scrollState: ReferenceScrollState.atEnd,
          scrollOffset: 0,
          hasVisibleScrollbar: true,
          scrollbarRect: ReferencePixelRect(581, 525, 5, 637),
        ),
      };

  for (final entry in expectedCaptureCases.entries) {
    test('${entry.key} matches the independently measured capture state', () {
      final referenceCase = tabReferenceCases.singleWhere(
        (item) => item.id == entry.key,
      );
      final expected = entry.value;
      expect(referenceCase.route, expected.route);
      expect(referenceCase.fileName, expected.fileName);
      expect(referenceCase.state, expected.state);
      expect(referenceCase.selectedTab, expected.selectedTab);
      expect(referenceCase.captureState.scrollState, expected.scrollState);
      expect(referenceCase.captureState.scrollOffset, expected.scrollOffset);
      expect(
        referenceCase.captureState.hasVisibleScrollbar,
        expected.hasVisibleScrollbar,
      );

      final scrollbars = referenceCase.visualRegions
          .where((region) => region.type == ReferenceVisualRegionType.scrollbar)
          .toList();
      if (expected.scrollbarRect == null) {
        expect(scrollbars, isEmpty);
        return;
      }

      expect(scrollbars, hasLength(1));
      final actual = scrollbars.single.rect;
      final wanted = expected.scrollbarRect!;
      expect(actual.left, wanted.left);
      expect(actual.top, wanted.top);
      expect(actual.width, wanted.width);
      expect(actual.height, wanted.height);
    });
  }

  const expectedProtectedRegions = <String, Map<String, ReferencePixelRect>>{
    'prices': {
      'prices-first-low-label': ReferencePixelRect(372, 220, 13, 38),
      'prices-first-high-label': ReferencePixelRect(487, 220, 15, 38),
      'prices-second-low-label': ReferencePixelRect(392, 320, 13, 38),
      'prices-second-high-label': ReferencePixelRect(515, 320, 15, 38),
    },
    'chart': {
      'chart-plot-frame': ReferencePixelRect(0, 260, 472, 7),
      'chart-right-price-axis': ReferencePixelRect(472, 260, 118, 880),
      'chart-x-axis-labels': ReferencePixelRect(0, 1140, 472, 28),
    },
    'trade': {
      'trade-header-currency-label': ReferencePixelRect(315, 97, 49, 27),
      'trade-section-surface': ReferencePixelRect(0, 327, 590, 38),
      'trade-scrollbar-indicator': ReferencePixelRect(581, 318, 5, 790),
    },
    'history-positions': {
      'history-positions-selected-segment': ReferencePixelRect(105, 97, 130, 6),
    },
    'history-orders': {
      'history-orders-scrollbar-indicator': ReferencePixelRect(
        581,
        177,
        5,
        687,
      ),
    },
    'history-orders-summary': {
      'history-orders-summary-scrollbar-indicator': ReferencePixelRect(
        581,
        474,
        5,
        688,
      ),
    },
    'history-deals': {
      'history-deals-scrollbar-indicator': ReferencePixelRect(581, 525, 5, 637),
    },
  };

  for (final entry in expectedProtectedRegions.entries) {
    test('${entry.key} protects measured static regions from masks', () {
      final referenceCase = tabReferenceCases.singleWhere(
        (item) => item.id == entry.key,
      );
      for (final expected in entry.value.entries) {
        final actual = referenceCase.staticControlRegions.singleWhere(
          (region) => region.name == expected.key,
        );
        expect(actual.rect.left, expected.value.left, reason: expected.key);
        expect(actual.rect.top, expected.value.top, reason: expected.key);
        expect(actual.rect.width, expected.value.width, reason: expected.key);
        expect(actual.rect.height, expected.value.height, reason: expected.key);
      }
    });
  }

  test(
    'trade header profit mask leaves the measured currency suffix static',
    () {
      const currencySuffix = ReferencePixelRect(315, 97, 49, 27);
      final trade = tabReferenceCases.singleWhere((item) => item.id == 'trade');
      final headerMask = trade.dynamicMaskRegions.singleWhere(
        (mask) =>
            mask.kind == ReferenceDynamicMaskKind.liveProfitAndLoss &&
            mask.rect.top < 145,
      );
      final rect = headerMask.rect;
      final overlaps =
          rect.left < currencySuffix.right &&
          rect.right > currencySuffix.left &&
          rect.top < currencySuffix.bottom &&
          rect.bottom > currencySuffix.top;
      expect(overlaps, isFalse);
    },
  );

  test('dynamic-only text audit set is an independent exact oracle', () {
    const expected = <String, Set<String>>{
      'prices': {
        'first-quote-bid',
        'first-quote-ask',
        'second-quote-bid',
        'second-quote-ask',
        'first-quote-time',
        'first-quote-low-value',
        'first-quote-high-value',
        'second-quote-time',
        'second-quote-low-value',
        'second-quote-high-value',
      },
      'chart': {'ticket-sell-price', 'ticket-buy-price'},
      'trade': {'header-profit-value', 'position-profit'},
      'history-positions': {'position-profit', 'summary-value'},
      'history-orders': {},
      'history-orders-summary': {},
      'history-deals': {},
    };
    const requiredStaticMixedParts = <String, Set<String>>{
      'prices': {
        'first-quote-low-label',
        'first-quote-high-label',
        'second-quote-low-label',
        'second-quote-high-label',
      },
      'trade': {'header-profit-currency'},
    };

    for (final referenceCase in tabReferenceCases) {
      final dynamicOnly = referenceCase.staticTextRegions
          .where(
            (region) => region.auditMode == StaticTextAuditMode.dynamicOnly,
          )
          .map((region) => region.name)
          .toSet();
      expect(dynamicOnly, expected[referenceCase.id], reason: referenceCase.id);

      final staticNames = referenceCase.staticTextRegions
          .where((region) => region.auditMode == StaticTextAuditMode.static)
          .map((region) => region.name)
          .toSet();
      expect(
        staticNames,
        containsAll(requiredStaticMixedParts[referenceCase.id] ?? const {}),
        reason: '${referenceCase.id} protected static mixed text',
      );
    }
  });

  test('every dynamic-only rectangle exactly matches its authorized mask', () {
    const expected = <String, Map<String, ReferencePixelRect>>{
      'prices': {
        'first-quote-bid': ReferencePixelRect(361, 180, 109, 37),
        'first-quote-ask': ReferencePixelRect(481, 180, 100, 37),
        'second-quote-bid': ReferencePixelRect(385, 278, 90, 40),
        'second-quote-ask': ReferencePixelRect(505, 278, 74, 40),
        'first-quote-time': ReferencePixelRect(11, 226, 74, 16),
        'first-quote-low-value': ReferencePixelRect(390, 220, 70, 38),
        'first-quote-high-value': ReferencePixelRect(508, 220, 72, 38),
        'second-quote-time': ReferencePixelRect(31, 327, 75, 17),
        'second-quote-low-value': ReferencePixelRect(410, 320, 50, 38),
        'second-quote-high-value': ReferencePixelRect(536, 320, 43, 38),
      },
      'chart': {
        'ticket-sell-price': ReferencePixelRect(35, 162, 120, 33),
        'ticket-buy-price': ReferencePixelRect(445, 162, 135, 33),
      },
      'trade': {
        'header-profit-value': ReferencePixelRect(225, 97, 85, 27),
        'position-profit': ReferencePixelRect(494, 388, 87, 27),
      },
      'history-positions': {
        'position-profit': ReferencePixelRect(505, 238, 85, 37),
        'summary-value': ReferencePixelRect(455, 552, 135, 40),
      },
    };

    for (final referenceCase in tabReferenceCases) {
      final dynamicOnly = referenceCase.staticTextRegions.where(
        (region) => region.auditMode == StaticTextAuditMode.dynamicOnly,
      );
      for (final region in dynamicOnly) {
        final wanted = expected[referenceCase.id]![region.name]!;
        expect(region.referenceRect.left, wanted.left, reason: region.name);
        expect(region.referenceRect.top, wanted.top, reason: region.name);
        expect(region.referenceRect.width, wanted.width, reason: region.name);
        expect(region.referenceRect.height, wanted.height, reason: region.name);
        expect(region.candidateRect.left, wanted.left, reason: region.name);
        expect(region.candidateRect.top, wanted.top, reason: region.name);
        expect(region.candidateRect.width, wanted.width, reason: region.name);
        expect(region.candidateRect.height, wanted.height, reason: region.name);
        expect(
          referenceCase.dynamicMaskRegions.any(
            (mask) =>
                mask.rect.left == wanted.left &&
                mask.rect.top == wanted.top &&
                mask.rect.width == wanted.width &&
                mask.rect.height == wanted.height,
          ),
          isTrue,
          reason: '${referenceCase.id} ${region.name} mask',
        );
      }
    }
  });
}
