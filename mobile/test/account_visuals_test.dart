import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';

void main() {
  testWidgets('account toolbar glyph ink matches the measured references', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              RepaintBoundary(
                key: const Key('account-back-reference-capture'),
                child: AccountRoundBackButton(onTap: () {}),
              ),
              RepaintBoundary(
                key: const Key('account-add-reference-capture'),
                child: AccountRoundAddButton(onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );

    final back = await _darkInkMetrics(
      tester,
      'account-back-reference-capture',
    );
    final add = await _darkInkMetrics(tester, 'account-add-reference-capture');
    expect(back.bounds, const Rect.fromLTWH(15, 13, 10, 18));
    expect(back.pixels, inInclusiveRange(58, 65));

    expect(add.bounds, const Rect.fromLTWH(13, 13, 17, 17));
    expect(add.pixels, inInclusiveRange(82, 92));
  });

  testWidgets('account visuals keep the reference sizes and hit targets', (
    tester,
  ) async {
    var backTaps = 0;
    var addTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const AccountBrokerMark(brand: DemoBrokerBrand.exness),
              AccountRoundBackButton(onTap: () => backTaps++),
              AccountRoundAddButton(onTap: () => addTaps++),
              const AccountChevronRight(),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
    expect(find.text('exness'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('account-round-back-button'))),
      const Size.square(43),
    );
    expect(
      tester.getSize(find.byKey(const Key('account-round-add-button'))),
      const Size.square(43),
    );
    expect(
      tester.getSize(find.byKey(const Key('account-chevron-glyph'))),
      const Size(10, 14),
    );

    await tester.tap(find.byKey(const Key('account-round-back-button')));
    await tester.tap(find.byKey(const Key('account-round-add-button')));

    expect(backTaps, 1);
    expect(addTaps, 1);
  });

  testWidgets('unknown broker does not render an Exness wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccountBrokerMark(brand: DemoBrokerBrand.unknown)),
      ),
    );

    expect(find.text('exness'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
  });

  testWidgets('technical YODO broker uses a neutral yellow mark without text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AccountBrokerMark(brand: DemoBrokerBrand.yodo)),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('account-broker-mark'))),
      const Size.square(31),
    );
    expect(find.text('yodo'), findsNothing);
    expect(find.text('exness'), findsNothing);
    final mark = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const Key('account-broker-mark')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(mark.color, const Color(0xFFFFE500));
  });

  testWidgets(
    'MetaQuotes broker uses the reference raster instead of bank icon',
    (tester) async {
      final metaquotesBrand = DemoBrokerBrand.values.firstWhere(
        (brand) => brand.name == 'metaquotes',
        orElse: () => DemoBrokerBrand.unknown,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountBrokerMark(brand: metaquotesBrand)),
        ),
      );

      expect(
        find.byKey(const Key('metaquotes-broker-mark-raster')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.account_balance_outlined), findsNothing);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('metaquotes-broker-mark-raster')),
          matching: find.byType(Image),
        ),
      );
      expect(
        image.image,
        const AssetImage('assets/images/metatrader5_splash.png'),
      );
    },
  );

  testWidgets('hero broker marks scale every brand to 60 pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AccountBrokerMark(
                key: Key('hero-vantage-mark'),
                brand: DemoBrokerBrand.vantage,
                size: 60,
              ),
              AccountBrokerMark(
                key: Key('hero-unknown-mark'),
                brand: DemoBrokerBrand.unknown,
                size: 60,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('hero-vantage-mark'))),
      const Size.square(60),
    );
    expect(
      tester.getSize(find.byKey(const Key('hero-unknown-mark'))),
      const Size.square(60),
    );
    final unknownIcon = tester.widget<Icon>(find.byType(Icon));
    expect(unknownIcon.size, 34.8);
  });
}

Future<({Rect bounds, int pixels})> _darkInkMetrics(
  WidgetTester tester,
  String boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(ValueKey(boundaryKey)),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read icon pixels for $boundaryKey');
  }

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  var pixels = 0;
  for (var y = 0; y < captured.height; y++) {
    for (var x = 0; x < captured.width; x++) {
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      final alpha = captured.bytes!.getUint8(offset + 3);
      if (alpha < 128) continue;
      if ((red + green + blue) / 3 >= 100) continue;
      pixels++;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No dark icon ink found for $boundaryKey');
  }
  return (
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ),
    pixels: pixels,
  );
}
