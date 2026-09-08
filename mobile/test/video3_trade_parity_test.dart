import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/trade_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt5_toolbar_icons.dart';

import 'test_support/load_test_fonts.dart';

const _videoPosition = DemoPosition(
  id: '58308513468',
  symbol: 'XAUUSD',
  side: 'BUY',
  volume: .01,
  openPrice: 4467.92,
  currentPrice: 4434.08,
  profit: -33.84,
);

DemoTradingState _video3Seed(String accountId) => const DemoTradingState(
  balance: 101684.09,
  positions: [
    _videoPosition,
    DemoPosition(
      id: '58308513469',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .01,
      openPrice: 4467.92,
      currentPrice: 4434.08,
      profit: -33.84,
    ),
    DemoPosition(
      id: '58308513470',
      symbol: 'XAUUSD',
      side: 'BUY',
      volume: .01,
      openPrice: 4467.92,
      currentPrice: 4434.08,
      profit: -33.84,
    ),
    DemoPosition(
      id: '58308513471',
      symbol: 'XAUUSD',
      side: 'SELL',
      volume: .01,
      openPrice: 4432.46,
      currentPrice: 4434.42,
      profit: -1.96,
    ),
    DemoPosition(
      id: '58308513472',
      symbol: 'XAUUSD',
      side: 'SELL',
      volume: .01,
      openPrice: 4434.36,
      currentPrice: 4434.42,
      profit: -.06,
    ),
  ],
  deals: [],
);

ProviderContainer _video3Container({
  Stream<DemoQuote> Function(String symbol)? quotes,
}) => ProviderContainer(
  overrides: [
    demoTradingSeedProvider.overrideWithValue(_video3Seed),
    demoQuoteProvider.overrideWith(
      (ref, symbol) => quotes?.call(symbol) ?? const Stream<DemoQuote>.empty(),
    ),
  ],
);

