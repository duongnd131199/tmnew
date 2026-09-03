import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/broker_list_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/existing_account_login_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/trading_server_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/theme/account_link_reference_theme.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

import 'test_support/load_test_fonts.dart';

void main() {
  setUpAll(loadMt5TestFonts);

  test(
    'reference server presentation keeps extra data after the image list',
    () {
      final options = referenceServerOptions(
        brokerId: 'yodo-demo',
        servers: const [
          MobileTradingServer(
            id: 'yodo-demo-01',
            name: 'YODO-Demo-01',
            brokerId: 'yodo-demo',
          ),
        ],
      );
      final names = options.map((option) => option.server.name).toList();

      expect(names.first, 'Exness-MT5Trial5');
      expect(
        options.singleWhere((option) => option.defaultOption).server.name,
        'Exness-MT5Trial5',
      );
      expect(
        names,
        containsAll(<String>[
          'Exness-MT5Real20',
          'Exness-MT5Real26',
          'Exness-MT5Real34',
        ]),
      );
    },
  );

  testWidgets('broker list presents MetaQuotes above Exness like the image', (
    tester,
  ) async {
    await _pump(tester, child: const BrokerListScreen());

    final metaquotes = tester.getCenter(
      find.byKey(const Key('broker-row-metaquotes')),
    );
    final exness = tester.getCenter(find.byKey(const Key('broker-row-exness')));

    expect(metaquotes.dy, lessThan(exness.dy));
  });

  testWidgets('broker choices render before the repository responds', (
    tester,
  ) async {
    final repository = _DelayedReferenceRepository();
    MobileBroker? selectedBroker;
    addTearDown(repository.release);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BrokerListScreen(
            onBrokerSelected: (broker) => selectedBroker = broker,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('broker-row-metaquotes')), findsOneWidget);
    expect(find.byKey(const Key('broker-row-exness')), findsOneWidget);
    expect(find.byKey(const Key('broker-catalog-loading')), findsNothing);

    await tester.tap(find.byKey(const Key('broker-row-exness')));
    await tester.pump();

    expect(selectedBroker, isNull);

    repository.release();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'optimistic broker tap waits for the canonical broker before selecting it',
    (tester) async {
      final repository = _DelayedReferenceRepository();
      addTearDown(repository.release);
      final container = ProviderContainer(
        overrides: [
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/accounts/add',
        routes: [
          GoRoute(
            path: '/accounts/add',
            builder: (context, state) => const BrokerListScreen(),
          ),
          GoRoute(
            path: '/accounts/add/:brokerId',
            builder: (context, state) => ExistingAccountLoginScreen(
              brokerId: state.pathParameters['brokerId']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('broker-row-exness')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const Key('existing-account-login-screen')),
        findsOneWidget,
      );
      expect(
        container.read(accountLinkControllerProvider).value?.selectedBroker,
        isNull,
      );
      expect(find.text('Exness-MT5Trial5'), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();

      final selectedBroker = container
          .read(accountLinkControllerProvider)
          .value
          ?.selectedBroker;
      expect(selectedBroker?.id, 'yodo-demo');
      expect(selectedBroker?.name, 'YODO Demo Markets');
    },
  );

  testWidgets('account form exposes both image login modes', (tester) async {
    await _pump(
      tester,
      child: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
    );

    expect(find.byKey(const Key('existing-account-type-row')), findsOneWidget);
    expect(find.text('Tài khoản giao dịch'), findsOneWidget);
    expect(find.text('Mã máy khách'), findsOneWidget);
    expect(find.text('Exness-MT5Trial5'), findsOneWidget);
    expect(
      find.byKey(const Key('existing-account-save-password-switch')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('existing-account-client-id-segment')),
    );
    await tester.pump();

    expect(find.text('Mã máy khách'), findsNWidgets(2));
    final identityField = tester.widget<TextField>(
      find.byKey(const Key('existing-account-login-field')),
    );
    expect(identityField.keyboardType, TextInputType.text);
    expect(identityField.decoration?.hintText, 'cl1234');
  });

  testWidgets(
    'reference broker mark and default server render before the repository responds',
    (tester) async {
      final repository = _DelayedReferenceRepository();
      addTearDown(repository.release);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountLinkRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('broker-mark-yodo-demo')),
        findsOneWidget,
      );
      expect(find.text('Exness-MT5Trial5'), findsOneWidget);
      expect(find.text('Chọn máy chủ'), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('save-password switch is enabled in the reference state', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
    );

    final switchFinder = find.byKey(
      const Key('existing-account-save-password-switch'),
    );
    expect(tester.widget<CupertinoSwitch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pump();

    expect(tester.widget<CupertinoSwitch>(switchFinder).value, isFalse);
  });

  testWidgets('broker chrome and rows use the measured image geometry', (
    tester,
  ) async {
    await _pump(tester, child: const BrokerListScreen());

    expect(
      tester.getSize(find.byKey(const Key('account-link-toolbar'))).height,
      70,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('account-link-back-button'))).dy,
      21,
    );
    expect(
      tester.getSize(find.byKey(const Key('broker-row-metaquotes'))).height,
      62,
    );
    expect(
      tester.getSize(find.byKey(const Key('broker-row-exness'))).height,
      62,
    );
    expect(
      tester.widget<Text>(find.text('MetaQuotes Ltd.')).style,
      AccountLinkReferenceTypography.brokerName,
    );
    expect(
      tester.widget<Text>(find.text('MetaQuotes')).style,
      AccountLinkReferenceTypography.brokerCompany,
    );
    expect(
      find.byKey(const Key('metaquotes-broker-mark-raster')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('broker-search-field'))).height,
      43,
    );
  });

  testWidgets('login form uses the measured compact row geometry', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('existing-account-login-screen')),
    );
    expect(scaffold.backgroundColor, const Color(0xFFF8F8F8));
    expect(
      tester.getSize(find.byKey(const Key('existing-account-header'))).height,
      84,
    );
    expect(
      tester.getSize(find.byKey(const Key('real-account-row'))).height,
      88,
    );
    expect(
      tester.getSize(find.byKey(const Key('demo-account-row'))).height,
      88,
    );
    for (final key in const <String>[
      'existing-account-type-row',
      'existing-account-server-row',
      'existing-account-login-row',
      'existing-account-password-row',
      'existing-account-save-password-row',
    ]) {
      final row = find.byKey(Key(key));
      expect(row, findsOneWidget, reason: key);
      expect(tester.getSize(row).height, 49, reason: key);
    }
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('existing-account-trading-account-segment')),
          )
          .dx,
      122,
    );
    expect(
      tester.getSize(find.byKey(const Key('existing-account-login-button'))),
      const Size(106, 46),
    );
  });

  testWidgets('server rows begin below the overlay header and use 49 rows', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const TradingServerScreen(brokerId: 'yodo-demo'),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('trading-server-screen')),
    );
    expect(scaffold.backgroundColor, const Color(0xFFF2F1F7));
    expect(tester.getTopLeft(find.byKey(const Key('server-list'))).dy, 0);
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('server-row-yodo-demo-01-reference-0')),
          )
          .dy,
      103,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('server-row-yodo-demo-01-reference-0')))
          .height,
      49,
    );
    expect(
      tester.widget<Text>(find.text('Exness-MT5Trial5')).style,
      AccountLinkReferenceTypography.serverName,
    );
  });

  testWidgets('broker image state remains visually locked', (tester) async {
    await _pump(tester, child: const BrokerListScreen());

    await expectLater(
      find.byKey(const Key('broker-list-screen')),
      matchesGoldenFile('goldens/account-link-reference/brokers.png'),
    );
  });

  testWidgets('trading-account image state remains visually locked', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
    );

    await expectLater(
      find.byKey(const Key('existing-account-login-screen')),
      matchesGoldenFile('goldens/account-link-reference/trading-account.png'),
    );
  });

  testWidgets('client-id image state remains visually locked', (tester) async {
    await _pump(
      tester,
      child: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
    );
    await tester.tap(
      find.byKey(const Key('existing-account-client-id-segment')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('existing-account-login-screen')),
      matchesGoldenFile('goldens/account-link-reference/client-id.png'),
    );
  });

  testWidgets('server-list top image state remains visually locked', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const TradingServerScreen(brokerId: 'yodo-demo'),
    );

    await expectLater(
      find.byKey(const Key('trading-server-screen')),
      matchesGoldenFile('goldens/account-link-reference/server-top.png'),
    );
  });

  testWidgets('server-list bottom image state remains visually locked', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const TradingServerScreen(brokerId: 'yodo-demo'),
      topSafeArea: 39,
    );
    const trial2Index = 9;
    const referenceOffset =
        AccountLinkReferenceMetrics.serverHeaderGap +
        trial2Index * AccountLinkReferenceMetrics.serverRowHeight;
    final scrollable = find.descendant(
      of: find.byKey(const Key('server-list')),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(scrollable).position.jumpTo(referenceOffset);
    await tester.pump();

    expect(
      tester
          .getTopLeft(
            find.byKey(
              const Key('server-row-yodo-demo-01-reference-$trial2Index'),
            ),
          )
          .dy,
      39 + AccountLinkReferenceMetrics.toolbarHeight,
    );
    expect(find.text('Exness-MT5Real34'), findsOneWidget);

    await expectLater(
      find.byKey(const Key('trading-server-screen')),
      matchesGoldenFile('goldens/account-link-reference/server-bottom.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double topSafeArea = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountLinkRepositoryProvider.overrideWithValue(
          const _ReferenceRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: EdgeInsets.only(top: topSafeArea),
            viewPadding: EdgeInsets.only(top: topSafeArea),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _ReferenceRepository implements AccountLinkRepository {
  const _ReferenceRepository();

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async => const [
    MobileBroker(
      id: 'yodo-demo',
      name: 'YODO Demo Markets',
      companyName: 'YODO Markets International Limited',
    ),
  ];

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async => const [
    MobileTradingServer(
      id: 'yodo-demo-01',
      name: 'YODO-Demo-01',
      brokerId: 'yodo-demo',
    ),
  ];

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();
}

final class _DelayedReferenceRepository implements AccountLinkRepository {
  final _brokers = Completer<List<MobileBroker>>();
  final _servers = Completer<List<MobileTradingServer>>();

  void release() {
    if (!_brokers.isCompleted) {
      _brokers.complete(const [
        MobileBroker(
          id: 'yodo-demo',
          name: 'YODO Demo Markets',
          companyName: 'YODO Markets International Limited',
        ),
      ]);
    }
    if (!_servers.isCompleted) {
      _servers.complete(const [
        MobileTradingServer(
          id: 'yodo-demo-01',
          name: 'YODO-Demo-01',
          brokerId: 'yodo-demo',
        ),
      ]);
    }
  }

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) => _brokers.future;

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) => _servers.future;

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();
}
