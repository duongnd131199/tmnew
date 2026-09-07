import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/audio/order_success_sound.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

class _RecordingOrderSuccessSoundPlayer implements OrderSuccessSoundPlayer {
  int playCount = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> play() async {
    playCount += 1;
  }

  @override
  Future<void> warmUp() async {}
}

void main() {
  const tradeViewportScale = 393 / 384;

  void useVideoViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 853);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  ProviderContainer createContainer({
    bool withCandles = false,
    OrderSuccessSoundPlayer? orderSuccessSoundPlayer,
  }) {
    return createVideoReferenceContainer(
      overrides: [
        if (orderSuccessSoundPlayer != null)
          orderSuccessSoundPlayerProvider.overrideWithValue(
            orderSuccessSoundPlayer,
          ),
        demoQuoteProvider.overrideWith((ref, symbol) {
          final quote = ref
              .read(demoQuotesProvider)
              .firstWhere((item) => item.symbol == symbol);
          return Stream.value(quote);
        }),
        if (withCandles)
          marketCandlesProvider.overrideWith((ref, request) {
            final now = DateTime(2026, 7, 17, 12);
            return Stream.value(
              List.generate(
                40,
                (index) => MarketCandle(
                  time: now.add(Duration(minutes: index)),
                  open: 4075 + index * .1,
                  high: 4076 + index * .1,
                  low: 4074 + index * .1,
                  close: 4075.5 + index * .1,
                ),
              ),
            );
          }),
      ],
    );
  }

  double tradePositionOffset(WidgetTester tester, String positionId) {
    final surface = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('trade-position-surface-$positionId')),
    );
    return (surface.transform?.storage[12] ?? 0) * tradeViewportScale;
  }

  testWidgets('plus order form does not show a position close action', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('order-close-position')), findsNothing);
    expect(find.text('Sell by Market'), findsOneWidget);
    expect(find.text('Buy by Market'), findsOneWidget);
  });

  testWidgets('slow order submission exposes no infrastructure message', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sell by Market'));
    await tester.pump();

    expect(find.textContaining('server'), findsNothing);
    expect(find.textContaining('đồng bộ'), findsNothing);
    expect(find.textContaining('Vui lòng chờ'), findsNothing);

    await tester.pump(const Duration(milliseconds: 750));
  });

  testWidgets('new order uses initial side and BTC protection tick size', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NewOrderScreen(symbol: 'BTCUSD', initialSide: 'sell'),
        ),
      ),
    );
    await tester.pump();

    final sellSide = tester.widget<Semantics>(
      find.byKey(const Key('order-side-sell')),
    );
    final buySide = tester.widget<Semantics>(
      find.byKey(const Key('order-side-buy')),
    );
    expect(sellSide.properties.selected, isTrue);
    expect(buySide.properties.selected, isFalse);

    String stopLossText() => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('order-sl-value')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    await tester.tap(find.byKey(const Key('order-sl-increase')));
    await tester.pump();
    expect(stopLossText(), '65175.99');
    await tester.tap(find.byKey(const Key('order-sl-increase')));
    await tester.pump();
    expect(stopLossText(), '65176.00');
  });

  testWidgets(
    'XAU volume, order type and fill policy sheets update a pending ticket',
    (tester) async {
      final container = createContainer();
      addTearDown(container.dispose);
      final pendingBefore = container.read(demoPendingOrdersProvider).length;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD+')),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('order-volume-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('order-volume-input')),
        '100',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('order-volume-done')));
      await tester.pumpAndSettle();
      expect(find.text('100.00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-type-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('order-type-option-buy-limit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buy Limit'), findsWidgets);
      expect(find.byKey(const Key('order-place-pending')), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-fill-policy-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('order-fill-option-immediate-or-cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Immediate or Cancel'), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-place-pending')));
      await tester.pump(const Duration(milliseconds: 750));
      expect(
        container.read(demoPendingOrdersProvider),
        hasLength(pendingBefore + 1),
      );
      expect(
        find.textContaining('100.00 XAUUSD', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('position close completion uses the actual position volume', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.read(activeDemoAccountIdProvider.notifier).select('10001002');
    final position = container.read(demoPositionsProvider).first;
    expect(position.volume, 179);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NewOrderScreen(
            symbol: position.symbol,
            closePositionId: position.id,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('179.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('order-close-position')));
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      find.textContaining('179.00 ${position.symbol}', findRichText: true),
      findsOneWidget,
    );
    expect(
      container
          .read(demoPositionsProvider)
          .where((item) => item.id == position.id),
      isEmpty,
    );
  });

  for (final side in ['sell', 'buy']) {
    testWidgets('$side market button opens a new position from close ticket', (
      tester,
    ) async {
      final container = createContainer();
      addTearDown(container.dispose);
      final before = container.read(demoPositionsProvider);
      final position = before.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NewOrderScreen(
              symbol: position.symbol,
              closePositionId: position.id,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(ValueKey('order-side-$side')));
      await tester.pump(const Duration(milliseconds: 750));

      expect(
        container
            .read(demoPositionsProvider)
            .where((item) => item.id == position.id),
        isNotEmpty,
      );
      expect(
        container.read(demoPositionsProvider),
        hasLength(before.length + 1),
      );
      expect(
        container.read(demoPositionsProvider).first.side,
        side.toUpperCase(),
      );
    });
  }

  testWidgets(
    'confirmed market order automatically returns to the updated Trade list',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer();
      addTearDown(container.dispose);
      final initialPositions = container.read(demoPositionsProvider).length;
      final router = GoRouter(
        initialLocation: '/market',
        routes: [
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketWatchScreen(),
          ),
          GoRoute(
            path: '/order',
            builder: (context, state) => NewOrderScreen(
              symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
              initialSide: state.uri.queryParameters['side'] ?? 'buy',
            ),
          ),
          GoRoute(
            path: '/trade',
            builder: (context, state) => Consumer(
              builder: (context, ref, child) => Scaffold(
                body: Text('TRADE ${ref.watch(demoPositionsProvider).length}'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('XAUUSD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giao dich'));
      await tester.pumpAndSettle();
      expect(find.text('Buy by Market'), findsOneWidget);

      await tester.tap(find.text('Buy by Market'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        container.read(demoPositionsProvider),
        hasLength(initialPositions + 1),
      );
      expect(find.textContaining('hoan tat'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('TRADE ${initialPositions + 1}'), findsOneWidget);
      expect(find.byType(NewOrderScreen), findsNothing);
    },
  );

  testWidgets(
    'confirmed position close automatically returns to the updated Trade list',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer();
      addTearDown(container.dispose);
      container.read(activeDemoAccountIdProvider.notifier).select('10001002');
      final position = container.read(demoPositionsProvider).first;
      final initialPositions = container.read(demoPositionsProvider).length;
      final router = GoRouter(
        initialLocation:
            '/order?symbol=${position.symbol}&positionId=${position.id}',
        routes: [
          GoRoute(
            path: '/order',
            builder: (context, state) => NewOrderScreen(
              symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
              closePositionId: state.uri.queryParameters['positionId'],
            ),
          ),
          GoRoute(
            path: '/trade',
            builder: (context, state) => Consumer(
              builder: (context, ref, child) => Scaffold(
                body: Text('TRADE ${ref.watch(demoPositionsProvider).length}'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('order-close-position')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        container.read(demoPositionsProvider),
        hasLength(initialPositions - 1),
      );
      expect(find.textContaining('hoan tat'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('TRADE ${initialPositions - 1}'), findsOneWidget);
      expect(find.byType(NewOrderScreen), findsNothing);
    },
  );

  testWidgets('orange position action opens a ticket-bound close form', (
    tester,
  ) async {
    final container = createContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NewOrderScreen(
            symbol: position.symbol,
            closePositionId: position.id,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('order-close-position')), findsOneWidget);
    expect(find.textContaining('#${position.id}'), findsWidgets);

    await tester.tap(find.byKey(const Key('order-close-position')));
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      container
          .read(demoPositionsProvider)
          .where((item) => item.id == position.id),
      isEmpty,
    );
    expect(find.textContaining('hoan tat'), findsOneWidget);
  });

  testWidgets('close form hides a server GUID behind a short numeric ticket', (
    tester,
  ) async {
    const position = DemoPosition(
      id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .25,
      openPrice: 4102.125,
      currentPrice: 4102.396,
      profit: 6.78,
    );
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NewOrderScreen(
            symbol: position.symbol,
            closePositionId: position.id,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('#11615687251 buy 0.25'), findsOneWidget);
    expect(find.textContaining(position.id), findsNothing);
  });

  testWidgets('position tap, swipe and context dialog follow the video', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;
    final row = find.byKey(ValueKey('trade-position-${position.id}'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Đóng trạng thái'), findsOneWidget);
    expect(find.text('Hoạt động hàng loạt...'), findsOneWidget);
    await tester.tapAt(const Offset(8, 110));
    await tester.pumpAndSettle();

    await tester.drag(row, const Offset(-220, 0));
    await tester.pumpAndSettle();
    final more = find.byKey(ValueKey('trade-menu-${position.id}'));
    expect(more, findsOneWidget);
    expect(
      tradePositionOffset(tester, position.id),
      closeTo(-168 * tradeViewportScale, .01),
    );

    await tester.drag(row, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(tradePositionOffset(tester, position.id), 0);

    await tester.drag(row, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(
      tradePositionOffset(tester, position.id),
      closeTo(-168 * tradeViewportScale, .01),
    );

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Đóng trạng thái'), findsOneWidget);
  });

  testWidgets(
    'selected position opens contextual bulk actions after its sheet closes',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer();
      addTearDown(container.dispose);
      final position = container.read(demoPositionsProvider).first;
      final initialIds = container
          .read(demoPositionsProvider)
          .map((item) => item.id)
          .toList(growable: false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TradeScreen()),
        ),
      );
      await tester.pump();

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byKey(ValueKey('trade-position-${position.id}')));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tap(find.text('Hoạt động hàng loạt...'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.byKey(const Key('position-bulk-actions-dialog')),
          findsOneWidget,
        );
        expect(
          find.text(
            '#${position.id} buy 0.25 XAUUSD '
            '${position.openPrice.toStringAsFixed(2)}',
          ),
          findsOneWidget,
        );
        expect(
          container.read(demoPositionsProvider).map((item) => item.id),
          orderedEquals(initialIds),
        );

        await tester.tap(find.byKey(const Key('position-bulk-cancel')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('position-bulk-actions-dialog')),
          findsNothing,
        );
      }
    },
  );

  testWidgets('trade close action opens the iOS close ticket', (tester) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(path: '/trade', builder: (_, _) => const TradeScreen()),
        GoRoute(
          path: '/order',
          builder: (_, state) => Scaffold(
            body: Text('CLOSE ${state.uri.queryParameters['positionId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('trade-position-${position.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đóng trạng thái'));
    await tester.pumpAndSettle();

    expect(find.text('CLOSE ${position.id}'), findsOneWidget);
    expect(
      container.read(demoPositionsProvider).map((item) => item.id),
      contains(position.id),
    );
  });

  testWidgets('trade swipe exposes iOS context modify and close actions', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(ValueKey('trade-position-${position.id}')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('trade-menu-${position.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('trade-modify-${position.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('trade-close-${position.id}')), findsOneWidget);
  });

  testWidgets('close by requires choosing the opposite iOS position', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    final source = container.read(demoPositionsProvider).first;
    final oppositeId = container
        .read(demoTradingProvider.notifier)
        .placeOrder(
          symbol: source.symbol,
          side: source.side == 'BUY' ? 'SELL' : 'BUY',
          volume: source.volume / 2,
          executedPrice: source.currentPrice,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('trade-position-${source.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đóng bởi'));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const ValueKey('confirm-close-by'));
    expect(
      find.byKey(ValueKey('close-by-candidate-$oppositeId')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(ValueKey('close-by-candidate-$oppositeId')));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Đã gửi yêu cầu'), findsNothing);

    expect(
      container
          .read(demoPositionsProvider)
          .where((item) => item.id == oppositeId),
      isEmpty,
    );
    expect(
      container
          .read(demoPositionsProvider)
          .singleWhere((item) => item.id == source.id)
          .volume,
      closeTo(source.volume / 2, .000001),
    );
  });

  testWidgets('close by chooser hides both server GUIDs', (tester) async {
    useVideoViewport(tester);
    const source = DemoPosition(
      id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .25,
      openPrice: 4102.125,
      currentPrice: 4102.396,
      profit: 6.78,
    );
    const opposite = DemoPosition(
      id: '5ff94719-e61a-4c05-bbab-bb6f81c15369',
      symbol: 'XAUUSD',
      side: 'SELL',
      volume: .25,
      openPrice: 4102.500,
      currentPrice: 4102.396,
      profit: -2.60,
    );
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [source, opposite]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('trade-position-${source.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Đóng bởi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('#11615687251'), findsOneWidget);
    expect(find.textContaining('#71383708458'), findsOneWidget);
    expect(find.textContaining(source.id), findsNothing);
    expect(find.textContaining(opposite.id), findsNothing);
  });

  testWidgets(
    'trade position follows the finger, resists overscroll and snaps smoothly',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer();
      addTearDown(container.dispose);
      final position = container.read(demoPositionsProvider).first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TradeScreen()),
        ),
      );
      await tester.pump();

      final row = find.byKey(ValueKey('trade-position-${position.id}'));
      final rowY = tester.getCenter(row).dy;
      expect(tradePositionOffset(tester, position.id), 0);

      final open = await tester.startGesture(Offset(180, rowY));
      await open.moveBy(const Offset(-35, 0));
      await tester.pump();
      expect(tradePositionOffset(tester, position.id), closeTo(-35, 1));
      await open.moveBy(const Offset(-45, 0));
      await tester.pump();
      expect(tradePositionOffset(tester, position.id), closeTo(-80, 1));
      await open.up();
      await tester.pumpAndSettle();
      expect(
        tradePositionOffset(tester, position.id),
        closeTo(-168 * tradeViewportScale, .01),
      );

      final stayOpen = await tester.startGesture(Offset(180, rowY));
      await stayOpen.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tradePositionOffset(tester, position.id),
        closeTo(-168 * tradeViewportScale + 20, 1),
      );
      await stayOpen.up();
      await tester.pumpAndSettle();
      expect(
        tradePositionOffset(tester, position.id),
        closeTo(-168 * tradeViewportScale, .01),
      );

      final close = await tester.startGesture(Offset(180, rowY));
      await close.moveBy(const Offset(110, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tradePositionOffset(tester, position.id),
        closeTo(-168 * tradeViewportScale + 110, 1),
      );
      await close.up();
      await tester.pumpAndSettle();
      expect(tradePositionOffset(tester, position.id), 0);

      final rightOverscroll = await tester.startGesture(Offset(180, rowY));
      await rightOverscroll.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(tradePositionOffset(tester, position.id), greaterThan(0));
      expect(
        tradePositionOffset(tester, position.id),
        lessThanOrEqualTo(24 * tradeViewportScale),
      );
      await rightOverscroll.up();
      await tester.pumpAndSettle();
      expect(tradePositionOffset(tester, position.id), 0);

      final leftOverscroll = await tester.startGesture(Offset(180, rowY));
      await leftOverscroll.moveBy(const Offset(-220, 0));
      await tester.pump();
      expect(
        tradePositionOffset(tester, position.id),
        lessThan(-168 * tradeViewportScale),
      );
      expect(
        tradePositionOffset(tester, position.id),
        greaterThanOrEqualTo(-192 * tradeViewportScale),
      );
      await leftOverscroll.up();
      await tester.pumpAndSettle();
      expect(
        tradePositionOffset(tester, position.id),
        closeTo(-168 * tradeViewportScale, .01),
      );
    },
  );

  testWidgets('trade account metrics scroll with the position list', (
    tester,
  ) async {
    useVideoViewport(tester);
    tester.view.physicalSize = const Size(393, 430);
    final container = createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();

    final section = find.text('Lenh co trang thai');
    final profit = find.byKey(const Key('trade-header-profit'));
    final sectionBefore = tester.getTopLeft(section).dy;
    final profitBefore = tester.getTopLeft(profit).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -67));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(section).dy, closeTo(sectionBefore - 47, 2));
    expect(tester.getTopLeft(profit).dy, closeTo(profitBefore, .1));
  });

  testWidgets('last pending order scrolls clear of the bottom tabs', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    container.read(activeDemoAccountIdProvider.notifier).select('10001002');
    final orderId = container
        .read(demoTradingProvider.notifier)
        .placePendingOrder(
          symbol: 'XAUUSD+',
          type: 'Buy Limit',
          volume: .25,
          price: 3932.70,
          stopLoss: 3900,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TradeScreen()),
      ),
    );
    await tester.pump();

    final listFinder = find.byType(ListView);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final row = find.byKey(ValueKey('trade-pending-$orderId'));
    expect(row, findsOneWidget);
    final listRect = tester.getRect(listFinder);
    final rowRect = tester.getRect(row);
    expect(listRect.bottom - rowRect.bottom, greaterThanOrEqualTo(100));
    expect(
      tester.getSize(find.byKey(const Key('trade-bottom-safe-gap'))).height,
      104,
    );
  });

  testWidgets('trade context actions keep the XAUUSD+ symbol in both routes', (
    tester,
  ) async {
    useVideoViewport(tester);
    final container = createContainer();
    addTearDown(container.dispose);
    final position = container.read(demoPositionsProvider).first;
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(
          path: '/trade',
          builder: (context, state) => const TradeScreen(),
        ),
        GoRoute(
          path: '/section',
          builder: (context, state) =>
              Scaffold(body: Text(state.uri.queryParameters['title'] ?? '')),
        ),
        GoRoute(
          path: '/chart',
          builder: (context, state) => Scaffold(
            body: Text('CHART ${state.uri.queryParameters['symbol']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    Future<void> openContextMenu() async {
      final row = find.byKey(ValueKey('trade-position-${position.id}'));
      await tester.drag(row, const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('trade-menu-${position.id}')));
      await tester.pumpAndSettle();
    }

    await openContextMenu();
    await tester.tap(find.text('Depth of Market'));
    await tester.pumpAndSettle();
    expect(find.text('Depth of Market XAUUSD+'), findsOneWidget);

    router.go('/trade');
    await tester.pumpAndSettle();
    await openContextMenu();
    await tester.tap(find.text('Biểu đồ'));
    await tester.pumpAndSettle();
    expect(find.text('CHART XAUUSD+'), findsOneWidget);
    expect(router.state.uri.queryParameters['timeframe'], 'H4');
  });

  testWidgets('successful chart one-click order plays one confirmation sound', (
    tester,
  ) async {
    useVideoViewport(tester);
    final soundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = createContainer(
      withCandles: true,
      orderSuccessSoundPlayer: soundPlayer,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();

    final positionsBefore = container.read(demoPositionsProvider).length;

    await tester.tap(find.byKey(const Key('chart-ticket-buy')));
    await tester.pump();

    expect(
      container.read(demoPositionsProvider),
      hasLength(positionsBefore + 1),
    );
    expect(soundPlayer.playCount, 1);
  });

  testWidgets('successful chart pending order plays one confirmation sound', (
    tester,
  ) async {
    useVideoViewport(tester);
    final soundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = createContainer(
      withCandles: true,
      orderSuccessSoundPlayer: soundPlayer,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.byKey(const Key('chart-gesture-area')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chart-pending-order-pill')));
    await tester.pump();

    expect(container.read(demoPendingOrdersProvider), hasLength(1));
    expect(soundPlayer.playCount, 1);
  });

  testWidgets(
    'chart long press opens the recorded transient Buy Limit workflow',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer(withCandles: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
          ),
        ),
      );
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      await tester.longPress(chart);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hien thi muc do giao dich'), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-jump')), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
      expect(container.read(demoPendingOrdersProvider), isEmpty);

      await tester.tap(find.byKey(const Key('chart-pending-order-pill')));
      await tester.pump();
      expect(container.read(demoPendingOrdersProvider), hasLength(1));
      expect(
        find.byKey(const Key('chart-pending-no-connection')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 241));
      await tester.pump();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);
    },
  );

  testWidgets(
    'pending chart order panel edits protection and confirms while connected',
    (tester) async {
      useVideoViewport(tester);
      final container = createContainer(withCandles: true);
      addTearDown(container.dispose);
      container
          .read(demoTradingProvider.notifier)
          .placePendingOrder(
            symbol: 'XAUUSD+',
            type: 'Buy Limit',
            volume: .25,
            price: 3948.18,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'XAUUSD+', initialTimeframe: 'H4'),
          ),
        ),
      );
      await tester.pump();

      final chart = find.byKey(const Key('chart-gesture-area'));
      expect(container.read(demoPendingOrdersProvider), hasLength(1));
      expect(
        container.read(demoPendingOrdersProvider).single.type,
        'Buy Limit',
      );
      final chartRect = tester.getRect(chart);
      dynamic painter = tester
          .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
          .painter;
      final pendingOrderY = painter.pendingOrderY as double?;
      expect(pendingOrderY, isNotNull);

      final awayY = pendingOrderY! < 70
          ? pendingOrderY + 70
          : pendingOrderY - 70;
      await tester.tapAt(Offset(chartRect.left + 100, chartRect.top + awayY));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);

      await tester.tapAt(
        Offset(chartRect.left + 100, chartRect.top + pendingOrderY),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-sl')), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-tp')), findsOneWidget);
      expect(find.byKey(const Key('chart-pending-collapse')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chart-pending-sl')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3900.50');
      await tester.tap(find.text('XONG'));
      await tester.pumpAndSettle();

      var pendingOrder = container.read(demoPendingOrdersProvider).single;
      expect(pendingOrder.stopLoss, 3900.50);
      expect(pendingOrder.takeProfit, isNull);

      await tester.tap(find.byKey(const Key('chart-pending-sl')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '3900.50',
      );
      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chart-pending-tp')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3995.50');
      await tester.tap(find.text('XONG'));
      await tester.pumpAndSettle();

      pendingOrder = container.read(demoPendingOrdersProvider).single;
      expect(pendingOrder.stopLoss, 3900.50);
      expect(pendingOrder.takeProfit, 3995.50);

      await tester.tap(find.byKey(const Key('chart-pending-tp')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '3995.50',
      );
      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chart-pending-collapse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);

      await tester.tapAt(
        Offset(chartRect.left + 100, chartRect.top + pendingOrderY),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('chart-pending-order-pill')),
        const Offset(130, 0),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('chart-pending-no-connection')),
        findsNothing,
      );
      expect(container.read(demoPendingOrdersProvider), hasLength(1));

      await tester.pump(const Duration(milliseconds: 241));
      await tester.pump();
      expect(find.byKey(const Key('chart-pending-order-pill')), findsNothing);
      expect(
        find.byKey(const Key('chart-pending-no-connection')),
        findsNothing,
      );
    },
  );
}
