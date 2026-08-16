import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  test('placing and closing a demo order updates positions and history', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    final initial = container.read(demoTradingProvider);
    container
        .read(demoTradingProvider.notifier)
        .placeOrder(
          symbol: 'EURUSD',
          side: 'BUY',
          volume: 0.10,
          executedPrice: 1.17302,
        );

    final afterOrder = container.read(demoTradingProvider);
    expect(afterOrder.positions, hasLength(initial.positions.length + 1));
    expect(afterOrder.positions.first.symbol, 'EURUSD');
    expect(afterOrder.orders, hasLength(initial.orders.length + 1));
    expect(afterOrder.deals, hasLength(initial.deals.length + 1));

    final positionId = afterOrder.positions.first.id;
    container
        .read(demoTradingProvider.notifier)
        .updateMarketPrice(symbol: 'EURUSD', bid: 1.17402, ask: 1.17405);
    final profit = container.read(demoTradingProvider).positions.first.profit;
    expect(profit, closeTo(.01, .000001));
    expect(
      container.read(demoTradingProvider.notifier).closePosition(positionId),
      isTrue,
    );

    final afterClose = container.read(demoTradingProvider);
    expect(afterClose.positions, hasLength(initial.positions.length));
    expect(afterClose.orders, hasLength(initial.orders.length + 2));
    expect(afterClose.deals, hasLength(initial.deals.length + 2));
    expect(afterClose.balance, closeTo(initial.balance + profit, .000001));
    expect(afterClose.deals.first.entry, 'out');
  });

  test('pending orders can be modified, canceled and filtered by type', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    final controller = container.read(demoTradingProvider.notifier);
    controller.cancelAllPendingOrders();

    final limitId = controller.placePendingOrder(
      symbol: 'XAUUSD',
      type: 'Buy Limit',
      volume: .01,
      price: 4000,
    );
    final stopId = controller.placePendingOrder(
      symbol: 'XAUUSD',
      type: 'Sell Stop',
      volume: .02,
      price: 3990,
    );
    expect(container.read(demoPendingOrdersProvider), hasLength(2));

    expect(
      controller.modifyPendingOrder(
        limitId,
        price: 4001,
        stopLoss: 3995,
        takeProfit: 4010,
      ),
      isTrue,
    );
    final modified = container
        .read(demoPendingOrdersProvider)
        .firstWhere((item) => item.id == limitId);
    expect(modified.price, 4001);
    expect(modified.stopLoss, 3995);
    expect(modified.takeProfit, 4010);

    expect(controller.cancelAllPendingOrders(limitOnly: true), 1);
    expect(container.read(demoPendingOrdersProvider).single.id, stopId);
    expect(
      container
          .read(demoOrdersProvider)
          .firstWhere((item) => item.id == limitId)
          .status,
      'canceled',
    );
    expect(controller.cancelPendingOrder(stopId), isTrue);
    expect(container.read(demoPendingOrdersProvider), isEmpty);
  });

  test(
    'market price fills pending orders and triggers position protection',
    () {
      final container = createVideoReferenceContainer();
      addTearDown(container.dispose);
      final controller = container.read(demoTradingProvider.notifier);
      controller.cancelAllPendingOrders();
      final initialPositions = container.read(demoPositionsProvider).length;
      final initialDeals = container.read(demoDealsProvider).length;

      final orderId = controller.placePendingOrder(
        symbol: 'EURUSD',
        type: 'Buy Limit',
        volume: .10,
        price: 1.14,
        stopLoss: 1.13,
        takeProfit: 1.15,
      );
      controller.updateMarketPrice(symbol: 'EURUSD', bid: 1.13997, ask: 1.14);

      expect(container.read(demoPendingOrdersProvider), isEmpty);
      expect(
        container.read(demoPositionsProvider),
        hasLength(initialPositions + 1),
      );
      final filled = container
          .read(demoPositionsProvider)
          .firstWhere((item) => item.id == orderId);
      expect(filled.openPrice, 1.14);
      expect(filled.stopLoss, 1.13);
      expect(
        container
            .read(demoOrdersProvider)
            .firstWhere((item) => item.id == orderId)
            .status,
        'filled',
      );
      expect(container.read(demoDealsProvider), hasLength(initialDeals + 1));

      controller.updateMarketPrice(
        symbol: 'EURUSD',
        bid: 1.15001,
        ask: 1.15004,
      );
      expect(
        container
            .read(demoPositionsProvider)
            .where((item) => item.id == orderId),
        isEmpty,
      );
      expect(container.read(demoDealsProvider), hasLength(initialDeals + 2));
    },
  );

  test(
    'position protection can be modified and account metrics are derived',
    () {
      final container = createVideoReferenceContainer();
      addTearDown(container.dispose);
      final controller = container.read(demoTradingProvider.notifier);
      final positionId = controller.placeOrder(
        symbol: 'EURUSD',
        side: 'SELL',
        volume: .10,
        executedPrice: 1.15,
      );

      expect(
        controller.modifyPosition(positionId, stopLoss: 1.16, takeProfit: 1.14),
        isTrue,
      );
      controller.updateMarketPrice(symbol: 'EURUSD', bid: 1.149, ask: 1.1491);
      final account = container.read(demoAccountProvider);
      expect(account.margin, greaterThan(0));
      expect(
        account.equity,
        closeTo(account.balance + account.profit, .000001),
      );
      expect(
        account.freeMargin,
        closeTo(account.equity - account.margin, .000001),
      );
    },
  );

  test('close by closes one buy and one sell for the same symbol', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    final controller = container.read(demoTradingProvider.notifier);
    final initialCount = container.read(demoPositionsProvider).length;
    final buyId = controller.placeOrder(
      symbol: 'EURUSD',
      side: 'BUY',
      volume: .10,
      executedPrice: 1.15,
    );
    controller.placeOrder(
      symbol: 'EURUSD',
      side: 'SELL',
      volume: .10,
      executedPrice: 1.15,
    );

    expect(controller.closeBy(buyId), isTrue);
    expect(container.read(demoPositionsProvider), hasLength(initialCount));
    expect(
      container
          .read(demoPositionsProvider)
          .where((item) => item.symbol == 'EURUSD'),
      isEmpty,
    );
  });

  test('close by keeps the unmatched remainder on the larger position', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    final controller = container.read(demoTradingProvider.notifier);
    final buyId = controller.placeOrder(
      symbol: 'EURUSD',
      side: 'BUY',
      volume: .10,
      executedPrice: 1.15,
    );
    final sellId = controller.placeOrder(
      symbol: 'EURUSD',
      side: 'SELL',
      volume: .04,
      executedPrice: 1.15,
    );

    expect(controller.closeByPositions(buyId, sellId), isTrue);
    final eurUsd = container
        .read(demoPositionsProvider)
        .where((item) => item.symbol == 'EURUSD')
        .toList(growable: false);
    expect(eurUsd, hasLength(1));
    expect(eurUsd.single.id, buyId);
    expect(eurUsd.single.volume, closeTo(.06, .000001));
    expect(
      container.read(demoDealsProvider).take(2).map((deal) => deal.volume),
      [.04, .04],
    );
  });

  test(
    'account trading changes stay isolated when switching away and back',
    () {
      final container = createVideoReferenceContainer();
      addTearDown(container.dispose);

      final vantage = container.read(demoTradingProvider);
      final closedId = vantage.positions.first.id;
      expect(
        container
            .read(demoTradingProvider.notifier)
            .closePosition(closedId, realizedProfit: 12.50),
        isTrue,
      );
      final changedVantage = container.read(demoTradingProvider);
      expect(changedVantage.positions, hasLength(vantage.positions.length - 1));
      expect(changedVantage.balance, vantage.balance + 12.50);

      container.read(activeDemoAccountIdProvider.notifier).select('10001003');
      expect(container.read(demoTradingProvider).positions, isEmpty);
      expect(container.read(demoTradingProvider).balance, 0);

      container.read(activeDemoAccountIdProvider.notifier).select('10001001');
      final restoredVantage = container.read(demoTradingProvider);
      expect(
        restoredVantage.positions.map((position) => position.id),
        isNot(contains(closedId)),
      );
      expect(restoredVantage.balance, changedVantage.balance);
      expect(
        restoredVantage.historyPositions.last.id,
        startsWith('closed-$closedId-'),
      );
    },
  );

  test('single and bulk closes append history in execution order', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    final initial = container.read(demoTradingProvider);
    final initialHistoryIds = initial.historyPositions
        .map((entry) => entry.id)
        .toList(growable: false);
    final firstPositionId = initial.positions.first.id;

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closePosition(firstPositionId),
      isTrue,
    );
    final afterSingle = container.read(demoTradingProvider);
    expect(
      afterSingle.historyPositions
          .take(initialHistoryIds.length)
          .map((entry) => entry.id),
      orderedEquals(initialHistoryIds),
    );
    expect(
      afterSingle.historyPositions.last.id,
      startsWith('closed-$firstPositionId-'),
    );

    final remainingPositionIds = afterSingle.positions
        .map((position) => position.id)
        .toList(growable: false);
    expect(
      container.read(demoTradingProvider.notifier).closeAllPositions(),
      remainingPositionIds.length,
    );

    final afterBulk = container.read(demoTradingProvider);
    expect(
      afterBulk.historyPositions,
      hasLength(initialHistoryIds.length + 1 + remainingPositionIds.length),
    );
    for (var index = 0; index < remainingPositionIds.length; index++) {
      expect(
        afterBulk.historyPositions[initialHistoryIds.length + 1 + index].id,
        startsWith('closed-${remainingPositionIds[index]}-'),
      );
    }
  });

  test('partial close keeps the remainder and records only closed volume', () {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    final before = container.read(demoTradingProvider);
    final position = before.positions.first;
    final closeVolume = position.volume / 2;

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closePosition(
            position.id,
            volume: closeVolume,
            realizedProfit: 4.25,
          ),
      isTrue,
    );

    final after = container.read(demoTradingProvider);
    final remainder = after.positions.singleWhere(
      (item) => item.id == position.id,
    );
    expect(remainder.volume, closeTo(position.volume - closeVolume, 0.000001));
    expect(after.deals.first.volume, closeVolume);
    expect(after.deals.first.entry, 'out');
    expect(after.historyPositions.last.volume, closeVolume);
    expect(after.balance, before.balance + 4.25);
  });
}
