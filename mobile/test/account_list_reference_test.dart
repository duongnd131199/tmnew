import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

import 'test_support/video_reference_fixtures.dart';

void main() {
  testWidgets('every account row keeps a white surface when selected', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(tester);
    addTearDown(container.dispose);

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFEEEDF5),
    );

    final activeMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(ValueKey('account-${_readOnlyAccount.id}')),
            matching: find.byType(Material),
          )
          .first,
    );
    final inactiveMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(ValueKey('account-${_masterAccount.id}')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(activeMaterial.color, const Color(0xFFFFFFFF));
    expect(inactiveMaterial.color, const Color(0xFFFFFFFF));

    for (final controlKey in const ['accounts-back', 'accounts-add']) {
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey(controlKey)),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const Color(0xFFFFFFFF));
      final shape = material.shape! as CircleBorder;
      expect(shape.side.color, const Color(0xFFD9D9DE));
      expect(shape.side.width, .6);
    }
  });

  testWidgets('fixed Delete account stays last and matches the reference', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(tester);
    addTearDown(container.dispose);

    const deleteAccountId = '28210230';
    final deleteRow = find.byKey(const ValueKey('account-$deleteAccountId'));
    final lastRealRow = find.byKey(ValueKey('account-${_masterAccount.id}'));

    expect(deleteRow, findsOneWidget);
    for (final copy in const [
      'Delete',
      '28210230 - VantageMarkets-Live 19',
      '0.00 USD, Hedge',
    ]) {
      expect(
        find.descendant(of: deleteRow, matching: find.text(copy)),
        findsOneWidget,
      );
    }
    expect(tester.getSize(deleteRow).height, 97);
    expect(
      tester.getTopLeft(deleteRow).dy,
      greaterThan(tester.getTopLeft(lastRealRow).dy),
    );

    final brokerMark = tester.widget<AccountBrokerMark>(
      find.descendant(of: deleteRow, matching: find.byType(AccountBrokerMark)),
    );
    expect(brokerMark.brand, DemoBrokerBrand.vantage);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: deleteRow, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );
    expect(
      find.descendant(
        of: deleteRow,
        matching: find.byType(AccountChevronRight),
      ),
      findsNothing,
    );
  });

  testWidgets('accounts copy uses the reference faces, sizes and weights', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(tester);
    addTearDown(container.dispose);

    final title = tester.widget<Text>(find.text('Tài khoản'));
    expect(title.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(title.style?.fontSize, 18.5);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.color, const Color(0xFF000000));

    final name = tester.widget<Text>(find.text(_readOnlyAccount.name));
    expect(name.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(name.style?.fontSize, 16.5);
    expect(name.style?.fontWeight, FontWeight.w700);
    expect(name.style?.color, const Color(0xFF0098FF));
    expect(name.style?.letterSpacing, .95);
    expect(name.style?.height, 1);
    final nameSpans = (name.textSpan! as TextSpan).children!;
    expect(nameSpans, hasLength(3));
    expect((nameSpans.first as TextSpan).text, 'MỖI NGÀY MỘT TỶ');
    final emojiGapSpan = nameSpans[1] as TextSpan;
    expect(emojiGapSpan.text, ' ');
    expect(emojiGapSpan.style?.fontSize, 13.5);
    expect(emojiGapSpan.style?.letterSpacing, 0);
    final emojiSpan = nameSpans.last as TextSpan;
    expect(emojiSpan.text, '🍀');
    expect(emojiSpan.style?.fontSize, 20.5);
    expect(emojiSpan.style?.letterSpacing, 0);

    final inactiveName = tester.widget<Text>(find.text(_masterAccount.name));
    expect(inactiveName.style?.fontFamily, AppTypography.referencePlainFamily);
    expect(inactiveName.style?.fontSize, 16.5);
    expect(inactiveName.style?.fontWeight, FontWeight.w400);
    expect(inactiveName.style?.color, const Color(0xFF000000));

    for (final copy in const [
      '213792753 - Exness-MT5Real28',
      '2 292.60 USD, Hedge',
    ]) {
      final text = tester.widget<Text>(find.text(copy));
      expect(text.style?.fontFamily, AppTypography.referencePlainFamily);
      expect(text.style?.fontSize, 13.5);
      expect(text.style?.fontWeight, FontWeight.w400);
      expect(text.style?.fontVariations, isNull);
      expect(text.style?.letterSpacing, .4);
      expect(text.style?.color, const Color(0xFF000000));
      expect(text.style?.height, 1);
    }

    final inactiveRow = find.byKey(ValueKey('account-${_masterAccount.id}'));
    for (final copy in const [
      '903189316 - Exness-MT5Real28',
      '0.00 USD, Hedge',
    ]) {
      final text = tester.widget<Text>(
        find.descendant(of: inactiveRow, matching: find.text(copy)),
      );
      expect(text.style?.color, const Color(0xFF3C3C43));
    }
  });

  testWidgets('trailing emoji remains one complete grapheme cluster', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(
      tester,
      accounts: const [_multiCodePointEmojiAccount, _masterAccount],
    );
    addTearDown(container.dispose);

    final name = tester.widget<Text>(
      find.text(_multiCodePointEmojiAccount.name),
    );
    final spans = (name.textSpan! as TextSpan).children!;
    expect((spans.first as TextSpan).text, 'MỖI NGÀY MỘT TỶ');
    expect((spans[1] as TextSpan).text, ' ');
    expect((spans.last as TextSpan).text, '👩🏽‍💻');
  });

  testWidgets('read only badge follows account permission without guessing', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(tester);
    addTearDown(container.dispose);

    expect(find.text('Read Only'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('account-${_readOnlyAccount.id}')),
        matching: find.byKey(
          ValueKey('account-read-only-${_readOnlyAccount.id}'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('account-${_masterAccount.id}')),
        matching: find.text('Read Only'),
      ),
      findsNothing,
    );

    final badge = tester.widget<DecoratedBox>(
      find.byKey(ValueKey('account-read-only-${_readOnlyAccount.id}')),
    );
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFF5F5F5));
    expect(decoration.border, Border.all(color: const Color(0xFF9A9A9F)));
    expect(decoration.borderRadius, BorderRadius.circular(10.5));
    expect(tester.getSize(find.byWidget(badge)), const Size(70, 21));

    final label = tester.widget<Text>(find.text('Read Only'));
    expect(label.style?.fontFamily, AppTypography.referenceCondensedFamily);
    expect(label.style?.fontSize, 16.5);
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(label.style?.color, const Color(0xFF3C3C43));
  });

  testWidgets('accounts row geometry follows the 402 point reference', (
    tester,
  ) async {
    final container = await _pumpAccountsReference(tester);
    addTearDown(container.dispose);

    final row = find.byKey(ValueKey('account-${_readOnlyAccount.id}'));
    final mark = find.descendant(
      of: row,
      matching: find.byKey(const Key('account-broker-mark')),
    );
    final name = find.text(_readOnlyAccount.name);
    final server = find.text('213792753 - Exness-MT5Real28');
    final balance = find.text('2 292.60 USD, Hedge');

    expect(tester.getSize(row).height, 97);
    expect(tester.getSize(mark), const Size.square(31));
    expect(
      tester.getSize(find.byKey(const Key('account-round-back-button'))),
      const Size.square(43),
    );
    expect(
      tester.getSize(find.byKey(const Key('account-round-add-button'))),
      const Size.square(43),
    );

    final rowOrigin = tester.getTopLeft(row);
    expect(rowOrigin.dy, 152);
    expect(
      tester.getTopLeft(find.byKey(const Key('account-round-back-button'))),
      const Offset(15.3333333333, 99),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('account-round-add-button'))),
      const Offset(345.6666666667, 99),
    );
    expect(tester.getTopLeft(find.text('Tài khoản')).dy, 111);
    expect(tester.getTopLeft(mark).dx - rowOrigin.dx, 15.3333333333);
    expect(tester.getTopLeft(mark).dy - rowOrigin.dy, 33);
    expect(
      tester.getTopLeft(name).dx - rowOrigin.dx,
      closeTo(60.3333333333, .0001),
    );
    expect(server, findsOneWidget);
    expect(balance, findsOneWidget);
  });
}

