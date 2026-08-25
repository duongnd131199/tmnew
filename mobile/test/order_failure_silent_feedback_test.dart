import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets('new-order market rejection stays silent', (tester) async {
    final adapter = _RejectOrderAdapter();
    final container = _container(adapter);
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
    expect(find.text('Sell by Market'), findsOneWidget);
  });

  testWidgets('new-order pending rejection stays silent', (tester) async {
    final adapter = _RejectOrderAdapter();
    final container = _container(adapter);
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
    await tester.tap(find.byKey(const ValueKey('order-type-option-buy-limit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-place-pending')));
    await tester.pumpAndSettle();

    expect(adapter.orderPosts, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('order-place-pending')), findsOneWidget);
  });

  testWidgets('chart market rejection stays silent', (tester) async {
    _useChartViewport(tester);
    final adapter = _RejectOrderAdapter();
    final container = _container(adapter);
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
    expect(find.byKey(const Key('chart-one-click-panel')), findsOneWidget);
  });

  testWidgets('chart pending rejection stays silent', (tester) async {
    _useChartViewport(tester);
    final adapter = _RejectOrderAdapter();
    final container = _container(adapter);
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
    expect(find.byKey(const Key('chart-pending-order-pill')), findsOneWidget);
  });
}

void _useChartViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 853);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

ProviderContainer _container(_RejectOrderAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      exV2EnabledProvider.overrideWithValue(true),
      exV2DioProvider.overrideWithValue(dio),
      deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
      exV2AccountProvider.overrideWithBuild((ref, controller) => _accountState),
      demoQuoteProvider.overrideWith((ref, symbol) => Stream.value(_quote)),
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
