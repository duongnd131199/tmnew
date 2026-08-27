import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, Tristate;

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
  Rect.fromLTWH(51, 786, 18, 16),
  Rect.fromLTWH(122, 786, 13, 16),
  Rect.fromLTWH(187, 784, 19, 19),
  Rect.fromLTWH(254, 785, 20, 18),
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

    expect(capsule.color, const Color(0xFFFFFFFF));
    expect(capsule.border, isNull);
    expect(selectedPill.color, const Color(0xFFEDEDED));
    expect(
      _painterColor(tester, 'bottom-nav-icon-chart'),
      const Color(0xFF000000),
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

    expect(bounds, const Rect.fromLTWH(254, 785, 20, 18));
    expect(
      bounds.width - bounds.height,
      lessThanOrEqualTo(2),
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

  testWidgets('navigation exposes five equal semantic interaction targets', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await _pumpNavigation(tester, selectedIndex: 2);

    final targetRects = <Rect>[];
    for (final kind in <String>[
      'quotes',
      'chart',
      'trade',
      'history',
      'settings',
    ]) {
      final target = find.byKey(ValueKey('bottom-nav-target-$kind'));
      expect(target, findsOneWidget);
      targetRects.add(tester.getRect(target));
    }

    expect(
      targetRects.every(
        (rect) => (rect.width - targetRects.first.width).abs() < 1e-9,
      ),
      isTrue,
    );
    expect(
      targetRects.every(
        (rect) => (rect.height - targetRects.first.height).abs() < 1e-9,
      ),
      isTrue,
    );
    expect(targetRects.every((rect) => rect.width >= 48), isTrue);
    expect(targetRects.every((rect) => rect.height >= 48), isTrue);

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('bottom-nav-target-trade')),
    );
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);
    for (final kind in <String>['quotes', 'chart', 'history', 'settings']) {
      expect(
        tester
            .getSemantics(find.byKey(ValueKey('bottom-nav-target-$kind')))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
        reason: kind,
      );
    }
    semanticsHandle.dispose();
  });

  testWidgets('selection changes nav ink without scaling label geometry', (
    tester,
  ) async {
    Size? referenceSize;
    for (var selected = 0; selected < 5; selected++) {
      await _pumpNavigation(
        tester,
        selectedIndex: selected,
        surfaceSize: const Size(393.3333333333, 853.3333333333),
      );
      final label = find.byKey(const ValueKey('bottom-nav-label-quotes'));
      final text = tester.widget<Text>(label);
      expect(text.style?.fontFamily, AppTypography.tabPlainFamily);
      expect(text.style?.fontSize, 9.5);
      expect(text.style?.height, 1);
      final transform = tester
          .renderObject<RenderBox>(label)
          .getTransformTo(null);
      expect(transform.storage[0], closeTo(1, .0001));
      final rect = tester.getRect(label);
      referenceSize ??= rect.size;
      expect(rect.size, referenceSize);
    }
  });

  testWidgets('iOS selected navigation label keeps the accent optical weight', (
    tester,
  ) async {
    await _pumpNavigation(
      tester,
      selectedIndex: 3,
      platform: TargetPlatform.iOS,
    );

    final selected = tester.widget<Text>(
      find.byKey(const ValueKey('bottom-nav-label-history')),
    );
    expect(_variableWeight(selected.style), 400);
  });

  testWidgets('unselected History label keeps its measured reference width', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 0);
    final unselected = tester.widget<Text>(
      find.byKey(const ValueKey('bottom-nav-label-history')),
    );
    expect(unselected.style?.letterSpacing, .4);

    await _pumpNavigation(tester, selectedIndex: 3);
    final selected = tester.widget<Text>(
      find.byKey(const ValueKey('bottom-nav-label-history')),
    );
    expect(selected.style?.letterSpacing, .5);
  });

  testWidgets('navigation labels use measured per-tab optical weights', (
    tester,
  ) async {
    const expectedUnselected = <String, double>{
      'quotes': 325,
      'chart': 342,
      'trade': 350,
      'history': 313,
      'settings': 329,
    };
    const expectedSelected = <String, double>{
      'quotes': 300,
      'chart': 281,
      'trade': 288,
      'history': 280,
      'settings': 350,
    };
    final kinds = expectedUnselected.keys.toList(growable: false);
    for (var selectedIndex = 0; selectedIndex < kinds.length; selectedIndex++) {
      await _pumpNavigation(tester, selectedIndex: selectedIndex);
      for (var index = 0; index < kinds.length; index++) {
        final kind = kinds[index];
        final label = tester.widget<Text>(
          find.byKey(ValueKey('bottom-nav-label-$kind')),
        );
        expect(
          _variableWeight(label.style),
          index == selectedIndex
              ? expectedSelected[kind]
              : expectedUnselected[kind],
          reason: 'selected=$selectedIndex kind=$kind',
        );
      }
    }
  });
}

Future<void> _pumpNavigation(
  WidgetTester tester, {
  required int selectedIndex,
  DemoAccountSnapshot account = _positiveAccount,
  Size surfaceSize = const Size(384, 848),
  ValueChanged<int>? onTap,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [demoAccountProvider.overrideWithValue(account)],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        debugShowCheckedModeBanner: false,
        home: _NavigationHarness(selectedIndex: selectedIndex, onTap: onTap),
      ),
    ),
  );
  await tester.pump();
}

double? _variableWeight(TextStyle? style) {
  final weights = style?.fontVariations
      ?.where((variation) => variation.axis == 'wght')
      .toList();
  if (weights == null || weights.isEmpty) return null;
  expect(weights, hasLength(1));
  return weights.single.value;
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
