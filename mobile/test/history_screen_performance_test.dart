import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets('positions tab does not iterate inactive order history', (
    tester,
  ) async {
    final orders = _CountingList<DemoOrder>(_orders(5000));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoOrdersProvider.overrideWithValue(orders)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();

    expect(orders.iteratorReads, 0);
  });

  testWidgets('sorting reuses the active order filter result', (tester) async {
    final orders = _CountingList<DemoOrder>(_orders(5000));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoOrdersProvider.overrideWithValue(orders)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();
    final readsAfterOpeningOrders = orders.iteratorReads;

    await tester.tap(find.byKey(const Key('history-sort-button')));
    await tester.pump();

    expect(readsAfterOpeningOrders, 1);
    expect(orders.iteratorReads, readsAfterOpeningOrders);
  });

  testWidgets('switching history tabs after an order update stays error free', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('history-tab-1')));
    final controller = container.read(demoTradingProvider.notifier)
      ..placePendingOrder(
        symbol: 'XAUUSD',
        type: 'Buy Limit',
        volume: 0.01,
        price: 4200,
      );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final orderId = controller.state.orders.single.id;
    expect(find.byKey(ValueKey('history-order-$orderId')), findsOneWidget);
  });

  testWidgets(
    'initial bottom anchor does not override a user scroll next frame',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoHistoryPositionsProvider.overrideWithValue(_positions(100)),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );

      final list = tester.widget<ListView>(
        find.byKey(const PageStorageKey('history-positions-list')),
      );
      final controller = list.controller!;
      expect(controller.position.maxScrollExtent, greaterThan(0));
      controller.jumpTo(0);

      await tester.pump();

      expect(controller.position.pixels, 0);
    },
  );

  testWidgets('orders lazily build rows and retain the final record', (
    tester,
  ) async {
    final orders = _orders(5000);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoOrdersProvider.overrideWithValue(orders)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-tab-1')));
    await tester.pump();

    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-orders-list')),
    );
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(list.itemExtentBuilder, isNotNull);
    expect(find.byKey(const Key('history-order-order-0')), findsOneWidget);
    expect(find.byKey(const Key('history-order-order-4999')), findsNothing);

    await _jumpToEnd(
      tester,
      find.byKey(const PageStorageKey('history-orders-list')),
    );

    expect(find.byKey(const Key('history-order-order-4999')), findsOneWidget);
  });

  testWidgets('deals lazily build rows and retain the final record', (
    tester,
  ) async {
    final deals = _deals(5000);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoDealsProvider.overrideWithValue(deals)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-tab-2')));
    await tester.pump();

    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('history-deals-list')),
    );
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    expect(list.itemExtentBuilder, isNotNull);
    expect(find.byKey(const Key('history-deal-deal-0')), findsOneWidget);
    expect(find.byKey(const Key('history-deal-deal-4999')), findsNothing);

    await _jumpToEnd(
      tester,
      find.byKey(const PageStorageKey('history-deals-list')),
    );

    expect(find.byKey(const Key('history-deal-deal-4999')), findsOneWidget);
  });
}

Future<void> _jumpToEnd(WidgetTester tester, Finder listFinder) async {
  final scrollableFinder = find.descendant(
    of: listFinder,
    matching: find.byType(Scrollable),
  );
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
}

List<DemoOrder> _orders(int count) => List<DemoOrder>.generate(
  count,
  (index) => DemoOrder(
    id: 'order-$index',
    symbol: 'XAUUSD+',
    side: 'BUY',
    type: 'MARKET',
    volume: 0.01,
    requestedPrice: 4000,
    executedPrice: 4000,
    status: 'filled',
    time: '2099.01.01 00:00:00',
  ),
  growable: false,
);

List<DemoDeal> _deals(int count) => List<DemoDeal>.generate(
  count,
  (index) => DemoDeal(
    id: 'deal-$index',
    symbol: 'XAUUSD+',
    side: 'BUY',
    volume: 0.01,
    profit: index.toDouble(),
    time: '2099.01.01 00:00:00',
  ),
  growable: false,
);

List<DemoHistoryPosition> _positions(int count) =>
    List<DemoHistoryPosition>.generate(
      count,
      (index) => DemoHistoryPosition(
        id: 'position-$index',
        title: 'XAUUSD+',
        side: 'BUY',
        volume: 0.01,
        openPrice: 4000,
        closePrice: 4001,
        profit: 1,
        time: '2099.01.01 00:00:00',
      ),
      growable: false,
    );

class _CountingList<E> extends ListBase<E> {
  _CountingList(this._items);

  final List<E> _items;
  int iteratorReads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  E operator [](int index) => _items[index];

  @override
  void operator []=(int index, E value) => throw UnsupportedError('read only');

  @override
  Iterator<E> get iterator {
    iteratorReads++;
    return _items.iterator;
  }
}
