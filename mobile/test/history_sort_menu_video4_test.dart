import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/load_test_fonts.dart';

void main() {
  setUpAll(loadMt5TestFonts);

  test('history mapping retains authoritative open and close timestamps', () {
    final dynamic position = ExV2DemoMapper.historyPosition({
      'id': 'position-1',
      'symbol': 'BTCUSD',
      'side': 'BUY',
      'volume': .1,
      'openPrice': 80000,
      'closePrice': 80100,
      'profit': 10,
      'createdAt': '2026-09-01T10:00:00Z',
      'closedAt': '2026-09-03T11:00:00Z',
    });

    expect(position.openedAt, DateTime.utc(2026, 9, 1, 10));
    expect(position.closedAt, DateTime.utc(2026, 9, 3, 11));
  });

  testWidgets('sort button opens the complete video 4444 history menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoHistoryPositionsProvider.overrideWithValue(_positions)],
        child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-sort-menu')), findsOneWidget);
    for (final label in const [
      'Sắp xếp theo',
      'Mặc định',
      'Cặp ngoại tệ',
      'Ticket',
      'Loại',
      'Khối lượng',
      'Thời gian mở',
      'Thời gian đóng',
      'Lợi nhuận',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.byKey(const Key('history-sort-indicator-default')),
      findsOneWidget,
    );
  });

  testWidgets('selecting symbol sorts rows immediately and keeps menu open', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-sort-option-symbol')));
    await tester.pump();

    expect(find.byKey(const Key('history-sort-menu')), findsOneWidget);
    expect(
      find.byKey(const Key('history-sort-indicator-symbol')),
      findsOneWidget,
    );
    _expectVerticalOrder(tester, const ['200', '300', '100']);
  });

  testWidgets('tapping the selected criterion toggles its sort direction', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    final symbol = find.byKey(const Key('history-sort-option-symbol'));
    await tester.tap(symbol);
    await tester.pump();
    await tester.tap(symbol);
    await tester.pump();

    _expectVerticalOrder(tester, const ['100', '300', '200']);
    final indicator = tester.widget<Icon>(
      find.byKey(const Key('history-sort-indicator-symbol')),
    );
    expect(indicator.icon, CupertinoIcons.arrow_up);
  });

  for (final scenario in const [
    (keyName: 'ticket', expectedIds: ['300', '200', '100']),
    (keyName: 'type', expectedIds: ['200', '300', '100']),
    (keyName: 'volume', expectedIds: ['300', '200', '100']),
    (keyName: 'open-time', expectedIds: ['200', '100', '300']),
    (keyName: 'close-time', expectedIds: ['200', '100', '300']),
    (keyName: 'profit', expectedIds: ['100', '200', '300']),
  ]) {
    testWidgets('${scenario.keyName} applies descending position ordering', (
      tester,
    ) async {
      await _pumpHistory(tester);

      await tester.tap(find.byKey(const Key('history-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('history-sort-option-${scenario.keyName}')),
      );
      await tester.pump();

      _expectVerticalOrder(tester, scenario.expectedIds);
      expect(
        find.byKey(Key('history-sort-indicator-${scenario.keyName}')),
        findsOneWidget,
      );
    });
  }

  testWidgets('default restores the authoritative source row order', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-sort-option-profit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-sort-option-default')));
    await tester.pump();

    _expectVerticalOrder(tester, const ['200', '100', '300']);
    expect(
      find.byKey(const Key('history-sort-indicator-default')),
      findsOneWidget,
    );
  });

  testWidgets('open and close time use their distinct server timestamps', (
    tester,
  ) async {
    final positions = [
      DemoHistoryPosition(
        id: 'first',
        title: 'XAUUSD',
        side: 'BUY',
        volume: .1,
        openPrice: 1,
        closePrice: 2,
        profit: 1,
        time: '2026.09.03 10:00:00',
        openedAt: DateTime.utc(2026, 9, 1),
        closedAt: DateTime.utc(2026, 9, 3),
      ),
      DemoHistoryPosition(
        id: 'second',
        title: 'BTCUSD',
        side: 'BUY',
        volume: .1,
        openPrice: 1,
        closePrice: 2,
        profit: 1,
        time: '2026.09.02 10:00:00',
        openedAt: DateTime.utc(2026, 9, 3),
        closedAt: DateTime.utc(2026, 9, 2),
      ),
      DemoHistoryPosition(
        id: 'third',
        title: 'EURUSD',
        side: 'BUY',
        volume: .1,
        openPrice: 1,
        closePrice: 2,
        profit: 1,
        time: '2026.09.01 10:00:00',
        openedAt: DateTime.utc(2026, 9, 2),
        closedAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    await _pumpHistory(tester, positions: positions);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-sort-option-open-time')));
    await tester.pump();
    _expectVerticalOrder(tester, const ['second', 'third', 'first']);

    await tester.tap(find.byKey(const Key('history-sort-option-close-time')));
    await tester.pump();
    _expectVerticalOrder(tester, const ['first', 'second', 'third']);
  });

  testWidgets('ticket sorting also applies to the orders segment', (
    tester,
  ) async {
    await _pumpHistory(tester, orders: _orders);

    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-sort-option-ticket')));
    await tester.pump();

    _expectVerticalOrder(tester, const [
      '300',
      '200',
      '100',
    ], rowPrefix: 'history-order');
  });

  testWidgets('profit sorting also applies to the deals segment', (
    tester,
  ) async {
    await _pumpHistory(tester, deals: _deals);

    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-sort-option-profit')));
    await tester.pump();

    _expectVerticalOrder(tester, const [
      '100',
      '200',
      '300',
    ], rowPrefix: 'history-deal');
  });

  testWidgets('sort popover matches the measured video 4444 geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62);
    tester.view.viewPadding = const FakeViewPadding(top: 62);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byKey(const Key('history-sort-menu')));
    expect(menu.left, closeTo(6, .01));
    expect(menu.top, closeTo(62, .01));
    expect(menu.width, closeTo(292, .01));
    expect(menu.height, closeTo(430, .01));
  });

  testWidgets('sort popover scales with the iPhone 17 video viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62);
    tester.view.viewPadding = const FakeViewPadding(top: 62);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byKey(const Key('history-sort-menu')));
    expect(menu.left, closeTo(6 * 402 / 384, .01));
    expect(menu.top, closeTo(62, .01));
    expect(menu.width, closeTo(292 * 402 / 384, .01));
    expect(menu.height, closeTo(430 * 874 / 848, .01));
  });

  testWidgets('sort popover preserves its video 4444 visual surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62);
    tester.view.viewPadding = const FakeViewPadding(top: 62);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('history-sort-menu')),
      matchesGoldenFile('goldens/history-sort-menu-video4-384x848.png'),
    );
  });

  testWidgets('sort popover scales from its fixed video anchor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62);
    tester.view.viewPadding = const FakeViewPadding(top: 62);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pump(const Duration(milliseconds: 40));

    final transition = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).last,
    );
    expect(
      transition.alignment,
      const Alignment(2 * 6 / 384 - 1, 2 * 62 / 848 - 1),
    );
  });

  testWidgets('sort popover uses the measured video neutral colors', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Sắp xếp theo'));
    expect(heading.style?.color, const Color(0xFF737373));
    final defaultRow = find.byKey(const Key('history-sort-option-default'));
    final rowContainer = tester.widget<Container>(
      find.descendant(of: defaultRow, matching: find.byType(Container)).first,
    );
    final decoration = rowContainer.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.color, const Color(0xFFDFDFE2));
  });

  testWidgets('sort popover separates its muted heading from white rows', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final headingSurfaces = find
        .ancestor(
          of: find.text('Sắp xếp theo'),
          matching: find.byType(ColoredBox),
        )
        .evaluate()
        .map((element) => element.widget)
        .whereType<ColoredBox>()
        .toList();
    expect(headingSurfaces, hasLength(1));
    if (headingSurfaces.isEmpty) return;
    expect(headingSurfaces.single.color, const Color(0xFFF6F6F6));
  });

  testWidgets('sort indicators match the smaller measured video ink scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 848);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final check = tester.widget<Icon>(
      find.byKey(const Key('history-sort-indicator-default')),
    );
    expect(check.size, 20);

    await tester.tap(find.byKey(const Key('history-sort-option-symbol')));
    await tester.pump();
    final arrow = tester.widget<Icon>(
      find.byKey(const Key('history-sort-indicator-symbol')),
    );
    expect(arrow.size, 16);
  });

  testWidgets('sort popover uses the measured darker edge shadow', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pumpAndSettle();

    final menuSurface = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('history-sort-menu')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = menuSurface.decoration as BoxDecoration;
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single.color, const Color(0x34000000));
  });
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  List<DemoHistoryPosition> positions = _positions,
  List<DemoOrder> orders = const [],
  List<DemoDeal> deals = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoHistoryPositionsProvider.overrideWithValue(positions),
        demoOrdersProvider.overrideWithValue(orders),
        demoDealsProvider.overrideWithValue(deals),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
    ),
  );
  await tester.pump();
}

