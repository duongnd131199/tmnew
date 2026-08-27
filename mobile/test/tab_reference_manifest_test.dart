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
      'family: Mt5RobotoVariable',
      'family: Mt5RobotoCondensedVariable',
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
      'assets/fonts/RobotoCondensed-Regular.ttf',
      'assets/fonts/RobotoCondensed-Medium.ttf',
      'assets/fonts/RobotoCondensed-Bold.ttf',
      'assets/fonts/Roboto-Variable.ttf',
      'assets/fonts/RobotoCondensed-Variable.ttf',
    ]) {
      expect(yaml, contains(token), reason: token);
    }
    for (final path in <String>[
      'assets/fonts/Roboto-Variable.ttf',
      'assets/fonts/RobotoCondensed-Variable.ttf',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
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
        'balance-value',
        'position-action',
        'position-secondary',
        'position-profit',
        'position-timestamp',
        'summary-value',
      },
      TabReferenceState.historyOrders: {
        'order-action',
        'order-secondary',
        'order-status',
        'order-timestamp',
      },
      TabReferenceState.historyOrdersSummary: {
        'order-action',
        'order-secondary',
        'order-status',
        'order-timestamp',
        'summary-value',
      },
      TabReferenceState.historyDeals: {
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

  test(
    'Prices assigns every static header and body foreground a local role',
    () {
      final prices = tabReferenceCases.singleWhere(
        (item) => item.id == 'prices',
      );
      const expectedRoles = {
        pricesBlackRole,
        pricesSecondaryRole,
        pricesBlueRole,
        pricesRedRole,
      };
      const expectedControls = {
        'prices-toolbar-list',
        'prices-toolbar-edit',
        'prices-toolbar-search',
        'prices-first-change-accent',
        'prices-second-change-accent',
      };

      expect(
        prices.foregroundRoleByRegion.values.toSet(),
        containsAll(expectedRoles),
      );
      expect(
        prices.staticControlRegions.map((control) => control.name).toSet(),
        containsAll(expectedControls),
      );
      final body = prices.visualRegions.singleWhere(
        (region) => region.name == 'prices-body-foreground',
      );
      expect(body.requiredForegroundRoles.toSet(), expectedRoles);
      expect(
        body.foregroundRegionNames,
        containsAll({
          'quote-corner',
          'quote-symbol',
          'second-quote-symbol',
          'first-quote-low-label',
          'first-quote-high-label',
          'second-quote-low-label',
          'second-quote-high-label',
          ...expectedControls.where((name) => name.contains('change')),
        }),
      );
    },
  );

  test('history selected segments are strict calibrated surfaces', () {
    const expectedRects = <String, ReferencePixelRect>{
      'history-positions': ReferencePixelRect(105, 97, 130, 6),
      'history-orders': ReferencePixelRect(230, 97, 135, 6),
      'history-orders-summary': ReferencePixelRect(230, 97, 135, 6),
      'history-deals': ReferencePixelRect(355, 97, 135, 6),
    };

    for (final entry in expectedRects.entries) {
      final referenceCase = tabReferenceCases.singleWhere(
        (item) => item.id == entry.key,
      );
      final surfaces = referenceCase.surfaceRegions
          .where((region) => region.name == 'selected-segment-surface')
          .toList(growable: false);
      expect(surfaces, hasLength(1), reason: entry.key);
      final surface = surfaces.single;
      expect(
        surface.rect.toString(),
        entry.value.toString(),
        reason: entry.key,
      );
      expect(
        surface.surfaceRole,
        navigationSelectedSurfaceRole,
        reason: entry.key,
      );
      expect(
        surface.surroundingRole,
        navigationWhiteSurfaceRole,
        reason: entry.key,
      );
      expect(surface.excludedRects, isEmpty, reason: entry.key);
      expect(surface.foregroundRegionNames, isEmpty, reason: entry.key);
      expect(
        referenceCase.staticTextRegions.where(
          (region) => region.name == 'selected-segment-surface',
        ),
        isEmpty,
        reason: '${entry.key}: a fill must never use text measurement',
      );
    }
  });

  test('status masks include only the measured y=55 JPEG halo', () {
    const expected = <ReferencePixelRect>[
      ReferencePixelRect(62, 15, 98, 41),
      ReferencePixelRect(406, 15, 184, 41),
    ];
    for (final referenceCase in tabReferenceCases) {
      final statusMasks = referenceCase.dynamicMaskRegions
          .where(
            (mask) => mask.kind == ReferenceDynamicMaskKind.systemStatusValues,
          )
          .toList(growable: false);
      expect(statusMasks, hasLength(2), reason: referenceCase.id);
      for (var index = 0; index < expected.length; index++) {
        final actual = statusMasks[index].rect;
        expect(actual.left, expected[index].left, reason: referenceCase.id);
        expect(actual.top, expected[index].top, reason: referenceCase.id);
        expect(actual.width, expected[index].width, reason: referenceCase.id);
        expect(actual.height, expected[index].height, reason: referenceCase.id);
        expect(statusMasks[index].reason.trim(), isNotEmpty);
      }
      final statusAuditRows = referenceCase.staticTextRegions
          .where(
            (region) =>
                region.auditMode == StaticTextAuditMode.dynamicOnly &&
                region.name.startsWith('system-status-'),
          )
          .toList(growable: false);
      expect(statusAuditRows, hasLength(2), reason: referenceCase.id);
      expect(
        statusAuditRows.map((region) => region.name).toSet(),
        {'system-status-clock', 'system-status-device'},
        reason: referenceCase.id,
      );
      for (var index = 0; index < expected.length; index++) {
        final row = statusAuditRows[index];
        expect(row.referenceRect.toString(), expected[index].toString());
        expect(row.candidateRect.toString(), expected[index].toString());
      }
    }
  });

  test('navigation regions give each foreground one semantic owner', () {
    const labelNames = <String>{
      'navigation-prices-label',
      'navigation-chart-label',
      'navigation-trade-label',
      'navigation-history-label',
      'navigation-settings-label',
    };
    const expectedSharedControls = <String, ReferencePixelRect>{
      'navigation-prices-icon': ReferencePixelRect(70, 1180, 42, 38),
      'navigation-chart-icon': ReferencePixelRect(175, 1180, 35, 38),
      'navigation-trade-icon': ReferencePixelRect(270, 1180, 45, 38),
      'navigation-history-icon': ReferencePixelRect(375, 1180, 48, 38),
      'navigation-settings-icon': ReferencePixelRect(478, 1180, 42, 38),
    };
    const expectedSelectedPills = <ReferenceSelectedTab, ReferencePixelRect>{
      ReferenceSelectedTab.prices: ReferencePixelRect(34, 1171, 114, 75),
      ReferenceSelectedTab.chart: ReferencePixelRect(136, 1171, 114, 75),
      ReferenceSelectedTab.trade: ReferencePixelRect(238, 1171, 114, 75),
      ReferenceSelectedTab.history: ReferencePixelRect(339, 1171, 115, 75),
    };

    for (final referenceCase in tabReferenceCases) {
      final controls = {
        for (final control in referenceCase.staticControlRegions)
          control.name: control.rect,
      };
      expect(
        controls.keys.toSet().intersection(labelNames),
        isEmpty,
        reason: '${referenceCase.id}: label ink belongs to static-text rows',
      );
      for (final entry in expectedSharedControls.entries) {
        expect(
          controls[entry.key].toString(),
          entry.value.toString(),
          reason: '${referenceCase.id}: ${entry.key}',
        );
      }
      expect(
        controls.keys.where((name) => name.startsWith('navigation-')),
        hasLength(5),
        reason: referenceCase.id,
      );
      expect(
        referenceCase.staticTextRegions.map((region) => region.name).toSet(),
        containsAll(labelNames),
        reason: '${referenceCase.id}: all labels remain strictly audited',
      );
      final navigation = referenceCase.visualRegions.singleWhere(
        (region) => region.name == 'bottom-navigation',
      );
      expect(
        navigation.rect.toString(),
        const ReferencePixelRect(28, 1169, 535, 93).toString(),
        reason: '${referenceCase.id}: capsule and measured shadow bounds',
      );
      expect(navigation.requiredForegroundRoles.toSet(), {
        navigationBlackRole,
        navigationBlueRole,
      });
      expect(navigation.foregroundRegionNames, hasLength(10));
      expect(navigation.shadowRegionNames, hasLength(3));
      final pill = referenceCase.visualRegions.singleWhere(
        (region) => region.name == 'bottom-navigation-selected-pill',
      );
      expect(
        pill.rect.toString(),
        expectedSelectedPills[referenceCase.selectedTab].toString(),
      );
      expect(pill.requiredForegroundRoles.toSet(), {navigationBlueRole});
      expect(pill.foregroundRegionNames, hasLength(2));
      expect(pill.shadowRegionNames, isEmpty);
      expect(referenceCase.shadowRegions.map((region) => region.name).toSet(), {
        'bottom-navigation-shadow-left',
        'bottom-navigation-shadow-right',
        'bottom-navigation-shadow-bottom',
      });
      expect(
        referenceCase.shadowRegions
            .map((region) => region.surfaceSampleRect.toString())
            .toSet(),
        {const ReferencePixelRect(460, 1238, 8, 5).toString()},
      );
    }
  });

  test('all seven navigation cases pin decoded-reference role interiors', () {
    const expected = <String, Set<String>>{
      'prices': {
        'navigation-black@[287:1186:288:1187]',
        'navigation-black@[386:1198:387:1199]',
        'navigation-blue@[552:191:553:192]',
        'navigation-blue@[572:192:573:193]',
      },
      'chart': {
        'navigation-black@[82:1209:83:1210]',
        'navigation-black@[497:1211:498:1212]',
        'navigation-blue@[148:164:149:165]',
        'navigation-blue@[64:158:65:159]',
      },
      'trade': {
        'navigation-black@[195:1198:196:1199]',
        'navigation-black@[386:1198:387:1199]',
        'navigation-blue@[88:384:89:385]',
        'navigation-blue@[130:858:131:859]',
      },
      'history-positions': {
        'navigation-black@[297:1203:298:1204]',
        'navigation-black@[497:1211:498:1212]',
        'navigation-blue@[526:181:527:182]',
        'navigation-blue@[397:1211:398:1212]',
      },
      'history-orders': {
        'navigation-black@[288:1202:289:1203]',
        'navigation-black@[498:1194:499:1195]',
        'navigation-blue@[117:929:118:930]',
        'navigation-blue@[384:1198:385:1199]',
      },
      'history-orders-summary': {
        'navigation-black@[297:1203:298:1204]',
        'navigation-black@[497:1211:498:1212]',
        'navigation-blue@[88:295:89:296]',
        'navigation-blue@[397:1211:398:1212]',
      },
      'history-deals': {
        'navigation-black@[297:1203:298:1204]',
        'navigation-black@[497:1211:498:1212]',
        'navigation-blue@[142:627:143:628]',
        'navigation-blue@[137:628:138:629]',
      },
    };
    for (final referenceCase in tabReferenceCases) {
      expect(
        referenceCase.referenceForegroundInteriors
            .where(
              (interior) =>
                  interior.role == navigationBlackRole ||
                  interior.role == navigationBlueRole,
            )
            .map((interior) => '${interior.role}@${interior.rect}')
            .toSet(),
        expected[referenceCase.id],
        reason: referenceCase.id,
      );
      final navigationRoles = Map.fromEntries(
        referenceCase.foregroundRoleByRegion.entries.where(
          (entry) => entry.key.startsWith('navigation-'),
        ),
      );
      expect(navigationRoles, hasLength(10));
      expect(navigationRoles.values.toSet(), {
        navigationBlackRole,
        navigationBlueRole,
      });
      expect(
        referenceCase.referenceForegroundInteriors.where(
          (interior) =>
              interior.role == navigationBlackRole ||
              interior.role == navigationBlueRole,
        ),
        hasLength(4),
      );
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
      'chart-plot-frame': ReferencePixelRect(0, 260, 507, 7),
      'chart-right-price-axis': ReferencePixelRect(507, 260, 83, 880),
      'chart-x-axis-labels': ReferencePixelRect(0, 1140, 507, 28),
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

  test(
    'chart contract isolates the 507px plot and measured plot-title blue',
    () {
      final chart = tabReferenceCases.singleWhere((item) => item.id == 'chart');
      final dynamicPlot = chart.dynamicMaskRegions.singleWhere(
        (region) => region.kind == ReferenceDynamicMaskKind.liveChartContent,
      );
      expect(dynamicPlot.rect.left, 0);
      expect(dynamicPlot.rect.top, 267);
      expect(dynamicPlot.rect.width, 507);
      expect(dynamicPlot.rect.height, 873);

      final plotSymbol = chart.staticTextRegions.singleWhere(
        (region) => region.name == 'plot-symbol',
      );
      expect(plotSymbol.ink.red, 57);
      expect(plotSymbol.ink.green, 133);
      expect(plotSymbol.ink.blue, 233);
    },
  );

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
    const systemStatus = {'system-status-clock', 'system-status-device'};
    const expected = <String, Set<String>>{
      'prices': {
        ...systemStatus,
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
      'chart': {...systemStatus, 'ticket-sell-price', 'ticket-buy-price'},
      'trade': {...systemStatus, 'header-profit-value', 'position-profit'},
      'history-positions': {
        ...systemStatus,
        'position-profit',
        'summary-value',
      },
      'history-orders': {...systemStatus},
      'history-orders-summary': {...systemStatus},
      'history-deals': {...systemStatus},
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
    const systemStatus = <String, ReferencePixelRect>{
      'system-status-clock': ReferencePixelRect(62, 15, 98, 41),
      'system-status-device': ReferencePixelRect(406, 15, 184, 41),
    };
    const expected = <String, Map<String, ReferencePixelRect>>{
      'prices': {
        ...systemStatus,
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
        ...systemStatus,
        'ticket-sell-price': ReferencePixelRect(35, 162, 120, 33),
        'ticket-buy-price': ReferencePixelRect(445, 162, 135, 33),
      },
      'trade': {
        ...systemStatus,
        'header-profit-value': ReferencePixelRect(225, 97, 85, 27),
        'position-profit': ReferencePixelRect(494, 388, 87, 27),
      },
      'history-positions': {
        ...systemStatus,
        'position-profit': ReferencePixelRect(505, 238, 85, 37),
        'summary-value': ReferencePixelRect(455, 552, 135, 40),
      },
      'history-orders': {...systemStatus},
      'history-orders-summary': {...systemStatus},
      'history-deals': {...systemStatus},
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
