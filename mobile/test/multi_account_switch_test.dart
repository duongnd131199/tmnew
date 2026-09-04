import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/account_link/data/linked_account_presentation_store.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';
import 'package:trading_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:trading_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:trading_mobile/features/market_watch/data/data_sources/realtime_market_service.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('empty mobile accounts API never renders local-only accounts', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      accountListEmpty: true,
    );
    addTearDown(fixture.dispose);

    expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-account-b')), findsNothing);
  });

  testWidgets(
    'cold-started reference account restores its Exness logo without catalog metadata',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/profile',
        accountListEmpty: true,
      );
      addTearDown(fixture.dispose);

      expect(find.text('LOGIN-A - Exness-MT5Real20'), findsOneWidget);
      expect(find.text('exness'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_outlined), findsNothing);
    },
  );

  testWidgets(
    'cold-started reference settings restores the video broker metadata',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/settings',
        accountListEmpty: true,
      );
      addTearDown(fixture.dispose);

      expect(find.text('Exness Technologies Ltd'), findsOneWidget);
      expect(
        find.text('LOGIN-A - Exness-MT5Real20\nAccess Point #9'),
        findsOneWidget,
      );
    },
  );

  testWidgets('successful empty account API discards stale inactive rows', (
    tester,
  ) async {
    final online = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
    );
    expect(find.byKey(const ValueKey('account-account-b')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    online.dispose();

    final empty = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      accountListEmpty: true,
    );
    addTearDown(empty.dispose);

    expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-account-b')), findsNothing);
  });

  testWidgets('server account catalog renders without local session state', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
    );
    addTearDown(fixture.dispose);

    expect(fixture.adapter.accountListCalls, 1);
    expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-account-b')), findsOneWidget);
  });

  testWidgets('saved account uses authoritative server activation', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/settings',
    );
    addTearDown(fixture.dispose);
    fixture.router.push('/profile');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pumpAndSettle();

    expect(fixture.adapter.activationCalls, 1);
    expect(fixture.adapter.activatedAccountIds, ['account-b']);
    expect(
      find.byKey(const Key('existing-account-login-screen')),
      findsNothing,
    );
  });

  testWidgets('server account activates without asking for a password', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/settings',
    );
    addTearDown(fixture.dispose);
    fixture.router.push('/profile');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pumpAndSettle();

    expect(fixture.adapter.activationCalls, 1);
    expect(fixture.adapter.activatedAccountIds, ['account-b']);
    expect(fixture.router.state.uri.path, '/settings');
    expect(
      find.byKey(const Key('existing-account-login-screen')),
      findsNothing,
    );
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue!
          .bootstrap
          .account
          .id,
      'account-b',
    );
  });

  testWidgets('unauthorized activation never opens the account relink form', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      activationUnauthorized: true,
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pumpAndSettle();

    expect(fixture.adapter.activationCalls, 1);
    expect(fixture.router.state.uri.path, '/profile');
    expect(
      find.byKey(const Key('existing-account-login-screen')),
      findsNothing,
    );
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue!
          .bootstrap
          .account
          .id,
      'account-a',
    );
  });

  testWidgets('account not found stays on profile and refreshes server list', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      activationAccountNotFound: true,
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pumpAndSettle();

    expect(fixture.adapter.activationCalls, 1);
    expect(fixture.adapter.accountListCalls, 2);
    expect(fixture.router.state.uri.path, '/profile');
    expect(
      find.byKey(const Key('existing-account-login-screen')),
      findsNothing,
    );
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue!
          .bootstrap
          .account
          .id,
      'account-a',
    );
  });

  testWidgets('production Settings add opens broker discovery', (tester) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/settings',
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const Key('settings-Tai khoan moi')));
    await tester.pumpAndSettle();

    expect(fixture.router.state.uri.path, '/accounts/add');
    expect(find.text('BROKER DISCOVERY'), findsOneWidget);
  });

  testWidgets('production Profile add opens broker discovery', (tester) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const Key('accounts-add')));
    await tester.pumpAndSettle();

    expect(fixture.router.state.uri.path, '/accounts/add');
    expect(find.text('BROKER DISCOVERY'), findsOneWidget);
  });

  testWidgets('production Profile add opens after bootstrap recovery', (
    tester,
  ) async {
    final bootstrapGate = Completer<ExV2AccountViewState?>();
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      bootstrapGate: bootstrapGate,
    );
    addTearDown(fixture.dispose);

    expect(fixture.container.read(exV2AccountProvider).isLoading, isTrue);
    bootstrapGate.complete(_accountAViewState());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accounts-add')));
    await tester.pumpAndSettle();

    expect(fixture.router.state.uri.path, '/accounts/add');
    expect(find.text('BROKER DISCOVERY'), findsOneWidget);
  });

  for (final accountState in _UnavailableAccountState.values) {
    testWidgets(
      'production Settings add uses broker discovery while account is ${accountState.name}',
      (tester) async {
        final fixture = await _pumpProductionRoute(
          tester,
          initialLocation: '/settings',
          unavailableAccountState: accountState,
        );
        addTearDown(fixture.dispose);

        await tester.tap(find.byKey(const Key('settings-Tai khoan moi')));
        await tester.pumpAndSettle();

        expect(fixture.router.state.uri.path, '/accounts/add');
        expect(find.text('BROKER DISCOVERY'), findsOneWidget);
      },
    );

    testWidgets(
      'production Profile add uses broker discovery while account is ${accountState.name}',
      (tester) async {
        final fixture = await _pumpProductionRoute(
          tester,
          initialLocation: '/profile',
          unavailableAccountState: accountState,
        );
        addTearDown(fixture.dispose);

        await tester.tap(find.byKey(const Key('accounts-add')));
        await tester.pumpAndSettle();

        expect(fixture.router.state.uri.path, '/accounts/add');
        expect(find.text('BROKER DISCOVERY'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'linked accounts come from the server with active account first',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/profile',
      );
      addTearDown(fixture.dispose);

      expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-account-b')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('account-account-a'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('account-account-b'))).dy,
        ),
      );
      expect(fixture.adapter.accountListCalls, 1);
      expect(find.text('Account A'), findsOneWidget);
      expect(find.text('Account B'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-account-b')),
          matching: find.text('200.00 USD, Hedge'),
        ),
        findsOneWidget,
      );
      expect(find.text('USD, Hedge'), findsNothing);

      final activeRow = find.byKey(const ValueKey('account-account-a'));
      final inactiveRow = find.byKey(const ValueKey('account-account-b'));
      expect(
        find.descendant(
          of: activeRow,
          matching: find.byKey(const Key('account-chevron-glyph')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: inactiveRow,
          matching: find.byKey(const Key('account-chevron-glyph')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: activeRow,
          matching: find.textContaining('LOGIN-A'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: inactiveRow,
          matching: find.textContaining('LOGIN-A'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Settings joins active broker metadata by account ID when logins match',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/settings',
      );
      addTearDown(fixture.dispose);

      expect(fixture.adapter.accountListCalls, 1);
      expect(find.text('Exness Technologies Ltd'), findsOneWidget);
      expect(
        find.text('LOGIN-A - Exness-MT5Trial\nAccess Point #1'),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsNothing);
      expect(find.textContaining('Second Broker'), findsNothing);
    },
  );

  testWidgets('technical YODO metadata never leaks into account UI', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/settings',
      technicalYodoMetadata: true,
    );
    addTearDown(fixture.dispose);

    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
    expect(
      find.text('LOGIN-A - Exness-MT5Real20\nAccess Point #1'),
      findsOneWidget,
    );
    expect(find.textContaining('YODO'), findsNothing);
    expect(find.textContaining('yodo'), findsNothing);

    fixture.router.push('/profile');
    await tester.pumpAndSettle();
    expect(find.text('exness'), findsNWidgets(2));
  });

  testWidgets(
    'account-list failure stays an error while bootstrap account remains visible',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/profile',
        accountListFails: true,
      );
      addTearDown(fixture.dispose);

      expect(fixture.adapter.accountListCalls, 1);
      expect(
        fixture.container.read(linkedTradingAccountsProvider).hasError,
        isTrue,
      );
      expect(find.byKey(const ValueKey('account-account-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-account-b')), findsNothing);
    },
  );

  testWidgets(
    'active account keeps its stored MetaQuotes identity when account list fails',
    (tester) async {
      const presentationStore = SecureLinkedAccountPresentationStore(
        FlutterSecureStorage(),
      );
      await presentationStore.write(
        'account-a',
        const LinkedAccountPresentation(
          companyName: 'MetaQuotes Ltd.',
          serverName: 'MetaQuotes-Demo',
        ),
      );
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/profile',
        accountListFails: true,
      );
      addTearDown(fixture.dispose);

      expect(find.text('LOGIN-A - MetaQuotes-Demo'), findsOneWidget);
      expect(
        find.byKey(const Key('metaquotes-broker-mark-raster')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.account_balance_outlined), findsNothing);
    },
  );

  testWidgets('activate failure leaves account A active everywhere', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      activationFails: true,
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fixture.adapter.activationCalls, 1);
    expect(fixture.router.state.uri.path, '/profile');
    final state = fixture.container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.account.id, 'account-a');
    expect(state.positions.map((position) => position.id), ['position-a']);
    expect(state.historyPositions.map((position) => position.id), [
      'history-a',
    ]);
    expect(state.settings['scope'], 'A');
    expect(fixture.container.read(activeDemoAccountProvider).id, 'LOGIN-A');
    expect(
      find.text('Activation failed\nMã lỗi: activation_failed'),
      findsOneWidget,
    );
  });

  testWidgets('offline market feed does not block REST account switch', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      connectionStatuses: Stream<MarketConnectionStatus>.value(
        MarketConnectionStatus.disconnected,
      ),
    );
    addTearDown(fixture.dispose);

    final row = find.byKey(const ValueKey('account-account-b'));
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNotNull);
    expect(fixture.adapter.activationCalls, 0);
  });

  testWidgets('activate conflict keeps account A and exposes safe code', (
    tester,
  ) async {
    final fixture = await _pumpProductionRoute(
      tester,
      initialLocation: '/profile',
      activationConflict: true,
    );
    addTearDown(fixture.dispose);

    await tester.tap(find.byKey(const ValueKey('account-account-b')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fixture.adapter.activatedAccountIds, ['account-b']);
    expect(
      fixture.container
          .read(exV2AccountProvider)
          .requireValue!
          .bootstrap
          .account
          .id,
      'account-a',
    );
    expect(find.textContaining('concurrency_conflict'), findsOneWidget);
    expect(find.textContaining('corr-switch-safe'), findsOneWidget);
  });

  testWidgets(
    'activate success publishes B without any account A branch data',
    (tester) async {
      final fixture = await _pumpProductionRoute(
        tester,
        initialLocation: '/settings',
      );
      addTearDown(fixture.dispose);
      fixture.router.push('/profile');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-account-b')));
      await tester.pumpAndSettle();

      expect(fixture.adapter.activationCalls, 1);
      expect(fixture.adapter.activatedAccountIds, ['account-b']);
      expect(fixture.router.state.uri.path, '/settings');
      final state = fixture.container.read(exV2AccountProvider).requireValue!;
      expect(state.bootstrap.account.id, 'account-b');
      expect(state.bootstrap.summary.accountId, 'account-b');
      expect(state.positions.map((position) => position.id), ['position-b']);
      expect(
        state.positions.any((position) => position.id == 'position-a'),
        isFalse,
      );
      expect(
        state.historyPositions.any((position) => position.id == 'history-a'),
        isFalse,
      );
      expect(state.settings['scope'], isNot('A'));
      expect(fixture.container.read(activeDemoAccountProvider).id, 'LOGIN-A');
      expect(
        fixture.container.read(activeDemoAccountProvider).name,
        'Account B',
      );
      expect(
        fixture.container.read(demoPositionsProvider).map((item) => item.id),
        ['position-b'],
      );
      expect(
        fixture.container
            .read(demoHistoryPositionsProvider)
            .any((item) => item.id == 'history-a'),
        isFalse,
      );
      expect(
        fixture.container
            .read(exV2NotificationsProvider)
            .value
            ?.any((item) => item['scope'] == 'A'),
        isFalse,
      );
      expect(
        fixture.container
            .read(exV2WalletViewProvider)
            .value
            ?.wallet
            .totalBalance,
        20,
      );
    },
  );
}

