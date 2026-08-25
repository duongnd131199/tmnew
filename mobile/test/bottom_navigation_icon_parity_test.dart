import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/load_test_fonts.dart';

const _positiveAccount = DemoAccountSnapshot(
  balance: 100000,
  equity: 100246,
  margin: 0,
  freeMargin: 100246,
  marginLevel: 0,
  profit: 246,
);

const _negativeAccount = DemoAccountSnapshot(
  balance: 100000,
  equity: 99910,
  margin: 0,
  freeMargin: 99910,
  marginLevel: 0,
  profit: -90,
);

const _iconSearchRects = <Rect>[
  Rect.fromLTWH(36, 780, 48, 28),
  Rect.fromLTWH(102, 780, 48, 28),
  Rect.fromLTWH(169, 780, 48, 28),
  Rect.fromLTWH(236, 780, 48, 28),
];

const _referenceBounds = <Rect>[
  Rect.fromLTWH(52, 790, 18, 16),
  Rect.fromLTWH(122, 790, 13, 16),
  Rect.fromLTWH(187, 789, 20, 18),
  Rect.fromLTWH(255, 789, 20, 19),
];

void main() {
  setUpAll(loadMt5TestFonts);

  testWidgets('navigation renders the measured video palette and no border', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 0);

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .toList(growable: false);
    final capsule = decorations.singleWhere(
      (decoration) => decoration.color == AppColors.navigationSurface,
    );
    final selectedPill = decorations.singleWhere(
      (decoration) => decoration.color == AppColors.navigationSelectedSurface,
    );

    expect(capsule.color, const Color(0xFFFDFDFD));
    expect(capsule.border, isNull);
    expect(selectedPill.color, const Color(0xFFE8E8E8));
    expect(
      _painterColor(tester, 'bottom-nav-icon-chart'),
      const Color(0xFF303030),
    );
  });

  testWidgets('four unselected icon contours match measured video bounds', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 4);

    final actualBounds = <Rect>[];
    for (final searchRect in _iconSearchRects) {
      actualBounds.add(await _darkInkBounds(tester, searchRect));
    }

    expect(actualBounds, _referenceBounds);
  });

  testWidgets('history clock keeps the reference circular silhouette', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 4);

    final bounds = await _darkInkBounds(tester, _iconSearchRects[3]);

    expect(bounds, const Rect.fromLTWH(255, 789, 20, 19));
    expect(
      bounds.width - bounds.height,
      lessThanOrEqualTo(1),
      reason: 'The clock arc must not be compressed into a horizontal oval.',
    );
  });

  testWidgets('Trade selection keeps the recorded profit color behavior', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 2, account: _positiveAccount);
    expect(_painterColor(tester, 'bottom-nav-icon-trade'), AppColors.primary);

    await _pumpNavigation(tester, selectedIndex: 2, account: _negativeAccount);
    expect(_painterColor(tester, 'bottom-nav-icon-trade'), AppColors.negative);
  });

  testWidgets('requested selected states match approved video goldens', (
    tester,
  ) async {
    for (final state in <(int, String)>[
      (0, 'quotes'),
      (1, 'chart'),
      (2, 'trade'),
      (3, 'history'),
    ]) {
      await _pumpNavigation(tester, selectedIndex: state.$1);
      await expectLater(
        find.byKey(const Key('bottom-navigation-icon-golden')),
        matchesGoldenFile('goldens/navigation/${state.$2}-384x848.png'),
      );
    }
  });

  testWidgets('navigation remains responsive and tappable at target widths', (
    tester,
  ) async {
    const labels = <String>[
      'Gia',
      'Bieu do',
      'Giao dich',
      'Lich su',
      'Cai dat',
    ];
    for (final width in <double>[360, 384, 393, 430]) {
      var tappedIndex = -1;
      await _pumpNavigation(
        tester,
        selectedIndex: 0,
        surfaceSize: Size(width, 848),
        onTap: (index) => tappedIndex = index,
      );

      expect(tester.takeException(), isNull, reason: 'width=$width');
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.text(labels[index]));
        await tester.pump();
        expect(
          tappedIndex,
          index,
          reason: 'width=$width label=${labels[index]}',
        );
      }
    }
  });

  testWidgets('selection changes nav ink without scaling label geometry', (
    tester,
  ) async {
    Rect? referenceRect;
    for (var selected = 0; selected < 5; selected++) {
      await _pumpNavigation(
        tester,
        selectedIndex: selected,
        surfaceSize: const Size(393.3333333333, 853.3333333333),
      );
      final label = find.byKey(const ValueKey('bottom-nav-label-quotes'));
      final text = tester.widget<Text>(label);
      expect(text.style?.fontFamily, AppTypography.plainFamily);
      expect(text.style?.fontSize, 9.5);
      expect(text.style?.height, 1);
      final transform = tester
          .renderObject<RenderBox>(label)
          .getTransformTo(null);
      expect(transform.storage[0], closeTo(1, .0001));
      final rect = tester.getRect(label);
      referenceRect ??= rect;
      expect(rect, referenceRect);
    }
  });
}

Future<void> _pumpNavigation(
  WidgetTester tester, {
  required int selectedIndex,
  DemoAccountSnapshot account = _positiveAccount,
  Size surfaceSize = const Size(384, 848),
  ValueChanged<int>? onTap,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [demoAccountProvider.overrideWithValue(account)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _NavigationHarness(selectedIndex: selectedIndex, onTap: onTap),
      ),
    ),
  );
  await tester.pump();
}

Color _painterColor(WidgetTester tester, String key) {
  final paint = tester.widget<CustomPaint>(find.byKey(ValueKey(key)));
  return (paint.painter! as dynamic).color as Color;
}

Future<Rect> _darkInkBounds(WidgetTester tester, Rect searchRect) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('bottom-navigation-icon-golden')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, height: image.height, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read navigation pixels');
  }
  final bytes = captured.bytes!;

  var minX = captured.width;
  var minY = captured.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = searchRect.top.toInt(); y < searchRect.bottom.toInt(); y++) {
    for (var x = searchRect.left.toInt(); x < searchRect.right.toInt(); x++) {
      final offset = (y * captured.width + x) * 4;
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      if ((red + green + blue) / 3 >= 160) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('Unselected icon ink was not found in $searchRect');
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

class _NavigationHarness extends StatelessWidget {
  const _NavigationHarness({required this.selectedIndex, this.onTap});

  final int selectedIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('bottom-navigation-icon-golden'),
      child: Material(
        color: Colors.white,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: MtBottomNavigationBar(
            selectedIndex: selectedIndex,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
  }
}
