import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/reference_font_loader.dart';

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
  Rect.fromLTWH(255, 785, 18, 18),
];

void main() {
  setUpAll(loadReferenceFonts);

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

  testWidgets('navigation exposes the exact Vietnamese labels', (tester) async {
    await _pumpNavigation(tester, selectedIndex: 0);

    const expectedLabels = <String, String>{
      'quotes': 'Gia',
      'chart': 'Bieu do',
      'trade': 'Giao dich',
      'history': 'Lich su',
      'settings': 'Cai dat',
    };
    for (final entry in expectedLabels.entries) {
      final label = find.byKey(ValueKey('bottom-nav-label-${entry.key}'));
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).data, entry.value);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(ValueKey('bottom-nav-target-${entry.key}')),
            )
            .properties
            .label,
        entry.value,
      );
    }
  });

  testWidgets('dark navigation uses the measured dark Trade palette', (
    tester,
  ) async {
    await _pumpNavigation(
      tester,
      selectedIndex: 2,
      brightness: Brightness.dark,
      typographyProfile: TypographyProfile.reference,
    );

    final decorationColors = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>()
        .toList(growable: false);
    expect(decorationColors, contains(const Color(0xFF181818)));
    expect(decorationColors, contains(const Color(0xFF313131)));

    for (final kind in <String>['quotes', 'chart', 'history', 'settings']) {
      expect(
        _painterColor(tester, 'bottom-nav-icon-$kind'),
        const Color(0xFFFDFDFD),
        reason: kind,
      );
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('bottom-nav-label-$kind')))
            .style
            ?.color,
        const Color(0xFFFDFDFD),
        reason: kind,
      );
    }

    final fade = tester.widget<DecoratedBox>(
      find.byKey(const Key('bottom-navigation-content-fade')),
    );
    final gradient = (fade.decoration as BoxDecoration).gradient!;
    expect(gradient.colors, <Color>[
      const Color(0xFF000000).withValues(alpha: 0),
      const Color(0xFF000000).withValues(alpha: .80),
      const Color(0xFF000000).withValues(alpha: .88),
    ]);
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

    expect(bounds, const Rect.fromLTWH(255, 785, 18, 18));
    expect(
      bounds.width - bounds.height,
      lessThanOrEqualTo(2),
      reason: 'The clock arc must not be compressed into a horizontal oval.',
    );
  });

  testWidgets('history clock hands keep the approved compact reach', (
    tester,
  ) async {
    await _pumpNavigation(tester, selectedIndex: 4);

    final innerHandInk = await _darkInkBounds(
      tester,
      const Rect.fromLTRB(262, 789, 267, 797),
    );

    expect(
      innerHandInk.top,
      790,
      reason: 'The minute hand should sit slightly inside the clock ring.',
    );
  });

  testWidgets('selected Settings gear matches the supplied reference ink', (
    tester,
  ) async {
    await _pumpNavigation(
      tester,
      selectedIndex: 4,
      surfaceSize: const Size(393.3333333333, 853.3333333333),
    );

    final bounds = await _darkInkBounds(
      tester,
      const Rect.fromLTWH(315, 780, 40, 34),
    );

    expect(bounds, const Rect.fromLTWH(324, 790, 18, 18));
  });

  testWidgets('unselected Settings gear exposes the eight reference teeth', (
    tester,
  ) async {
    await _pumpNavigation(
      tester,
      selectedIndex: 3,
      surfaceSize: const Size(393.3333333333, 853.3333333333),
    );

    final toothCount = await _ellipticalDarkInkRunCount(
      tester,
      center: const Offset(332.5, 799),
      innerRadius: 6.75,
      outerRadius: 7,
      scaleX: 1,
      scaleY: 1,
    );

    expect(toothCount, 8);
  });

  testWidgets(
    'Chart Trade History and Settings soften content crossing the menu',
    (tester) async {
      for (var selectedIndex = 0; selectedIndex < 5; selectedIndex++) {
        await _pumpNavigation(tester, selectedIndex: selectedIndex);
        final fade = find.byKey(const Key('bottom-navigation-content-fade'));
        if (selectedIndex == 0) {
          expect(fade, findsNothing);
          continue;
        }

        expect(fade, findsOneWidget, reason: 'selected=$selectedIndex');
        final box = tester.widget<DecoratedBox>(fade);
        final gradient =
            (box.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
        expect(gradient.stops, const <double>[0, .28, 1]);
        expect(gradient.colors, <Color>[
          AppColors.background.withValues(alpha: 0),
          AppColors.background.withValues(alpha: .80),
          AppColors.background.withValues(alpha: .88),
        ]);
      }
    },
  );

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
      (4, 'settings'),
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
      expect(text.style?.fontFamily, AppTypography.referencePlainFamily);
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

  testWidgets('iOS selected navigation label keeps the locked static face', (
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
    expect(selected.style?.fontWeight, FontWeight.w400);
    expect(selected.style?.fontVariations, isNull);
  });

  testWidgets('navigation labels resolve their explicit semantic variants', (
    tester,
  ) async {
    const cases =
        <
          ({
            String kind,
            TypographyVariantId selectedVariant,
            TypographyVariantId unselectedVariant,
            double selectedTracking,
          })
        >[
          (
            kind: 'quotes',
            selectedVariant: TypographyVariantId.navigationQuotesSelected,
            unselectedVariant: TypographyVariantId.navigationQuotesUnselected,
            selectedTracking: .4,
          ),
          (
            kind: 'chart',
            selectedVariant: TypographyVariantId.navigationChartSelected,
            unselectedVariant: TypographyVariantId.navigationChartUnselected,
            selectedTracking: .5,
          ),
          (
            kind: 'trade',
            selectedVariant: TypographyVariantId.navigationTradeSelected,
            unselectedVariant: TypographyVariantId.navigationTradeUnselected,
            selectedTracking: .5,
          ),
          (
            kind: 'history',
            selectedVariant: TypographyVariantId.navigationHistorySelected,
            unselectedVariant: TypographyVariantId.navigationHistoryUnselected,
            selectedTracking: .5,
          ),
          (
            kind: 'settings',
            selectedVariant: TypographyVariantId.navigationSettingsSelected,
            unselectedVariant: TypographyVariantId.navigationSettingsUnselected,
            selectedTracking: .3,
          ),
        ];

    for (final profile in TypographyProfile.values) {
      for (
        var selectedIndex = 0;
        selectedIndex < cases.length;
        selectedIndex++
      ) {
        await _pumpNavigation(
          tester,
          selectedIndex: selectedIndex,
          typographyProfile: profile,
        );
        for (var index = 0; index < cases.length; index++) {
          final navigationCase = cases[index];
          final selected = index == selectedIndex;
          final labelFinder = find.byKey(
            ValueKey('bottom-nav-label-${navigationCase.kind}'),
          );
          final label = tester.widget<Text>(labelFinder);
          final semanticStyle = AppTypography.forRole(
            tester.element(labelFinder),
            ReferenceTextRole.navigationLabel,
            colorRole: selected
                ? ReferenceTextColorRole.navigationSelected
                : ReferenceTextColorRole.navigationUnselected,
            variant: selected
                ? navigationCase.selectedVariant
                : navigationCase.unselectedVariant,
          );
          final expectedTracking = selected
              ? navigationCase.selectedTracking
              : .4;

          expect(
            label.style,
            semanticStyle,
            reason:
                'profile=${profile.name} selected=$selectedIndex '
                'kind=${navigationCase.kind}',
          );
          expect(label.style?.letterSpacing, expectedTracking);
          expect(label.style?.fontFamily, AppTypography.referencePlainFamily);
          expect(label.style?.fontWeight, FontWeight.w400);
          expect(label.style?.fontVariations, isNull);
        }
      }
    }
  });

  testWidgets('navigation label offsets are isolated to the legacy profile', (
    tester,
  ) async {
    const kinds = <String>['quotes', 'chart', 'trade', 'history', 'settings'];

    for (var selectedIndex = 0; selectedIndex < kinds.length; selectedIndex++) {
      for (final profile in TypographyProfile.values) {
        await _pumpNavigation(
          tester,
          selectedIndex: selectedIndex,
          typographyProfile: profile,
        );
        for (var index = 0; index < kinds.length; index++) {
          final legacyOffset = switch ((index, index == selectedIndex)) {
            (0, true) => const Offset(.6666666667, 0),
            (2, true) => const Offset(0, .6666666667),
            (3, _) || (4, _) => const Offset(-.6666666667, 0),
            _ => Offset.zero,
          };
          final expected = profile == TypographyProfile.legacy
              ? legacyOffset
              : Offset.zero;
          final actual = _ancestorTranslation(
            tester,
            find.byKey(ValueKey('bottom-nav-label-${kinds[index]}')),
          );
          expect(
            actual.dx,
            closeTo(expected.dx, .0001),
            reason:
                'profile=${profile.name} selected=$selectedIndex '
                'kind=${kinds[index]} dx',
          );
          expect(
            actual.dy,
            closeTo(expected.dy, .0001),
            reason:
                'profile=${profile.name} selected=$selectedIndex '
                'kind=${kinds[index]} dy',
          );
        }
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
  TypographyProfile? typographyProfile,
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [demoAccountProvider.overrideWithValue(account)],
      child: MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: typographyProfile == null
            ? ThemeData(platform: platform, brightness: brightness)
            : withTypographyProfile(
                ThemeData(platform: platform, brightness: brightness),
                typographyProfile,
              ),
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

Offset _ancestorTranslation(WidgetTester tester, Finder finder) {
  var offset = Offset.zero;
  for (final transform in tester.widgetList<Transform>(
    find.ancestor(of: finder, matching: find.byType(Transform)),
  )) {
    offset += Offset(
      transform.transform.storage[12],
      transform.transform.storage[13],
    );
  }
  return offset;
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

Future<int> _ellipticalDarkInkRunCount(
  WidgetTester tester, {
  required Offset center,
  required double innerRadius,
  required double outerRadius,
  required double scaleX,
  required double scaleY,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('bottom-navigation-icon-golden')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
    final result = (width: image.width, bytes: bytes);
    image.dispose();
    return result;
  });
  if (captured == null || captured.bytes == null) {
    throw StateError('Unable to read navigation pixels');
  }

  const sampleCount = 720;
  final samples = <bool>[];
  for (var index = 0; index < sampleCount; index++) {
    final angle = -math.pi / 2 + index * math.pi * 2 / sampleCount;
    var hasInk = false;
    for (var radius = innerRadius; radius <= outerRadius; radius += .25) {
      final x = ((center.dx + math.cos(angle) * radius * scaleX) * 4).round();
      final y = ((center.dy + math.sin(angle) * radius * scaleY) * 4).round();
      final offset = (y * captured.width + x) * 4;
      final red = captured.bytes!.getUint8(offset);
      final green = captured.bytes!.getUint8(offset + 1);
      final blue = captured.bytes!.getUint8(offset + 2);
      if ((red + green + blue) / 3 < 205) {
        hasInk = true;
        break;
      }
    }
    samples.add(hasInk);
  }

  var runs = 0;
  for (var index = 0; index < samples.length; index++) {
    final previous = samples[(index + samples.length - 1) % samples.length];
    if (samples[index] && !previous) runs++;
  }
  return runs;
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
