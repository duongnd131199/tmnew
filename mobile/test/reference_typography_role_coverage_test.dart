import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

import 'test_support/legacy_typography_geometry_snapshots.dart';
import 'test_support/reference_font_lock.dart';

void main() {
  test('the measured reference typography profile ships by default', () {
    expect(defaultTypographyProfile, TypographyProfile.reference);
  });

  test('every semantic role has one metrics-only locked token', () {
    expect(
      AppTypography.referenceTokens.keys.toSet(),
      ReferenceTextRole.values.toSet(),
    );

    final lock = ReferenceFontLock.current;
    final lockedTokens = <String, ReferenceTextToken>{
      for (final entry in AppTypography.referenceTokens.entries)
        entry.key.name: entry.value,
      for (final entry in AppTypography.referenceVariantOverrides.entries)
        entry.key.toString(): entry.value,
    };
    for (final MapEntry(key: role, value: token) in lockedTokens.entries) {
      final face = lock.bySha(token.faceSha256);
      final style = token.style;
      final requestedWeight = (style.fontWeight ?? FontWeight.w400).value;

      expect(style.color, isNull, reason: role);
      expect(style.fontFamilyFallback, isNull, reason: role);
      expect(style.fontFamily, face.flutterFamily, reason: role);
      if (face.axes.isEmpty) {
        expect(face.os2WeightClass, requestedWeight, reason: role);
        expect(
          style.fontVariations ?? const <FontVariation>[],
          isEmpty,
          reason: role,
        );
        expect(<int>{400, 700}, contains(requestedWeight), reason: role);
      } else {
        final weightAxis = face.axes.singleWhere((axis) => axis.tag == 'wght');
        expect(style.fontVariations, <FontVariation>[
          FontVariation('wght', requestedWeight.toDouble()),
        ], reason: role);
        expect(
          requestedWeight,
          inInclusiveRange(weightAxis.minimum, weightAxis.maximum),
          reason: role,
        );
      }
      expect(_axis(style, 'wdth'), isNull, reason: role);
    }
  });

  test('requested Settings and Chart roles lock complete metrics', () {
    expect(
      AppTypography
          .referenceTokens[ReferenceTextRole.settingsAccountMetaMultiline]!
          .style,
      AppTypography.settingsAccountMetaMultiline,
    );
    expect(AppTypography.settingsAccountMetaMultiline.height, 1.5);

    expect(AppTypography.settingsNotificationBadge.fontSize, 14);
    expect(AppTypography.settingsNotificationBadge.fontWeight, FontWeight.w700);
    expect(AppTypography.settingsNotificationBadge.height, 1);

    expect(AppTypography.chartDialogTimeframe.fontSize, 13);
    expect(AppTypography.chartDialogTimeframe.fontWeight, FontWeight.w700);
    expect(AppTypography.chartDialogTimeframe.letterSpacing, -1.2);
    expect(AppTypography.chartDialogTimeframe.height, 1);

    expect(AppTypography.chartTimeframeHint.fontSize, 14.3);
    expect(AppTypography.chartTimeframeHint.fontWeight, FontWeight.w400);
    expect(AppTypography.chartTimeframeHint.letterSpacing, -1.2);
    expect(AppTypography.chartTimeframeHint.height, 1.49);

    expect(AppTypography.chartOneClickVolume.fontSize, 16.5);
    expect(AppTypography.chartOneClickVolume.fontWeight, FontWeight.w700);
    expect(AppTypography.chartOneClickVolume.letterSpacing, -1.2);
    expect(AppTypography.chartOneClickVolume.height, 1);
    expect(AppTypography.chartOneClickVolume.fontFeatures, const <FontFeature>[
      FontFeature.tabularFigures(),
    ]);
  });

  test('semantic colors and geometry are complete and independent', () {
    expect(
      ReferenceTextColors.reference.keys.toSet(),
      ReferenceTextColorRole.values.toSet(),
    );
    expect(
      AppTypography.referenceGeometry.keys.toSet(),
      ReferenceTextRole.values.toSet(),
    );
    for (final geometry in AppTypography.referenceGeometry.values) {
      expect(geometry, const TypographyTextGeometry());
    }
  });

  test('History status and Chart plot use their source-locked RGBs', () {
    final decoded =
        jsonDecode(
              File(
                '../docs/screens/reference-typography-color-lock.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final roles = decoded['colorRoles']! as List<dynamic>;

    List<int> lockedRgb(String roleId, {String variantId = 'light'}) {
      final role = roles.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['colorRoleId'] == roleId,
      );
      final variants = role['variants']! as List<dynamic>;
      final variant = variants.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['variantId'] == variantId,
      );
      final consensus = variant['consensus']! as Map<String, dynamic>;
      return (consensus['rgb']! as List<dynamic>).cast<int>();
    }

    expect(lockedRgb('historyStatus'), <int>[41, 68, 118]);
    expect(lockedRgb('chartPlot'), <int>[61, 135, 234]);
    expect(lockedRgb('secondary', variantId: 'light.settingsRows'), <int>[
      142,
      142,
      142,
    ]);
    expect(AppColors.historyOrderStatus, const Color(0xFF294476));
    expect(AppColors.chartPlotTitleBlue, const Color(0xFF3D87EA));
    expect(AppColors.settingsRowSecondary, const Color(0xFF8E8E8E));
    expect(
      ReferenceTextColors.reference[ReferenceTextColorRole.historyStatus],
      const Color(0xFF294476),
    );
    expect(
      ReferenceTextColors.reference[ReferenceTextColorRole.chartPlot],
      const Color(0xFF3D87EA),
    );
    expect(AppColors.historyOrderStatus, isNot(AppColors.historyPositiveText));
    expect(AppColors.chartPlotTitleBlue, isNot(AppColors.primary));
  });

  test('iOS and Android share reference metrics, variants and colors', () {
    expect(
      AppTypography.referenceTokensFor(TargetPlatform.iOS),
      AppTypography.referenceTokensFor(TargetPlatform.android),
    );
    expect(
      AppTypography.referenceVariantOverridesFor(TargetPlatform.iOS),
      AppTypography.referenceVariantOverridesFor(TargetPlatform.android),
    );
    expect(
      ReferenceTextColors.referenceFor(TargetPlatform.iOS),
      ReferenceTextColors.referenceFor(TargetPlatform.android),
    );
    expect(
      ReferenceTextColors.referenceVariantOverridesFor(TargetPlatform.iOS),
      ReferenceTextColors.referenceVariantOverridesFor(TargetPlatform.android),
    );
  });

  test(
    'legacy manifest captures and resolves every declared style variant',
    () {
      final geometrySnapshots =
          <
            (
              ReferenceTextRole,
              TypographyVariantId,
              TargetPlatform,
              Brightness,
            ),
            LegacyTypographyGeometrySnapshot
          >{
            for (final snapshot in legacyTypographyGeometrySnapshots)
              (
                snapshot.metricRole,
                snapshot.variant,
                snapshot.platform,
                snapshot.brightness,
              ): snapshot,
          };
      expect(
        geometrySnapshots.length,
        legacyTypographyGeometrySnapshots.length,
        reason: 'Independent geometry snapshot keys must be unique.',
      );
      expect(
        legacyTypographyGeometrySnapshots
            .map((snapshot) => snapshot.styleKey)
            .toSet(),
        AppTypography.legacyGeometry.keys.toSet(),
      );
      expect(legacyTypographyCallsiteManifest, isNotEmpty);
      expect(
        legacyTypographyCallsiteManifest.map((item) => item.styleKey).toSet(),
        AppTypography.legacyTokens.keys.toSet(),
      );
      for (final callsite in legacyTypographyCallsiteManifest) {
        final resolved = resolveLegacyTypography(
          role: callsite.metricRole,
          colorRole: callsite.colorRole,
          variant: callsite.variant,
          platform: callsite.platform,
          brightness: callsite.brightness,
        );
        expect(
          resolved.styleSnapshot,
          callsite.currentStyleSnapshot,
          reason: callsite.id,
        );
        final geometrySnapshot =
            geometrySnapshots[(
              callsite.metricRole,
              callsite.variant,
              callsite.platform,
              callsite.brightness,
            )];
        expect(geometrySnapshot, isNotNull, reason: callsite.id);
        expect(
          resolved.geometry,
          geometrySnapshot!.geometry,
          reason: callsite.id,
        );
        expect(resolved.color, callsite.currentColor, reason: callsite.id);
      }
      expect(
        legacyTypographyCallsiteManifest.map((item) => item.platform).toSet(),
        <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS},
      );
      expect(
        legacyTypographyCallsiteManifest.map((item) => item.brightness).toSet(),
        <Brightness>{Brightness.light},
      );
      final capturedVariants = legacyTypographyCallsiteManifest
          .map((item) => item.variant)
          .toSet();
      expect(
        capturedVariants,
        containsAll(<TypographyVariantId>[
          TypographyVariantId.quoteXau,
          TypographyVariantId.quoteBtc,
          TypographyVariantId.quoteOther,
          TypographyVariantId.historyPositions,
          TypographyVariantId.historyOrders,
          TypographyVariantId.historyDeals,
          TypographyVariantId.historyBalance,
          TypographyVariantId.chartTicketBuy,
          TypographyVariantId.chartTicketSell,
        ]),
      );
    },
  );

  test('legacy semantic resolver retains role-specific current colors', () {
    expect(
      AppTypography.legacyColorForRole(
        ReferenceTextRole.settingsRowSubtitle,
        ReferenceTextColorRole.secondary,
      ),
      AppColors.settingsRowSecondary,
    );
    expect(
      AppTypography.legacyColorForRole(
        ReferenceTextRole.quoteMeta,
        ReferenceTextColorRole.secondary,
      ),
      AppColors.pricesSecondary,
    );
    expect(
      AppTypography.legacyColorForRole(
        ReferenceTextRole.historySecondary,
        ReferenceTextColorRole.secondary,
      ),
      AppColors.tradingSecondaryText,
    );
  });

  test('reference Settings subtitle variants resolve the measured gray', () {
    final settingsRowVariants = TypographyVariantId.all.where(
      (variant) => variant.value.startsWith('settings.row.'),
    );

    expect(settingsRowVariants, isNotEmpty);
    for (final variant in settingsRowVariants) {
      expect(
        ReferenceTextColors.resolveReference(
          ReferenceTextColorRole.secondary,
          variant: variant,
        ),
        AppColors.settingsRowSecondary,
        reason: variant.value,
      );
    }
  });

  test(
    'legacy resolver rejects undeclared variants instead of falling back',
    () {
      expect(
        () => resolveLegacyTypography(
          role: ReferenceTextRole.settingsRowTitle,
          colorRole: ReferenceTextColorRole.primary,
          variant: const TypographyVariantId('missing'),
          platform: TargetPlatform.android,
          brightness: Brightness.light,
        ),
        throwsStateError,
      );
      expect(
        () => resolveLegacyTypography(
          role: ReferenceTextRole.settingsRowTitle,
          colorRole: ReferenceTextColorRole.primary,
          variant: TypographyVariantId.base,
          platform: TargetPlatform.android,
          brightness: Brightness.dark,
        ),
        throwsStateError,
      );
    },
  );

  testWidgets('forRole composes profile metrics with semantic color', (
    tester,
  ) async {
    late TextStyle referenceStyle;
    await tester.pumpWidget(
      MaterialApp(
        theme: withTypographyProfile(
          ThemeData(platform: TargetPlatform.iOS),
          TypographyProfile.reference,
        ),
        home: Builder(
          builder: (context) {
            referenceStyle = AppTypography.forRole(
              context,
              ReferenceTextRole.settingsNotificationBadge,
              colorRole: ReferenceTextColorRole.white,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(referenceStyle.color, Colors.white);
    expect(referenceStyle.fontWeight, FontWeight.w700);
    expect(referenceStyle.fontVariations, isNull);
  });

  testWidgets('forRole resolves the measured dark Trade semantic colors', (
    tester,
  ) async {
    late TextStyle primary;
    late TextStyle secondary;
    late TextStyle action;
    late TextStyle positive;
    await tester.pumpWidget(
      MaterialApp(
        theme: withTypographyProfile(
          ThemeData.dark(useMaterial3: true),
          TypographyProfile.reference,
        ),
        home: Builder(
          builder: (context) {
            primary = AppTypography.forRole(
              context,
              ReferenceTextRole.tradeMetricLabel,
              colorRole: ReferenceTextColorRole.primary,
            );
            secondary = AppTypography.forRole(
              context,
              ReferenceTextRole.tradePositionSecondary,
              colorRole: ReferenceTextColorRole.secondary,
            );
            action = AppTypography.forRole(
              context,
              ReferenceTextRole.tradePositionSide,
              colorRole: ReferenceTextColorRole.blueAction,
            );
            positive = AppTypography.forRole(
              context,
              ReferenceTextRole.tradePositionProfit,
              colorRole: ReferenceTextColorRole.positive,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(primary.color, const Color(0xFFEEEEEE));
    expect(secondary.color, const Color(0xFF969696));
    expect(action.color, const Color(0xFF0678F0));
    expect(positive.color, const Color(0xFF007CFF));
  });

  testWidgets(
    'reference tab scope is neutral while explicit legacy is scoped',
    (tester) async {
      const inherited = TextStyle(
        fontFamily: 'ParentSentinel',
        fontWeight: FontWeight.w300,
        fontVariations: <FontVariation>[FontVariation('slnt', -10)],
      );

      Future<TextStyle> pump(TypographyProfile profile) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: withTypographyProfile(ThemeData(), profile),
            themeAnimationDuration: Duration.zero,
            home: const DefaultTextStyle(
              style: inherited,
              child: MtTabTextScope(
                child: Text('probe', key: Key('profile-scope-probe')),
              ),
            ),
          ),
        );
        return DefaultTextStyle.of(
          tester.element(find.byKey(const Key('profile-scope-probe'))),
        ).style;
      }

      expect(await pump(TypographyProfile.reference), inherited);
      final legacy = await pump(TypographyProfile.legacy);
      expect(legacy.fontFamily, AppTypography.tabCondensedFamily);
      expect(_axis(legacy, 'wdth'), AppTypography.tabWidth);
    },
  );

  test('ticket side variants are explicit metric overrides', () {
    const buyKey = TypographyStyleKey(
      ReferenceTextRole.chartTicketLabel,
      TypographyVariantId.chartTicketBuy,
    );
    const sellKey = TypographyStyleKey(
      ReferenceTextRole.chartTicketLabel,
      TypographyVariantId.chartTicketSell,
    );
    expect(
      AppTypography.referenceVariantOverrides[buyKey]!.style.letterSpacing,
      1.2,
    );
    expect(
      AppTypography.referenceVariantOverrides[sellKey]!.style.letterSpacing,
      .42,
    );
  });
}

double? _axis(TextStyle style, String name) {
  for (final variation in style.fontVariations ?? const <FontVariation>[]) {
    if (variation.axis == name) return variation.value;
  }
  return null;
}
