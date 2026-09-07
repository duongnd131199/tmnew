import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  void useLdPlayerViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<ProviderContainer> pumpProductionApp(WidgetTester tester) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    addTearDown(() => appRouter.go('/market'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/trade');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Trade add opens the full-width reference order ticket', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    await pumpProductionApp(tester);

    await tester.tap(find.byKey(const Key('trade-add-button')));
    await tester.pumpAndSettle();

    final ticket = find.byKey(const Key('trade-add-order-ticket'));
    expect(ticket, findsOneWidget);
    final ticketRect = tester.getRect(ticket);
    expect(ticketRect.left, 0);
    expect(ticketRect.width, closeTo(590 / 1.5, .01));
    expect(find.byType(MtBottomNavigationBar), findsNothing);

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('-5'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);

    final typeRow = find.byKey(const Key('order-type-field'));
    final quoteStrip = find.byKey(const Key('order-quote-strip'));
    expect(tester.getRect(typeRow).left, 0);
    expect(tester.getRect(typeRow).width, closeTo(590 / 1.5, .01));
    expect(tester.getRect(quoteStrip).left, 0);
    expect(tester.getRect(quoteStrip).width, closeTo(590 / 1.5, .01));

    final backRect = tester.getRect(find.byKey(const Key('order-back-button')));
    expect(backRect.left, closeTo(17.3333333333, .75));
    expect(backRect.width, 40);

    final titleRect = tester.getRect(
      find.byKey(const Key('order-header-title')),
    );
    expect(titleRect.center.dx, closeTo((590 / 1.5) / 2, .75));

    final stopLossDecrease = tester.getRect(
      find.byKey(const Key('order-sl-decrease')),
    );
    final stopLossIncrease = tester.getRect(
      find.byKey(const Key('order-sl-increase')),
    );
    expect(stopLossDecrease.center.dx, closeTo(288.5 / 1.5, .75));
    expect(stopLossIncrease.center.dx, closeTo(564.5 / 1.5, .75));

    final prices = tester
        .widgetList<Text>(
          find.descendant(of: quoteStrip, matching: find.byType(Text)),
        )
        .toList(growable: false);
    expect(prices, hasLength(2));
    expect(
      prices.map((price) => price.style?.color),
      everyElement(const Color(0xFF007FFF)),
    );

    final sell = tester.widget<Material>(
      find.byKey(const Key('order-market-sell')),
    );
    final buy = tester.widget<Material>(
      find.byKey(const Key('order-market-buy')),
    );
    expect(sell.color, const Color(0xFFDD5E4F));
    expect(buy.color, const Color(0xFF4A92F4));

    expect(find.text('Vao lenh thi truong'), findsOneWidget);
    final typeText = tester.widget<Text>(find.text('Vao lenh thi truong'));
    expect(typeText.style?.fontFamily, 'sans-serif');
    expect(find.text('Cat lo'), findsOneWidget);
    expect(find.text('Chot loi'), findsOneWidget);
    expect(find.text('khong cai dat'), findsNWidgets(2));
    expect(find.text('Vào lệnh thị trường'), findsNothing);
    expect(find.text('Cắt lỗ'), findsNothing);
    expect(find.text('Chốt lời'), findsNothing);
    expect(find.text('không cài đặt'), findsNothing);
    expect(
      find.text(
        'Chú ý !!! Giao dịch được thực thi ở các điều kiện thị trường, '
        'có thể có sự khác biệt về giá so với giá yêu cầu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('regular order route opens the full-width reference ticket', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    await pumpProductionApp(tester);

    appRouter.go('/order?symbol=XAUUSD%2B');
    await tester.pumpAndSettle();

    final ticket = find.byKey(const Key('regular-order-ticket'));
    expect(ticket, findsOneWidget);
    expect(tester.getRect(ticket).left, 0);
    expect(tester.getRect(ticket).width, closeTo(590 / 1.5, .01));
    expect(find.byKey(const Key('trade-add-order-ticket')), findsNothing);
    expect(find.byType(MtBottomNavigationBar), findsNothing);
  });

  testWidgets('regular order quotes emphasize their final two digits', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NewOrderScreen(symbol: 'XAUUSD+'),
        ),
      ),
    );
    await tester.pump();

    final prices = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('order-quote-strip')),
            matching: find.byType(Text),
          ),
        )
        .toList(growable: false);
    expect(prices, hasLength(2));
    expect(prices[0].style?.color, AppColors.tradeNegative);
    expect(prices[1].style?.color, AppColors.primary);
    for (final price in prices) {
      expect(price.textSpan, isNotNull);
      final spans = (price.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans, hasLength(2));
      expect(spans.first.style?.fontSize, 20.5);
      expect(spans.first.style?.fontWeight, FontWeight.w600);
      expect(spans.last.style?.fontSize, 26.5);
      expect(spans.last.style?.fontWeight, FontWeight.w700);
    }
  });

  testWidgets('regular order ticket defaults volume to 0.01', (tester) async {
    useLdPlayerViewport(tester);
    await pumpProductionApp(tester);

    appRouter.go('/order?symbol=XAUUSD%2B');
    await tester.pumpAndSettle();

    expect(find.text('-0.5'), findsOneWidget);
    expect(find.text('-0.1'), findsOneWidget);
    expect(find.text('0.01'), findsOneWidget);
    expect(find.text('+0.1'), findsOneWidget);
    expect(find.text('+0.5'), findsOneWidget);
  });

  testWidgets(
    'close ticket uses the approved typography and equal market buttons',
    (tester) async {
      useLdPlayerViewport(tester);
      final container = createVideoReferenceContainer(
        overrides: [
          demoPositionsProvider.overrideWithValue(const [
            DemoPosition(
              id: 'reference-close-position',
              symbol: 'XAUUSD',
              side: 'BUY',
              volume: .01,
              openPrice: 4467.92,
              currentPrice: 4434.08,
              profit: -33.84,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const NewOrderScreen(
              symbol: 'XAUUSD',
              closePositionId: 'reference-close-position',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('-0.5'), findsOneWidget);
      expect(find.text('-0.1'), findsOneWidget);
      expect(find.text('+0.1'), findsOneWidget);
      expect(find.text('+0.5'), findsOneWidget);
      for (final label in ['-0.5', '-0.1', '+0.1', '+0.5']) {
        final stepLabel = tester.widget<Text>(find.text(label));
        expect(stepLabel.style?.color, AppColors.orderTicketQuote);
        expect(stepLabel.style?.fontSize, 14.5);
        expect(stepLabel.style?.fontWeight, FontWeight.w600);
      }

      expect(find.text('Vao lenh thi truong'), findsOneWidget);
      final orderType = tester.widget<Text>(find.text('Vao lenh thi truong'));
      expect(orderType.style?.fontSize, 15);
      expect(orderType.style?.color, AppColors.textPrimary);

      final stopLoss = tester.widget<Text>(find.text('Cat lo'));
      expect(stopLoss.style?.fontSize, 14.5);
      expect(stopLoss.style?.color, AppColors.textSecondary);
      expect(find.text('Chot loi'), findsOneWidget);

      final unsetValues = tester.widgetList<Text>(find.text('khong cai dat'));
      expect(unsetValues, hasLength(2));
      expect(
        unsetValues.map((text) => text.style?.fontSize),
        everyElement(14.5),
      );
      expect(
        unsetValues.map((text) => text.style?.color),
        everyElement(const Color(0xFFC7C7C7)),
      );

      final quoteStrip = find.byKey(const Key('order-quote-strip'));
      expect(tester.getSize(quoteStrip).height, 55);
      final prices = tester
          .widgetList<Text>(
            find.descendant(of: quoteStrip, matching: find.byType(Text)),
          )
          .toList(growable: false);
      expect(prices, hasLength(2));
      expect(
        prices.map((text) => text.textSpan?.toPlainText()),
        orderedEquals(['4104.09', '4104.22']),
      );
      expect(
        prices.map((text) => text.style?.color),
        everyElement(AppColors.textPrimary),
      );
      final bidSpans = (prices[0].textSpan! as TextSpan).children!
          .cast<TextSpan>();
      final askSpans = (prices[1].textSpan! as TextSpan).children!
          .cast<TextSpan>();
      expect(bidSpans.map((span) => span.text), ['4104.', '09']);
      expect(askSpans.map((span) => span.text), ['4104.', '22']);
      for (final spans in [bidSpans, askSpans]) {
        expect(spans.first.style?.fontSize, 20.5);
        expect(spans.first.style?.fontWeight, FontWeight.w600);
        expect(spans.last.style?.fontSize, 26.5);
        expect(spans.last.style?.fontWeight, FontWeight.w700);
      }

      final sell = find.byKey(const Key('order-market-sell'));
      final buy = find.byKey(const Key('order-market-buy'));
      final sellRect = tester.getRect(sell);
      final buyRect = tester.getRect(buy);
      expect(sellRect.height, 39);
      expect(buyRect.height, sellRect.height);
      expect(buyRect.width, closeTo(sellRect.width, .01));
      expect(buyRect.top, sellRect.top);
      expect(buyRect.bottom, sellRect.bottom);

      final sellText = tester.widget<Text>(find.text('Sell by Market'));
      final buyText = tester.widget<Text>(find.text('Buy by Market'));
      expect(sellText.style?.fontSize, 16);
      expect(buyText.style?.fontSize, sellText.style?.fontSize);
      expect(sellText.style?.fontWeight, FontWeight.w400);
      expect(buyText.style?.fontWeight, sellText.style?.fontWeight);

      final closeBanner = tester.widget<Text>(find.textContaining('Đóng #'));
      expect(closeBanner.style?.fontSize, 14);
      expect(closeBanner.style?.fontWeight, FontWeight.w400);
      expect(closeBanner.data, contains('ở Thị Trường với mức Lỗ'));

      final warning = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('order-market-warning')),
          matching: find.byType(Text),
        ),
      );
      expect(warning.style?.fontSize, 13.2);
      expect(warning.style?.color, AppColors.textSecondary);
      expect(warning.data, startsWith('Chú ý !!! Giao dịch'));
    },
  );

  testWidgets('Trade add opens the symbol at the top of the position list', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [
          DemoPosition(
            id: 'btc-position',
            symbol: 'BTCUSD',
            side: 'BUY',
            volume: .25,
            openPrice: 79900,
            currentPrice: 79910,
            profit: 2.5,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/trade',
      routes: [
        GoRoute(path: '/trade', builder: (_, _) => const TradeScreen()),
        GoRoute(
          path: '/order',
          builder: (_, state) => NewOrderScreen(
            symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
            tradeAddReferenceLayout:
                state.uri.queryParameters['source'] == 'trade-add',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('trade-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trade-add-order-ticket')), findsOneWidget);
    expect(find.text('BTCUSDT'), findsOneWidget);
    expect(find.text('Bitcoin vs US Dollar Tether'), findsOneWidget);
  });

  testWidgets(
    'Trade add prefers the active chart symbol over the first open position',
    (tester) async {
      useLdPlayerViewport(tester);
      final container = createVideoReferenceContainer(
        overrides: [
          chartViewSessionSeedProvider.overrideWithValue(
            ChartViewSessionState(activeSymbol: 'BTCUSD'),
          ),
          demoPositionsProvider.overrideWithValue(const [
            DemoPosition(
              id: 'closed-market-position',
              symbol: 'XAUUSD',
              side: 'BUY',
              volume: .25,
              openPrice: 4430,
              currentPrice: 4430,
              profit: 0,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/trade',
        routes: [
          GoRoute(path: '/trade', builder: (_, _) => const TradeScreen()),
          GoRoute(
            path: '/order',
            builder: (_, state) => NewOrderScreen(
              symbol: state.uri.queryParameters['symbol'] ?? 'XAUUSD+',
              tradeAddReferenceLayout:
                  state.uri.queryParameters['source'] == 'trade-add',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('trade-add-button')));
      await tester.pumpAndSettle();

      expect(find.text('BTCUSDT'), findsOneWidget);
      expect(find.text('Bitcoin vs US Dollar Tether'), findsOneWidget);
      expect(find.text('XAUUSD'), findsNothing);
      expect(find.text('0.01'), findsOneWidget);
      expect(find.text('0.25'), findsNothing);
      expect(find.text('1.00'), findsNothing);
    },
  );

  testWidgets('BTC close ticket synchronizes both header lines', (
    tester,
  ) async {
    useLdPlayerViewport(tester);
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [
          DemoPosition(
            id: 'btc-close-position',
            symbol: 'BTCUSD',
            side: 'BUY',
            volume: .25,
            openPrice: 79666.91,
            currentPrice: 79732.73,
            profit: 16.46,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NewOrderScreen(
            symbol: 'BTCUSD',
            closePositionId: 'btc-close-position',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BTCUSDT'), findsOneWidget);
    expect(find.text('Bitcoin vs US Dollar Tether'), findsOneWidget);
    expect(find.text('BTCUSD'), findsNothing);
    expect(find.text('Bitcoin'), findsNothing);
    expect(find.text('0.01'), findsOneWidget);
    expect(find.text('0.25'), findsNothing);
    expect(find.textContaining('buy 0.01 ở Thị Trường'), findsOneWidget);
  });
}
