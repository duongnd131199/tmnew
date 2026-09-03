import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';
import 'package:trading_mobile/shared/widgets/mt5_settings_icons.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

void main() {
  testWidgets('settings matches the 590x1280 reference typography and rhythm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(393.3333333333, 853.3333333333),
              padding: EdgeInsets.only(top: 24),
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const Key('settings-account'))).dy,
      closeTo(104, .01),
    );
    expect(
      tester.getSize(find.byKey(const Key('settings-account'))).height,
      closeTo(93.3333333333, .01),
    );

    const expectedRowHeights = <String, double>{
      'Tai khoan moi': 45.3333333333,
      'Hop thu': 55.3333333333,
      'Tin tuc': 46,
      'Tradays': 54,
      'Trao doi va tin nhan': 54,
      'Cong dong trader': 46.6666666667,
      'MQL5 Algo Trading': 46,
      'OTP': 54,
      'Giao diện': 54,
      'Nhung bieu do': 45.3333333333,
      'Nhat ky': 45.3333333333,
      'Cai dat': 48,
    };
    for (final entry in expectedRowHeights.entries) {
      expect(
        tester.getSize(find.byKey(ValueKey('settings-${entry.key}'))).height,
        closeTo(entry.value, .01),
        reason: entry.key,
      );
    }

    final firstTitle = tester.widget<Text>(find.text('Tai khoan moi'));
    final firstSubtitle = tester.widget<Text>(
      find.text('Bạn đã đăng ký tài khoản mới - Demo-Live-01'),
    );
    expect(firstTitle.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(
      firstTitle.style?.fontSize,
      15,
      reason:
          'The lossless Settings source measures the first row title at '
          '141x17 physical pixels; the former 16px token rendered 153x18.',
    );
    expect(firstTitle.style?.fontWeight, FontWeight.w400);
    expect(firstTitle.style?.fontVariations, isNull);
    expect(firstSubtitle.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(firstSubtitle.style?.fontSize, 14);
    expect(firstSubtitle.style?.fontVariations, isNull);
    expect(
      firstSubtitle.style?.color,
      const Color(0xFF8E8E8E),
      reason: 'The source-locked Settings subtitle composite is #8E8E8E.',
    );
    expect(find.text('Australian Dollar: RBA keeps hik...'), findsNothing);

    final accountNameOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const Key('settings-account-name')),
        matching: find.byType(Opacity),
      ),
    );
    final accountCompanyOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const Key('settings-account-company')),
        matching: find.byType(Opacity),
      ),
    );
    expect(accountNameOpacity.opacity, 1);
    expect(accountCompanyOpacity.opacity, 1);
    final accountName = tester.widget<Text>(
      find.byKey(const Key('settings-account-name')),
    );
    final accountCompany = tester.widget<Text>(
      find.byKey(const Key('settings-account-company')),
    );
    expect(accountName.style?.fontWeight, FontWeight.w400);
    expect(accountName.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(
      accountName.style?.fontSize,
      15,
      reason: 'The reference name is 140px wide; 16px rendered 152px.',
    );
    expect(accountName.style?.fontVariations, isNull);
    expect(accountCompany.style?.fontWeight, FontWeight.w400);
    expect(
      accountCompany.style?.fontFamily,
      AppTypography.referencePlainFamily,
    );
    expect(
      accountCompany.style?.fontSize,
      12,
      reason: 'The reference company is 134x14px; 13.33px rendered 150x17.',
    );
    expect(accountCompany.style?.fontVariations, isNull);
    final toolbarTitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Cai dat' &&
          widget.textAlign == TextAlign.center,
    );
    final toolbarText = tester.widget<Text>(toolbarTitle);
    expect(toolbarText.style?.fontSize, 16.5);
    expect(toolbarText.style?.fontWeight, FontWeight.w700);
    expect(toolbarText.style?.letterSpacing, 0);
    final accountServer = find.byKey(
      const Key('settings-account-server-access'),
    );
    final accountServerText = tester.widget<Text>(accountServer);
    expect(
      accountServerText.style,
      AppTypography.settingsAccountMetaMultiline.copyWith(
        color: AppColors.textPrimary,
      ),
      reason: 'Multiline account metadata must use its locked role directly.',
    );
    expect(
      accountServerText.style?.fontSize,
      12,
      reason:
          'The two reference metadata lines measure 264x15 and 146x13; '
          '13.33px rendered 291x16 and 166x15.',
    );
    expect(toolbarTitle, findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-account-name'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(toolbarTitle).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-account-company'))).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byKey(const Key('settings-account-name'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(accountServer).dy,
      greaterThanOrEqualTo(
        tester
            .getBottomLeft(find.byKey(const Key('settings-account-company')))
            .dy,
      ),
    );
    expect(
      tester.getBottomLeft(accountServer).dy,
      lessThanOrEqualTo(
        tester.getBottomLeft(find.byKey(const Key('settings-account'))).dy,
      ),
    );
    expect(find.byKey(const Key('settings-connected-indicator')), findsNothing);

    final notificationBadge = find.byKey(
      const Key('settings-notification-Trao doi va tin nhan'),
    );
    final notificationText = tester.widget<Text>(
      find.descendant(of: notificationBadge, matching: find.byType(Text)),
    );
    expect(
      notificationText.style,
      AppTypography.settingsNotificationBadge.copyWith(color: Colors.white),
      reason: 'Notification badge must not mutate toolbar title metrics.',
    );

    final list = tester.widget<ListView>(
      find.byKey(const Key('settings-scroll-view')),
    );
    expect(
      list.padding,
      const EdgeInsets.fromLTRB(18.6666666667, 80, 18.6666666667, 118),
    );
  });

  testWidgets('settings content scrolls behind the translucent fixed header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(393, 320),
              padding: EdgeInsets.only(top: 24),
              viewPadding: EdgeInsets.only(top: 24),
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    const overlayKey = Key('settings-header-overlay');
    final overlay = find.byKey(overlayKey);
    expect(overlay, findsOneWidget);
    final decoration = tester.widget<DecoratedBox>(overlay).decoration;
    final gradient = (decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.stops, const [0, .72, 1]);
    expect(gradient.colors, [
      AppColors.background.withValues(alpha: .88),
      AppColors.background.withValues(alpha: .80),
      AppColors.background.withValues(alpha: 0),
    ]);

    final title = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Cai dat' &&
          widget.textAlign == TextAlign.center,
    );
    final titleTop = tester.getTopLeft(title);
    final overlayRect = tester.getRect(overlay);
    final overlayBottom = tester.getBottomLeft(overlay).dy;
    final account = find.byKey(const Key('settings-account'));
    expect(tester.getTopLeft(account).dy, closeTo(overlayBottom, .01));

    await tester.drag(
      find.byKey(const Key('settings-scroll-view')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(account).dy, lessThan(overlayBottom));
    expect(tester.getTopLeft(title), titleTop);
    expect(tester.getRect(overlay), overlayRect);
  });

  testWidgets('settings omits the demo corner ribbon for every account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_referenceDemoAccount),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(393.3333333333, 853.3333333333),
              padding: EdgeInsets.only(top: 24),
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final ribbon = find.byKey(const Key('settings-account-demo-ribbon'));
    expect(ribbon, findsNothing);
    expect(find.text('Demo'), findsNothing);
  });

  testWidgets('settings canonical text paints without scale compensation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_referenceDemoAccount),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(393.3333333333, 853.3333333333),
              padding: EdgeInsets.only(top: 24),
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final finder in <Finder>[
      find.byKey(const Key('settings-account-name')),
      find.byKey(const Key('settings-account-company')),
      find.byKey(const Key('settings-account-server-access')),
      find.text('Tai khoan moi'),
      find.text('Hop thu'),
      find.text('Bạn đã đăng ký tài khoản mới - MetaQuotes-Demo'),
      find.text('Tin tuc'),
      find.text('Tradays'),
      find.text('Lich Kinh Te'),
      find.text('Trao doi va tin nhan'),
      find.text('Dang nhap vao cong dong MQ...'),
      find.text('Cong dong trader'),
      find.text('MQL5 Algo Trading'),
      find.text('OTP'),
      find.text('Khoi tao mat khau mot lan'),
      find.text('Giao dien'),
      find.text('Tiếng Việt'),
      find.text('Nhung bieu do'),
      find.text('Nhat ky'),
    ]) {
      final scale = _paintScale(tester, finder);
      expect(scale.dx, closeTo(1, .001), reason: finder.toString());
      expect(scale.dy, closeTo(1, .001), reason: finder.toString());
    }
  });

  testWidgets('settings text offsets are isolated to the legacy profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1280);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Finder rowText(String title, String text) => find.descendant(
      of: find.byKey(ValueKey('settings-$title')),
      matching: find.text(text),
    );

    final cases = <(Finder, Offset)>[
      (
        find.byKey(const Key('settings-account-name')),
        const Offset(0, 1.6666666667),
      ),
      (
        find.byKey(const Key('settings-account-company')),
        const Offset(.6666666667, 1.3333333333),
      ),
      (
        find.byKey(const Key('settings-account-server-access')),
        const Offset(.6666666667, 0),
      ),
      (
        rowText('Tai khoan moi', 'Tai khoan moi'),
        const Offset(-.6666666667, .3),
      ),
      (rowText('Hop thu', 'Hop thu'), const Offset(-.6666666667, -.9666666667)),
      (
        rowText('Hop thu', 'Bạn đã đăng ký tài khoản mới - MetaQuotes-Demo'),
        const Offset(-.6666666667, -1.6333333333),
      ),
      (
        rowText('Trao doi va tin nhan', 'Trao doi va tin nhan'),
        const Offset(-.6666666667, -1.6633333333),
      ),
      (
        rowText('Trao doi va tin nhan', 'Dang nhap vao cong dong MQ...'),
        const Offset(-.6666666667, -.6633333333),
      ),
      (rowText('Giao diện', 'Giao dien'), const Offset(-.6666666667, -.3)),
      (rowText('Giao diện', 'Tiếng Việt'), const Offset(-.6666666667, -2.3)),
    ];

    for (final profile in TypographyProfile.values) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeDemoAccountProvider.overrideWithValue(_referenceDemoAccount),
          ],
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: withTypographyProfile(ThemeData(), profile),
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(393.3333333333, 853.3333333333),
                padding: EdgeInsets.only(top: 24),
              ),
              child: SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var index = 0; index < cases.length; index++) {
        final expected = profile == TypographyProfile.legacy
            ? cases[index].$2
            : Offset.zero;
        final actual = _ancestorTranslation(tester, cases[index].$1);
        expect(
          actual.dx,
          closeTo(expected.dx, .0001),
          reason: 'profile=${profile.name} case $index dx',
        );
        expect(
          actual.dy,
          closeTo(expected.dy, .0001),
          reason: 'profile=${profile.name} case $index dy',
        );
      }
    }
  });

  testWidgets('settings notification badge uses the locked static bold face', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    final badge = find.byKey(
      const Key('settings-notification-Trao doi va tin nhan'),
    );
    final badgeText = tester.widget<Text>(
      find.descendant(of: badge, matching: find.byType(Text)),
    );
    expect(badgeText.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(badgeText.style?.fontWeight, FontWeight.w700);
    expect(badgeText.style?.fontVariations, isNull);
    expect(badgeText.style?.fontSize, 14);
    expect(badgeText.style?.color, Colors.white);
  });

  testWidgets('settings list uses the recorded full-color icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const Key('settings-icon-atlas'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final kind in MtSettingsIconKind.values)
                  RepaintBoundary(
                    key: ValueKey('settings-icon-golden-${kind.name}'),
                    child: MtSettingsIcon(key: ValueKey(kind), kind),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(MtSettingsIconKind.values, hasLength(12));
    final settingsIcon = find.byKey(const ValueKey(MtSettingsIconKind.about));
    expect(
      find.descendant(of: settingsIcon, matching: find.byType(CustomPaint)),
      findsNothing,
      reason: 'The reference Settings row uses the supplied full-color asset.',
    );
    final settingsArtwork = find.descendant(
      of: settingsIcon,
      matching: find.byType(Image),
    );
    expect(settingsArtwork, findsOneWidget);
    final settingsImage = tester.widget<Image>(settingsArtwork);
    expect(settingsImage.image, isA<AssetImage>());
    expect(
      (settingsImage.image as AssetImage).assetName,
      'assets/images/metatrader5_settings_menu.png',
    );
    expect(settingsImage.filterQuality, FilterQuality.high);
    await tester.runAsync(
      () => precacheImage(settingsImage.image, tester.element(settingsArtwork)),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: settingsIcon, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(tester.getSize(settingsIcon), const Size(29, 29));
    await expectLater(
      find.byKey(const ValueKey('settings-icon-golden-about')),
      matchesGoldenFile('goldens/settings/list-settings-icon-29.png'),
    );
    await expectLater(
      find.byKey(const Key('settings-icon-atlas')),
      matchesGoldenFile('goldens/settings/settings-icon-atlas-29.png'),
    );

    for (final kind in MtSettingsIconKind.values.where(
      (kind) => kind != MtSettingsIconKind.about,
    )) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(kind)),
          matching: find.byType(Image),
        ),
        findsNothing,
        reason: kind.name,
      );
    }
    for (final kind in MtSettingsIconKind.values) {
      expect(tester.getSize(find.byKey(ValueKey(kind))), const Size(29, 29));
    }
  });

  testWidgets('Settings artwork resolves every approved Retina variant', (
    tester,
  ) async {
    const provider = AssetImage('assets/images/metatrader5_settings_menu.png');
    const variants = <(double, String, int, int, int)>[
      (1, 'assets/images/metatrader5_settings_menu.png', 29, 2066, 3964166875),
      (
        2,
        'assets/images/2.0x/metatrader5_settings_menu.png',
        58,
        5912,
        1081902415,
      ),
      (
        3,
        'assets/images/3.0x/metatrader5_settings_menu.png',
        87,
        11506,
        1785447180,
      ),
      (
        4,
        'assets/images/4.0x/metatrader5_settings_menu.png',
        116,
        17574,
        1451260820,
      ),
    ];

    final resolvedVariants = await tester.runAsync(() async {
      final resolved = <(String, double, int, int, int)>[];
      for (final (devicePixelRatio, _, _, _, _) in variants) {
        final key = await provider.obtainKey(
          ImageConfiguration(devicePixelRatio: devicePixelRatio),
        );
        final data = await rootBundle.load(key.name);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        resolved.add((
          key.name,
          key.scale,
          frame.image.width,
          bytes.length,
          _fnv1a32(bytes),
        ));
        expect(frame.image.height, frame.image.width, reason: key.name);
        frame.image.dispose();
        codec.dispose();
      }
      return resolved;
    });
    expect(resolvedVariants, isNotNull);

    for (var index = 0; index < variants.length; index++) {
      final (devicePixelRatio, assetPath, pixels, byteLength, fingerprint) =
          variants[index];
      final (resolvedPath, scale, width, bytes, resolvedFingerprint) =
          resolvedVariants![index];
      expect(resolvedPath, assetPath, reason: 'DPR $devicePixelRatio');
      expect(scale, devicePixelRatio, reason: assetPath);
      expect(width, pixels, reason: assetPath);
      expect(bytes, byteLength, reason: assetPath);
      expect(resolvedFingerprint, fingerprint, reason: assetPath);
    }
  });

  testWidgets('every non-Settings row paints its measured vector glyph', (
    tester,
  ) async {
    const expectedBackgrounds = <MtSettingsIconKind, Color>{
      MtSettingsIconKind.newAccount: Color(0xFF4BCF1C),
      MtSettingsIconKind.mail: Color(0xFF52C9FA),
      MtSettingsIconKind.news: Color(0xFFFBA526),
      MtSettingsIconKind.tradays: Color(0xFFD62F2E),
      MtSettingsIconKind.messages: Color(0xFF4D7DC4),
      MtSettingsIconKind.community: Color(0xFF3474DE),
      MtSettingsIconKind.telegram: Color(0xFF2BA9F8),
      MtSettingsIconKind.otp: Color(0xFF4CDA64),
      MtSettingsIconKind.interface: Color(0xFF169FFF),
      MtSettingsIconKind.charts: Color(0xFF179BFA),
      MtSettingsIconKind.journal: Color(0xFFBEC4D0),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final kind in expectedBackgrounds.keys)
              MtSettingsIcon(key: ValueKey(kind), kind),
          ],
        ),
      ),
    );

    for (final entry in expectedBackgrounds.entries) {
      final icon = find.byKey(ValueKey(entry.key));
      expect(
        find.descendant(of: icon, matching: find.byType(CustomPaint)),
        findsOneWidget,
        reason: '${entry.key.name} must use its measured vector glyph.',
      );
      expect(
        find.descendant(of: icon, matching: find.byType(Icon)),
        findsNothing,
        reason: '${entry.key.name} must not fall back to a Material icon.',
      );
      if (entry.key != MtSettingsIconKind.interface) {
        expect(
          find.descendant(of: icon, matching: find.byType(Text)),
          findsNothing,
          reason: '${entry.key.name} must use its measured vector glyph.',
        );
      }

      final box = tester.widget<DecoratedBox>(
        find.descendant(of: icon, matching: find.byType(DecoratedBox)),
      );
      expect(
        (box.decoration as BoxDecoration).color,
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('Charts icon leaves the hollow candle cavity clear', (
    tester,
  ) async {
    const boundaryKey = Key('charts-hollow-candle-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.charts),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    expect(
      _nearWhiteCoverage(
        pixels!,
        image.width,
        image.height,
        const Offset(9.5, 12),
        const Offset(9.5, 18.7),
        pixelRatio: 4,
      ),
      lessThan(.25),
      reason: 'The left wick must stop at the hollow candle body.',
    );
  });

  testWidgets('Charts icon uses the measured candle bounds', (tester) async {
    const boundaryKey = Key('charts-reference-bounds-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.charts),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    const referenceSegments = <(Offset, Offset)>[
      (Offset(10.7, 8.1), Offset(10.7, 10.6)),
      (Offset(10.7, 20.1), Offset(10.7, 22.8)),
      (Offset(20.2, 5.6), Offset(20.2, 7.3)),
      (Offset(20.2, 17.9), Offset(20.2, 18.6)),
      (Offset(23.0, 8.3), Offset(23.0, 17.2)),
    ];
    for (final (start, end) in referenceSegments) {
      expect(
        _nearWhiteCoverage(
          pixels!,
          image.width,
          image.height,
          start,
          end,
          pixelRatio: 4,
        ),
        greaterThan(.75),
        reason: 'Both reference candles must retain their measured bounds.',
      );
    }

    const clearSegments = <(Offset, Offset)>[
      (Offset(15.5, 8.3), Offset(15.5, 17.2)),
      (Offset(24.5, 8.3), Offset(24.5, 17.2)),
    ];
    for (final (start, end) in clearSegments) {
      expect(
        _nearWhiteCoverage(
          pixels!,
          image.width,
          image.height,
          start,
          end,
          pixelRatio: 4,
        ),
        lessThan(.25),
        reason: 'The candle geometry must not bleed outside measured bounds.',
      );
    }
  });

  testWidgets('Charts vector and Settings asset scale below 29px', (
    tester,
  ) async {
    const iconSize = 14.5;
    const chartsBoundaryKey = Key('small-charts-boundary');
    const settingsBoundaryKey = Key('small-settings-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: chartsBoundaryKey,
                child: MtSettingsIcon(
                  MtSettingsIconKind.charts,
                  size: iconSize,
                ),
              ),
              RepaintBoundary(
                key: settingsBoundaryKey,
                child: MtSettingsIcon(MtSettingsIconKind.about, size: iconSize),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final chartsBoundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(chartsBoundaryKey),
    );
    final settingsBoundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(settingsBoundaryKey),
    );
    final captures = await tester.runAsync(() async {
      final chartsImage = await chartsBoundary.toImage(pixelRatio: 8);
      final settingsImage = await settingsBoundary.toImage(pixelRatio: 8);
      final chartsPixels = await chartsImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final settingsPixels = await settingsImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return (chartsImage, chartsPixels, settingsImage, settingsPixels);
    });
    expect(captures, isNotNull);
    final (chartsImage, chartsPixels, settingsImage, settingsPixels) =
        captures!;
    addTearDown(chartsImage.dispose);
    addTearDown(settingsImage.dispose);
    expect(chartsPixels, isNotNull);
    expect(settingsPixels, isNotNull);

    final smallSettingsImage = find.descendant(
      of: find.byKey(settingsBoundaryKey),
      matching: find.byType(Image),
    );
    expect(smallSettingsImage, findsOneWidget);
    expect(tester.getSize(smallSettingsImage), const Size.square(iconSize));

    expect(
      _nearWhiteCoverage(
        chartsPixels!,
        chartsImage.width,
        chartsImage.height,
        const Offset(10.1, 2.9),
        const Offset(10.1, 3.65),
        pixelRatio: 8,
      ),
      greaterThan(.7),
      reason: 'The right wick must scale to half of its 29px coordinates.',
    );
    expect(
      _nearWhiteCoverage(
        settingsPixels!,
        settingsImage.width,
        settingsImage.height,
        const Offset(5, 3.8),
        const Offset(5, 4.5),
        pixelRatio: 8,
      ),
      lessThan(.3),
      reason: 'The supplied emblem must not regress to a white slider knob.',
    );
  });

  testWidgets('Tradays icon renders two continuous calendar bindings', (
    tester,
  ) async {
    const boundaryKey = Key('tradays-bindings-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.tradays),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    const bindingSegments = <(Offset, Offset)>[
      (Offset(10.2, 9.8), Offset(10.9, 12.1)),
      (Offset(18, 7), Offset(18.8, 9.3)),
    ];
    for (final (start, end) in bindingSegments) {
      expect(
        _nearWhiteCoverage(
          pixels!,
          image.width,
          image.height,
          start,
          end,
          pixelRatio: 4,
        ),
        greaterThan(.75),
        reason: 'Both reference calendar bindings must remain continuous.',
      );
    }
  });

  testWidgets('Tradays icon keeps the front calendar rail distinct', (
    tester,
  ) async {
    const boundaryKey = Key('tradays-front-rail-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.tradays),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    expect(
      _nearWhiteCoverage(
        pixels!,
        image.width,
        image.height,
        const Offset(9.8, 15),
        const Offset(22.1, 10.75),
        pixelRatio: 4,
      ),
      greaterThan(.8),
      reason: 'The reference has a separate diagonal rail above the candles.',
    );
  });

  testWidgets('Tradays icon renders the folded desk-calendar stand', (
    tester,
  ) async {
    const boundaryKey = Key('tradays-stand-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.tradays),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    const standSegments = <(Offset, Offset)>[
      (Offset(8.6, 12.4), Offset(5.9, 22.4)),
      (Offset(5.9, 22.4), Offset(12.1, 22.2)),
    ];
    for (final (start, end) in standSegments) {
      expect(
        _nearWhiteCoverage(
          pixels!,
          image.width,
          image.height,
          start,
          end,
          pixelRatio: 4,
        ),
        greaterThan(.75),
        reason: 'The reference calendar has a visible folded left stand.',
      );
    }
  });

  testWidgets('Tradays icon renders three continuous candle wicks', (
    tester,
  ) async {
    const boundaryKey = Key('tradays-icon-boundary');
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MtSettingsIcon(MtSettingsIconKind.tradays),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image, pixels);
    });
    expect(capture, isNotNull);
    final (image, pixels) = capture!;
    addTearDown(image.dispose);
    expect(pixels, isNotNull);

    const wickSegments = <(Offset, Offset)>[
      (Offset(12.4, 15.3), Offset(14.5, 21.5)),
      (Offset(15.5, 13.1), Offset(18.3, 21)),
      (Offset(18.4, 11.2), Offset(21.3, 19.3)),
    ];
    for (final (start, end) in wickSegments) {
      expect(
        _nearWhiteCoverage(
          pixels!,
          image.width,
          image.height,
          start,
          end,
          pixelRatio: 4,
        ),
        greaterThan(.75),
        reason: 'Each reference candle must have one continuous white wick.',
      );
    }
  });

  testWidgets(
    'interface icon centers each bilingual glyph and keeps Han glyph smaller',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: MtSettingsIcon(
              MtSettingsIconKind.interface,
              key: Key('interface-icon'),
            ),
          ),
        ),
      );

      final icon = find.byKey(const Key('interface-icon'));
      expect(
        find.descendant(of: icon, matching: find.byType(ClipRRect)),
        findsOneWidget,
        reason: 'The gray half must keep both rounded right corners.',
      );
      final latinGlyph = find.descendant(of: icon, matching: find.text('A'));
      final hanGlyph = find.descendant(of: icon, matching: find.text('文'));
      expect(latinGlyph, findsOneWidget);
      expect(hanGlyph, findsOneWidget);

      final iconRect = tester.getRect(icon);
      final latinRect = tester.getRect(latinGlyph);
      final hanRect = tester.getRect(hanGlyph);
      expect(
        latinRect.center.dx,
        closeTo(iconRect.left + iconRect.width * .25, .05),
      );
      expect(
        hanRect.center.dx,
        closeTo(iconRect.left + iconRect.width * .75, .05),
      );
      expect(latinRect.center.dy, closeTo(iconRect.center.dy, .05));
      expect(hanRect.center.dy, closeTo(iconRect.center.dy, .05));
      expect(
        hanRect.height,
        lessThanOrEqualTo(latinRect.height * .75),
        reason: 'The right-side glyph is visibly smaller in the reference.',
      );
    },
  );

  testWidgets('settings account header renders canonical broker metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(288, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDemoAccountProvider.overrideWithValue(_exnessAccount),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text(_exnessAccount.name), findsOneWidget);
    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
    expect(
      find.text('Bạn đã đăng ký tài khoản mới - Exness-MT5Real20'),
      findsOneWidget,
    );
    expect(
      find.text('109740422 - Exness-MT5Real20\nAccess Point #9'),
      findsOneWidget,
    );
    expect(find.text('active'), findsNothing);
    expect(find.textContaining('trochoi.top'), findsNothing);
    expect(find.text('EX V2'), findsNothing);

    final name = find.byKey(const Key('settings-account-name'));
    final company = find.byKey(const Key('settings-account-company'));
    final server = find.byKey(const Key('settings-account-server-access'));
    expect(name, findsOneWidget);
    expect(company, findsOneWidget);
    expect(server, findsOneWidget);
    expect(tester.getCenter(name).dx, inInclusiveRange(144, 146));
    expect(tester.getCenter(company).dx, inInclusiveRange(144, 146));
    expect(tester.getCenter(server).dx, inInclusiveRange(144, 146));
    expect(tester.getTopLeft(name).dy, lessThan(tester.getTopLeft(company).dy));
    expect(
      tester.getTopLeft(company).dy,
      lessThan(tester.getTopLeft(server).dy),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('settings-account')),
        matching: find.byKey(const Key('account-chevron-glyph')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings-account-demo-ribbon')), findsNothing);
  });

  test('settings visible typography is resolved through semantic roles', () {
    final source = File(
      'lib/features/profile/presentation/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'AppTypography\.forRole\s*\(').allMatches(source).length,
      greaterThanOrEqualTo(7),
      reason:
          'Toolbar, account name/company/meta, row title/subtitle, and badge '
          'must all resolve their semantic typography at the callsite.',
    );
    for (final directStyle in const <String>[
      'style: AppTypography.settingsToolbarTitle',
      'style: AppTypography.settingsAccountName',
      'style: AppTypography.settingsAccountCompany',
      'style: AppTypography.settingsAccountMetaMultiline',
      'style: AppTypography.settingsRowTitle',
      'style: AppTypography.settingsRowSubtitle',
      'style: AppTypography.settingsNotificationBadge',
    ]) {
      expect(source, isNot(contains(directStyle)), reason: directStyle);
    }
  });

  testWidgets(
    'settings semantic roles keep every row variant and locked ink color',
    (tester) async {
      tester.view.physicalSize = const Size(590, 1800);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: withTypographyProfile(
              ThemeData(brightness: Brightness.light),
              TypographyProfile.reference,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      void expectRole({
        required Finder finder,
        required ReferenceTextRole role,
        required ReferenceTextColorRole colorRole,
        required Color lockedColor,
        TypographyVariantId variant = TypographyVariantId.base,
      }) {
        expect(finder, findsOneWidget);
        final text = tester.widget<Text>(finder);
        final context = tester.element(finder);
        expect(
          text.style,
          AppTypography.forRole(
            context,
            role,
            colorRole: colorRole,
            variant: variant,
          ),
          reason: '${role.name}:${variant.value}',
        );
        expect(
          text.style?.color,
          lockedColor,
          reason: '${role.name}:${variant.value} ink',
        );
      }

      expectRole(
        finder: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Cai dat' &&
              widget.textAlign == TextAlign.center,
        ),
        role: ReferenceTextRole.settingsToolbarTitle,
        colorRole: ReferenceTextColorRole.primary,
        lockedColor: const Color(0xFF000000),
      );
      expectRole(
        finder: find.byKey(const Key('settings-account-name')),
        role: ReferenceTextRole.settingsAccountName,
        colorRole: ReferenceTextColorRole.primary,
        lockedColor: const Color(0xFF000000),
      );
      expectRole(
        finder: find.byKey(const Key('settings-account-company')),
        role: ReferenceTextRole.settingsAccountCompany,
        colorRole: ReferenceTextColorRole.primary,
        lockedColor: const Color(0xFF000000),
      );
      expectRole(
        finder: find.byKey(const Key('settings-account-server-access')),
        role: ReferenceTextRole.settingsAccountMetaMultiline,
        colorRole: ReferenceTextColorRole.primary,
        lockedColor: const Color(0xFF000000),
      );

      const titleCases =
          <({String id, String label, TypographyVariantId variant})>[
            (
              id: 'Tai khoan moi',
              label: 'Tai khoan moi',
              variant: TypographyVariantId.settingsRowNewAccount,
            ),
            (
              id: 'Hop thu',
              label: 'Hop thu',
              variant: TypographyVariantId.settingsRowMailbox,
            ),
            (
              id: 'Tin tuc',
              label: 'Tin tuc',
              variant: TypographyVariantId.settingsRowNews,
            ),
            (
              id: 'Tradays',
              label: 'Tradays',
              variant: TypographyVariantId.settingsRowTradays,
            ),
            (
              id: 'Trao doi va tin nhan',
              label: 'Trao doi va tin nhan',
              variant: TypographyVariantId.settingsRowCommunity,
            ),
            (
              id: 'Cong dong trader',
              label: 'Cong dong trader',
              variant: TypographyVariantId.settingsRowTraderCommunity,
            ),
            (
              id: 'MQL5 Algo Trading',
              label: 'MQL5 Algo Trading',
              variant: TypographyVariantId.settingsRowAlgoTrading,
            ),
            (
              id: 'OTP',
              label: 'OTP',
              variant: TypographyVariantId.settingsRowOtp,
            ),
            (
              id: 'Giao diện',
              label: 'Giao dien',
              variant: TypographyVariantId.settingsRowLanguage,
            ),
            (
              id: 'Nhung bieu do',
              label: 'Nhung bieu do',
              variant: TypographyVariantId.settingsRowEmbeddedCharts,
            ),
            (
              id: 'Nhat ky',
              label: 'Nhat ky',
              variant: TypographyVariantId.settingsRowJournal,
            ),
            (
              id: 'Cai dat',
              label: 'Cai dat',
              variant: TypographyVariantId.settingsRowFinal,
            ),
          ];
      for (final item in titleCases) {
        expectRole(
          finder: find.descendant(
            of: find.byKey(ValueKey('settings-${item.id}')),
            matching: find.text(item.label),
          ),
          role: ReferenceTextRole.settingsRowTitle,
          colorRole: ReferenceTextColorRole.primary,
          variant: item.variant,
          lockedColor: const Color(0xFF000000),
        );
      }

      const subtitleCases =
          <({String id, String label, TypographyVariantId variant})>[
            (
              id: 'Hop thu',
              label: 'Bạn đã đăng ký tài khoản mới - Demo-Live-01',
              variant: TypographyVariantId.settingsRowMailbox,
            ),
            (
              id: 'Tradays',
              label: 'Lich Kinh Te',
              variant: TypographyVariantId.settingsRowTradays,
            ),
            (
              id: 'Trao doi va tin nhan',
              label: 'Dang nhap vao cong dong MQ...',
              variant: TypographyVariantId.settingsRowCommunity,
            ),
            (
              id: 'OTP',
              label: 'Khoi tao mat khau mot lan',
              variant: TypographyVariantId.settingsRowOtp,
            ),
            (
              id: 'Giao diện',
              label: 'Tiếng Việt',
              variant: TypographyVariantId.settingsRowLanguage,
            ),
          ];
      for (final item in subtitleCases) {
        expectRole(
          finder: find.descendant(
            of: find.byKey(ValueKey('settings-${item.id}')),
            matching: find.text(item.label),
          ),
          role: ReferenceTextRole.settingsRowSubtitle,
          colorRole: ReferenceTextColorRole.secondary,
          variant: item.variant,
          lockedColor: const Color(0xFF8E8E8E),
        );
      }

      expectRole(
        finder: find.descendant(
          of: find.byKey(
            const Key('settings-notification-Trao doi va tin nhan'),
          ),
          matching: find.byType(Text),
        ),
        role: ReferenceTextRole.settingsNotificationBadge,
        colorRole: ReferenceTextColorRole.white,
        lockedColor: const Color(0xFFFFFFFF),
      );
    },
  );

  testWidgets('settings renders the exact recorded reference copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    for (final text in const [
      'Cai dat',
      'Tai khoan moi',
      'Hop thu',
      'Bạn đã đăng ký tài khoản mới - Demo-Live-01',
      'Tin tuc',
      'Tradays',
      'Lich Kinh Te',
      'Trao doi va tin nhan',
      'Dang nhap vao cong dong MQ...',
      'Cong dong trader',
      'MQL5 Algo Trading',
    ]) {
      expect(find.text(text), findsWidgets, reason: 'Missing "$text"');
    }

    for (final unexpectedText in const [
      'Cài đặt',
      'Tài khoản mới',
      'Hộp thư',
      'Tin tức',
      'Lịch Kinh Tế',
      'Trao đổi và tin nhắn',
      'Đăng nhập vào cộng đồng MQ...',
      'Cộng đồng trader',
    ]) {
      expect(
        find.text(unexpectedText),
        findsNothing,
        reason: 'Unexpected "$unexpectedText"',
      );
    }
    expect(find.text('Australian Dollar: RBA keeps hik...'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Nhung bieu do'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    for (final text in const [
      'OTP',
      'Khoi tao mat khau mot lan',
      'Giao dien',
      'Tiếng Việt',
      'Nhung bieu do',
      'Nhat ky',
      'Cai dat',
    ]) {
      expect(find.text(text), findsWidgets, reason: 'Missing "$text"');
    }

    for (final unexpectedText in const [
      'Khởi tạo mật khẩu một lần',
      'Giao diện',
      'Tieng Viet',
      'Nhúng biểu đồ',
      'Nhật ký',
    ]) {
      expect(
        find.text(unexpectedText),
        findsNothing,
        reason: 'Unexpected "$unexpectedText"',
      );
    }
  });

  testWidgets('settings matches the video 2 account card and divider', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    expect(find.text('Demo Account One'), findsOneWidget);
    expect(find.text('Demo Markets Ltd'), findsOneWidget);

    final accountIcon = find.byKey(const Key('settings-icon-Tai khoan moi'));
    final notificationBadge = find.byKey(
      const Key('settings-notification-Trao doi va tin nhan'),
    );
    final communityIcon = find.byKey(
      const Key('settings-icon-Trao doi va tin nhan'),
    );
    final connectedIndicator = find.byKey(
      const Key('settings-connected-indicator'),
    );
    expect(tester.getSize(accountIcon), const Size(29, 29));
    expect(tester.getSize(notificationBadge), const Size(21, 21));
    expect(connectedIndicator, findsNothing);

    final iconOrigin = tester.getTopLeft(accountIcon);
    final communityIconOrigin = tester.getTopLeft(communityIcon);
    final titleOrigin = tester.getTopLeft(find.text('Tai khoan moi'));
    final badgeOrigin = tester.getTopLeft(notificationBadge);
    expect(
      titleOrigin.dx - iconOrigin.dx,
      closeTo(43, .01),
      reason: 'Semantic row typography keeps the recorded 43px title gap.',
    );
    expect(badgeOrigin.dx - communityIconOrigin.dx, closeTo(13, .01));
    expect(badgeOrigin.dy - communityIconOrigin.dy, closeTo(-7.3, .01));

    final accountRow = find.byKey(const Key('settings-Tai khoan moi'));
    final accountChevron = find.descendant(
      of: accountRow,
      matching: find.byKey(const Key('settings-row-chevron')),
    );
    expect(tester.getSize(accountChevron), const Size(18, 18));

    expect(find.byKey(const Key('settings-account-accent')), findsNothing);
    final divider = find.byKey(const Key('settings-account-divider'));
    expect(divider, findsOneWidget);
    expect(tester.getSize(divider).height, .5);
    expect(tester.widget<Divider>(divider).color, AppColors.divider);

    final scrollView = tester.widget<ListView>(
      find.byKey(const Key('settings-scroll-view')),
    );
    expect(scrollView.physics, isA<BouncingScrollPhysics>());
    expect(
      (scrollView.physics! as BouncingScrollPhysics).parent,
      isA<AlwaysScrollableScrollPhysics>(),
    );

    expect(find.bySemanticsLabel('Tai khoan moi'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Trao doi va tin nhan.*2 thông báo')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Nhung bieu do'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhung bieu do'), findsOneWidget);
    expect(find.text('Nhat ky'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('trade navigation follows loss, flat and profit colors', (
    tester,
  ) async {
    final container = createVideoReferenceContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MtBottomNavigationBar(
              selectedIndex: 2,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    Text selectedLabel() => tester.widget<Text>(find.text('Giao dich'));

    expect(
      find.byKey(const ValueKey('bottom-nav-icon-quotes')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-icon-chart')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-icon-history')),
      findsOneWidget,
    );
    final historyIconScale = _paintScale(
      tester,
      find.byKey(const ValueKey('bottom-nav-icon-history')),
    );
    expect(
      historyIconScale.dx,
      closeTo(historyIconScale.dy, .001),
      reason: 'The History clock must remain circular in the bottom bar.',
    );
    final settingsIcon = find.byKey(const ValueKey('bottom-nav-icon-settings'));
    expect(settingsIcon, findsOneWidget);
    expect(tester.widget(settingsIcon), isA<CustomPaint>());
    expect(selectedLabel().style?.color, AppColors.negative);

    container.read(activeDemoAccountIdProvider.notifier).select('10001003');
    await tester.pump();
    expect(selectedLabel().style?.color, AppColors.primary);

    container.read(activeDemoAccountIdProvider.notifier).select('10001001');
    container
        .read(demoTradingProvider.notifier)
        .updateMarketPrice(symbol: 'XAUUSD+', bid: 4105.51, ask: 4105.64);
    await tester.pump();
    expect(selectedLabel().style?.color, AppColors.primary);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MtBottomNavigationBar(
              selectedIndex: 4,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Cai dat')).style?.color,
      AppColors.primary,
    );
  });
}

Offset _paintScale(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final origin = box.localToGlobal(Offset.zero);
  final xEdge = box.localToGlobal(Offset(box.size.width, 0));
  final yEdge = box.localToGlobal(Offset(0, box.size.height));
  return Offset(
    (xEdge.dx - origin.dx) / box.size.width,
    (yEdge.dy - origin.dy) / box.size.height,
  );
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

double _nearWhiteCoverage(
  ByteData pixels,
  int width,
  int height,
  Offset start,
  Offset end, {
  required double pixelRatio,
}) {
  const sampleCount = 17;
  var nearWhiteSamples = 0;
  for (var index = 0; index < sampleCount; index++) {
    final progress = .08 + index * (.84 / (sampleCount - 1));
    final point = Offset.lerp(start, end, progress)! * pixelRatio;
    var foundNearWhite = false;
    for (var dy = -2; dy <= 2 && !foundNearWhite; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = point.dx.round() + dx;
        final y = point.dy.round() + dy;
        if (x < 0 || x >= width || y < 0 || y >= height) continue;
        final offset = (y * width + x) * 4;
        final red = pixels.getUint8(offset);
        final green = pixels.getUint8(offset + 1);
        final blue = pixels.getUint8(offset + 2);
        final alpha = pixels.getUint8(offset + 3);
        if (red >= 235 && green >= 235 && blue >= 235 && alpha >= 235) {
          foundNearWhite = true;
          break;
        }
      }
    }
    if (foundNearWhite) nearWhiteSamples++;
  }
  return nearWhiteSamples / sampleCount;
}

int _fnv1a32(Uint8List bytes) {
  var hash = 2166136261;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 16777619) & 0xFFFFFFFF;
  }
  return hash;
}

const _exnessAccount = DemoAccountProfile(
  id: '109740422',
  name: 'Mỗi Ngày Một Tỷ 🍀',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real20',
  accessPoint: 'Access Point #9',
  balance: 154763.90,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 154763.90,
);

const _referenceDemoAccount = DemoAccountProfile(
  id: '111500232',
  name: 'HaiAa NamAa',
  company: 'MetaQuotes Ltd.',
  server: 'MetaQuotes-Demo',
  accessPoint: 'Access Point HK 1',
  balance: 100000,
  brand: DemoBrokerBrand.metaquotes,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 100000,
  isDemo: true,
);
