import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/order/presentation/screens/new_order_screen.dart';
import 'package:trading_mobile/features/trade/presentation/screens/position_detail_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/load_test_fonts.dart';
import 'test_support/video_reference_fixtures.dart';

const _iphone17Size = Size(402, 874);
const _referenceWidth = 590 / 1.5;
const _position = DemoPosition(
  id: '58308513468',
  symbol: 'XAUUSD',
  side: 'BUY',
  volume: .01,
  openPrice: 4410.25,
  currentPrice: 4410.68,
  profit: -57.67,
);

void _useIphone17Viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _host(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(
          size: _iphone17Size,
          devicePixelRatio: 3,
          padding: EdgeInsets.only(top: 24),
          viewPadding: EdgeInsets.only(top: 24),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _loadSystemSansTestFont() async {
  final loader = FontLoader('sans-serif')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  await loader.load();
}

void main() {
  final referenceScale = _iphone17Size.width / _referenceWidth;
  setUpAll(() async {
    await loadMt5TestFonts();
    await _loadSystemSansTestFont();
  });

  testWidgets('close ticket preserves reference block sizes on iPhone 17', (
    tester,
  ) async {
    _useIphone17Viewport(tester);
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [_position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container,
        const NewOrderScreen(symbol: 'XAUUSD', closePositionId: '58308513468'),
      ),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(const Key('order-back-button'))).width,
      closeTo(40 * referenceScale, .01),
    );
    expect(
      tester.getRect(find.byKey(const Key('order-type-field'))).height,
      closeTo(41 * referenceScale, .01),
    );
    expect(find.byKey(const Key('order-type-control-divider')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('order-quote-strip'))).height,
      closeTo(55 * referenceScale, .01),
    );
    final marketButton = tester.getRect(
      find.byKey(const Key('order-market-sell')),
    );
    final closeBanner = tester.getRect(
      find.byKey(const Key('order-close-position')),
    );
    expect(marketButton.height, closeTo(39 * referenceScale, .01));
    expect(
      closeBanner.top - marketButton.bottom,
      closeTo(4 * referenceScale, .02),
    );
    expect(closeBanner.height, closeTo(38 * referenceScale, .01));
  });

  testWidgets('position modify preserves reference block sizes on iPhone 17', (
    tester,
  ) async {
    _useIphone17Viewport(tester);
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [_position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, const PositionDetailScreen(positionId: '58308513468')),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byIcon(CupertinoIcons.chevron_left)).width,
      closeTo(40 * referenceScale, .01),
    );
    final actionField = tester.getRect(
      find.byKey(const Key('position-action-field')),
    );
    final quoteStrip = tester.getRect(
      find.byKey(const Key('position-detail-quote-strip')),
    );
    expect(actionField.height, closeTo(41 * referenceScale, .01));
    expect(
      quoteStrip.top - actionField.bottom,
      closeTo((1.3333333333 + 36.3333333333 * 2) * referenceScale, .02),
    );
    expect(
      find.byKey(const Key('position-detail-control-divider')),
      findsOneWidget,
    );
    expect(quoteStrip.height, closeTo(55 * referenceScale, .01));
    expect(
      tester.getRect(find.byType(FilledButton)).height,
      closeTo(38 * referenceScale, .01),
    );
  });

  testWidgets('short wide viewports keep the original unscaled layout', (
    tester,
  ) async {
    final container = createVideoReferenceContainer(
      overrides: [
        demoPositionsProvider.overrideWithValue(const [_position]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container,
        const NewOrderScreen(symbol: 'XAUUSD', closePositionId: '58308513468'),
      ),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(const Key('order-close-position'))).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
  });
}