Future<ProviderContainer> _pumpAccountsReference(
  WidgetTester tester, {
  List<DemoAccountProfile> accounts = const [_readOnlyAccount, _masterAccount],
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = createVideoReferenceContainer(
    overrides: [demoAccountCatalogProvider.overrideWithValue(accounts)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(402, 874),
            padding: EdgeInsets.only(top: 62),
          ),
          child: ProfileScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

const _readOnlyAccount = DemoAccountProfile(
  id: '213792753',
  name: 'MỖI NGÀY MỘT TỶ 🍀',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real28',
  accessPoint: 'Access Point #9',
  balance: 2292.60,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 2292.60,
  isMaster: false,
);

const _masterAccount = DemoAccountProfile(
  id: '903189316',
  name: 'Tài khoản giao dịch',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real28',
  accessPoint: 'Access Point #9',
  balance: 0,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 0,
);

const _multiCodePointEmojiAccount = DemoAccountProfile(
  id: '213792753',
  name: 'MỖI NGÀY MỘT TỶ 👩🏽‍💻',
  company: 'Exness Technologies Ltd',
  server: 'Exness-MT5Real28',
  accessPoint: 'Access Point #9',
  balance: 2292.60,
  brand: DemoBrokerBrand.exness,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 2292.60,
);
