import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('production uses the public paths before the Nginx V2 rewrite', () {
    expect(
      ExV2Config.production.restBaseUrl,
      'https://trochoi.top/ex/v2/api',
    );
    expect(
      ExV2Config.production.hubUrl,
      'https://trochoi.top/ex/v2/hubs/trading',
    );
  });

  test('production loading never exposes offline fixture accounts', () {
    final gate = Completer<ExV2AccountViewState?>();
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild((ref, controller) => gate.future),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(demoAccountsProvider), isEmpty);
    expect(
      () => container.read(activeDemoAccountProvider),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('authorized server account'),
        ),
      ),
    );
  });

  test('production account provider starts from server bootstrap', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter();
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(exV2AccountProvider.future);

    expect(state, isNotNull);
    expect(state!.accountCode, 'TEST-100');
    expect(state.balance, 5000);
    final accounts = container.read(demoAccountsProvider);
    expect(accounts, hasLength(1));
    expect(accounts.single.id, 'TEST-100');
    expect(accounts.single.company, 'Trading Account');
    expect(accounts.single.server, 'Trading Server');
    expect(accounts.single.accessPoint, 'Access Point #1');
  });

  test('initial bootstrap retries one transient server failure', () async {
    final adapter = _TransientBootstrapAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container
        .read(exV2AccountProvider.future)
        .timeout(const Duration(seconds: 2));

    expect(state?.accountCode, 'TEST-100');
    expect(adapter.bootstrapCalls, 2);
  });

  test('empty account API never exposes a local-only account', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter();
    FlutterSecureStorage.setMockInitialValues({
      'ex_v2_account_sessions_v1': jsonEncode([
        {
          'account': {'id': 'account-2', 'login': 'TEST-200'},
          'deviceToken': 'legacy-token-account-2',
        },
      ]),
    });
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final linkedSubscription = container.listen(
      linkedTradingAccountsProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(linkedSubscription.close);

    await container.read(exV2AccountProvider.future);
    await container.read(linkedTradingAccountsProvider.future);

    final accounts = container.read(demoAccountsProvider);
    expect(accounts.map((account) => account.linkedAccountId), ['account-1']);
  });

  test('linked account activation uses the server catalog', () async {
    final adapter = _BootstrapAdapter(includeLinkedAccounts: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    await container.read(linkedTradingAccountsProvider.future);

    final result = await container
        .read(linkedTradingAccountsProvider.notifier)
        .activate('account-2');

    expect(adapter.activationCalls, 1);
    expect(result?.account.id, 'account-2');
  });

  test('bootstrap becomes visible before slower history endpoints', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter(
        historyDelay: const Duration(seconds: 1),
      );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container
        .read(exV2AccountProvider.future)
        .timeout(const Duration(milliseconds: 250));

    expect(state?.balance, 5000);
  });

  test('production paged history contracts hydrate all history tabs', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = _BootstrapAdapter(productionHistory: true);
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(exV2AccountProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final state = container.read(exV2AccountProvider).value!;

    expect(state.orders.single.id, 'history-order-1');
    expect(state.deals, hasLength(2));
    expect(state.deals.every((deal) => deal.entry == 'out'), isTrue);
    final tradingHistory = state.historyPositions.singleWhere(
      (entry) => entry.id == 'history-position-1',
    );
    expect(tradingHistory.volume, 0.01);
    expect(tradingHistory.closePrice, closeTo(4369.4, 0.000001));
    expect(tradingHistory.profit, -0.77);
    final balanceHistory = state.historyPositions
        .where((entry) => entry.isBalance)
        .toList(growable: false);
    expect(balanceHistory.map((entry) => entry.subtitle), [
      'D-ALLINT-USD-INT-924750483461',
      'W-BANKVNGT-USD-1475391737862',
    ]);
    expect(balanceHistory.map((entry) => entry.profit), [518.54, -2000]);
    final profile = container.read(demoAccountsProvider).single;
    expect(profile.historyDeposit, 1200);
    expect(profile.historyWithdrawal, -300);
    expect(profile.historyProfit, -12.34);
    expect(profile.historySwap, -1.25);
    expect(profile.historyCommission, -2.5);
  });

  test(
    'deposit rows never replace the canonical history summary total',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = _BootstrapAdapter(
          productionHistory: true,
          historySummaryDeposit: 0,
          depositRows: const [
            {
              'id': 'deposit-completed',
              'accountId': 'account-1',
              'amount': 518.54,
              'currency': 'USD',
              'method': 'demo',
              'reference': 'completed',
              'status': 'approved',
              'createdAtUtc': '2026-07-21T02:28:53Z',
              'updatedAtUtc': '2026-07-21T02:31:53Z',
              'approvedAtUtc': '2026-07-21T02:31:53Z',
              'rejectedAtUtc': null,
              'transactionId': '11111111-1111-4111-8111-111111111111',
              'snapshotVersion': 2,
            },
            {
              'id': 'deposit-pending',
              'accountId': 'account-1',
              'amount': 100,
              'currency': 'USD',
              'method': 'demo',
              'reference': 'pending',
              'status': 'pending',
              'createdAtUtc': '2026-07-22T02:28:53Z',
              'updatedAtUtc': '2026-07-22T02:28:53Z',
              'approvedAtUtc': null,
              'rejectedAtUtc': null,
              'transactionId': null,
              'snapshotVersion': 3,
            },
            {
              'id': 'deposit-rejected',
              'accountId': 'account-1',
              'amount': 20,
              'currency': 'USD',
              'method': 'demo',
              'reference': 'rejected',
              'status': 'rejected',
              'createdAtUtc': '2026-07-23T02:28:53Z',
              'updatedAtUtc': '2026-07-23T02:31:53Z',
              'approvedAtUtc': null,
              'rejectedAtUtc': '2026-07-23T02:31:53Z',
              'transactionId': null,
              'snapshotVersion': 4,
            },
          ],
        );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(exV2AccountProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final profile = container.read(activeDemoAccountProvider);
      expect(profile.historyDeposit, 0);
    },
  );

  test(
    'wallet transactions never replace the canonical summary total',
    () async {
      const reference = 'D-ALLINT-USD-INT-924750483461';
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = _BootstrapAdapter(
          productionHistory: true,
          historySummaryDeposit: 0,
          historyTransactionRows: const [
            {
              'id': 'transaction-deposit',
              'type': 'deposit',
              'amount': 75,
              'currency': 'USD',
              'status': 'completed',
              'reference': reference,
              'completedAtUtc': '2026-07-21T02:28:53Z',
            },
          ],
          depositRows: const [],
        );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(exV2AccountProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(activeDemoAccountProvider).historyDeposit, 0);
    },
  );

  test('deposit transport retry reuses one idempotency key', () async {
    final adapter = _BootstrapAdapter(depositTransportFailures: 1);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    await container
        .read(exV2AccountProvider.notifier)
        .createWalletRequest(isDeposit: true, amount: 500, note: 'retry');

    expect(adapter.depositPosts, 2);
    expect(adapter.depositIdempotencyKeys.toSet(), hasLength(1));
    expect(
      container.read(exV2AccountProvider).requireValue!.deposits,
      hasLength(1),
    );
  });

  test('transient history failure preserves the confirmed snapshot', () async {
    final adapter = _BootstrapAdapter(productionHistory: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(exV2AccountProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final confirmed = container.read(exV2AccountProvider).value!;
    expect(confirmed.deals, hasLength(2));
    final confirmedTradingHistory = confirmed.historyPositions.singleWhere(
      (entry) => !entry.isBalance,
    );
    expect(confirmedTradingHistory.closePrice, isNotNull);

    adapter.failHistoryDeals = true;
    await container.read(exV2AccountProvider.notifier).refresh();
    final afterFailure = container.read(exV2AccountProvider).value!;

    expect(afterFailure.deals.map((deal) => deal.id), [
      'history-deal-1',
      'history-deal-2',
    ]);
    final tradingHistoryAfterFailure = afterFailure.historyPositions
        .singleWhere((entry) => !entry.isBalance);
    expect(
      tradingHistoryAfterFailure.closePrice,
      confirmedTradingHistory.closePrice,
    );
  });

  test('deposit is not shown before the server confirms HTTP 201', () async {
    final gate = Completer<void>();
    final adapter = _BootstrapAdapter(mutationGate: gate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);

    final submitting = container
        .read(exV2AccountProvider.notifier)
        .createWalletRequest(isDeposit: true, amount: 500, note: 'demo');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exV2AccountProvider).value?.deposits, isEmpty);
    gate.complete();
    await submitting;
  });

  test(
    'pending deposit stays visible in History while the server list lags',
    () async {
      final gate = Completer<void>();
      final adapter = _BootstrapAdapter(mutationGate: gate);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final controller = container.read(exV2AccountProvider.notifier);

      final submitting = controller.createWalletRequest(
        isDeposit: true,
        amount: 5000000,
        note: 'deposit-five-million',
      );
      await Future<void>.delayed(Duration.zero);

      var accountState = container.read(exV2AccountProvider).requireValue!;
      expect(accountState.deposits, isEmpty);
      expect(
        accountState.historyPositions.where(
          (entry) => entry.id.startsWith('wallet-'),
        ),
        isEmpty,
      );
      expect(accountState.historySummary.deposit, 0);

      gate.complete();
      await submitting;
      await controller.refresh(queueAfterInFlight: true);

      accountState = container.read(exV2AccountProvider).requireValue!;
      expect(accountState.deposits.single['status'], 'pending');
      final pendingRows = accountState.historyPositions
          .where((entry) => entry.id.startsWith('wallet-'))
          .toList(growable: false);
      expect(
        pendingRows,
        hasLength(1),
        reason: pendingRows
            .map((entry) => '${entry.id}|${entry.profit}|${entry.subtitle}')
            .join('\n'),
      );
      expect(pendingRows.single.profit, 5000000);
      expect(accountState.historySummary.deposit, 0);
    },
  );

  test(
    'approved status without a decision snapshot never fabricates totals',
    () async {
      final adapter = _BootstrapAdapter(depositMutationStatus: 'approved');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final controller = container.read(exV2AccountProvider.notifier);

      await controller.createWalletRequest(
        isDeposit: true,
        amount: 5000000,
        note: 'completed-five-million',
      );

      var accountState = container.read(exV2AccountProvider).requireValue!;
      expect(accountState.historySummary.deposit, 0);
      expect(
        accountState.historyPositions
            .singleWhere((entry) => entry.id.startsWith('wallet-'))
            .profit,
        5000000,
      );

      await controller.refresh(queueAfterInFlight: true);

      accountState = container.read(exV2AccountProvider).requireValue!;
      expect(accountState.historySummary.deposit, 0);
      final completedRows = accountState.historyPositions
          .where((entry) => entry.id.startsWith('wallet-'))
          .toList(growable: false);
      expect(completedRows, hasLength(1));
      expect(completedRows.single.profit, 5000000);
    },
  );

  test('notification becomes read before the server responds', () async {
    final gate = Completer<void>();
    final adapter = _BootstrapAdapter(
      mutationGate: gate,
      includeNotification: true,
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final marking = container
        .read(exV2AccountProvider.notifier)
        .markNotificationRead('notification-1');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exV2AccountProvider).value?.notifications.single['isRead'],
      isTrue,
    );
    gate.complete();
    await marking;
  });

  test(
    'an in-flight mutation cannot publish into a replacement bootstrap',
    () async {
      final orderGate = Completer<void>();
      final adapter = _AccountSwitchAdapter(orderGate);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      final controller = container.read(exV2AccountProvider.notifier);

      final creating = controller.createOrder(
        symbol: 'XAUUSD+',
        side: 'buy',
        volume: 0.01,
        commandMetadata: const ExV2CommandMetadata(
          idempotencyKey: 'old-account-order',
          correlationId: 'old-account-correlation',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      controller.publishBootstrap(
        ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
      );
      orderGate.complete();
      await creating;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(exV2AccountProvider).requireValue!;
      expect(state.bootstrap.account.id, 'account-2');
      expect(state.bootstrap.summary.accountId, 'account-2');
      expect(state.orders, isEmpty);
      expect(state.pendingOperationIds, isEmpty);
    },
  );

  test('stale hydration cannot overwrite a replacement bootstrap', () async {
    final historyGate = Completer<void>();
    final adapter = _HydrationSwitchAdapter(historyGate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    while (adapter.historyOrderCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    container
        .read(exV2AccountProvider.notifier)
        .publishBootstrap(
          ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
        );
    historyGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.account.id, 'account-2');
    expect(state.orders, isEmpty);
  });

  test('stale refresh cannot overwrite a replacement bootstrap', () async {
    final refreshGate = Completer<void>();
    final adapter = _RefreshSwitchAdapter(refreshGate);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(
          _MemoryTokenStore('test-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    final controller = container.read(exV2AccountProvider.notifier);

    final refreshing = controller.refresh();
    while (adapter.bootstrapCalls < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.publishBootstrap(
      ExV2Bootstrap.fromJson(_bootstrapForAccount('account-2', 'TEST-200')),
    );
    refreshGate.complete();
    await refreshing;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.account.id, 'account-2');
    expect(state.bootstrap.summary.accountId, 'account-2');
  });

  test(
    'account generation changes only when a different bootstrap is committed',
    () async {
      final adapter = _GenerationAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(
            _MemoryTokenStore('test-token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(exV2AccountGenerationProvider);
      await container.read(exV2AccountProvider.future);
      await Future<void>.delayed(Duration.zero);
      final accountA = container.read(exV2AccountGenerationProvider);
      expect(accountA.accountId, 'account-1');

      adapter.failBootstrap = true;
      await container.read(exV2AccountProvider.notifier).refresh();
      expect(container.read(exV2AccountProvider).hasError, isFalse);
      expect(
        container
            .read(exV2AccountProvider)
            .requireValue!
            .bootstrap
            .summary
            .balance,
        5000,
      );
      expect(container.read(exV2AccountGenerationProvider), accountA);

      adapter.failBootstrap = false;
      await container.read(exV2AccountProvider.notifier).refresh();
      expect(container.read(exV2AccountGenerationProvider), accountA);

      container
          .read(exV2AccountProvider.notifier)
          .publishBootstrap(
            ExV2Bootstrap.fromJson(
              _bootstrapForAccount('account-1', 'TEST-100-REFRESHED'),
            ),
          );
      expect(container.read(exV2AccountGenerationProvider), accountA);

      container
          .read(exV2AccountProvider.notifier)
          .publishBootstrap(
            ExV2Bootstrap.fromJson(
              _bootstrapForAccount('account-2', 'TEST-200'),
            ),
          );
      final accountB = container.read(exV2AccountGenerationProvider);
      expect(accountB.accountId, 'account-2');
      expect(accountB.value, accountA.value + 1);
    },
  );
}

final class _TransientBootstrapAdapter implements HttpClientAdapter {
  int bootstrapCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      bootstrapCalls += 1;
      if (bootstrapCalls == 1) {
        return ResponseBody.fromString(
          jsonEncode({
            'code': 'INTERNAL_ERROR',
            'message': 'Temporary server failure',
          }),
          503,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _GenerationAdapter implements HttpClientAdapter {
  bool failBootstrap = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      if (failBootstrap) {
        return ResponseBody.fromString(
          jsonEncode({'code': 'unavailable', 'message': 'Unavailable'}),
          503,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _HydrationSwitchAdapter implements HttpClientAdapter {
  _HydrationSwitchAdapter(this.historyGate);

  final Completer<void> historyGate;
  int historyOrderCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/history/orders')) {
      historyOrderCalls += 1;
      if (historyOrderCalls == 1) {
        await historyGate.future;
        return _response([
          {
            'id': 'old-history-order',
            'accountCode': 'TEST-100',
            'symbol': 'XAUUSD+',
            'side': 'buy',
            'volume': 0.01,
            'openPrice': 4300,
            'profit': 1,
            'openedAt': '2026-08-16T08:00:00Z',
            'status': 'closed',
          },
        ]);
      }
      return _response(<Object?>[]);
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

final class _RefreshSwitchAdapter implements HttpClientAdapter {
  _RefreshSwitchAdapter(this.refreshGate);

  final Completer<void> refreshGate;
  int bootstrapCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/mobile/bootstrap')) {
      bootstrapCalls += 1;
      if (bootstrapCalls > 1) await refreshGate.future;
      return _response(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (path.endsWith('/settings')) return _response(<String, Object?>{});
    return _response(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

final class _AccountSwitchAdapter implements HttpClientAdapter {
  _AccountSwitchAdapter(this.orderGate);

  final Completer<void> orderGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.uri.path.endsWith('/orders')) {
      await orderGate.future;
      return _jsonResponse({
        'id': 'server-order-old-account',
        'clientOrderId': 'old-account-order',
        'symbol': 'XAUUSD+',
        'type': 'market',
        'side': 'buy',
        'volume': 0.01,
        'requestedPrice': null,
        'executedPrice': 4300,
        'stopLoss': null,
        'takeProfit': null,
        'status': 'filled',
        'createdAt': '2026-08-16T08:00:00Z',
        'version': 1,
        'rowVersion': null,
      });
    }
    if (options.uri.path.endsWith('/mobile/bootstrap')) {
      return _jsonResponse(_bootstrapForAccount('account-1', 'TEST-100'));
    }
    if (options.uri.path.endsWith('/settings')) {
      return _jsonResponse(<String, Object?>{});
    }
    return _jsonResponse(<Object?>[]);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _jsonResponse(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _bootstrapForAccount(String id, String code) => {
  ..._bootstrap,
  'version': id == 'account-1' ? 1 : 2,
  'activeAccount': {
    ..._bootstrap['activeAccount']! as Map<String, Object?>,
    'id': id,
    'accountCode': code,
  },
  'summary': {
    ..._bootstrap['summary']! as Map<String, Object?>,
    'accountId': id,
  },
};

final class _MemoryTokenStore implements DeviceTokenStore {
  _MemoryTokenStore(this.value);
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

final class _BootstrapAdapter implements HttpClientAdapter {
  _BootstrapAdapter({
    this.historyDelay = Duration.zero,
    this.productionHistory = false,
    this.mutationGate,
    this.includeNotification = false,
    this.includeLinkedAccounts = false,
    this.historySummaryDeposit = 1200,
    this.depositRows,
    this.historyTransactionRows,
    this.depositMutationStatus = 'pending',
    int depositTransportFailures = 0,
  }) : remainingDepositTransportFailures = depositTransportFailures;

  final Duration historyDelay;
  final bool productionHistory;
  final Completer<void>? mutationGate;
  final bool includeNotification;
  final bool includeLinkedAccounts;
  final double historySummaryDeposit;
  final List<Map<String, Object?>>? depositRows;
  final List<Map<String, Object?>>? historyTransactionRows;
  final String depositMutationStatus;
  int remainingDepositTransportFailures;
  int depositPosts = 0;
  final List<String> depositIdempotencyKeys = <String>[];
  bool failHistoryDeals = false;
  int activationCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (options.method == 'PUT' &&
        path.endsWith('/mobile/accounts/account-2/activate')) {
      activationCalls += 1;
      return _jsonResponse({
        'account': {
          'id': 'account-2',
          'brokerId': 'exness-demo',
          'brokerName': 'Exness',
          'serverId': 'exness-demo',
          'serverName': 'Exness-MT5Trial',
          'login': 'TEST-200',
          'isActive': true,
          'displayName': null,
          'currency': 'USD',
          'status': 'active',
        },
        'bootstrap': _bootstrapForAccount('account-2', 'TEST-200'),
      });
    }
    if (options.method == 'GET' && path.endsWith('/mobile/accounts')) {
      return _jsonResponse(
        includeLinkedAccounts
            ? [
                {
                  'id': 'account-1',
                  'brokerId': 'exness-demo',
                  'brokerName': 'Exness',
                  'serverId': 'exness-demo',
                  'serverName': 'Exness-MT5Trial',
                  'login': 'TEST-100',
                  'isActive': true,
                  'displayName': null,
                  'currency': 'USD',
                  'status': 'active',
                },
                {
                  'id': 'account-2',
                  'brokerId': 'exness-demo',
                  'brokerName': 'Exness',
                  'serverId': 'exness-demo',
                  'serverName': 'Exness-MT5Trial',
                  'login': 'TEST-200',
                  'isActive': false,
                  'displayName': null,
                  'currency': 'USD',
                  'status': 'active',
                },
              ]
            : const <Object?>[],
      );
    }
    if (failHistoryDeals && path.endsWith('/history/deals')) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 'HISTORY_UNAVAILABLE',
          'message': 'History is temporarily unavailable',
        }),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/deposits') && options.method == 'POST') {
      depositPosts += 1;
      depositIdempotencyKeys.add(
        options.headers['Idempotency-Key']?.toString() ?? '',
      );
      if (remainingDepositTransportFailures > 0) {
        remainingDepositTransportFailures -= 1;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'synthetic connection failure',
        );
      }
      await mutationGate?.future;
      final body = (options.data as Map).cast<String, Object?>();
      return _jsonResponse({
        'id': '11111111-1111-4111-8111-111111111111',
        'accountId': 'account-1',
        'amount': body['amount'],
        'currency': body['currency'],
        'method': body['method'],
        'reference': body['reference'],
        'status': depositMutationStatus,
        'createdAtUtc': '2026-08-13T08:01:00Z',
        'updatedAtUtc': '2026-08-13T08:01:00Z',
        'approvedAtUtc': depositMutationStatus == 'approved'
            ? '2026-08-13T08:01:00Z'
            : null,
        'rejectedAtUtc': null,
        'transactionId': depositMutationStatus == 'approved'
            ? '22222222-2222-4222-8222-222222222222'
            : null,
        'snapshotVersion': 2,
      }, statusCode: 201);
    }
    if (path.endsWith('/notifications/notification-1/read') &&
        options.method == 'PUT') {
      await mutationGate?.future;
      return _jsonResponse(<String, Object?>{});
    }
    if (!options.uri.path.endsWith('/mobile/bootstrap')) {
      await Future<void>.delayed(historyDelay);
    }
    final historyPayload = productionHistory
        ? _productionHistoryPayload(
            options.uri.path,
            historySummaryDeposit: historySummaryDeposit,
            depositRows: depositRows,
            historyTransactionRows: historyTransactionRows,
          )
        : null;
    if (includeNotification && path.endsWith('/notifications')) {
      return _jsonResponse([
        {'id': 'notification-1', 'title': 'Update', 'isRead': false},
      ]);
    }
    return ResponseBody.fromString(
      jsonEncode(
        options.uri.path.endsWith('/mobile/bootstrap')
            ? _bootstrap
            : options.uri.path.endsWith('/settings')
            ? <String, Object?>{}
            : historyPayload ?? <Object?>[],
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _jsonResponse(Object value, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

Object? _productionHistoryPayload(
  String path, {
  required double historySummaryDeposit,
  List<Map<String, Object?>>? depositRows,
  List<Map<String, Object?>>? historyTransactionRows,
}) {
  Object paged(Object item) => {
    'page': 1,
    'pageSize': 50,
    'total': 1,
    'items': [item],
  };
  if (path.endsWith('/history/orders')) {
    return paged({
      'id': 'history-order-1',
      'accountCode': 'TEST-100',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.01,
      'openPrice': 4368.78,
      'closePrice': 4369.55,
      'profit': -0.77,
      'openedAt': '2026-08-13T15:22:00Z',
      'closedAt': '2026-08-13T15:24:00Z',
      'status': 'closed',
    });
  }
  if (path.endsWith('/history/deals')) {
    return {
      'page': 1,
      'pageSize': 50,
      'total': 2,
      'items': [
        {
          'id': 'history-deal-1',
          'positionId': 'HISTORY-POSITION-1',
          'type': 'out',
          'symbol': 'XAUUSD+',
          'side': 'buy',
          'volume': 0.004,
          'price': 4369.1,
          'profit': -0.3,
          'createdAtUtc': '2026-08-13T15:23:00Z',
        },
        {
          'id': 'history-deal-2',
          'positionId': 'history-position-1',
          'dealType': 'close',
          'symbol': 'XAUUSD+',
          'side': 'buy',
          'volume': 0.006,
          'price': 4369.6,
          'profit': -0.47,
          'createdAtUtc': '2026-08-13T15:24:00Z',
        },
      ],
    };
  }
  if (path.endsWith('/history/summary')) {
    return {
      'deposit': historySummaryDeposit,
      'withdrawal': -300,
      'realizedProfit': -12.34,
      'swap': -1.25,
      'commission': -2.5,
      'netChange': 883.91,
    };
  }
  if (path.endsWith('/history/transactions')) {
    final rows = historyTransactionRows;
    if (rows != null) {
      return {'page': 1, 'pageSize': 50, 'total': rows.length, 'items': rows};
    }
    return paged({
      'id': 'transaction:1475391737862',
      'type': 'Rút tiền',
      'timestamp': '2026-07-21T06:49:19Z',
      'amountValue': 2000,
      'currency': 'USD',
      'status': 'hoàn tất',
    });
  }
  if (path.endsWith('/wallet/transactions')) {
    return <Object?>[];
  }
  if (path.endsWith('/deposits')) {
    return depositRows ??
        [
          {
            'id': 'deposit:1',
            'accountId': 'account-1',
            'amount': 518.54,
            'currency': 'USD',
            'method': 'VNVIETQR-1',
            'reference': '924750483461',
            'status': 'approved',
            'createdAtUtc': '2026-07-21T02:28:53Z',
            'updatedAtUtc': '2026-07-21T02:31:53Z',
            'approvedAtUtc': '2026-07-21T02:31:53Z',
            'rejectedAtUtc': null,
            'transactionId': '11111111-1111-4111-8111-111111111111',
            'snapshotVersion': 2,
          },
        ];
  }
  if (path.endsWith('/withdrawals')) {
    return [
      {
        'id': 'withdrawal:1',
        'amount': 2000,
        'currency': 'USD',
        'bankName': 'BANKVNGT',
        'reference': 'W-BANKVNGT-USD-1475391737862',
        'status': 'hoàn tất',
        'createdAt': '2026-07-21T06:49:18.900Z',
        'updatedAt': '2026-07-21T06:52:19Z',
      },
    ];
  }
  if (path.endsWith('/history/positions')) {
    return {
      'page': 1,
      'pageSize': 50,
      'total': 2,
      'items': [
        {
          'positionId': 'history-position-1',
          'symbol': 'XAUUSD+',
          'side': 'sell',
          'initialVolume': 0.01,
          'remainingVolume': 0,
          'entryPrice': 4368.78,
          'realizedProfit': -0.77,
          'status': 'closed',
          'closedAtUtc': '2026-08-13T15:24:00Z',
          'createdAtUtc': '2026-08-13T15:22:00Z',
        },
        {
          'id': 'open-position-must-not-enter-history',
          'symbol': 'XAUUSD+',
          'side': 'buy',
          'initialVolume': 1,
          'remainingVolume': 1,
          'entryPrice': 4370,
          'realizedProfit': 0,
          'status': 'open',
          'closedAtUtc': null,
          'createdAtUtc': '2026-08-13T15:25:00Z',
        },
      ],
    };
  }
  return null;
}

final _bootstrap = <String, Object?>{
  'serverTime': '2026-08-13T08:00:00Z',
  'version': 1,
  'device': {'id': 'device-1', 'name': 'Phone'},
  'activeAccount': {
    'id': 'account-1',
    'accountCode': 'TEST-100',
    'name': 'Demo account',
    'currency': 'USD',
    'status': 'active',
  },
  'summary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 5000,
    'equity': 5000,
    'profit': 0,
    'margin': 0,
    'freeMargin': 5000,
    'marginLevel': 0,
    'updatedAt': '2026-08-13T08:00:00Z',
  },
  'positions': <Object?>[],
  'pendingOrders': <Object?>[],
  'recentDeals': <Object?>[],
  'wallet': {
    'currency': 'USD',
    'availableBalance': 1000,
    'lockedBalance': 0,
    'totalBalance': 1000,
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