Future<_RouteFixture> _pumpProductionRoute(
  WidgetTester tester, {
  required String initialLocation,
  bool activationFails = false,
  bool activationConflict = false,
  bool activationUnauthorized = false,
  bool activationAccountNotFound = false,
  bool accountListFails = false,
  _UnavailableAccountState? unavailableAccountState,
  Completer<ExV2AccountViewState?>? bootstrapGate,
  Stream<MarketConnectionStatus>? connectionStatuses,
  bool technicalYodoMetadata = false,
  bool accountListEmpty = false,
}) async {
  tester.view.physicalSize = const Size(384, 848);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final adapter = _AccountApiAdapter(
    activationFails: activationFails,
    activationConflict: activationConflict,
    activationUnauthorized: activationUnauthorized,
    activationAccountNotFound: activationAccountNotFound,
    accountListFails: accountListFails,
    technicalYodoMetadata: technicalYodoMetadata,
    accountListEmpty: accountListEmpty,
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  final accountOverride = bootstrapGate != null
      ? exV2AccountProvider.overrideWithBuild(
          (ref, controller) => bootstrapGate.future,
        )
      : switch (unavailableAccountState) {
          _UnavailableAccountState.loading =>
            exV2AccountProvider.overrideWithBuild(
              (ref, controller) => Completer<ExV2AccountViewState?>().future,
            ),
          _UnavailableAccountState.error =>
            exV2AccountProvider.overrideWithBuild(
              (ref, controller) => Future<ExV2AccountViewState?>.error(
                StateError('bootstrap unavailable'),
              ),
            ),
          null => exV2AccountProvider.overrideWithBuild(
            (ref, controller) => _accountAViewState(),
          ),
        };
  final container = ProviderContainer(
    overrides: [
      exV2EnabledProvider.overrideWithValue(true),
      exV2DioProvider.overrideWithValue(dio),
      deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
      marketConnectionStatusProvider.overrideWith(
        (ref) =>
            connectionStatuses ??
            Stream.value(MarketConnectionStatus.connected),
      ),
      accountOverride,
    ],
  );

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/accounts/add',
        builder: (context, state) =>
            const Scaffold(body: Text('BROKER DISCOVERY')),
      ),
      GoRoute(
        path: '/accounts/add/:brokerId',
        builder: (context, state) => Scaffold(
          key: const Key('existing-account-login-screen'),
          body: Text(
            '${state.uri.queryParameters['login'] ?? ''}|'
            '${state.uri.queryParameters['serverId'] ?? ''}',
          ),
        ),
      ),
      GoRoute(
        path: '/account-detail',
        builder: (context, state) => const Scaffold(body: Text('DETAIL')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const Scaffold(body: Text('OFFLINE REGISTRATION')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  if (unavailableAccountState != _UnavailableAccountState.loading &&
      bootstrapGate == null) {
    await tester.pumpAndSettle();
  }
  return _RouteFixture(container, router, adapter);
}

ExV2AccountViewState _accountAViewState() =>
    ExV2AccountViewState.fromBootstrap(
      ExV2Bootstrap.fromJson(_bootstrapA),
    ).copyWith(
      historyPositions: const [
        DemoHistoryPosition(
          id: 'history-a',
          title: 'A-HISTORY',
          profit: 1,
          time: '2026.08.16 08:00:00',
        ),
      ],
      notifications: const [
        {'id': 'notification-a', 'scope': 'A'},
      ],
      settings: const {'scope': 'A'},
    );

enum _UnavailableAccountState { loading, error }

final class _RouteFixture {
  const _RouteFixture(this.container, this.router, this.adapter);

  final ProviderContainer container;
  final GoRouter router;
  final _AccountApiAdapter adapter;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

final class _AccountApiAdapter implements HttpClientAdapter {
  _AccountApiAdapter({
    required this.activationFails,
    required this.activationConflict,
    required this.activationUnauthorized,
    required this.activationAccountNotFound,
    required this.accountListFails,
    required this.technicalYodoMetadata,
    required this.accountListEmpty,
  });

  final bool activationFails;
  final bool activationConflict;
  final bool activationUnauthorized;
  final bool activationAccountNotFound;
  final bool accountListFails;
  final bool technicalYodoMetadata;
  final bool accountListEmpty;
  int accountListCalls = 0;
  int activationCalls = 0;
  final List<String> activatedAccountIds = [];
  String activeAccountId = 'account-a';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) return _json(_bootstrapA);
    if (path.endsWith('/mobile/accounts')) {
      accountListCalls += 1;
      if (accountListFails) {
        return _json({
          'code': 'unavailable',
          'message': 'Unavailable',
        }, statusCode: 503);
      }
      if (accountListEmpty) return _json(<Object?>[]);
      return _json(
        technicalYodoMetadata
            ? [_linkedYodoB, _linkedYodoA]
            : [_linkedB, _linkedA],
      );
    }
    if (options.method == 'PUT' &&
        path.endsWith('/mobile/accounts/account-b/activate')) {
      activationCalls += 1;
      activatedAccountIds.add('account-b');
      if (activationUnauthorized) {
        return _json({
          'code': 'invalid_session',
          'message': 'Session authentication is required.',
          'correlationId': 'corr-legacy-auth',
        }, statusCode: 401);
      }
      if (activationAccountNotFound) {
        return _json({
          'code': 'account_not_found',
          'message': 'Linked account was not found.',
          'correlationId': 'corr-account-relink',
        }, statusCode: 404);
      }
      if (activationConflict) {
        return _json({
          'code': 'concurrency_conflict',
          'message': 'The operation conflicted with another account change.',
          'correlationId': 'corr-switch-safe',
        }, statusCode: 409);
      }
      if (activationFails) {
        return _json({
          'code': 'activation_failed',
          'message': 'Activation failed',
        }, statusCode: 500);
      }
      activeAccountId = 'account-b';
      return _json({
        'account': {..._linkedB, 'isActive': true},
        'bootstrap': _bootstrapB,
      });
    }
    if (path.endsWith('/settings')) {
      return _json({'scope': activeAccountId == 'account-a' ? 'A' : 'B'});
    }
    if (path.endsWith('/notifications')) {
      final scope = activeAccountId == 'account-a' ? 'A' : 'B';
      return _json([
        {'id': 'notification-${scope.toLowerCase()}', 'scope': scope},
      ]);
    }
    return _json(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _MemoryTokenStore implements DeviceTokenStore {
  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() async => 'device-token';

  @override
  Future<void> write(String token) async {}
}

ResponseBody _json(Object? value, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(value),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _linkedA = <String, Object?>{
  'id': 'account-a',
  'brokerId': 'broker-exness',
  'brokerName': 'Exness Technologies Ltd',
  'serverId': 'server-a',
  'serverName': 'Exness-MT5Trial',
  'login': 'LOGIN-A',
  'isActive': true,
  'displayName': 'Account A',
  'currency': 'USD',
  'balance': 100,
  'status': 'active',
};

const _linkedB = <String, Object?>{
  'id': 'account-b',
  'brokerId': 'broker-second',
  'brokerName': 'Second Broker Ltd',
  'serverId': 'server-b',
  'serverName': 'SecondBroker-MT5Real',
  'login': 'LOGIN-A',
  'isActive': false,
  'displayName': 'Account B',
  'currency': 'USD',
  'balance': 200,
  'status': 'active',
};

const _linkedYodoA = <String, Object?>{
  'id': 'account-a',
  'brokerId': 'yodo-demo',
  'brokerName': 'YODO Demo Markets',
  'serverId': 'yodo-demo-01',
  'serverName': 'YODO-Demo-01',
  'login': 'LOGIN-A',
  'isActive': true,
  'displayName': 'Account A',
  'currency': 'USD',
  'status': 'active',
};

const _linkedYodoB = <String, Object?>{
  'id': 'account-b',
  'brokerId': 'yodo-demo',
  'brokerName': 'YODO Demo Markets',
  'serverId': 'yodo-demo-01',
  'serverName': 'YODO-Demo-01',
  'login': 'LOGIN-B',
  'isActive': false,
  'displayName': 'Account B',
  'currency': 'USD',
  'status': 'active',
};

const _bootstrapA = <String, Object?>{
  'serverTime': '2026-08-16T08:00:00Z',
  'version': 1,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-a',
    'accountCode': 'LOGIN-A',
    'name': 'Account A',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-a',
    'currency': 'USD',
    'balance': 100,
    'equity': 100,
    'profit': 0,
    'margin': 0,
    'freeMargin': 100,
    'marginLevel': 0,
    'updatedAt': '2026-08-16T08:00:00Z',
  },
  'positions': [
    {
      'id': 'position-a',
      'symbol': 'A-SYMBOL',
      'side': 'BUY',
      'initialVolume': 0.01,
      'remainingVolume': 0.01,
      'entryPrice': 100,
      'realizedProfit': 0,
      'status': 'open',
      'createdAt': '2026-08-16T08:00:00Z',
    },
  ],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 10,
    'lockedBalance': 0,
    'totalBalance': 10,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};

const _bootstrapB = <String, Object?>{
  'serverTime': '2026-08-16T08:01:00Z',
  'version': 2,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-b',
    'accountCode': 'LOGIN-A',
    'name': 'Account B',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-b',
    'currency': 'USD',
    'balance': 200,
    'equity': 200,
    'profit': 0,
    'margin': 0,
    'freeMargin': 200,
    'marginLevel': 0,
    'updatedAt': '2026-08-16T08:01:00Z',
  },
  'positions': [
    {
      'id': 'position-b',
      'symbol': 'B-SYMBOL',
      'side': 'BUY',
      'initialVolume': 0.02,
      'remainingVolume': 0.02,
      'entryPrice': 200,
      'realizedProfit': 0,
      'status': 'open',
      'createdAt': '2026-08-16T08:01:00Z',
    },
  ],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 20,
    'lockedBalance': 0,
    'totalBalance': 20,
  },
  'performance': {
    'netProfit': 0,
    'grossProfit': 0,
    'grossLoss': 0,
    'floatingProfit': 0,
    'tradingVolume': 0,
    'updatedAt': null,
    'integrityWarnings': 0,
  },
  'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
  'integrityWarnings': 0,
};
