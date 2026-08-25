import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('create order waits for server and refreshes the position', () async {
    final adapter = _TradingAdapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final order = await container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);

    expect(order.id, 'server-order-1');
    expect(adapter.orderPosts, 1);
    for (
      var attempt = 0;
      attempt < 20 &&
          (container.read(exV2AccountProvider).value?.positions.isEmpty ??
              true);
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      container.read(exV2AccountProvider).value?.positions.single.id,
      'server-position-1',
    );
  });

  test('create order exposes a sending row before HTTP completes', () async {
    final adapter = _TradingAdapter()..orderGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final creating = container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);
    await Future<void>.delayed(Duration.zero);

    final optimistic = container.read(exV2AccountProvider).value!;
    expect(optimistic.orders.single.status, 'sending');
    expect(optimistic.pendingOperationIds, hasLength(1));
    await container.read(exV2AccountProvider.notifier).refresh();
    expect(
      container
          .read(exV2AccountProvider)
          .value
          ?.orders
          .where((order) => order.status == 'sending'),
      hasLength(1),
    );

    adapter.orderGate!.complete();
    await creating;
  });

  test(
    'rapid market commands remain independent while server is slow',
    () async {
      final adapter = _TradingAdapter()..orderGate = Completer<void>();
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final commands = List.generate(
        3,
        (_) => container
            .read(exV2AccountProvider.notifier)
            .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
      );
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(exV2AccountProvider).value!;
      expect(optimistic.orders, hasLength(3));
      expect(optimistic.orders.map((order) => order.id).toSet(), hasLength(3));
      expect(optimistic.pendingOperationIds, hasLength(3));
      for (var attempt = 0; attempt < 20 && adapter.orderPosts < 3; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(adapter.orderPosts, 3);
      expect(adapter.clientOrderIds.toSet(), hasLength(3));

      adapter.orderGate!.complete();
      await Future.wait(commands);
    },
  );

  test('rapid accepted orders coalesce background reconciliation', () async {
    final adapter = _TradingAdapter()..orderGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(() {
      final orderGate = adapter.orderGate;
      if (orderGate != null && !orderGate.isCompleted) orderGate.complete();
      final bootstrapGate = adapter.bootstrapGate;
      if (bootstrapGate != null && !bootstrapGate.isCompleted) {
        bootstrapGate.complete();
      }
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    final initialBootstrapReads = adapter.bootstrapReads;
    adapter.bootstrapGate = Completer<void>();

    final commands = List.generate(
      10,
      (_) => container
          .read(exV2AccountProvider.notifier)
          .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
    );
    for (var attempt = 0; attempt < 100 && adapter.orderPosts < 10; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(adapter.orderPosts, 10);

    adapter.orderGate!.complete();
    await Future.wait(commands);
    for (
      var attempt = 0;
      attempt < 100 && adapter.bootstrapReads == initialBootstrapReads;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(adapter.bootstrapReads, initialBootstrapReads + 1);
    expect(adapter.maxConcurrentBootstrapReads, 1);

    adapter.bootstrapGate!.complete();
    for (
      var attempt = 0;
      attempt < 100 && adapter.bootstrapReads < initialBootstrapReads + 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(
      adapter.bootstrapReads,
      lessThanOrEqualTo(initialBootstrapReads + 2),
    );
    expect(adapter.maxConcurrentBootstrapReads, 1);
  });

  test('failed optimistic create removes its sending row', () async {
    final adapter = _TradingAdapter(rejectOrder: true);
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
      throwsA(isA<ExV2RequestFailure>()),
    );

    final rolledBack = container.read(exV2AccountProvider).value!;
    expect(rolledBack.orders, isEmpty);
    expect(rolledBack.pendingOperationIds, isEmpty);
  });

  test('failed create reports its typed diagnostic once', () async {
    final adapter = _TradingAdapter(rejectOrder: true);
    final reported = <Object>[];
    final container = _container(adapter, orderFailureReporter: reported.add);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
      throwsA(isA<ExV2RequestFailure>()),
    );

    expect(reported, hasLength(1));
    expect(
      reported.single,
      isA<ExV2RequestFailure>()
          .having((error) => error.statusCode, 'statusCode', 422)
          .having((error) => error.code, 'code', 'ORDER_REJECTED')
          .having(
            (error) => error.correlationId,
            'correlationId',
            'order-test-correlation',
          ),
    );
  });

  test('accepted order survives a failed follow-up bootstrap', () async {
    final adapter = _TradingAdapter(failBootstrapAfterAcceptedOrder: true);
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final accepted = await container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final current = container.read(exV2AccountProvider).value!;
    expect(accepted.id, 'server-order-1');
    expect(adapter.orderPosts, 1);
    expect(current.orders.single.id, 'server-order-1');
    expect(current.orders.single.status, 'filled');
    expect(current.pendingOperationIds, isEmpty);
  });

  test(
    'create order exposes server rejection and keeps state unchanged',
    () async {
      final adapter = _TradingAdapter(rejectOrder: true);
      final container = _container(adapter);
      addTearDown(container.dispose);
      final before = await container.read(exV2AccountProvider.future);

      await expectLater(
        container
            .read(exV2AccountProvider.notifier)
            .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.01),
        throwsA(
          isA<ExV2RequestFailure>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.message, 'message', 'Order rejected'),
        ),
      );

      expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
      expect(
        container.read(exV2AccountProvider).value?.balance,
        before?.balance,
      );
    },
  );

  test('close position waits for server and refreshes it away', () async {
    final adapter = _TradingAdapter()..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    final before = await container.read(exV2AccountProvider.future);
    expect(before?.positions.single.id, 'server-position-1');
    adapter.onClosedHistoryRead = () {
      unawaited(container.read(exV2AccountProvider.notifier).refresh());
    };

    final closeDeal = await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    expect(adapter.closePosts, 1);
    expect(closeDeal?.positionId, 'server-position-1');
    expect(closeDeal?.price, 4365.28);
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
  });

  test(
    'close publishes authoritative balance before delayed history completes',
    () async {
      final historyGate = Completer<void>();
      final historyStarted = Completer<void>();
      final adapter = _TradingAdapter()
        ..created = true
        ..postCloseHistoryGate = historyGate
        ..postCloseHistoryStarted = historyStarted;
      final container = _container(adapter);
      addTearDown(() {
        if (!historyGate.isCompleted) historyGate.complete();
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);

      var closeCompleted = false;
      final closing = container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1')
          .whenComplete(() => closeCompleted = true);
      await historyStarted.future;

      final accountState = container.read(exV2AccountProvider).value!;
      expect(closeCompleted, isFalse);
      expect(adapter.closePosts, 1);
      expect(accountState.positions, isEmpty);
      expect(accountState.balance, closeTo(5306.525, 0.000001));
      expect(
        container.read(demoAccountProvider).balance,
        closeTo(5306.525, 0.000001),
      );
      expect(
        accountState.pendingOperationIds,
        contains('position:server-position-1'),
      );

      historyGate.complete();
      await closing;
    },
  );

  test(
    'partial close publishes server balance before delayed history completes',
    () async {
      final historyGate = Completer<void>();
      final historyStarted = Completer<void>();
      final adapter = _TradingAdapter()
        ..created = true
        ..postCloseHistoryGate = historyGate
        ..postCloseHistoryStarted = historyStarted;
      final container = _container(adapter);
      addTearDown(() {
        if (!historyGate.isCompleted) historyGate.complete();
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1', volume: 0.004);
      await historyStarted.future;

      final accountState = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(accountState.positions.single.volume, closeTo(0.006, 0.000001));
      expect(accountState.balance, closeTo(5120.0, 0.000001));
      expect(
        container.read(demoAccountProvider).balance,
        closeTo(5120.0, 0.000001),
      );

      historyGate.complete();
      await closing;
    },
  );

  test(
    'close preserves live profit for positions left open during history sync',
    () async {
      final historyGate = Completer<void>();
      final historyStarted = Completer<void>();
      final adapter = _TradingAdapter()
        ..created = true
        ..oppositeCreated = true
        ..postCloseHistoryGate = historyGate
        ..postCloseHistoryStarted = historyStarted;
      final container = _container(adapter);
      addTearDown(() {
        if (!historyGate.isCompleted) historyGate.complete();
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      container
          .read(exV2AccountProvider.notifier)
          .updateMarketPrice(symbol: 'XAUUSD+', bid: 4380, ask: 4381);
      expect(
        container.read(exV2AccountProvider).value!.profit,
        closeTo(3.52, 0.000001),
      );

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');
      await historyStarted.future;

      final accountState = container.read(exV2AccountProvider).value!;
      expect(accountState.hasLiveValuation, isTrue);
      expect(accountState.positions.single.id, 'server-position-2');
      expect(accountState.positions.single.currentPrice, 4381);
      expect(accountState.positions.single.profit, closeTo(-2.76, 0.000001));
      expect(accountState.profit, closeTo(-2.76, 0.000001));

      historyGate.complete();
      await closing;
    },
  );

  test(
    'partial close revalues remaining volume without a zero profit frame',
    () async {
      final historyGate = Completer<void>();
      final historyStarted = Completer<void>();
      final adapter = _TradingAdapter()
        ..created = true
        ..postCloseHistoryGate = historyGate
        ..postCloseHistoryStarted = historyStarted;
      final container = _container(adapter);
      addTearDown(() {
        if (!historyGate.isCompleted) historyGate.complete();
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      container
          .read(exV2AccountProvider.notifier)
          .updateMarketPrice(symbol: 'XAUUSD+', bid: 4380, ask: 4381);

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1', volume: 0.004);
      await historyStarted.future;

      final position = container
          .read(exV2AccountProvider)
          .value!
          .positions
          .single;
      expect(position.volume, closeTo(0.006, 0.000001));
      expect(position.currentPrice, 4380);
      expect(position.profit, closeTo(3.768, 0.000001));

      historyGate.complete();
      await closing;
    },
  );

  test('close history cannot overwrite a newer optimistic command', () async {
    final historyGate = Completer<void>();
    final historyStarted = Completer<void>();
    final adapter = _TradingAdapter()
      ..created = true
      ..postCloseHistoryGate = historyGate
      ..postCloseHistoryStarted = historyStarted
      ..orderGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(() {
      if (!historyGate.isCompleted) historyGate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);

    final closing = container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');
    await historyStarted.future;
    final ordering = container
        .read(exV2AccountProvider.notifier)
        .createOrder(symbol: 'XAUUSD+', side: 'buy', volume: 0.02);
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(exV2AccountProvider)
          .value!
          .orders
          .any((row) => row.status == 'sending'),
      isTrue,
    );
    historyGate.complete();
    await closing;

    final state = container.read(exV2AccountProvider).value!;
    expect(state.orders.any((row) => row.status == 'sending'), isTrue);
    expect(state.balance, closeTo(5306.525, 0.000001));
    adapter.orderGate!.complete();
    await ordering;
  });

  test(
    'close history preserves a concurrent position protection edit',
    () async {
      final historyGate = Completer<void>();
      final historyStarted = Completer<void>();
      final adapter = _TradingAdapter()
        ..created = true
        ..oppositeCreated = true
        ..postCloseHistoryGate = historyGate
        ..postCloseHistoryStarted = historyStarted
        ..protectionGate = Completer<void>();
      final container = _container(adapter);
      addTearDown(() {
        if (!historyGate.isCompleted) historyGate.complete();
        if (!(adapter.protectionGate?.isCompleted ?? true)) {
          adapter.protectionGate!.complete();
        }
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');
      await historyStarted.future;
      final protecting = container
          .read(exV2AccountProvider.notifier)
          .updatePositionProtection(
            positionId: 'server-position-2',
            takeProfit: 4400,
          );
      await Future<void>.delayed(Duration.zero);
      historyGate.complete();
      await closing;

      final state = container.read(exV2AccountProvider).value!;
      expect(state.positions.single.id, 'server-position-2');
      expect(state.positions.single.takeProfit, 4400);
      adapter.protectionGate!.complete();
      await protecting;
    },
  );

  test('committed close publishes matching deals and closed history', () async {
    final refreshGate = Completer<void>();
    final adapter = _TradingAdapter()
      ..created = true
      ..postCloseRefreshGate = refreshGate;
    final container = _container(adapter);
    addTearDown(() {
      if (!refreshGate.isCompleted) refreshGate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    final state = container.read(exV2AccountProvider).value!;
    expect(state.positions, isEmpty);
    expect(state.deals.map((deal) => deal.id), [
      'close-deal-1',
      'close-deal-2',
    ]);
    expect(state.historyPositions.single.id.toLowerCase(), 'server-position-1');
    expect(
      state.historyPositions.single.closePrice,
      closeTo(4365.58, 0.000001),
    );
  });

  test(
    'close awaits matching balance history and summary without resending POST',
    () async {
      final adapter = _TradingAdapter(delayedClosedHistory: true)
        ..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(state.positions, isEmpty);
      expect(state.balance, closeTo(5306.525, 0.000001));
      expect(state.deals.map((deal) => deal.id), [
        'close-deal-1',
        'close-deal-2',
      ]);
      expect(state.historyPositions.single.closePrice, isNotNull);
      expect(state.historySummary.realizedProfit, closeTo(306.525, 0.000001));
      expect(state.historySummary.netChange, closeTo(306.525, 0.000001));
    },
  );

  test('close rejects a stale bootstrap even when history is ready', () async {
    final adapter = _TradingAdapter(staleBootstrapReadsAfterClose: 1)
      ..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    final state = container.read(exV2AccountProvider).value!;
    expect(adapter.closePosts, 1);
    expect(adapter.postCloseBootstrapReads, greaterThanOrEqualTo(2));
    expect(state.positions, isEmpty);
    expect(state.balance, closeTo(5306.525, 0.000001));
    expect(state.historyPositions.single.closePrice, isNotNull);
  });

  test(
    'close retries reads after the first post-close bootstrap fails',
    () async {
      final adapter = _TradingAdapter(failFirstPostCloseBootstrap: true)
        ..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(adapter.postCloseBootstrapReads, greaterThanOrEqualTo(2));
      expect(state.balance, closeTo(5306.525, 0.000001));
      expect(state.deals, isNotEmpty);
      expect(state.historyPositions, isNotEmpty);
    },
  );

  test('close waits until history summary reflects realized profit', () async {
    final adapter = _TradingAdapter(delayedHistorySummary: true)
      ..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    final state = container.read(exV2AccountProvider).value!;
    expect(adapter.closePosts, 1);
    expect(adapter.postCloseHistorySummaryReads, greaterThanOrEqualTo(2));
    expect(state.historySummary.realizedProfit, closeTo(306.525, 0.000001));
  });

  test(
    'committed close keeps authoritative balance when history endpoint fails',
    () async {
      final adapter = _TradingAdapter(failPostCloseHistoryDeals: true)
        ..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(state.positions, isEmpty);
      expect(state.balance, closeTo(5306.525, 0.000001));
      expect(state.deals, isEmpty);
      expect(state.historyPositions, isEmpty);
    },
  );

  test('close removes the position before the server responds', () async {
    final adapter = _TradingAdapter()..created = true;
    adapter.closeGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closing = container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      contains('position:server-position-1'),
    );
    await container.read(exV2AccountProvider.notifier).refresh();
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);

    adapter.closeGate!.complete();
    await closing;
  });

  test(
    'contextual bulk closes sequentially and publishes history as one group',
    () async {
      final adapter = _TradingAdapter(contextualBulkFixture: true);
      adapter.bulkCloseGates.addAll(
        List<Completer<void>>.generate(3, (_) => Completer<void>()),
      );
      final container = _container(adapter);
      addTearDown(() {
        for (final gate in adapter.bulkCloseGates) {
          if (!gate.isCompleted) gate.complete();
        }
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      final publishedHistorySizes = <int>[];
      final subscription = container.listen(exV2AccountProvider, (_, next) {
        final size = next.value?.historyPositions.length;
        if (size != null) publishedHistorySizes.add(size);
      });
      addTearDown(subscription.close);

      expect(container.read(demoPositionsProvider), hasLength(4));
      final closed = container
          .read(demoTradingProvider.notifier)
          .closeMatchingPositions(symbol: 'XAUUSD+');

      expect(closed, 3);
      expect(
        container.read(demoPositionsProvider).map((position) => position.id),
        orderedEquals(['e-buy-win']),
      );
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.closePosts, 1);
      expect(container.read(demoHistoryPositionsProvider), isEmpty);

      adapter.bulkCloseGates[0].complete();
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.closePosts, 2);
      expect(container.read(demoHistoryPositionsProvider), isEmpty);

      adapter.bulkCloseGates[1].complete();
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 3;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.closePosts, 3);
      expect(container.read(demoHistoryPositionsProvider), isEmpty);

      adapter.bulkCloseGates[2].complete();
      for (
        var attempt = 0;
        attempt < 200 &&
            container
                .read(exV2AccountProvider)
                .value!
                .pendingOperationIds
                .isNotEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(
        adapter.closePositionIds,
        orderedEquals(['x-buy-win', 'x-buy-loss', 'x-sell-win']),
      );
      expect(adapter.closePositionIds.toSet(), hasLength(3));
      expect(adapter.closePositionIds, isNot(contains('e-buy-win')));
      expect(adapter.closePosts, 3);
      expect(adapter.maxConcurrentBulkClosePosts, 1);
      expect(adapter.closeByPosts, 0);
      expect(
        container.read(exV2AccountProvider).value!.pendingOperationIds,
        isEmpty,
      );
      expect(
        container
            .read(demoHistoryPositionsProvider)
            .map((position) => position.id)
            .toSet(),
        {'x-buy-win', 'x-buy-loss', 'x-sell-win'},
      );
      expect(publishedHistorySizes.where((size) => size > 0), everyElement(3));
    },
  );

  test(
    'bulk close defers refresh work until the command group settles',
    () async {
      final adapter = _TradingAdapter(contextualBulkFixture: true);
      adapter.bulkCloseGates.addAll(
        List<Completer<void>>.generate(3, (_) => Completer<void>()),
      );
      final container = _container(adapter);
      addTearDown(() {
        for (final gate in adapter.bulkCloseGates) {
          if (!gate.isCompleted) gate.complete();
        }
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      expect(adapter.bootstrapReads, 1);

      expect(
        container
            .read(demoTradingProvider.notifier)
            .closeMatchingPositions(symbol: 'XAUUSD+'),
        3,
      );
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      adapter.bulkCloseGates[0].complete();
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await container.read(exV2AccountProvider.notifier).refresh();

      expect(adapter.bootstrapReads, 1);
      expect(container.read(demoHistoryPositionsProvider), isEmpty);

      adapter.bulkCloseGates[1].complete();
      adapter.bulkCloseGates[2].complete();
      for (
        var attempt = 0;
        attempt < 200 &&
            container
                .read(exV2AccountProvider)
                .value!
                .pendingOperationIds
                .isNotEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      for (
        var attempt = 0;
        attempt < 200 && adapter.bootstrapReads < 3;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.bootstrapReads, 3);
    },
  );

  test('concurrent refresh requests share one bootstrap read', () async {
    final adapter = _TradingAdapter();
    final container = _container(adapter);
    addTearDown(() {
      final gate = adapter.bootstrapGate;
      if (gate != null && !gate.isCompleted) gate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    final initialBootstrapReads = adapter.bootstrapReads;
    adapter.bootstrapGate = Completer<void>();

    final notifier = container.read(exV2AccountProvider.notifier);
    final refreshes = <Future<void>>[
      notifier.refresh(),
      notifier.refresh(),
      notifier.refresh(),
    ];
    for (
      var attempt = 0;
      attempt < 100 && adapter.bootstrapReads == initialBootstrapReads;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    adapter.bootstrapGate!.complete();
    await Future.wait(refreshes);

    expect(adapter.bootstrapReads, initialBootstrapReads + 1);
    expect(adapter.maxConcurrentBootstrapReads, 1);
  });

  test('bulk reconciliation loads core and history in parallel', () async {
    final adapter = _TradingAdapter(contextualBulkFixture: true)
      ..contextualBulkFinalBootstrapGate = Completer<void>()
      ..contextualBulkFinalHistoryStarted = Completer<void>();
    final container = _container(adapter);
    addTearDown(() {
      final gate = adapter.contextualBulkFinalBootstrapGate;
      if (gate != null && !gate.isCompleted) gate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closeMatchingPositions(symbol: 'XAUUSD+'),
      3,
    );
    for (
      var attempt = 0;
      attempt < 200 && adapter.bootstrapReads < 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    for (
      var attempt = 0;
      attempt < 50 && !adapter.contextualBulkFinalHistoryStarted!.isCompleted;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final historyStartedWhileBootstrapBlocked =
        adapter.contextualBulkFinalHistoryStarted!.isCompleted;
    adapter.contextualBulkFinalBootstrapGate!.complete();
    for (
      var attempt = 0;
      attempt < 200 &&
          container
              .read(exV2AccountProvider)
              .value!
              .pendingOperationIds
              .isNotEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(historyStartedWhileBootstrapBlocked, isTrue);
  });

  test('30-position bulk close performs one final reconciliation', () async {
    final bulkPositions = List<Map<String, Object?>>.generate(
      30,
      (index) => {
        'id': 'bulk-xau-$index',
        'symbol': 'XAUUSD+',
        'side': index.isEven ? 'BUY' : 'SELL',
        'initialVolume': 0.01,
        'remainingVolume': 0.01,
        'entryPrice': 4600 + index.toDouble(),
        'realizedProfit': index.isEven ? 1.0 : -1.0,
        'status': 'open',
        'createdAt': '2026-08-24T01:00:00Z',
      },
    );
    final adapter = _TradingAdapter(
      contextualBulkFixture: true,
      contextualBulkPositions: bulkPositions,
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    final positiveHistoryPublicationSizes = <int>[];
    container.listen(demoHistoryPositionsProvider, (_, next) {
      if (next.isNotEmpty) positiveHistoryPublicationSizes.add(next.length);
    });

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closeMatchingPositions(symbol: 'XAUUSD+'),
      30,
    );
    for (
      var attempt = 0;
      attempt < 1000 &&
          container
              .read(exV2AccountProvider)
              .value!
              .pendingOperationIds
              .isNotEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    for (
      var attempt = 0;
      attempt < 200 && container.read(demoHistoryPositionsProvider).length < 30;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(adapter.closePosts, 30);
    expect(adapter.maxConcurrentBulkClosePosts, 1);
    expect(adapter.bootstrapReads, 2);
    expect(positiveHistoryPublicationSizes, [30]);
    expect(container.read(demoPositionsProvider), isEmpty);
  });

  test('concurrent close groups share one global POST lane', () async {
    final adapter = _TradingAdapter(contextualBulkFixture: true);
    adapter.bulkCloseGates.addAll(
      List<Completer<void>>.generate(4, (_) => Completer<void>()),
    );
    final container = _container(adapter);
    addTearDown(() {
      for (final gate in adapter.bulkCloseGates) {
        if (!gate.isCompleted) gate.complete();
      }
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    final notifier = container.read(exV2AccountProvider.notifier);

    final first = notifier.closePositions(['x-buy-win', 'x-buy-loss']);
    final second = notifier.closePositions(['x-sell-win', 'e-buy-win']);
    for (var attempt = 0; attempt < 100 && adapter.closePosts < 2; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final maxBeforeRelease = adapter.maxConcurrentBulkClosePosts;
    for (final gate in adapter.bulkCloseGates) {
      if (!gate.isCompleted) gate.complete();
    }
    await Future.wait([first, second]);

    expect(maxBeforeRelease, 1);
    expect(adapter.maxConcurrentBulkClosePosts, 1);
  });

  test('stale initial hydration cannot erase committed bulk history', () async {
    final adapter = _TradingAdapter(contextualBulkFixture: true)
      ..initialContextualHistoryGate = Completer<void>()
      ..initialContextualHistoryStarted = Completer<void>();
    final container = _container(adapter);
    addTearDown(() {
      final gate = adapter.initialContextualHistoryGate;
      if (gate != null && !gate.isCompleted) gate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    await adapter.initialContextualHistoryStarted!.future;

    expect(
      container
          .read(demoTradingProvider.notifier)
          .closeMatchingPositions(symbol: 'XAUUSD+'),
      3,
    );
    for (
      var attempt = 0;
      attempt < 500 && container.read(demoHistoryPositionsProvider).length < 3;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(container.read(demoHistoryPositionsProvider), hasLength(3));

    adapter.initialContextualHistoryGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(demoHistoryPositionsProvider), hasLength(3));
  });

  test('authoritative account refresh aborts a bulk group cleanly', () async {
    final adapter = _TradingAdapter(contextualBulkFixture: true);
    adapter.bulkCloseGates.add(Completer<void>());
    final container = _container(adapter);
    addTearDown(() {
      if (!adapter.bulkCloseGates.single.isCompleted) {
        adapter.bulkCloseGates.single.complete();
      }
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    final notifier = container.read(exV2AccountProvider.notifier);
    final closing = notifier.closePositions(['x-buy-win']);
    for (var attempt = 0; attempt < 100 && adapter.closePosts < 1; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final queuedClose = notifier.closePositions(['x-buy-loss']);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(adapter.closePosts, 1);

    adapter
      ..contextualAccountId = 'account-2'
      ..contextualBootstrapVersionOverride = 0
      ..bulkOpenPositionIds.clear();
    await notifier.refresh(allowDuringGroupedClose: true);

    expect(
      container.read(exV2AccountProvider).value!.bootstrap.account.id,
      'account-2',
    );
    expect(
      container.read(exV2AccountProvider).value!.pendingOperationIds,
      isEmpty,
    );
    adapter.bulkCloseGates.single.complete();
    await Future.wait([closing, queuedClose]);
    expect(adapter.closePosts, 1);
    final readsBeforeOrdinaryRefresh = adapter.bootstrapReads;
    await notifier.refresh();
    expect(adapter.bootstrapReads, readsBeforeOrdinaryRefresh + 1);
  });

  test('bulk settlement requeues a superseded account refresh', () async {
    final adapter = _TradingAdapter(contextualBulkFixture: true);
    final container = _container(adapter);
    addTearDown(() {
      final gate = adapter.bootstrapGate;
      if (gate != null && !gate.isCompleted) gate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    adapter.bootstrapGate = Completer<void>();
    final notifier = container.read(exV2AccountProvider.notifier);

    final switching = notifier.refresh(allowDuringGroupedClose: true);
    for (
      var attempt = 0;
      attempt < 100 && adapter.bootstrapReads < 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final closing = notifier.closePositions(['x-buy-win']);
    for (var attempt = 0; attempt < 100 && adapter.closePosts < 1; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    adapter.bootstrapGate!.complete();
    await Future.wait([switching, closing]);
    for (
      var attempt = 0;
      attempt < 200 && adapter.bootstrapReads < 4;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(adapter.bootstrapReads, greaterThanOrEqualTo(4));
  });

  test('partial close awaits its deal summary and remaining volume', () async {
    final adapter = _TradingAdapter(delayedClosedHistory: true)..created = true;
    adapter.closeGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closing = container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1', volume: 0.004);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exV2AccountProvider).value?.positions.single.volume,
      closeTo(0.006, 0.000001),
    );
    adapter.closeGate!.complete();
    await closing;
    expect(adapter.lastCloseData?['volume'], 0.004);
    expect(adapter.closePosts, 1);
    expect(adapter.preCloseHistoryDealReads, greaterThanOrEqualTo(1));
    expect(
      container.read(exV2AccountProvider).value?.positions.single.volume,
      closeTo(0.006, 0.000001),
    );
    final state = container.read(exV2AccountProvider).value!;
    expect(state.deals.single.volume, closeTo(0.004, 0.000001));
    expect(state.historySummary.realizedProfit, closeTo(120, 0.000001));
  });

  test(
    'close by immediately preserves the larger position remainder',
    () async {
      final adapter = _TradingAdapter()
        ..created = true
        ..oppositeCreated = true
        ..closeByGate = Completer<void>();
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final closing = container
          .read(exV2AccountProvider.notifier)
          .closeBy('server-position-1', 'server-position-2');
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(exV2AccountProvider).value!.positions;
      expect(optimistic, hasLength(1));
      expect(optimistic.single.id, 'server-position-1');
      expect(optimistic.single.volume, closeTo(.006, .000001));

      adapter.closeByGate!.complete();
      await closing;
      final committed = container.read(exV2AccountProvider).value!.positions;
      expect(committed, hasLength(1));
      expect(committed.single.id, 'server-position-1');
      expect(committed.single.volume, closeTo(.006, .000001));
      expect(adapter.closeByPosts, 1);
    },
  );

  test('failed optimistic close restores the position', () async {
    final adapter = _TradingAdapter(rejectClose: true)..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1'),
      throwsA(isA<ExV2RequestFailure>()),
    );

    expect(
      container.read(exV2AccountProvider).value?.positions.single.id,
      'server-position-1',
    );
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      isEmpty,
    );
  });

  test(
    'committed close stays removed while closing deal is still syncing',
    () async {
      final adapter = _TradingAdapter(omitClosedDeal: true)..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      final closeDeal = await container
          .read(exV2AccountProvider.notifier)
          .closePosition('server-position-1');

      expect(closeDeal, isNull);
      expect(adapter.closePosts, 1);
      expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
      expect(
        container.read(exV2AccountProvider).value?.balance,
        closeTo(5306.525, 0.000001),
      );
      expect(
        container.read(exV2AccountProvider).value?.pendingOperationIds,
        isEmpty,
      );
    },
  );

  test('position not found removes a stale local position', () async {
    final adapter = _TradingAdapter(stalePositionOnClose: true)..created = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final closeDeal = await container
        .read(exV2AccountProvider.notifier)
        .closePosition('server-position-1');

    expect(closeDeal, isNull);
    expect(adapter.closePosts, 1);
    expect(container.read(exV2AccountProvider).value?.positions, isEmpty);
    expect(
      container.read(exV2AccountProvider).value?.pendingOperationIds,
      isEmpty,
    );
  });

  test(
    'position-not-found cannot publish bootstrap from another account',
    () async {
      final adapter = _TradingAdapter(
        stalePositionOnClose: true,
        switchAccountAfterRejectedClose: true,
      )..created = true;
      final container = _container(adapter);
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      await expectLater(
        container
            .read(exV2AccountProvider.notifier)
            .closePosition('server-position-1'),
        throwsA(isA<ExV2RequestFailure>()),
      );

      final state = container.read(exV2AccountProvider).value!;
      expect(state.bootstrap.account.id, 'account-1');
      expect(state.bootstrap.summary.accountId, 'account-1');
      expect(state.positions.single.id, 'server-position-1');
    },
  );

  test('limit and stop UI orders use the server pending contract', () async {
    final adapter = _TradingAdapter();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .createOrder(
          symbol: 'XAUUSD+',
          side: 'buy',
          volume: 0.01,
          type: 'limit',
          requestedPrice: 1000,
        );

    expect(adapter.lastOrderData?['type'], 'pending');
    expect(adapter.lastOrderData?['requestedPrice'], 1000);
  });

  test('cancel removes a pending order before HTTP completes', () async {
    final adapter = _TradingAdapter()..pending = true;
    adapter.cancelGate = Completer<void>();
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final canceling = container
        .read(exV2AccountProvider.notifier)
        .cancelOrder('pending-order-1');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exV2AccountProvider).value?.pendingOrders, isEmpty);
    adapter.cancelGate!.complete();
    await canceling;
  });

  test('failed optimistic cancel restores the pending order', () async {
    final adapter = _TradingAdapter(rejectCancel: true)..pending = true;
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await expectLater(
      container
          .read(exV2AccountProvider.notifier)
          .cancelOrder('pending-order-1'),
      throwsA(isA<ExV2RequestFailure>()),
    );

    expect(
      container.read(exV2AccountProvider).value?.pendingOrders.single.id,
      'pending-order-1',
    );
  });
}

ProviderContainer _container(
  HttpClientAdapter adapter, {
  void Function(Object error)? orderFailureReporter,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      exV2EnabledProvider.overrideWithValue(true),
      exV2DioProvider.overrideWithValue(dio),
      deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
      if (orderFailureReporter != null)
        exV2OrderFailureReporterProvider.overrideWithValue(
          orderFailureReporter,
        ),
    ],
  );
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? token = 'test-token';

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

final class _TradingAdapter implements HttpClientAdapter {
  _TradingAdapter({
    this.rejectOrder = false,
    this.rejectClose = false,
    this.rejectCancel = false,
    this.omitClosedDeal = false,
    this.stalePositionOnClose = false,
    this.failBootstrapAfterAcceptedOrder = false,
    this.delayedClosedHistory = false,
    this.staleBootstrapReadsAfterClose = 0,
    this.failFirstPostCloseBootstrap = false,
    this.delayedHistorySummary = false,
    this.failPostCloseHistoryDeals = false,
    this.switchAccountAfterRejectedClose = false,
    this.contextualBulkFixture = false,
    List<Map<String, Object?>>? contextualBulkPositions,
  }) : _bulkFixturePositions =
           contextualBulkPositions ?? _contextualBulkPositions {
    bulkOpenPositionIds.addAll(
      _bulkFixturePositions.map((position) => position['id']! as String),
    );
  }

  final bool rejectOrder;
  final bool rejectClose;
  final bool rejectCancel;
  final bool omitClosedDeal;
  final bool stalePositionOnClose;
  final bool failBootstrapAfterAcceptedOrder;
  final bool delayedClosedHistory;
  final int staleBootstrapReadsAfterClose;
  final bool failFirstPostCloseBootstrap;
  final bool delayedHistorySummary;
  final bool failPostCloseHistoryDeals;
  final bool switchAccountAfterRejectedClose;
  final bool contextualBulkFixture;
  final List<Map<String, Object?>> _bulkFixturePositions;
  int orderPosts = 0;
  int closePosts = 0;
  int closeByPosts = 0;
  int bootstrapVersion = 0;
  int bootstrapReads = 0;
  int activeBootstrapReads = 0;
  int maxConcurrentBootstrapReads = 0;
  bool created = false;
  bool oppositeCreated = false;
  bool pending = false;
  bool closeCommitted = false;
  bool rejectedCloseOccurred = false;
  int closedHistoryDealReads = 0;
  int closedHistoryPositionReads = 0;
  int postCloseBootstrapReads = 0;
  int preCloseHistoryDealReads = 0;
  int postCloseHistorySummaryReads = 0;
  Map<String, dynamic>? lastOrderData;
  final List<String> clientOrderIds = <String>[];
  Map<String, dynamic>? lastCloseData;
  final List<String> closePositionIds = <String>[];
  final List<String> bulkCommittedPositionIds = <String>[];
  final List<Completer<void>> bulkCloseGates = <Completer<void>>[];
  int activeBulkClosePosts = 0;
  int maxConcurrentBulkClosePosts = 0;
  final Set<String> bulkOpenPositionIds = <String>{};
  double remainingVolume = 0.01;
  String contextualAccountId = 'account-1';
  int? contextualBootstrapVersionOverride;
  void Function()? onClosedHistoryRead;
  bool _concurrentRefreshTriggered = false;
  Completer<void>? closeGate;
  Completer<void>? closeByGate;
  Completer<void>? orderGate;
  Completer<void>? cancelGate;
  Completer<void>? postCloseRefreshGate;
  Completer<void>? postCloseHistoryGate;
  Completer<void>? postCloseHistoryStarted;
  Completer<void>? protectionGate;
  Completer<void>? bootstrapGate;
  Completer<void>? contextualBulkFinalBootstrapGate;
  Completer<void>? contextualBulkFinalHistoryStarted;
  Completer<void>? initialContextualHistoryGate;
  Completer<void>? initialContextualHistoryStarted;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/orders') && options.method == 'POST') {
      orderPosts++;
      lastOrderData = (options.data as Map).cast<String, dynamic>();
      clientOrderIds.add(lastOrderData!['clientOrderId'] as String);
      if (rejectOrder) {
        return _json({
          'code': 'ORDER_REJECTED',
          'message': 'Order rejected',
          'correlationId': 'order-test-correlation',
        }, statusCode: 422);
      }
      await orderGate?.future;
      created = true;
      return _json(_order);
    }
    if (contextualBulkFixture &&
        path.contains('/positions/') &&
        path.endsWith('/close') &&
        options.method == 'POST') {
      final segments = options.uri.pathSegments;
      final positionId = segments[segments.indexOf('positions') + 1];
      final gateIndex = closePosts;
      closePosts++;
      closePositionIds.add(positionId);
      activeBulkClosePosts++;
      if (activeBulkClosePosts > maxConcurrentBulkClosePosts) {
        maxConcurrentBulkClosePosts = activeBulkClosePosts;
      }
      try {
        if (gateIndex < bulkCloseGates.length) {
          await bulkCloseGates[gateIndex].future;
        }
        bulkOpenPositionIds.remove(positionId);
        bulkCommittedPositionIds.add(positionId);
        return _json({
          ..._bulkFixturePositions.singleWhere(
            (position) => position['id'] == positionId,
          ),
          'remainingVolume': 0,
          'realizedProfit': 0,
          'status': 'closed',
          'closedAt': '2026-08-24T02:00:00Z',
        });
      } finally {
        activeBulkClosePosts--;
      }
    }
    if (path.endsWith('/positions/server-position-1/close') &&
        options.method == 'POST') {
      closePosts++;
      lastCloseData = (options.data as Map).cast<String, dynamic>();
      if (stalePositionOnClose) {
        created = false;
        rejectedCloseOccurred = true;
        return _json({
          'code': 'POSITION_NOT_FOUND',
          'message': 'Position not found',
        }, statusCode: 422);
      }
      if (rejectClose) {
        return _json({
          'code': 'CLOSE_REJECTED',
          'message': 'Close rejected',
        }, statusCode: 422);
      }
      await closeGate?.future;
      final requestedVolume = (lastCloseData?['volume'] as num?)?.toDouble();
      final partialExecution =
          requestedVolume != null && requestedVolume < remainingVolume;
      if (partialExecution) {
        remainingVolume -= requestedVolume;
      } else {
        remainingVolume = 0;
        created = false;
      }
      closeCommitted = remainingVolume == 0;
      closedHistoryDealReads = 0;
      closedHistoryPositionReads = 0;
      postCloseBootstrapReads = 0;
      return _json({
        ..._bootstrapPosition,
        'remainingVolume': remainingVolume,
        'realizedProfit': partialExecution ? 120.0 : 306.525,
        'status': partialExecution ? 'open' : 'closed',
        'closedAt': partialExecution
            ? '2026-08-13T16:30:10Z'
            : '2026-08-13T16:31:10Z',
      });
    }
    if (path.endsWith('/positions/server-position-1/close-by') &&
        options.method == 'POST') {
      closeByPosts++;
      await closeByGate?.future;
      remainingVolume -= 0.004;
      oppositeCreated = false;
      return _json(<String, Object?>{});
    }
    if (path.endsWith('/positions/server-position-2/protection') &&
        options.method == 'PUT') {
      await protectionGate?.future;
      return _json(<String, Object?>{});
    }
    if (path.endsWith('/orders/pending-order-1') &&
        options.method == 'DELETE') {
      if (rejectCancel) {
        return _json({
          'code': 'CANCEL_REJECTED',
          'message': 'Cancel rejected',
        }, statusCode: 422);
      }
      await cancelGate?.future;
      pending = false;
      return _json(<String, Object?>{});
    }
    if (path.endsWith('/mobile/bootstrap')) {
      bootstrapReads++;
      activeBootstrapReads++;
      if (activeBootstrapReads > maxConcurrentBootstrapReads) {
        maxConcurrentBootstrapReads = activeBootstrapReads;
      }
      await bootstrapGate?.future;
      activeBootstrapReads--;
      if (contextualBulkFixture) {
        if (bulkCommittedPositionIds.length == 3) {
          await contextualBulkFinalBootstrapGate?.future;
        }
        return _json({
          ..._bootstrap(
            version: contextualBootstrapVersionOverride ?? ++bootstrapVersion,
            withPosition: false,
            accountId: contextualAccountId,
          ),
          'positions': [
            for (final position in _bulkFixturePositions)
              if (bulkOpenPositionIds.contains(position['id'])) position,
          ],
        });
      }
      if (failBootstrapAfterAcceptedOrder && created) {
        return _json({
          'code': 'BOOTSTRAP_UNAVAILABLE',
          'message': 'Bootstrap unavailable',
        }, statusCode: 503);
      }
      if (remainingVolume < 0.01) {
        postCloseBootstrapReads++;
        if (failFirstPostCloseBootstrap && postCloseBootstrapReads == 1) {
          return _json({
            'code': 'BOOTSTRAP_UNAVAILABLE',
            'message': 'Bootstrap unavailable',
          }, statusCode: 503);
        }
        if (closeCommitted &&
            postCloseRefreshGate != null &&
            postCloseBootstrapReads > 1) {
          await postCloseRefreshGate!.future;
        }
      }
      final staleAfterClose =
          closeCommitted &&
          postCloseBootstrapReads <= staleBootstrapReadsAfterClose;
      return _json(
        _bootstrap(
          version: ++bootstrapVersion,
          withPosition: staleAfterClose || created,
          withPending: pending,
          remainingVolume: staleAfterClose ? 0.01 : remainingVolume,
          withOppositePosition: oppositeCreated,
          accountId: rejectedCloseOccurred && switchAccountAfterRejectedClose
              ? 'account-2'
              : 'account-1',
          balanceOverride: remainingVolume > 0 && remainingVolume < 0.01
              ? 5120.0
              : null,
        ),
      );
    }
    if (contextualBulkFixture && path.endsWith('/history/summary')) {
      if (bulkCommittedPositionIds.length == 3 &&
          !(contextualBulkFinalHistoryStarted?.isCompleted ?? true)) {
        contextualBulkFinalHistoryStarted!.complete();
      }
      return _json({
        'deposit': 0,
        'withdrawal': 0,
        'realizedProfit': 0,
        'swap': 0,
        'commission': 0,
        'netChange': 0,
      });
    }
    if (path.endsWith('/history/summary')) {
      if (remainingVolume < 0.01) postCloseHistorySummaryReads++;
      final realizedProfit = closeCommitted
          ? 306.525
          : remainingVolume < 0.01
          ? 120.0
          : 0.0;
      final visibleRealizedProfit =
          delayedHistorySummary && postCloseHistorySummaryReads == 1
          ? 0.0
          : realizedProfit;
      return _json({
        'deposit': 0,
        'withdrawal': 0,
        'realizedProfit': visibleRealizedProfit,
        'swap': 0,
        'commission': 0,
        'netChange': visibleRealizedProfit,
      });
    }
    if (path.endsWith('/settings')) return _json(<String, Object?>{});
    if (contextualBulkFixture && path.endsWith('/history/deals')) {
      if (bulkCommittedPositionIds.isEmpty &&
          initialContextualHistoryGate != null) {
        if (!(initialContextualHistoryStarted?.isCompleted ?? true)) {
          initialContextualHistoryStarted!.complete();
        }
        await initialContextualHistoryGate!.future;
      }
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': bulkCommittedPositionIds.length,
        'items': [
          for (final positionId in bulkCommittedPositionIds)
            {
              'id': 'close-$positionId',
              'positionId': positionId,
              'orderId': 'order-$positionId',
              'dealType': 'close',
              'symbol': _bulkFixturePositions.singleWhere(
                (position) => position['id'] == positionId,
              )['symbol'],
              'side': 'sell',
              'volume': _bulkFixturePositions.singleWhere(
                (position) => position['id'] == positionId,
              )['initialVolume'],
              'price': _bulkFixturePositions.singleWhere(
                (position) => position['id'] == positionId,
              )['entryPrice'],
              'profit': 0,
              'createdAtUtc': '2026-08-24T02:00:00Z',
            },
        ],
      });
    }
    if (path.endsWith('/history/deals')) {
      final hasCloseExecution = remainingVolume < 0.01;
      if (!hasCloseExecution) preCloseHistoryDealReads++;
      if (hasCloseExecution) closedHistoryDealReads++;
      if (hasCloseExecution && postCloseHistoryGate != null) {
        if (!(postCloseHistoryStarted?.isCompleted ?? true)) {
          postCloseHistoryStarted!.complete();
        }
        await postCloseHistoryGate!.future;
      }
      if (hasCloseExecution && failPostCloseHistoryDeals) {
        return _json({
          'code': 'HISTORY_UNAVAILABLE',
          'message': 'History unavailable',
        }, statusCode: 503);
      }
      if (closeCommitted && !_concurrentRefreshTriggered) {
        _concurrentRefreshTriggered = true;
        scheduleMicrotask(() => onClosedHistoryRead?.call());
      }
      if (hasCloseExecution &&
          delayedClosedHistory &&
          closedHistoryDealReads == 1) {
        return _json({
          'page': 1,
          'pageSize': 50,
          'total': 0,
          'items': <Object?>[],
        });
      }
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': !hasCloseExecution || omitClosedDeal
            ? 0
            : closeCommitted
            ? 2
            : 1,
        'items': !hasCloseExecution || omitClosedDeal
            ? <Object?>[]
            : closeCommitted
            ? [
                {
                  'id': 'close-deal-1',
                  'positionId': 'server-position-1',
                  'orderId': 'server-order-1',
                  'dealType': 'close',
                  'symbol': 'XAUUSD+',
                  'side': 'sell',
                  'volume': 0.004,
                  'price': 4365.28,
                  'profit': 120,
                  'createdAtUtc': '2026-08-13T16:30:10Z',
                },
                {
                  'id': 'close-deal-2',
                  'positionId': 'server-position-1',
                  'orderId': 'server-order-1',
                  'dealType': 'out_by',
                  'symbol': 'XAUUSD+',
                  'side': 'sell',
                  'volume': 0.006,
                  'price': 4365.78,
                  'profit': 186.525,
                  'createdAtUtc': '2026-08-13T16:31:10Z',
                },
              ]
            : [
                {
                  'id': 'partial-close-deal-1',
                  'positionId': 'server-position-1',
                  'orderId': 'server-order-1',
                  'dealType': 'close',
                  'symbol': 'XAUUSD+',
                  'side': 'sell',
                  'volume': 0.004,
                  'price': 4365.28,
                  'profit': 120,
                  'createdAtUtc': '2026-08-13T16:30:10Z',
                },
              ],
      });
    }
    if (contextualBulkFixture && path.endsWith('/history/positions')) {
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': bulkCommittedPositionIds.length,
        'items': [
          for (final positionId in bulkCommittedPositionIds)
            {
              ..._bulkFixturePositions.singleWhere(
                (position) => position['id'] == positionId,
              ),
              'positionId': positionId,
              'remainingVolume': 0,
              'realizedProfit': 0,
              'status': 'closed',
              'createdAtUtc': '2026-08-24T01:00:00Z',
              'closedAtUtc': '2026-08-24T02:00:00Z',
            },
        ],
      });
    }
    if (path.endsWith('/history/positions')) {
      if (closeCommitted) closedHistoryPositionReads++;
      final delayed =
          closeCommitted &&
          delayedClosedHistory &&
          closedHistoryPositionReads == 1;
      return _json({
        'page': 1,
        'pageSize': 50,
        'total': closeCommitted && !delayed ? 1 : 0,
        'items': closeCommitted && !delayed
            ? [
                {
                  'positionId': 'SERVER-POSITION-1',
                  'symbol': 'XAUUSD+',
                  'side': 'buy',
                  'initialVolume': 0.01,
                  'remainingVolume': 0,
                  'entryPrice': 4373.72,
                  'realizedProfit': 306.525,
                  'status': 'closed',
                  'createdAtUtc': '2026-08-13T14:00:00Z',
                  'closedAtUtc': '2026-08-13T16:31:10Z',
                },
              ]
            : <Object?>[],
      });
    }
    return _json(<Object?>[]);
  }

  ResponseBody _json(Object body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

final _order = <String, Object?>{
  'id': 'server-order-1',
  'clientOrderId': 'client-order-1',
  'symbol': 'XAUUSD+',
  'type': 'market',
  'side': 'buy',
  'volume': 0.01,
  'requestedPrice': null,
  'executedPrice': 4373.72,
  'stopLoss': null,
  'takeProfit': null,
  'status': 'filled',
  'createdAt': '2026-08-13T14:00:00Z',
  'version': 2,
  'rowVersion': 'order-rv',
};

Map<String, Object?> _bootstrap({
  required int version,
  required bool withPosition,
  bool withPending = false,
  double remainingVolume = 0.01,
  bool withOppositePosition = false,
  String accountId = 'account-1',
  double? balanceOverride,
}) => {
  'serverTime': '2026-08-13T14:00:00Z',
  'version': version,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': accountId,
    'accountCode': 'TEST-100',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': accountId,
    'currency': 'USD',
    'balance': balanceOverride ?? (withPosition ? 5000 : 5306.525),
    'equity': balanceOverride ?? (withPosition ? 5000 : 5306.525),
    'profit': 0,
    'margin': 0,
    'freeMargin': balanceOverride ?? (withPosition ? 5000 : 5306.525),
    'marginLevel': 0,
    'updatedAt': '2026-08-13T14:00:00Z',
  },
  'positions': <Object?>[
    if (withPosition)
      <String, Object?>{
        ..._bootstrapPosition,
        'remainingVolume': remainingVolume,
      },
    if (withOppositePosition) _oppositeBootstrapPosition,
  ],
  'pendingOrders': withPending ? [_pendingOrder] : <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 1000,
    'lockedBalance': 0,
    'totalBalance': 1000,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};

final _bootstrapPosition = <String, Object?>{
  'id': 'server-position-1',
  'symbol': 'XAUUSD+',
  'side': 'BUY',
  'initialVolume': 0.01,
  'remainingVolume': 0.01,
  'entryPrice': 4373.72,
  'realizedProfit': 0,
  'status': 'open',
  'createdAt': '2026-08-13T14:00:00Z',
};

final _contextualBulkPositions = <Map<String, Object?>>[
  {
    'id': 'x-buy-win',
    'symbol': 'XAUUSD+',
    'side': 'BUY',
    'initialVolume': 1,
    'remainingVolume': 1,
    'entryPrice': 4622.83,
    'realizedProfit': 27,
    'status': 'open',
    'createdAt': '2026-08-24T01:00:00Z',
  },
  {
    'id': 'x-buy-loss',
    'symbol': 'XAUUSD+',
    'side': 'BUY',
    'initialVolume': 2,
    'remainingVolume': 2,
    'entryPrice': 4624.0,
    'realizedProfit': -90,
    'status': 'open',
    'createdAt': '2026-08-24T01:01:00Z',
  },
  {
    'id': 'x-sell-win',
    'symbol': 'XAUUSD+',
    'side': 'SELL',
    'initialVolume': .5,
    'remainingVolume': .5,
    'entryPrice': 4624.1,
    'realizedProfit': 50,
    'status': 'open',
    'createdAt': '2026-08-24T01:02:00Z',
  },
  {
    'id': 'e-buy-win',
    'symbol': 'EURUSD',
    'side': 'BUY',
    'initialVolume': .1,
    'remainingVolume': .1,
    'entryPrice': 1.1,
    'realizedProfit': 10,
    'status': 'open',
    'createdAt': '2026-08-24T01:03:00Z',
  },
];

final _oppositeBootstrapPosition = <String, Object?>{
  'id': 'server-position-2',
  'symbol': 'XAUUSD+',
  'side': 'SELL',
  'initialVolume': 0.004,
  'remainingVolume': 0.004,
  'entryPrice': 4374.1,
  'realizedProfit': 0,
  'status': 'open',
  'createdAt': '2026-08-13T14:00:10Z',
};

final _pendingOrder = <String, Object?>{
  'id': 'pending-order-1',
  'clientOrderId': 'pending-client-1',
  'symbol': 'XAUUSD+',
  'type': 'pending',
  'side': 'buy',
  'volume': 0.01,
  'requestedPrice': 4300.0,
  'executedPrice': null,
  'stopLoss': null,
  'takeProfit': null,
  'status': 'pending',
  'createdAt': '2026-08-13T14:00:00Z',
  'version': 1,
  'rowVersion': 'pending-rv',
};
