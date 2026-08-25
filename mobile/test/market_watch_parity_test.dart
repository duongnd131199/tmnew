import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/market_watch/presentation/screens/market_watch_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  Future<ProviderContainer> pumpMarket(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = container ?? createVideoReferenceContainer();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(384, 848),
              padding: EdgeInsets.only(top: 24),
            ),
            child: RepaintBoundary(
              key: Key('market-icon-reference-capture'),
              child: MarketWatchScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return scope;
  }

  testWidgets('Quotes toolbar icon ink matches the measured references', (
    tester,
  ) async {
    await pumpMarket(tester);

    final list = await _buttonInkMetrics(
      tester,
      const Key('market-toggle-view'),
    );
    final edit = await _buttonInkMetrics(
      tester,
      const Key('market-manage-button'),
    );
    final search = await _buttonInkMetrics(
      tester,
      const Key('market-search-button'),
    );

    expect(list.bounds, const Rect.fromLTWH(14, 14, 15, 13));
    expect(list.pixels, inInclusiveRange(70, 100));
    expect(edit.bounds, const Rect.fromLTWH(13, 13, 16, 16));
    expect(edit.pixels, inInclusiveRange(50, 75));
    expect(search.bounds, const Rect.fromLTWH(11, 11, 20, 20));
    expect(search.pixels, inInclusiveRange(75, 105));
  });

  double rowOffset(WidgetTester tester, String symbol) {
    final row = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(symbol),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return row.transform?.storage[12] ?? 0;
  }

  testWidgets('header and split-price typography match the video geometry', (
    tester,
  ) async {
    await pumpMarket(tester);

    final toggleRect = tester.getRect(
      find.byKey(const Key('market-toggle-view')),
    );
    final manageRect = tester.getRect(
      find.byKey(const Key('market-manage-button')),
    );
    final searchRect = tester.getRect(
      find.byKey(const Key('market-search-button')),
    );

    expect(toggleRect.left, closeTo(15.3, .1));
    expect(toggleRect.top, closeTo(61.3666666667, .1));
    expect(toggleRect.width, closeTo(42.6666666667, .01));
    expect(toggleRect.height, closeTo(42.6666666667, .01));
    expect(manageRect.left, closeTo(274.6333333333, .1));
    expect(manageRect.top, closeTo(61.3666666667, .1));
    expect(searchRect.left, closeTo(328.0333333333, .1));
    expect(searchRect.top, closeTo(61.3666666667, .1));

    final headerTitle = tester.widget<Text>(find.text('Gia'));
    expect(headerTitle.style?.fontFamily, 'sans-serif');
    expect(headerTitle.style?.fontSize, 20.5);
    final dailyChange = tester.widget<Text>(
      find.byKey(const ValueKey('market-change-XAUUSD+')),
    );
    expect(dailyChange.style?.fontFamily, 'sans-serif-condensed');
    expect(dailyChange.style?.fontSize, 17);
    final symbol = tester.widget<Text>(find.text('XAUUSD'));
    expect(symbol.style?.fontFamily, 'sans-serif-condensed');
    expect(symbol.style?.fontSize, 18);
    final tickTime = tester.widget<Text>(
      find.byKey(const ValueKey('market-time-XAUUSD+')),
    );
    expect(tickTime.style?.fontFamily, 'sans-serif-condensed');
    expect(tickTime.style?.fontSize, 17);

    final xauBid = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-XAUUSD+')),
    );
    final bidSpans = (xauBid.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .toList();
    expect(bidSpans[0].text, '4104.');
    expect(bidSpans[0].style?.fontSize, 18.5);
    expect(bidSpans[1].text, '09');
    expect(bidSpans[1].style?.fontSize, 29);

    final btcBid = tester.widget<Text>(
      find.byKey(const ValueKey('market-bid-BTCUSD')),
    );
    final btcSpans = (btcBid.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .toList();
    expect(btcSpans[0].text, '65175.');
    expect(btcSpans[1].text, '98');

    await tester.tap(find.text('XAUUSD'));
    await tester.pumpAndSettle();
    final menuRect = tester.getRect(
      find.byKey(const ValueKey('market-symbol-menu-XAUUSD+')),
    );
    final firstAction = find.byKey(const Key('market-menu-first-action'));
    final firstActionRect = tester.getRect(firstAction);
    expect(firstActionRect.top - menuRect.top, closeTo(69.3, 1));
    final actionMaterial = find
        .descendant(of: firstAction, matching: find.byType(Material))
        .first;
    expect(tester.getSize(actionMaterial).height, 47);
  });

  testWidgets(
    'quote row follows drag, resists overscroll and snaps by threshold',
    (tester) async {
      await pumpMarket(tester);

      final xau = find.text('XAUUSD');
      final xauRowY = tester.getCenter(xau).dy;
      final drag = await tester.startGesture(Offset(180, xauRowY));
      await drag.moveBy(const Offset(-35, 0));
      await tester.pump();
      expect(rowOffset(tester, 'XAUUSD'), lessThan(-1));
      expect(rowOffset(tester, 'XAUUSD'), greaterThan(-80));
      expect(rowOffset(tester, 'XAUUSD'), isNot(-123));
      await drag.moveBy(const Offset(-45, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), -142);

      expect(
        find.byKey(const ValueKey('market-order-XAUUSD+')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('market-chart-XAUUSD+')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('market-delete-XAUUSD+')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('market-order-XAUUSD+'))),
        const Size(48, 48),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('market-order-XAUUSD+'))).left,
        closeTo(253, .1),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('market-chart-XAUUSD+'))).left,
        closeTo(329, .1),
      );

      final rebound = await tester.startGesture(Offset(180, xauRowY));
      await rebound.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await rebound.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), -142);

      final close = await tester.startGesture(Offset(180, xauRowY));
      await close.moveBy(const Offset(95, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await close.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), 0);

      final elastic = await tester.startGesture(Offset(180, xauRowY));
      await elastic.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(rowOffset(tester, 'XAUUSD'), greaterThan(0));
      expect(rowOffset(tester, 'XAUUSD'), lessThanOrEqualTo(24));
      await elastic.up();
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'XAUUSD'), 0);

      await tester.drag(find.text('BTCUSD'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(rowOffset(tester, 'BTCUSD'), -117);
      expect(find.byKey(const ValueKey('market-order-BTCUSD')), findsNothing);
      expect(
        find.byKey(const ValueKey('market-delete-BTCUSD')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('market-chart-BTCUSD')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('market-chart-BTCUSD'))),
        const Size(48, 48),
      );
      expect(rowOffset(tester, 'XAUUSD'), 0);
    },
  );

  testWidgets('tick drives time, spread and price color but not daily color', (
    tester,
  ) async {
    final controllers = <String, StreamController<DemoQuote>>{
      'XAUUSD+': StreamController<DemoQuote>.broadcast(),
      'BTCUSD': StreamController<DemoQuote>.broadcast(),
    };
    addTearDown(() async {
      for (final controller in controllers.values) {
        await controller.close();
      }
    });
    final container = createVideoReferenceContainer(
      overrides: [
        demoQuoteProvider.overrideWith(
          (ref, symbol) => controllers[symbol]!.stream,
        ),
      ],
    );
    await pumpMarket(tester, container: container);

    final initialTime = tester.widget<Text>(
      find.byKey(const ValueKey('market-time-XAUUSD+')),
    );
    expect(initialTime.data, isNot('05:23:45'));
    expect(initialTime.data, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-spread-XAUUSD+')))
          .data,
      '13',
    );

    controllers['XAUUSD+']!.add(
      const DemoQuote(
        symbol: 'XAUUSD+',
        name: 'Gold US Dollar',
        bid: 4104.10,
        ask: 4104.21,
        changePercent: -1.24,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-spread-XAUUSD+')))
          .data,
      '11',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-bid-XAUUSD+')))
          .style
          ?.color,
      AppColors.primary,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('market-ask-XAUUSD+')))
          .style
          ?.color,
      AppColors.negative,
    );
    final dailyChange = tester.widget<Text>(
      find.byKey(const ValueKey('market-change-XAUUSD+')),
    );
    final dailySpans = (dailyChange.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .toList();
    expect(dailySpans[1].style?.color, AppColors.primary);
    expect(dailyChange.textSpan!.toPlainText(), contains('1.26%'));
  });
}

Future<({Rect bounds, int pixels})> _buttonInkMetrics(
  WidgetTester tester,
  Key buttonKey,
) async {
  final buttonRect = tester.getRect(find.byKey(buttonKey));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('market-icon-reference-capture')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read Quotes toolbar pixels');
  }

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  var pixels = 0;
  for (var y = buttonRect.top.floor(); y < buttonRect.bottom.ceil(); y++) {
    for (var x = buttonRect.left.floor(); x < buttonRect.right.ceil(); x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128 || (red + green + blue) / 3 >= 100) continue;
      pixels++;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No dark icon ink found for $buttonKey');
  }
  final origin = Offset(
    buttonRect.left.floorToDouble(),
    buttonRect.top.floorToDouble(),
  );
  return (
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ).shift(-origin),
    pixels: pixels,
  );
}