void _useVideoViewport(
  WidgetTester tester, {
  Size size = const Size(384, 848),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpTrade(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(384, 848),
}) async {
  _useVideoViewport(tester, size: size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 24),
          ),
          child: TradeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadMt5TestFonts);

  testWidgets('populated trade header keeps the wallet control', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    expect(find.byKey(const Key('trade-balance-button')), findsOneWidget);
    expect(find.byKey(const Key('trade-wallet-glyph')), findsOneWidget);
    expect(find.byKey(const Key('trade-account-metrics')), findsOneWidget);
  });

  testWidgets('position tap opens the compact floating action dialog', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    await tester.tap(find.byKey(const ValueKey('trade-position-58308513468')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final dialog = find.byKey(const Key('position-actions-dialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.text('Trạng thái: #58308513468\nXAUUSD buy 0.01'),
      findsOneWidget,
    );
    const labels = [
      'Đóng trạng thái',
      'Đóng bởi',
      'Sửa trạng thái',
      'Giao dịch',
      'Depth of Market',
      'Biểu đồ',
      'Hoạt động hàng loạt...',
      'Hủy',
    ];
    final tops = <double>[];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
      tops.add(tester.getTopLeft(find.text(label)).dy);
    }
    expect(tops, orderedEquals([...tops]..sort()));

    final rect = tester.getRect(dialog);
    expect(rect.left, closeTo(50, 2));
    expect(rect.right, closeTo(337, 2));
    expect(rect.height, closeTo(498, 4));
  });

  testWidgets(
    'position swipe matches the video geometry glyphs colors and text ink',
    (tester) async {
      final container = _video3Container();
      addTearDown(container.dispose);
      await _pumpTrade(tester, container);

      final row = find.byKey(const ValueKey('trade-position-58308513468'));
      await tester.drag(row, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final surface = find.byKey(
        const ValueKey('trade-position-surface-58308513468'),
      );
      expect(
        tester.widget<AnimatedContainer>(surface).transform!.storage[12],
        closeTo(-168, .01),
      );

      final menuAction = find.byKey(const ValueKey('trade-menu-58308513468'));
      final modifyAction = find.byKey(
        const ValueKey('trade-modify-58308513468'),
      );
      final closeAction = find.byKey(const ValueKey('trade-close-58308513468'));

      final rowRect = tester.getRect(row);
      final menuRect = tester.getRect(menuAction);
      final modifyRect = tester.getRect(modifyAction);
      final closeRect = tester.getRect(closeAction);
      for (final rect in [menuRect, modifyRect, closeRect]) {
        expect(rect.size, const Size.square(46));
        expect(rect.top - rowRect.top, closeTo(3, .01));
      }
      expect(menuRect.left, closeTo(225, .01));
      expect(modifyRect.left - menuRect.right, closeTo(8, .01));
      expect(closeRect.left - modifyRect.right, closeTo(8, .01));
      expect(384 - closeRect.right, closeTo(5, .01));

      final actions = <Finder, Color>{
        menuAction: const Color(0xFF929FB2),
        modifyAction: const Color(0xFF3F4BA1),
        closeAction: const Color(0xFFEB8305),
      };
      for (final entry in actions.entries) {
        expect(
          tester
              .widget<Material>(
                find.descendant(of: entry.key, matching: find.byType(Material)),
              )
              .color,
          entry.value,
        );
      }

      final menuIcon = tester.widget<Icon>(
        find.descendant(
          of: menuAction,
          matching: find.byIcon(CupertinoIcons.ellipsis),
        ),
      );
      expect(menuIcon.size, 22);
      final modifyIconFinder = find.descendant(
        of: modifyAction,
        matching: find.byType(MtToolbarIcon),
      );
      expect(modifyIconFinder, findsOneWidget);
      final modifyIcon = tester.widget<MtToolbarIcon>(modifyIconFinder);
      expect(modifyIcon.kind, MtToolbarIconKind.edit);
      expect(modifyIcon.size, 17);
      expect(modifyIcon.color, AppColors.tradeSwipeActionGlyph);
      final closeIcon = tester.widget<Icon>(
        find.descendant(
          of: closeAction,
          matching: find.byIcon(CupertinoIcons.check_mark_circled),
        ),
      );
      expect(closeIcon.size, 20);

      final primary = tester.widget<Text>(
        find.byKey(const ValueKey('trade-position-primary-58308513468')),
      );
      final spans = (primary.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
        spans.first.style?.fontFamily,
        AppTypography.referenceCondensedFamily,
      );
      expect(spans.first.style?.fontWeight, FontWeight.w700);
      expect(spans.last.style?.fontFamily, AppTypography.referencePlainFamily);
      expect(spans.last.style?.fontWeight, FontWeight.w700);
      final secondary = tester.widget<Text>(
        find.byKey(const ValueKey('trade-position-secondary-58308513468')),
      );
      expect(
        secondary.style?.fontFamily,
        AppTypography.referenceCondensedFamily,
      );
      expect(secondary.style?.fontSize, 16);
      expect(secondary.style?.fontWeight, FontWeight.w400);
      expect(secondary.style?.color, const Color(0xFF3C3C43));
    },
  );

  testWidgets('iPhone 17 normalizes Trade to the 384 pixel video width', (
    tester,
  ) async {
    const deviceSize = Size(402, 874);
    const videoWidth = 384.0;
    const scale = 402 / videoWidth;
    final container = _video3Container();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container, size: deviceSize);

    final row = find.byKey(const ValueKey('trade-position-58308513468'));
    await tester.drag(row, const Offset(-230, 0));
    await tester.pumpAndSettle();

    final menu = tester.getRect(
      find.byKey(const ValueKey('trade-menu-58308513468')),
    );
    final modify = tester.getRect(
      find.byKey(const ValueKey('trade-modify-58308513468')),
    );
    final close = tester.getRect(
      find.byKey(const ValueKey('trade-close-58308513468')),
    );

    expect(menu.left, closeTo(225 * scale, .02));
    expect(menu.width, closeTo(46 * scale, .02));
    expect(modify.left - menu.right, closeTo(8 * scale, .02));
    expect(close.left - modify.right, closeTo(8 * scale, .02));
    expect(deviceSize.width - close.right, closeTo(5 * scale, .02));
  });

  testWidgets('contextual bulk follows loss state and closes opposite pairs', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    await _pumpTrade(tester, container);

    await tester.tap(find.byKey(const ValueKey('trade-position-58308513468')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoạt động hàng loạt...'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng Các Lệnh Có Trạng Thái Đang Lỗ'), findsOneWidget);
    expect(find.text('Đóng Các Lệnh Có Trạng Thái Đang Có Lời'), findsNothing);
    final closeBy = find.byKey(
      const ValueKey('position-bulk-action-closeBySymbol'),
    );
    expect(find.text('Đóng bởi XAUUSD'), findsOneWidget);
    expect(closeBy, findsOneWidget);

    await tester.tap(closeBy);
    await tester.pumpAndSettle();

    expect(
      container.read(demoPositionsProvider).map((item) => item.id),
      orderedEquals(['58308513470']),
    );
  });

  testWidgets('position action field reveals the full video action list', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    _useVideoViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const PositionDetailScreen(positionId: '58308513468'),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('position-detail-lower-surface')),
          )
          .color,
      AppColors.orderTicketSurface,
    );

    await tester.tap(find.byKey(const Key('position-action-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('position-action-menu')), findsOneWidget);
    for (final label in const [
      'Vao lenh thi truong',
      'Buy Limit',
      'Sell Limit',
      'Buy Stop',
      'Sell Stop',
      'Buy Stop Limit',
      'Sell Stop Limit',
      'Sửa trạng thái',
      'Đóng bởi',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('position detail uses the approved order-ticket presentation', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    _useVideoViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const PositionDetailScreen(positionId: '58308513468'),
        ),
      ),
    );
    await tester.pump();

    final subtitle = tester.widget<Text>(find.text('Gold vs US Dollar'));
    expect(subtitle.style?.fontSize, 11.5);
    expect(subtitle.style?.color, AppColors.textSecondary);

    final symbolTitle = tester.widget<Text>(find.text('XAUUSD'));
    expect(symbolTitle.style?.fontWeight, FontWeight.w600);

    final actionField = find.byKey(const Key('position-action-field'));
    expect(tester.getSize(actionField).height, 41);
    final actionLabel = tester.widget<Text>(
      find.textContaining('#58308513468'),
    );
    expect(actionLabel.style?.fontSize, 15);
    expect(actionLabel.style?.fontWeight, FontWeight.w300);
    expect(actionLabel.style?.color, AppColors.textPrimary);

    expect(find.text('Cat lo'), findsOneWidget);
    final stopLoss = tester.widget<Text>(find.text('Cat lo'));
    final takeProfit = tester.widget<Text>(find.text('Chot loi'));
    expect(stopLoss.style?.fontSize, 14.5);
    expect(takeProfit.style?.fontSize, 14.5);
    expect(stopLoss.style?.color, AppColors.textSecondary);
    expect(takeProfit.style?.color, AppColors.textSecondary);

    final unsetValues = tester.widgetList<Text>(find.text('khong cai dat'));
    expect(unsetValues, hasLength(2));
    expect(unsetValues.map((text) => text.style?.fontSize), everyElement(14.5));
    expect(
      unsetValues.map((text) => text.style?.color),
      everyElement(const Color(0xFFC7C7C7)),
    );

    final quoteTexts = tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                ((widget.data ?? widget.textSpan?.toPlainText()) ==
                        '4434.080' ||
                    (widget.data ?? widget.textSpan?.toPlainText()) ==
                        '4434.204'),
          ),
        )
        .toList(growable: false);
    expect(quoteTexts, hasLength(2));
    expect(quoteTexts[0].style?.color, AppColors.tradeNegative);
    expect(quoteTexts[1].style?.color, AppColors.tradeNegative);
    expect(quoteTexts.map((text) => text.textSpan), everyElement(isNotNull));
    final bidSpans = (quoteTexts[0].textSpan! as TextSpan).children!
        .cast<TextSpan>();
    final askSpans = (quoteTexts[1].textSpan! as TextSpan).children!
        .cast<TextSpan>();
    expect(bidSpans.map((span) => span.text), ['4434.0', '80']);
    expect(askSpans.map((span) => span.text), ['4434.2', '04']);
    for (final spans in [bidSpans, askSpans]) {
      expect(spans.first.style?.fontSize, 20.5);
      expect(spans.first.style?.fontWeight, FontWeight.w600);
      expect(spans.last.style?.fontSize, 26.5);
      expect(spans.last.style?.fontWeight, FontWeight.w700);
    }

    final modify = find.byType(FilledButton);
    expect(tester.getSize(modify).height, 40);
    final modifyButton = tester.widget<FilledButton>(modify);
    const disabled = <WidgetState>{WidgetState.disabled};
    expect(
      modifyButton.style?.backgroundColor?.resolve(disabled),
      const Color(0xFFBEBEBE),
    );
    expect(
      modifyButton.style?.foregroundColor?.resolve(disabled),
      Colors.white,
    );
    expect(
      modifyButton.style?.side?.resolve(disabled),
      const BorderSide(color: Color(0xFFB2B2B2)),
    );
    final modifyText = tester.widget<Text>(find.text('Chinh sua'));
    expect(modifyText.style?.fontSize, 16);
    expect(modifyText.style?.fontWeight, FontWeight.w400);

    final warningFinder = find.descendant(
      of: find.byKey(const Key('position-detail-lower-surface')),
      matching: find.byType(Text),
    );
    final warning = tester.widget<Text>(warningFinder);
    expect(warning.style?.fontSize, 13.2);
    expect(warning.style?.color, AppColors.textSecondary);
    expect(
      warning.data,
      'Chot Loi/ Cat Lo phai duoc dat it nhat 0 điểm so voi gia thi\n'
      'truong. Qua trinh Chot Loi/ Cat Lo se duoc thuc hien boi\n'
      'broker.',
    );
    expect(warning.maxLines, 3);
    expect(warning.overflow, TextOverflow.clip);
    expect(
      tester.renderObject<RenderParagraph>(warningFinder).didExceedMaxLines,
      isFalse,
    );
    final warningParagraph = tester.renderObject<RenderParagraph>(
      warningFinder,
    );
    final lowerSurface = tester.renderObject<RenderBox>(
      find.byKey(const Key('position-detail-lower-surface')),
    );
    final paintedWarningBounds = MatrixUtils.transformRect(
      warningParagraph.getTransformTo(lowerSurface),
      Offset.zero & warningParagraph.size,
    );
    expect(paintedWarningBounds.height, closeTo(47.52, .5));
  });

  testWidgets('position detail moves both quote colors together with ticks', (
    tester,
  ) async {
    final quotes = StreamController<DemoQuote>();
    addTearDown(quotes.close);
    final container = _video3Container(quotes: (_) => quotes.stream);
    addTearDown(container.dispose);
    final paintBoundaryKey = GlobalKey();
    _useVideoViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: paintBoundaryKey,
            child: const PositionDetailScreen(positionId: '58308513468'),
          ),
        ),
      ),
    );
    await tester.pump();

    List<Text> quoteTexts() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('position-detail-quote-strip')),
            matching: find.byType(Text),
          ),
        )
        .toList(growable: false);

    Iterable<Color?> quoteColors() =>
        quoteTexts().map((text) => text.style?.color);

    Iterable<Color?> quoteRunColors() => quoteTexts().expand(
      (text) => (text.textSpan! as TextSpan).children!.cast<TextSpan>().map(
        (span) => span.style?.color,
      ),
    );

    quotes.add(
      const DemoQuote(
        symbol: 'XAUUSD',
        name: 'Gold US Dollar',
        bid: 4434,
        ask: 4434.4,
        changePercent: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(quoteTexts().map((text) => text.textSpan?.toPlainText()), [
      '4434.000',
      '4434.400',
    ]);
    expect(quoteColors(), everyElement(AppColors.tradeNegative));

    quotes.add(
      const DemoQuote(
        symbol: 'XAUUSD',
        name: 'Gold US Dollar',
        bid: 4434.2,
        ask: 4434.6,
        changePercent: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(quoteTexts().map((text) => text.textSpan?.toPlainText()), [
      '4434.200',
      '4434.600',
    ]);
    expect(quoteColors(), everyElement(AppColors.primary));

    quotes.add(
      const DemoQuote(
        symbol: 'XAUUSD',
        name: 'Gold US Dollar',
        bid: 4434.1,
        ask: 4434.5,
        changePercent: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(quoteTexts().map((text) => text.textSpan?.toPlainText()), [
      '4434.100',
      '4434.500',
    ]);
    expect(quoteColors(), everyElement(AppColors.tradeNegative));
    expect(quoteRunColors(), everyElement(AppColors.tradeNegative));

    final boundary =
        paintBoundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final firstQuote = tester.renderObject<RenderBox>(find.text('4434.100'));
    final firstQuoteTopLeft = firstQuote.localToGlobal(
      Offset.zero,
      ancestor: boundary,
    );
    final image = (await tester.runAsync(boundary.toImage))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    var redPixels = 0;
    var staleBluePixels = 0;
    for (
      var y = firstQuoteTopLeft.dy.floor();
      y < firstQuoteTopLeft.dy.ceil() + firstQuote.size.height.ceil();
      y++
    ) {
      for (
        var x = firstQuoteTopLeft.dx.floor();
        x < firstQuoteTopLeft.dx.ceil() + firstQuote.size.width.ceil();
        x++
      ) {
        final offset = (y * image.width + x) * 4;
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        if (red > 180 && green < 110 && blue < 110) redPixels++;
        if (blue > 150 && red < 100 && green < 170) staleBluePixels++;
      }
    }
    expect(redPixels, greaterThan(20));
    expect(staleBluePixels, 0);
  });

  testWidgets('detail tickets cap the iPhone 17 dynamic-island top inset', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    _useVideoViewport(tester);

    Widget host(Widget child) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(384, 848),
            padding: EdgeInsets.only(top: 62),
          ),
          child: child,
        ),
      ),
    );

    await tester.pumpWidget(
      host(const PositionDetailScreen(positionId: '58308513468')),
    );
    await tester.pump();
    final modifyBackIcon = tester.getRect(
      find.byIcon(CupertinoIcons.chevron_left),
    );
    expect(modifyBackIcon.left, closeTo(18, 1));
    expect(modifyBackIcon.top, closeTo(53, 1));

    await tester.pumpWidget(
      host(
        const NewOrderScreen(symbol: 'XAUUSD', closePositionId: '58308513468'),
      ),
    );
    await tester.pump();
    final closeBack = tester.getRect(
      find.byKey(const Key('order-back-button')),
    );
    expect(closeBack.left, closeTo(17.3333333333, 1));
    expect(closeBack.top, closeTo(53, 1));
  });

  testWidgets('close ticket stays full width without notices and completes', (
    tester,
  ) async {
    final container = _video3Container();
    addTearDown(container.dispose);
    _useVideoViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const NewOrderScreen(
            symbol: 'XAUUSD',
            closePositionId: '58308513468',
          ),
        ),
      ),
    );
    await tester.pump();

    final ticket = find.byKey(const Key('position-close-order-ticket'));
    expect(ticket, findsOneWidget);
    expect(tester.getRect(ticket).left, 0);
    expect(tester.getRect(ticket).width, 384);
    expect(find.text('-0.5'), findsOneWidget);
    expect(find.text('-0.1'), findsOneWidget);
    expect(find.text('+0.1'), findsOneWidget);
    expect(find.text('+0.5'), findsOneWidget);

    await tester.tap(find.text('Sell by Market'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Vui lòng chờ...'), findsNothing);
    expect(find.text('Lệnh đã được gửi đến server'), findsNothing);
    expect(find.byKey(const Key('order-type-field')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    expect(
      find.textContaining('market sell 0.01 XAUUSD at', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('hoan tat', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Fill or Kill', findRichText: true),
      findsNothing,
    );
    expect(
      container.read(demoPositionsProvider).map((item) => item.id),
      contains('58308513468'),
    );
    expect(container.read(demoPositionsProvider), hasLength(6));
  });

  testWidgets('close-ticket quotes refresh while staying reference black', (
    tester,
  ) async {
    final quotes = StreamController<DemoQuote>();
    addTearDown(quotes.close);
    final container = _video3Container(quotes: (_) => quotes.stream);
    addTearDown(container.dispose);
    _useVideoViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NewOrderScreen(
            symbol: 'XAUUSD',
            closePositionId: '58308513468',
          ),
        ),
      ),
    );
    await tester.pump();

    quotes.add(
      const DemoQuote(
        symbol: 'XAUUSD',
        name: 'Gold US Dollar',
        bid: 4434,
        ask: 4434.4,
        changePercent: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    quotes.add(
      const DemoQuote(
        symbol: 'XAUUSD',
        name: 'Gold US Dollar',
        bid: 4434.2,
        ask: 4434.3,
        changePercent: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    final quoteTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('order-quote-strip')),
            matching: find.byType(Text),
          ),
        )
        .toList(growable: false);
    expect(quoteTexts, hasLength(2));
    expect(
      quoteTexts.map((text) => text.data ?? text.textSpan?.toPlainText()),
      ['4434.20', '4434.30'],
    );
    expect(quoteTexts[0].style?.color, AppColors.textPrimary);
    expect(quoteTexts[1].style?.color, AppColors.textPrimary);
  });
}
