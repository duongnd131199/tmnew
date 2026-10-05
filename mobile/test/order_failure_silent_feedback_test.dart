import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/audio/order_success_sound.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/rendering/mt5_candle_painter.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/order/presentation/order_failure_message.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('market-closed API error uses the stable Vietnamese message', () {
    expect(
      orderFailureMessage(
        const ExV2RequestFailure(
          statusCode: 503,
          message: 'The market is closed for this symbol.',
          code: 'MARKET_CLOSED',
        ),
        fallback: 'Không thể đặt lệnh',
      ),
      'Thị trường đang đóng cửa',
    );
  });

  testWidgets('new-order lets the authoritative server decide market status', (
    tester,
  ) async {
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final quoteTimestamp = DateTime.utc(2026, 9, 4, 20, 57, 59);
    final container = _container(
      adapter,
      quote: DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4430.155,
        ask: 4430.415,
        changePercent: .2,
        sourceTimestamp: quoteTimestamp,
      ),
      now: () => quoteTimestamp.add(const Duration(seconds: 31)),
      failureSoundPlayer: failureSoundPlayer,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD+')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sell by Market'));
    await tester.pumpAndSettle();

    expect(adapter.orderPosts, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Order rejected'), findsNothing);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets('new-order market rejection stays silent and plays failure cue', (
    tester,
  ) async {
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      failureSoundPlayer: failureSoundPlayer,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD+')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sell by Market'));
    await tester.pumpAndSettle();

    expect(adapter.orderPosts, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Order rejected'), findsNothing);
    expect(find.textContaining('ORDER_REJECTED'), findsNothing);
    expect(find.textContaining('test-correlation-id'), findsNothing);
    expect(find.text('Sell by Market'), findsOneWidget);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets(
    'new-order pending rejection stays silent and plays failure cue',
    (tester) async {
      final adapter = _RejectOrderAdapter();
      final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
      final container = _container(
        adapter,
        failureSoundPlayer: failureSoundPlayer,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NewOrderScreen(symbol: 'XAUUSD+')),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('order-type-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('order-type-option-buy-limit')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('order-place-pending')));
      await tester.pumpAndSettle();

      expect(adapter.orderPosts, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Order rejected'), findsNothing);
      expect(find.textContaining('ORDER_REJECTED'), findsNothing);
      expect(find.textContaining('test-correlation-id'), findsNothing);
      expect(find.byKey(const Key('order-place-pending')), findsOneWidget);
      expect(failureSoundPlayer.playCount, 1);
    },
  );

  testWidgets('chart market rejection stays silent and plays failure cue', (
    tester,
  ) async {
    _useChartViewport(tester);
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      failureSoundPlayer: failureSoundPlayer,
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

    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();

    expect(adapter.orderPosts, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Order rejected'), findsNothing);
    expect(find.textContaining('ORDER_REJECTED'), findsNothing);
    expect(find.textContaining('test-correlation-id'), findsNothing);
    expect(find.byKey(const Key('chart-one-click-panel')), findsOneWidget);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets(
    'chart market success acknowledges before position refresh completes',
    (tester) async {
      _useChartViewport(tester);
      final adapter = _AcceptedChartOrderAdapter();
      final soundPlayer = _RecordingOrderSuccessSoundPlayer();
      final container = _container(
        adapter,
        quote: _btcQuote,
        soundPlayer: soundPlayer,
      );
      addTearDown(() {
        adapter.releaseBootstrap();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M5'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('chart-ticket-buy')));
      for (
        var attempt = 0;
        attempt < 20 && adapter.bootstrapReads == 0;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(adapter.orderPosts, 1);
      expect(adapter.bootstrapReads, 1);
      expect(soundPlayer.playCount, 1);
      expect(container.read(demoPositionsProvider), isEmpty);

      adapter.releaseBootstrap();
      for (
        var attempt = 0;
        attempt < 30 && container.read(demoPositionsProvider).isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(
        container.read(demoPositionsProvider).single.id,
        'server-chart-position',
      );
      expect(soundPlayer.playCount, 1);
    },
  );

  testWidgets('chart market success retries a stale bootstrap in background', (
    tester,
  ) async {
    _useChartViewport(tester);
    final adapter = _AcceptedChartOrderAdapter(
      gateBootstrap: false,
      staleBootstrapReads: 1,
    );
    final soundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      quote: _btcQuote,
      soundPlayer: soundPlayer,
    );
    addTearDown(() {
      adapter.releaseBootstrap();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M5'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chart-ticket-buy')));

    for (
      var attempt = 0;
      attempt < 40 && container.read(demoPositionsProvider).isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 25));
    }

    expect(adapter.orderPosts, 1);
    expect(soundPlayer.playCount, 1);
    expect(adapter.bootstrapReads, 2);
    expect(
      container.read(demoPositionsProvider).single.id,
      'server-chart-position',
    );
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                .painter!
            as Mt5CandlePainter;
    expect(painter.positions.single.id, 'server-chart-position');
    expect(painter.hitTargets.positionOverlays, isNotEmpty);
  });

  testWidgets(
    'chart market success uses authoritative positions while bootstrap stays stale',
    (tester) async {
      _useChartViewport(tester);
      final adapter = _AcceptedChartOrderAdapter(
        gateBootstrap: false,
        staleBootstrapReads: 100,
        directPositionsFresh: true,
      );
      final soundPlayer = _RecordingOrderSuccessSoundPlayer();
      const walletHistory = DemoHistoryPosition(
        id: 'wallet-deposit-1',
        title: 'Balance',
        profit: 1000000,
        time: '2026.09.05 09:03:00',
        subtitle: 'D-ALLINT-USD-INT-817506909087',
      );
      final accountState = _accountState.copyWith(
        historyPositions: const [walletHistory],
        deposits: const [
          {
            'id': 'deposit-1',
            'amount': 1000000,
            'status': 'completed',
            'createdAtUtc': '2026-09-05T02:03:00Z',
          },
        ],
      );
      final container = _container(
        adapter,
        accountState: accountState,
        quote: _btcQuote,
        soundPlayer: soundPlayer,
      );
      addTearDown(() {
        adapter.releaseBootstrap();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChartScreen(symbol: 'BTCUSD', initialTimeframe: 'M5'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chart-one-click-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chart-ticket-buy')));

      for (
        var attempt = 0;
        attempt < 40 && container.read(demoPositionsProvider).isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      expect(adapter.orderPosts, 1);
      expect(soundPlayer.playCount, 1);
      expect(adapter.directPositionReads, 1);
      expect(
        container.read(demoPositionsProvider).single.id,
        'server-chart-position',
      );
      final painter =
          tester
                  .widget<CustomPaint>(find.byKey(const Key('chart-canvas')))
                  .painter!
              as Mt5CandlePainter;
      expect(painter.positions.single.id, 'server-chart-position');
      expect(painter.hitTargets.positionOverlays, isNotEmpty);
      final synchronizedState = container
          .read(exV2AccountProvider)
          .requireValue!;
      expect(synchronizedState.historyPositions, contains(walletHistory));
      expect(synchronizedState.deposits.single['id'], 'deposit-1');
    },
  );

  testWidgets('chart pending rejection stays silent and plays failure cue', (
    tester,
  ) async {
    _useChartViewport(tester);
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      failureSoundPlayer: failureSoundPlayer,
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
    await tester.pumpAndSettle();

    expect(adapter.orderPosts, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Order rejected'), findsNothing);
    expect(find.textContaining('ORDER_REJECTED'), findsNothing);
    expect(find.textContaining('test-correlation-id'), findsNothing);
    expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets('position protection rejection stays silent on the ticket', (
    tester,
  ) async {
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      accountState: _positionAccountState,
      failureSoundPlayer: failureSoundPlayer,
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(
          path: '/trade',
          builder: (_, _) => const Scaffold(body: Text('Trade')),
        ),
        GoRoute(
          path: '/position',
          builder: (_, _) =>
              const PositionDetailScreen(positionId: 'server-position-1'),
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
    router.push('/position');
    await tester.pumpAndSettle();

    await tester.tap(find.text('+').first);
    await tester.pump();
    await tester.tap(find.text('Chinh sua'));
    await tester.pumpAndSettle();

    expect(adapter.protectionPuts, 1);
    expect(find.byType(PositionDetailScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Protection rejected'), findsNothing);
    expect(find.textContaining('PROTECTION_REJECTED'), findsNothing);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets('position close rejection stays silent on the ticket', (
    tester,
  ) async {
    final adapter = _RejectOrderAdapter();
    final failureSoundPlayer = _RecordingOrderSuccessSoundPlayer();
    final container = _container(
      adapter,
      accountState: _positionAccountState,
      failureSoundPlayer: failureSoundPlayer,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NewOrderScreen(
            symbol: 'XAUUSD+',
            closePositionId: 'server-position-1',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('order-close-position')));
    await tester.pumpAndSettle();

    expect(adapter.closePosts, 1);
    expect(adapter.orderPosts, 0);
    expect(
      find.byKey(const Key('position-close-order-ticket')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Close rejected'), findsNothing);
    expect(find.textContaining('CLOSE_REJECTED'), findsNothing);
    expect(failureSoundPlayer.playCount, 1);
  });

  testWidgets(
    'BTC position ticket stays visible without wait notices while order posts',
    (tester) async {
      final adapter = _DelayedOrderAdapter();
      final container = _container(
        adapter,
        accountState: _btcPositionAccountState,
        quote: _btcQuote,
      );
      addTearDown(() {
        adapter.release();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NewOrderScreen(
              symbol: 'BTCUSD',
              closePositionId: 'server-btc-position',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Buy by Market'));
      await tester.pump();

      for (
        var attempt = 0;
        attempt < 20 && adapter.orderPosts == 0;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }

      expect(adapter.orderPosts, 1);
      expect(
        find.byKey(const Key('position-close-order-ticket')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('order-type-field')), findsOneWidget);
      expect(find.text('Vui lòng chờ...'), findsNothing);
      expect(find.text('Lệnh đã được gửi đến server'), findsNothing);

      adapter.release();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('market buy 0.25 BTCUSDT at', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('hoan tat', findRichText: true),
        findsOneWidget,
      );
    },
  );
}

void _useChartViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 853);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

ProviderContainer _container(
  HttpClientAdapter adapter, {
  ExV2AccountViewState? accountState,
  DemoQuote quote = _quote,
  DateTime Function()? now,
  OrderSuccessSoundPlayer? soundPlayer,
  OrderSuccessSoundPlayer? failureSoundPlayer,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      exV2EnabledProvider.overrideWithValue(true),
      exV2DioProvider.overrideWithValue(dio),
      deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
      exV2AccountProvider.overrideWithBuild(
        (ref, controller) => accountState ?? _accountState,
      ),
      demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(quote)),
      if (now != null) marketClockProvider.overrideWithValue(now),
      if (soundPlayer != null)
        orderSuccessSoundPlayerProvider.overrideWithValue(soundPlayer),
      if (failureSoundPlayer != null)
        orderFailureSoundPlayerProvider.overrideWithValue(failureSoundPlayer),
      marketCandlesProvider.overrideWith(
        (ref, request) => Stream.value(_candles),
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

final class _RejectOrderAdapter implements HttpClientAdapter {
  int orderPosts = 0;
  int closePosts = 0;
  int protectionPuts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/orders')) {
      orderPosts += 1;
      return _json({
        'code': 'ORDER_REJECTED',
        'message': 'Order rejected',
        'correlationId': 'test-correlation-id',
      }, statusCode: 422);
    }
    if (options.method == 'PUT' &&
        options.path.endsWith('/positions/server-position-1/protection')) {
      protectionPuts += 1;
      return _json({
        'code': 'PROTECTION_REJECTED',
        'message': 'Protection rejected',
        'correlationId': 'test-correlation-id',
      }, statusCode: 422);
    }
    if (options.method == 'POST' &&
        options.path.endsWith('/positions/server-position-1/close')) {
      closePosts += 1;
      return _json({
        'code': 'CLOSE_REJECTED',
        'message': 'Close rejected',
        'correlationId': 'test-correlation-id',
      }, statusCode: 422);
    }
    return _json(<String, Object?>{});
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

final class _DelayedOrderAdapter implements HttpClientAdapter {
  final Completer<void> _gate = Completer<void>();
  int orderPosts = 0;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/orders')) {
      orderPosts += 1;
      final body = (options.data as Map).cast<String, dynamic>();
      await _gate.future;
      return _json({
        'id': 'server-btc-order',
        'clientOrderId': body['clientOrderId'],
        'symbol': 'BTCUSD',
        'type': 'market',
        'side': 'BUY',
        'volume': 0.25,
        'requestedPrice': null,
        'executedPrice': 79965.44,
        'stopLoss': null,
        'takeProfit': null,
        'status': 'filled',
        'createdAt': '2026-09-06T06:10:00Z',
        'version': 2,
        'rowVersion': 'btc-order-version',
      }, statusCode: 201);
    }
    if (options.method == 'GET' && options.path.endsWith('/mobile/bootstrap')) {
      return _json({
        ..._bootstrap,
        'version': 2,
        'positions': [
          ...(_bootstrap['positions']! as List),
          {
            'id': 'server-new-btc-position',
            'symbol': 'BTCUSD',
            'side': 'BUY',
            'initialVolume': 0.25,
            'remainingVolume': 0.25,
            'entryPrice': 79965.44,
            'realizedProfit': 0.0,
            'status': 'open',
            'createdAt': '2026-09-06T06:10:00Z',
            'rowVersion': 'new-btc-position-version',
          },
        ],
        'recentDeals': [
          {
            'id': 'server-btc-entry-deal',
            'orderId': 'server-btc-order',
            'positionId': 'server-new-btc-position',
            'type': 'in',
            'symbol': 'BTCUSD',
            'side': 'BUY',
            'volume': 0.25,
            'price': 79965.44,
            'profit': 0.0,
            'createdAtUtc': '2026-09-06T06:10:00Z',
          },
        ],
      });
    }
    return _json(<String, Object?>{});
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

final class _AcceptedChartOrderAdapter implements HttpClientAdapter {
  _AcceptedChartOrderAdapter({
    this.gateBootstrap = true,
    this.staleBootstrapReads = 0,
    this.directPositionsFresh = false,
  });

  final bool gateBootstrap;
  final int staleBootstrapReads;
  final bool directPositionsFresh;
  final Completer<void> _bootstrapGate = Completer<void>();
  int orderPosts = 0;
  int bootstrapReads = 0;
  int directPositionReads = 0;

  void releaseBootstrap() {
    if (!_bootstrapGate.isCompleted) _bootstrapGate.complete();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/orders')) {
      orderPosts += 1;
      final body = (options.data as Map).cast<String, dynamic>();
      return _json({
        'id': 'server-chart-order',
        'clientOrderId': body['clientOrderId'],
        'symbol': 'BTCUSD',
        'type': 'market',
        'side': 'BUY',
        'volume': 0.25,
        'requestedPrice': null,
        'executedPrice': 79965.44,
        'stopLoss': null,
        'takeProfit': null,
        'status': 'filled',
        'createdAt': '2026-09-06T06:10:00Z',
        'version': 2,
        'rowVersion': 'chart-order-version',
      }, statusCode: 201);
    }
    if (options.method == 'GET' && options.path.endsWith('/mobile/bootstrap')) {
      bootstrapReads += 1;
      if (gateBootstrap) await _bootstrapGate.future;
      if (bootstrapReads <= staleBootstrapReads) {
        return _json(_bootstrap);
      }
      return _json({
        ..._bootstrap,
        'version': 2,
        'positions': [
          {
            'id': 'server-chart-position',
            'symbol': 'BTCUSD',
            'side': 'BUY',
            'initialVolume': 0.25,
            'remainingVolume': 0.25,
            'entryPrice': 79965.44,
            'realizedProfit': 0.0,
            'status': 'open',
            'createdAt': '2026-09-06T06:10:00Z',
            'rowVersion': 'chart-position-version',
          },
        ],
        'recentDeals': [
          {
            'id': 'server-chart-entry-deal',
            'orderId': 'server-chart-order',
            'positionId': 'server-chart-position',
            'type': 'in',
            'symbol': 'BTCUSD',
            'side': 'BUY',
            'volume': 0.25,
            'price': 79965.44,
            'profit': 0.0,
            'createdAtUtc': '2026-09-06T06:10:00Z',
          },
        ],
      });
    }
    if (options.method == 'GET' &&
        options.path.endsWith('/positions') &&
        !options.path.contains('/history/positions')) {
      directPositionReads += 1;
      return _json(
        directPositionsFresh
            ? [
                {
                  'id': 'server-chart-position',
                  'symbol': 'BTCUSD',
                  'side': 'BUY',
                  'initialVolume': 0.25,
                  'remainingVolume': 0.25,
                  'entryPrice': 79965.44,
                  'realizedProfit': 0.0,
                  'status': 'open',
                  'createdAt': '2026-09-06T06:10:00Z',
                  'rowVersion': 'chart-position-version',
                },
              ]
            : <Object?>[],
      );
    }
    return _json(<String, Object?>{});
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

final class _RecordingOrderSuccessSoundPlayer
    implements OrderSuccessSoundPlayer {
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

const _quote = DemoQuote(
  symbol: 'XAUUSD+',
  name: 'Gold US Dollar',
  bid: 4656.76,
  ask: 4657.06,
  changePercent: .2,
);

final _candles = List<MarketCandle>.unmodifiable(
  List.generate(
    40,
    (index) => MarketCandle(
      time: DateTime.utc(2026, 8, 25).add(Duration(hours: index * 4)),
      open: 4640 + index * .4,
      high: 4642 + index * .4,
      low: 4638 + index * .4,
      close: 4641 + index * .4,
    ),
  ),
);

final _accountState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson(_bootstrap),
);

final _positionAccountState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson({
    ..._bootstrap,
    'positions': [
      {
        'id': 'server-position-1',
        'symbol': 'XAUUSD+',
        'side': 'BUY',
        'initialVolume': 0.01,
        'remainingVolume': 0.01,
        'entryPrice': 4650.0,
        'realizedProfit': 0.0,
        'status': 'open',
        'createdAt': '2026-08-25T08:00:00Z',
        'rowVersion': 'row-version-1',
      },
    ],
  }),
);

const _btcQuote = DemoQuote(
  symbol: 'BTCUSD',
  name: 'Bitcoin',
  bid: 79955.44,
  ask: 79965.44,
  changePercent: .2,
);

final _btcPositionAccountState = ExV2AccountViewState.fromBootstrap(
  ExV2Bootstrap.fromJson({
    ..._bootstrap,
    'positions': [
      {
        'id': 'server-btc-position',
        'symbol': 'BTCUSD',
        'side': 'BUY',
        'initialVolume': 0.25,
        'remainingVolume': 0.25,
        'entryPrice': 79768.46,
        'realizedProfit': 0.0,
        'status': 'open',
        'createdAt': '2026-09-06T05:00:00Z',
        'rowVersion': 'btc-position-version',
      },
    ],
  }),
);

final _bootstrap = <String, Object?>{
  'serverTime': '2026-08-25T08:00:00Z',
  'version': 1,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': '109740422',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 100000.0,
    'equity': 100000.0,
    'profit': 0.0,
    'margin': 0.0,
    'freeMargin': 100000.0,
    'marginLevel': 0.0,
    'updatedAt': '2026-08-25T08:00:00Z',
  },
  'positions': <Object?>[],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 100000.0,
    'lockedBalance': 0.0,
    'totalBalance': 100000.0,
  },
  'performance': {
    'netProfit': 0.0,
    'grossProfit': 0.0,
    'grossLoss': 0.0,
    'floatingProfit': 0.0,
    'tradingVolume': 0.0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};
