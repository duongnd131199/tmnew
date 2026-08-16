import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/app/router.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/broker_list_screen.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/trading_server_screen.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  testWidgets(
    'broker frame exposes reference controls, rows, and text search',
    (tester) async {
      final repository = _CatalogRepository();
      MobileBroker? infoBroker;
      var qrTaps = 0;

      await _pump(
        tester,
        repository: repository,
        child: BrokerListScreen(
          onQrPressed: () => qrTaps += 1,
          onBrokerInfo: (broker) => infoBroker = broker,
        ),
      );

      expect(find.text('Brokers'), findsOneWidget);
      expect(find.byKey(const Key('account-link-back-button')), findsOneWidget);
      expect(find.byKey(const Key('account-link-qr-button')), findsOneWidget);
      expect(find.text('Exness Technologies Ltd'), findsOneWidget);
      expect(find.text('Exness'), findsOneWidget);
      expect(find.text('MetaQuotes Ltd.'), findsOneWidget);
      expect(find.text('MetaQuotes'), findsOneWidget);
      expect(find.byKey(const Key('broker-info-exness')), findsOneWidget);
      expect(find.byKey(const Key('broker-info-metaquotes')), findsOneWidget);
      expect(find.byKey(const Key('broker-mark-exness')), findsOneWidget);
      expect(find.byKey(const Key('broker-mark-metaquotes')), findsOneWidget);

      final search = tester.widget<TextField>(
        find.byKey(const Key('broker-search-field')),
      );
      expect(search.keyboardType, TextInputType.text);
      expect(
        search.decoration?.hintText,
        'Vui lòng nhập tên công ty hoặc máy chủ',
      );

      await tester.tap(find.byKey(const Key('broker-info-metaquotes')));
      await tester.tap(find.byKey(const Key('account-link-qr-button')));
      expect(infoBroker?.id, 'metaquotes');
      expect(qrTaps, 1);
    },
  );

  testWidgets('broker search filters immediately and sends a debounced query', (
    tester,
  ) async {
    final repository = _CatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
    );

    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'meta',
    );
    await tester.pump();

    expect(find.text('Exness Technologies Ltd'), findsNothing);
    expect(find.text('MetaQuotes Ltd.'), findsOneWidget);
    expect(repository.brokerQueries, ['']);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(repository.brokerQueries, ['', 'meta']);
    expect(find.text('MetaQuotes Ltd.'), findsOneWidget);
  });

  testWidgets('catalog text retains its semantic typography family', (
    tester,
  ) async {
    final repository = _CatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
    );

    expect(
      tester.widget<Text>(find.text('EX')).style?.fontFamily,
      AppTypography.caption.fontFamily,
    );
    expect(
      tester
          .widget<Text>(find.text('Exness Technologies Ltd'))
          .style
          ?.fontFamily,
      AppTypography.titleMedium.fontFamily,
    );

    await _pump(
      tester,
      repository: repository,
      child: const TradingServerScreen(brokerId: 'exness'),
    );
    expect(
      tester.widget<Text>(find.text('Exness-MT5Real1')).style?.fontFamily,
      AppTypography.titleMedium.fontFamily,
    );
  });

  testWidgets('server-matched broker survives authoritative search response', (
    tester,
  ) async {
    final repository = _ServerNameSearchRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
    );

    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'MT5Real20',
    );
    await tester.pump();
    expect(find.text('Exness Technologies Ltd'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(repository.brokerQueries, ['', 'MT5Real20']);
    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
  });

  testWidgets('selecting a broker cancels its queued search request', (
    tester,
  ) async {
    final repository = _CatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: BrokerListScreen(onBrokerSelected: (_) {}),
    );

    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'meta',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('broker-row-metaquotes')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.brokerQueries, ['']);
  });

  testWidgets('a stale broker response never replaces the newer query', (
    tester,
  ) async {
    final repository = _DeferredCatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
    );

    await tester.enterText(find.byKey(const Key('broker-search-field')), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('broker-search-field')), 'new');
    await tester.pump(const Duration(milliseconds: 300));

    repository.complete('new', const [
      MobileBroker(id: 'new-broker', name: 'New Brokerage'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('New Brokerage'), findsOneWidget);

    repository.complete('old', const [
      MobileBroker(id: 'old-broker', name: 'Old Brokerage'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('New Brokerage'), findsOneWidget);
    expect(find.text('Old Brokerage'), findsNothing);
  });

  testWidgets('an earlier A response cannot authorize B results after A-B-A', (
    tester,
  ) async {
    final repository = _AbaCatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
    );

    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'alpha',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'beta',
    );
    await tester.pump(const Duration(milliseconds: 300));

    repository.complete('beta', 0, const [
      MobileBroker(id: 'beta-broker', name: 'Beta Brokerage'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Beta Brokerage'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('broker-search-field')),
      'alpha',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Beta Brokerage'), findsNothing);

    repository.complete('alpha', 0, const [
      MobileBroker(id: 'stale-alpha', name: 'Stale Alpha Brokerage'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Beta Brokerage'), findsNothing);

    repository.complete('alpha', 1, const [
      MobileBroker(id: 'latest-alpha', name: 'Latest Alpha Brokerage'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Latest Alpha Brokerage'), findsOneWidget);
  });

  testWidgets('broker load failure stays visible and retry uses the server', (
    tester,
  ) async {
    final repository = _RetryCatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const BrokerListScreen(),
      settle: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('broker-catalog-error')), findsOneWidget);
    expect(find.text('Unable to link this account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('broker-catalog-retry')));
    await tester.pump();
    await tester.pump();

    expect(repository.calls, 2);
    expect(find.text('Exness Technologies Ltd'), findsOneWidget);
    expect(find.byKey(const Key('broker-catalog-error')), findsNothing);
  });

  testWidgets('broker selection uses the stable account form route', (
    tester,
  ) async {
    final repository = _CatalogRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountLinkRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: appRouter,
        ),
      ),
    );
    addTearDown(() => appRouter.go('/'));

    appRouter.go('/accounts/add');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('broker-row-exness')));
    await tester.pumpAndSettle();

    expect(appRouter.state.uri.path, '/accounts/add/exness');
  });

  testWidgets('server frame scrolls and returns the selected server to form', (
    tester,
  ) async {
    final repository = _CatalogRepository();
    MobileTradingServer? callbackValue;

    await _pump(
      tester,
      repository: repository,
      child: _ServerSelectionHarness(
        onSelected: (server) => callbackValue = server,
      ),
    );
    await tester.tap(find.byKey(const Key('open-server-list')));
    await tester.pumpAndSettle();

    expect(find.text('Máy chủ'), findsOneWidget);
    expect(find.byKey(const Key('account-link-back-button')), findsOneWidget);
    expect(find.byKey(const Key('server-list')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('server-row-server-1'))).height,
      56,
    );
    expect(find.byKey(const Key('server-divider-server-1')), findsOneWidget);
    expect(find.text('Exness-MT5Real15'), findsNothing);

    await tester.drag(
      find.byKey(const Key('server-list')),
      const Offset(0, -760),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exness-MT5Real15'), findsOneWidget);

    await tester.tap(find.text('Exness-MT5Real15'));
    await tester.pumpAndSettle();

    expect(callbackValue?.id, 'server-15');
    expect(find.text('FORM SERVER: Exness-MT5Real15'), findsOneWidget);
  });

  testWidgets('server load failure offers a real retry without fixture data', (
    tester,
  ) async {
    final repository = _RetryServerRepository();
    await _pump(
      tester,
      repository: repository,
      child: const TradingServerScreen(brokerId: 'exness'),
      settle: false,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('server-catalog-error')), findsOneWidget);
    expect(find.text('Unable to link this account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('server-catalog-retry')));
    await tester.pump();
    await tester.pump();

    expect(repository.serverCalls, 2);
    expect(find.text('Exness-MT5Real20'), findsOneWidget);
  });

  testWidgets('server route retry reloads its broker before server discovery', (
    tester,
  ) async {
    final repository = _RetryRouteCatalogRepository();
    await _pump(
      tester,
      repository: repository,
      child: const TradingServerScreen(brokerId: 'exness'),
      settle: false,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('server-catalog-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('server-catalog-retry')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.brokerCalls, 2);
    expect(repository.serverCalls, 1);
    expect(find.text('Exness-MT5Real20'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required AccountLinkRepository repository,
  required Widget child,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountLinkRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.dark, home: child),
    ),
  );
  if (settle) {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }
}

final class _ServerSelectionHarness extends StatefulWidget {
  const _ServerSelectionHarness({required this.onSelected});

  final ValueChanged<MobileTradingServer> onSelected;

  @override
  State<_ServerSelectionHarness> createState() =>
      _ServerSelectionHarnessState();
}

final class _ServerSelectionHarnessState
    extends State<_ServerSelectionHarness> {
  String? serverName;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ElevatedButton(
          key: const Key('open-server-list'),
          onPressed: () async {
            final selected = await Navigator.of(context)
                .push<MobileTradingServer>(
                  MaterialPageRoute(
                    builder: (_) => TradingServerScreen(
                      brokerId: 'exness',
                      onSelected: widget.onSelected,
                    ),
                  ),
                );
            if (selected != null) setState(() => serverName = selected.name);
          },
          child: const Text('OPEN'),
        ),
        Text('FORM SERVER: ${serverName ?? 'none'}'),
      ],
    ),
  );
}

class _CatalogRepository implements AccountLinkRepository {
  final List<String> brokerQueries = <String>[];

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async {
    brokerQueries.add(query);
    final normalized = query.trim().toLowerCase();
    return _brokers
        .where(
          (broker) =>
              normalized.isEmpty ||
              broker.name.toLowerCase().contains(normalized) ||
              (broker.companyName?.toLowerCase().contains(normalized) ?? false),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async => List<MobileTradingServer>.generate(
    20,
    (index) => MobileTradingServer(
      id: 'server-${index + 1}',
      name: index == 14 ? 'Exness-MT5Real15' : 'Exness-MT5Real${index + 1}',
      brokerId: brokerId,
    ),
  );

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();
}

final class _DeferredCatalogRepository extends _CatalogRepository {
  final Map<String, Completer<List<MobileBroker>>> _requests = {};

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) {
    brokerQueries.add(query);
    if (query.isEmpty) return Future.value(_brokers);
    return (_requests[query] ??= Completer<List<MobileBroker>>()).future;
  }

  void complete(String query, List<MobileBroker> value) =>
      _requests[query]!.complete(value);
}

final class _AbaCatalogRepository extends _CatalogRepository {
  final Map<String, List<Completer<List<MobileBroker>>>> _requests = {};

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) {
    brokerQueries.add(query);
    if (query.isEmpty) return Future.value(_brokers);
    final completer = Completer<List<MobileBroker>>();
    (_requests[query] ??= []).add(completer);
    return completer.future;
  }

  void complete(String query, int index, List<MobileBroker> value) =>
      _requests[query]![index].complete(value);
}

final class _ServerNameSearchRepository extends _CatalogRepository {
  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async {
    brokerQueries.add(query);
    if (query == 'MT5Real20') return [_brokers.first];
    return _brokers;
  }
}

final class _RetryCatalogRepository extends _CatalogRepository {
  int calls = 0;

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async {
    calls += 1;
    if (calls == 1) throw StateError('catalog offline');
    return _brokers;
  }
}

final class _RetryServerRepository extends _CatalogRepository {
  int serverCalls = 0;

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async {
    serverCalls += 1;
    if (serverCalls == 1) throw StateError('servers offline');
    return const [
      MobileTradingServer(
        id: 'server-20',
        name: 'Exness-MT5Real20',
        brokerId: 'exness',
      ),
    ];
  }
}

final class _RetryRouteCatalogRepository extends _CatalogRepository {
  int brokerCalls = 0;
  int serverCalls = 0;

  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async {
    brokerCalls += 1;
    if (brokerCalls == 1) throw StateError('broker catalog offline');
    return _brokers;
  }

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async {
    serverCalls += 1;
    return const [
      MobileTradingServer(
        id: 'server-20',
        name: 'Exness-MT5Real20',
        brokerId: 'exness',
      ),
    ];
  }
}

const _brokers = [
  MobileBroker(
    id: 'exness',
    name: 'Exness Technologies Ltd',
    companyName: 'Exness',
  ),
  MobileBroker(
    id: 'metaquotes',
    name: 'MetaQuotes Ltd.',
    companyName: 'MetaQuotes',
  ),
];