void _expectVerticalOrder(
  WidgetTester tester,
  List<String> ids, {
  String rowPrefix = 'history-position',
}) {
  final tops = [
    for (final id in ids)
      tester.getTopLeft(find.byKey(ValueKey('$rowPrefix-$id'))).dy,
  ];
  expect(tops, orderedEquals([...tops]..sort()));
}

const _positions = [
  DemoHistoryPosition(
    id: '200',
    title: 'XAUUSD',
    side: 'SELL',
    volume: .2,
    openPrice: 2000,
    closePrice: 2001,
    profit: 5,
    time: '2026.09.03 10:00:00',
  ),
  DemoHistoryPosition(
    id: '100',
    title: 'BTCUSD',
    side: 'BUY',
    volume: .1,
    openPrice: 80000,
    closePrice: 80100,
    profit: 9,
    time: '2026.09.02 10:00:00',
  ),
  DemoHistoryPosition(
    id: '300',
    title: 'EURUSD',
    side: 'SELL',
    volume: .3,
    openPrice: 1.1,
    closePrice: 1.2,
    profit: -1,
    time: '2026.09.01 10:00:00',
  ),
];

const _orders = [
  DemoOrder(
    id: '200',
    symbol: 'XAUUSD',
    side: 'SELL',
    type: 'Sell Market',
    volume: .2,
    requestedPrice: 2000,
    status: 'filled',
    time: '2026.09.03 10:00:00',
  ),
  DemoOrder(
    id: '100',
    symbol: 'BTCUSD',
    side: 'BUY',
    type: 'Buy Market',
    volume: .1,
    requestedPrice: 80000,
    status: 'filled',
    time: '2026.09.02 10:00:00',
  ),
  DemoOrder(
    id: '300',
    symbol: 'EURUSD',
    side: 'SELL',
    type: 'Sell Market',
    volume: .3,
    requestedPrice: 1.1,
    status: 'filled',
    time: '2026.09.01 10:00:00',
  ),
];

const _deals = [
  DemoDeal(
    id: '200',
    symbol: 'XAUUSD',
    side: 'SELL',
    volume: .2,
    price: 2000,
    profit: 5,
    time: '2026.09.03 10:00:00',
  ),
  DemoDeal(
    id: '100',
    symbol: 'BTCUSD',
    side: 'BUY',
    volume: .1,
    price: 80000,
    profit: 9,
    time: '2026.09.02 10:00:00',
  ),
  DemoDeal(
    id: '300',
    symbol: 'EURUSD',
    side: 'SELL',
    volume: .3,
    price: 1.1,
    profit: -1,
    time: '2026.09.01 10:00:00',
  ),
];
