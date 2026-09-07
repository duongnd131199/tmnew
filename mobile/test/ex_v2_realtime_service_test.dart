import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_realtime_service.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  test('subscribes and emits account invalidations', () async {
    final hub = _RecordingHubConnection();
    final service = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final events = <ExV2RealtimeEvent>[];
    final subscription = service.events.listen(events.add);

    await service.start();
    hub.emit('AccountSnapshotInvalidated', [
      {'version': 3, 'accountId': 'account-1'},
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(hub.invocations.single.method, 'Subscribe');
    expect(events.single.name, 'AccountSnapshotInvalidated');
    expect(events.single.version, 3);

    await subscription.cancel();
    await service.dispose();
  });

  test(
    'requests an authoritative account summary refresh on the active hub',
    () async {
      final hub = _RecordingHubConnection();
      final service = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );

      await service.start();
      await service.refreshAccountSummary();

      expect(hub.invocations.map((invocation) => invocation.method), [
        'Subscribe',
        'RefreshAccountSummary',
      ]);
      await service.dispose();
    },
  );

  test('does not coerce malformed realtime envelope metadata', () async {
    final hub = _RecordingHubConnection();
    final service = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final events = <ExV2RealtimeEvent>[];
    final subscription = service.events.listen(events.add);

    await service.start();
    hub.emit('AccountSummaryUpdated', [
      {
        'eventId': 123,
        'correlationId': true,
        'version': 2.5,
        'accountId': 7,
        'data': const <String, Object?>{},
      },
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.eventId, isNull);
    expect(events.single.correlationId, isNull);
    expect(events.single.version, isNull);
    expect(events.single.accountId, isNull);

    await subscription.cancel();
    await service.dispose();
  });

  test('successful hub reconnect requests an authoritative resync', () async {
    final hub = _RecordingHubConnection();
    final service = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/v2/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final events = <ExV2RealtimeEvent>[];
    final subscription = service.events.listen(events.add);

    await service.start();
    hub.reconnect();
    await Future<void>.delayed(Duration.zero);

    expect(events.map((event) => event.name), contains('RealtimeReconnected'));

    await subscription.cancel();
    await service.dispose();
  });

  test('subscribes and emits the canonical close execution envelope', () async {
    final hub = _RecordingHubConnection();
    final service = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final events = <ExV2RealtimeEvent>[];
    final subscription = service.events.listen(events.add);

    await service.start();
    hub.emit('CloseExecutionCommitted', [
      {
        'eventId': 'event-1',
        'accountId': 'account-1',
        'version': 4,
        'correlationId': 'correlation-1',
        'data': {
          'accountId': 'account-1',
          'version': 4,
          'committedAtUtc': '2026-09-01T10:00:00Z',
        },
      },
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.name, 'CloseExecutionCommitted');
    expect(events.single.accountId, 'account-1');
    expect(events.single.version, 4);
    expect(events.single.eventId, 'event-1');
    expect(events.single.correlationId, 'correlation-1');
    expect(events.single.data['eventId'], 'event-1');
    expect(
      (events.single.data['data']! as Map)['committedAtUtc'],
      '2026-09-01T10:00:00Z',
    );

    await subscription.cancel();
    await service.dispose();
  });

  test('subscribes and emits the canonical deposit update envelope', () async {
    final hub = _RecordingHubConnection();
    final service = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/v2/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final events = <ExV2RealtimeEvent>[];
    final subscription = service.events.listen(events.add);

    await service.start();
    hub.emit('DepositRequestUpdated', [
      {
        'eventId': '11111111-1111-4111-8111-111111111111',
        'accountId': 'account-1',
        'version': 2,
        'entityId': '22222222-2222-4222-8222-222222222222',
        'correlationId': '33333333-3333-4333-8333-333333333333',
        'updatedAt': '2026-09-01T10:00:00Z',
        'data': _pendingDeposit,
      },
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.name, 'DepositRequestUpdated');
    expect(events.single.eventId, '11111111-1111-4111-8111-111111111111');
    expect(events.single.accountId, 'account-1');
    expect(events.single.version, 2);

    await subscription.cancel();
    await service.dispose();
  });

  test('account restart creates a fresh realtime service', () async {
    final hubs = <_RecordingHubConnection>[];
    final container = ProviderContainer(
      overrides: [
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2AccountProvider.overrideWithBuild((ref, controller) async => null),
        exV2RealtimeServiceProvider.overrideWith((ref) {
          final hub = _RecordingHubConnection();
          hubs.add(hub);
          return ExV2RealtimeService(
            hubUrl: 'https://example.com/ex/v2/hubs/trading',
            tokenReader: () async => 'current-token',
            connectionFactory: () => hub,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    final controller = container.read(exV2AccountProvider.notifier);

    await controller.restartRealtimeForCurrentToken();
    await controller.restartRealtimeForCurrentToken();

    expect(hubs, hasLength(2));
    expect(hubs.first.stopCalls, 1);
    expect(hubs.last.invocations.single.method, 'Subscribe');
  });

  test(
    'large account summary version gap publishes then resyncs REST',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('AccountSummaryUpdated');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      container
          .read(exV2AccountProvider.notifier)
          .updateMarketPrice(symbol: 'XAUUSD+', bid: 3310, ask: 3310.2);
      expect(
        container.read(exV2AccountProvider).requireValue!.hasLiveValuation,
        isFalse,
      );

      hub.emit('AccountSummaryUpdated', [
        {
          'eventId': '11111111-1111-4111-8111-111111111111',
          'accountId': 'account-1',
          'version': 1025,
          'correlationId': '22222222-2222-4222-8222-222222222222',
          'data': {
            'accountId': 'account-1',
            'currency': 'USD',
            'balance': 5000,
            'equity': 5025,
            'profit': 25,
            'margin': 200,
            'freeMargin': 4825,
            'marginLevel': 2512.5,
            'updatedAt': '2026-09-04T10:00:00Z',
          },
        },
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final state = container.read(exV2AccountProvider).requireValue!;
      expect(adapter.bootstrapReads, 2);
      expect(state.bootstrap.version, 1025);
      expect(state.bootstrap.summary.balance, 5000);
      expect(state.bootstrap.summary.equity, 5025);
      expect(state.bootstrap.summary.profit, 25);
      expect(state.bootstrap.summary.margin, 200);
      expect(state.bootstrap.summary.freeMargin, 4825);
      expect(state.bootstrap.summary.marginLevel, 2512.5);
      expect(state.positions.single.id, 'position-1');
      expect(state.hasLiveValuation, isFalse);

      container
          .read(exV2AccountProvider.notifier)
          .updateMarketPrice(symbol: 'XAUUSD+', bid: 3311, ask: 3311.2);
      final resumed = container.read(demoAccountProvider);
      expect(resumed.balance, 5000);
      expect(resumed.profit, 25);
      expect(resumed.equity, 5025);
      expect(resumed.margin, 200);
      expect(resumed.freeMargin, 4825);
      expect(resumed.marginLevel, 2512.5);
    },
  );

  test(
    'summary event still applies when another event already published its version',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('AccountSummaryUpdated');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      hub.emit('DepositRequestUpdated', [
        {
          'eventId': '11111111-1111-4111-8111-111111111111',
          'accountId': 'account-1',
          'version': 2,
          'entityId': '22222222-2222-4222-8222-222222222222',
          'correlationId': '33333333-3333-4333-8333-333333333333',
          'updatedAt': '2026-09-01T10:00:00Z',
          'data': _pendingDeposit,
        },
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(exV2AccountProvider).requireValue!.bootstrap.version,
        2,
      );

      hub.emit('AccountSummaryUpdated', [
        {
          'eventId': '44444444-4444-4444-8444-444444444444',
          'accountId': 'account-1',
          'version': 2,
          'correlationId': '55555555-5555-4555-8555-555555555555',
          'data': {
            'accountId': 'account-1',
            'currency': 'USD',
            'balance': 5000,
            'equity': 5025,
            'profit': 25,
            'margin': 200,
            'freeMargin': 4825,
            'marginLevel': 2512.5,
            'updatedAt': '2026-09-01T10:00:01Z',
            'positionValuations': <Object?>[
              <String, Object?>{
                'positionId': 'position-1',
                'symbol': 'XAUUSD+',
                'currentPrice': 3301.75,
                'floatingProfit': 25,
              },
            ],
          },
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      final account = container.read(exV2AccountProvider).requireValue!;
      expect(account.bootstrap.version, 2);
      expect(account.equity, 5025);
      expect(account.profit, 25);
      expect(account.margin, 200);
      expect(account.freeMargin, 4825);
      expect(account.marginLevel, 2512.5);
      expect(account.positions.single.currentPrice, 3301.75);
      expect(account.positions.single.profit, 25);
      expect(account.liveValuationPositionIds, {'position-1'});
      expect(adapter.bootstrapReads, 1);
    },
  );

  test(
    'open position polls the lightweight summary without reloading bootstrap',
    () async {
      final hub = _RecordingHubConnection();
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final adapter = _RealtimeAccountAdapter(
        polledSummary: const {
          'accountId': 'account-1',
          'currency': 'USD',
          'balance': 5000,
          'equity': 5030,
          'profit': 30,
          'margin': 210,
          'freeMargin': 4820,
          'marginLevel': 2395.24,
          'updatedAt': '2026-09-01T10:00:02Z',
          'positionValuations': <Object?>[
            <String, Object?>{
              'positionId': 'position-1',
              'symbol': 'XAUUSD+',
              'currentPrice': 3302.25,
              'floatingProfit': 30,
            },
          ],
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2FastAccountSummarySyncProvider.overrideWithValue(true),
          exV2AccountSummaryPollIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);

      for (var attempt = 0; attempt < 100; attempt++) {
        final account = container.read(exV2AccountProvider).value;
        if (adapter.summaryReads > 0 && account?.equity == 5030) break;
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final account = container.read(exV2AccountProvider).requireValue!;
      expect(adapter.summaryReads, greaterThanOrEqualTo(1));
      expect(adapter.bootstrapReads, 1);
      expect(
        hub.invocations.map((invocation) => invocation.method),
        contains('RefreshAccountSummary'),
      );
      expect(account.balance, 5000);
      expect(account.equity, 5030);
      expect(account.profit, 30);
      expect(account.margin, 210);
      expect(account.freeMargin, 4820);
      expect(account.marginLevel, 2395.24);
      expect(account.positions.single.currentPrice, 3302.25);
      expect(account.positions.single.profit, 30);
      expect(account.liveValuationPositionIds, {'position-1'});
    },
  );

  test('same-account hydration cannot regress a newer summary event', () async {
    final hydrationGate = Completer<void>();
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter()
      ..nextHydrationGate = hydrationGate;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(() {
      if (!hydrationGate.isCompleted) hydrationGate.complete();
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('AccountSummaryUpdated');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    hub.emit('AccountSummaryUpdated', [
      {
        'eventId': '11111111-1111-4111-8111-111111111111',
        'correlationId': '22222222-2222-4222-8222-222222222222',
        'version': 2,
        'accountId': 'account-1',
        'data': {
          'accountId': 'account-1',
          'currency': 'USD',
          'balance': 5000,
          'equity': 5025,
          'profit': 25,
          'margin': 200,
          'freeMargin': 4825,
          'marginLevel': 2512.5,
          'updatedAt': '2026-09-04T10:00:00Z',
        },
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(exV2AccountProvider).requireValue!.bootstrap.version,
      2,
    );

    hydrationGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(state.bootstrap.version, 2);
    expect(state.bootstrap.summary.balance, 5000);
    expect(state.bootstrap.summary.equity, 5025);
    expect(state.bootstrap.summary.profit, 25);
    expect(state.bootstrap.summary.margin, 200);
    expect(state.bootstrap.summary.freeMargin, 4825);
    expect(state.bootstrap.summary.marginLevel, 2512.5);
  });

  test('malformed account summary UUID falls back to REST', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('AccountSummaryUpdated');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    hub.emit('AccountSummaryUpdated', [
      {
        'eventId': '11111111-1111-4111-8111-111111111111',
        'accountId': 'account-1',
        'version': 2,
        'correlationId': 'not-a-uuid',
        'data': {
          'accountId': 'account-1',
          'currency': 'USD',
          'balance': 9000,
          'equity': 9100,
          'profit': 100,
          'margin': 200,
          'freeMargin': 8900,
          'marginLevel': 4550,
          'updatedAt': '2026-09-04T10:00:00Z',
        },
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(adapter.bootstrapReads, 2);
    expect(state.bootstrap.version, 1);
    expect(state.bootstrap.summary.balance, 5000);
  });

  test(
    'canonical close event publishes history without waiting for REST',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      hub.emit('CloseExecutionCommitted', [
        {
          'eventId': 'event-1',
          'accountId': 'account-1',
          'version': 2,
          'correlationId': 'correlation-1',
          'data': _realtimeCloseSync,
        },
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.bootstrapReads, 1);
      expect(state.bootstrap.version, 2);
      expect(state.positions, isEmpty);
      expect(state.balance, 5012.5);
      expect(state.historySummary.realizedProfit, 12.5);
      expect(state.historyPositions.single.id, 'position-1');
      expect(state.historyPositions.single.closePrice, 3301.75);
      expect(state.deals.single.id, 'deal-out-1');
    },
  );

  test(
    'pending deposit event updates the list without waiting for REST',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/v2/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('DepositRequestUpdated');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      hub.emit('DepositRequestUpdated', [
        {
          'eventId': '11111111-1111-4111-8111-111111111111',
          'accountId': 'account-1',
          'version': 2,
          'entityId': '22222222-2222-4222-8222-222222222222',
          'correlationId': '33333333-3333-4333-8333-333333333333',
          'updatedAt': '2026-09-01T10:00:00Z',
          'data': _pendingDeposit,
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      final account = container.read(exV2AccountProvider).requireValue!;
      expect(account.bootstrap.version, 2);
      expect(account.deposits.single['status'], 'pending');
      expect(account.historySummary.deposit, 0);
      expect(adapter.bootstrapReads, 1);
    },
  );

  test(
    'approved deposit event applies the committed financial snapshot',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/v2/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('DepositRequestUpdated');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      hub.emit('DepositRequestUpdated', [
        {
          'eventId': '44444444-4444-4444-8444-444444444444',
          'accountId': 'account-1',
          'version': 2,
          'entityId': '22222222-2222-4222-8222-222222222222',
          'correlationId': '55555555-5555-4555-8555-555555555555',
          'updatedAt': '2026-09-01T10:01:00Z',
          'data': _approvedDepositDecision,
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      final account = container.read(exV2AccountProvider).requireValue!;
      expect(account.bootstrap.version, 2);
      expect(account.deposits.single['status'], 'approved');
      expect(account.balance, 5500);
      expect(account.equity, 5500);
      expect(account.historySummary.deposit, 500);
      expect(
        account.historyTransactions.single['depositRequestId'],
        '22222222-2222-4222-8222-222222222222',
      );
      expect(adapter.bootstrapReads, 1);
    },
  );

  test('retrying the same close event does not duplicate history', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final envelope = {
      'eventId': 'event-retry-1',
      'accountId': 'account-1',
      'version': 2,
      'correlationId': 'correlation-retry-1',
      'data': _realtimeCloseSync,
    };

    hub.emit('CloseExecutionCommitted', [envelope]);
    hub.emit('CloseExecutionCommitted', [envelope]);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final state = container.read(exV2AccountProvider).value!;
    expect(adapter.bootstrapReads, 1);
    expect(state.deals.map((deal) => deal.id), ['deal-out-1']);
    expect(state.orders.map((order) => order.id), ['legacy-order-1']);
    expect(state.historyPositions.map((position) => position.id), [
      'position-1',
    ]);
  });

  test('HTTP before realtime applies one canonical close snapshot', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter(returnCloseSync: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    await container
        .read(exV2AccountProvider.notifier)
        .closePosition('position-1');
    hub.emit('CloseExecutionCommitted', [
      {
        'eventId': 'event-after-http',
        'accountId': 'account-1',
        'version': 2,
        'correlationId': adapter.lastCorrelationId,
        'data': adapter.closeSyncForLastRequest(),
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final state = container.read(exV2AccountProvider).value!;
    expect(adapter.closePosts, 1);
    expect(adapter.bootstrapReads, 1);
    expect(state.positions, isEmpty);
    expect(state.deals.map((deal) => deal.id), ['deal-out-1']);
    expect(state.orders.map((order) => order.id), ['legacy-order-1']);
    expect(state.historyPositions.map((position) => position.id), [
      'position-1',
    ]);
  });

  test(
    'realtime before HTTP response applies one canonical close snapshot',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter(
        returnCloseSync: true,
        closeGate: Completer<void>(),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(() {
        if (!(adapter.closeGate?.isCompleted ?? true)) {
          adapter.closeGate!.complete();
        }
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final close = container
          .read(exV2AccountProvider.notifier)
          .closePosition('position-1');
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final sync = adapter.closeSyncForLastRequest();
      hub.emit('CloseExecutionCommitted', [
        {
          'eventId': 'event-before-http',
          'accountId': 'account-1',
          'version': 2,
          'correlationId': adapter.lastCorrelationId,
          'data': sync,
        },
      ]);
      await Future<void>.delayed(Duration.zero);
      adapter.closeGate!.complete();
      await close;
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final state = container.read(exV2AccountProvider).value!;
      expect(adapter.closePosts, 1);
      expect(adapter.bootstrapReads, 1);
      expect(state.positions, isEmpty);
      expect(state.deals.map((deal) => deal.id), ['deal-out-1']);
      expect(state.historyPositions.map((position) => position.id), [
        'position-1',
      ]);
    },
  );

  test('newer summary does not block immediate HTTP close history', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter(
      returnCloseSync: true,
      closeGate: Completer<void>(),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(() {
      if (!(adapter.closeGate?.isCompleted ?? true)) {
        adapter.closeGate!.complete();
      }
      container.dispose();
    });
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 &&
          (!hub.handlers.containsKey('AccountSummaryUpdated') ||
              !hub.handlers.containsKey('CloseExecutionCommitted'));
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    final close = container
        .read(exV2AccountProvider.notifier)
        .closePosition('position-1');
    for (var attempt = 0; attempt < 100 && adapter.closePosts < 1; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    hub.emit('AccountSummaryUpdated', [
      {
        'eventId': '55555555-5555-4555-8555-555555555555',
        'correlationId': '66666666-6666-4666-8666-666666666666',
        'version': 3,
        'accountId': 'account-1',
        'data': {
          'accountId': 'account-1',
          'currency': 'USD',
          'balance': 5025,
          'equity': 5025,
          'profit': 0,
          'margin': 0,
          'freeMargin': 5025,
          'marginLevel': 0,
          'updatedAt': '2026-09-01T10:00:01Z',
        },
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(exV2AccountProvider).requireValue!.bootstrap.version,
      3,
    );

    adapter.closeGate!.complete();
    await close;

    final state = container.read(exV2AccountProvider).requireValue!;
    expect(adapter.closePosts, 1);
    expect(adapter.bootstrapReads, 1);
    expect(state.bootstrap.version, 3);
    expect(state.bootstrap.summary.balance, 5025);
    expect(
      state.bootstrap.summary.updatedAt.toIso8601String(),
      '2026-09-01T10:00:01.000Z',
    );
    expect(state.positions, isEmpty);
    expect(state.deals.map((deal) => deal.id), ['deal-out-1']);
    expect(state.orders.map((order) => order.id), ['legacy-order-1']);
    expect(state.historyPositions.map((position) => position.id), [
      'position-1',
    ]);
  });

  test('close event for another account does not trigger a refresh', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final foreignSummary = Map<String, Object?>.from(
      _realtimeCloseSync['accountSummary']! as Map,
    )..['accountId'] = 'account-2';
    final foreignSync = <String, Object?>{
      ..._realtimeCloseSync,
      'accountId': 'account-2',
      'accountSummary': foreignSummary,
    };

    hub.emit('CloseExecutionCommitted', [
      {
        'eventId': 'foreign-event-1',
        'accountId': 'account-2',
        'version': 2,
        'correlationId': 'foreign-correlation-1',
        'data': foreignSync,
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final state = container.read(exV2AccountProvider).value!;
    expect(adapter.bootstrapReads, 1);
    expect(state.bootstrap.account.id, 'account-1');
    expect(state.bootstrap.version, 1);
    expect(state.positions.single.id, 'position-1');
    expect(state.historyPositions, isEmpty);
  });

  test(
    'close event with a version gap queues reconciliation behind an in-flight read',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(container.dispose);
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final blockedRefresh = Completer<void>();
      adapter.nextBootstrapGate = blockedRefresh;
      final inFlight = container.read(exV2AccountProvider.notifier).refresh();
      for (
        var attempt = 0;
        attempt < 100 && adapter.bootstrapReads < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final gapSync = <String, Object?>{..._realtimeCloseSync, 'version': 3};
      hub.emit('CloseExecutionCommitted', [
        {
          'eventId': 'event-queued-refresh',
          'accountId': 'account-1',
          'version': 3,
          'correlationId': 'correlation-queued-refresh',
          'data': gapSync,
        },
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(exV2AccountProvider).value!.bootstrap.version, 3);
      expect(adapter.bootstrapReads, 2);

      blockedRefresh.complete();
      await inFlight;
      for (
        var attempt = 0;
        attempt < 100 && adapter.bootstrapReads < 3;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(adapter.bootstrapReads, 3);
    },
  );

  test('malformed close envelope schedules a canonical REST refresh', () async {
    final hub = _RecordingHubConnection();
    final adapter = _RealtimeAccountAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final realtime = ExV2RealtimeService(
      hubUrl: 'https://example.com/ex/v2/hubs/trading',
      tokenReader: () async => 'test-token',
      connectionFactory: () => hub,
    );
    final container = ProviderContainer(
      overrides: [
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
        exV2DioProvider.overrideWithValue(dio),
        deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        exV2RealtimeServiceProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(exV2AccountProvider.future);
    for (
      var attempt = 0;
      attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    hub.emit('CloseExecutionCommitted', [
      {'eventId': 'event-without-metadata', 'data': _realtimeCloseSync},
    ]);
    for (
      var attempt = 0;
      attempt < 100 && adapter.bootstrapReads < 2;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(adapter.bootstrapReads, 2);
  });

  test(
    'external close event does not settle or roll back a local close command',
    () async {
      final hub = _RecordingHubConnection();
      final adapter = _RealtimeAccountAdapter()..closeGate = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      final realtime = ExV2RealtimeService(
        hubUrl: 'https://example.com/ex/v2/hubs/trading',
        tokenReader: () async => 'test-token',
        connectionFactory: () => hub,
      );
      final container = ProviderContainer(
        overrides: [
          exV2EnabledProvider.overrideWithValue(true),
          exV2RealtimeEnabledProvider.overrideWithValue(true),
          exV2DioProvider.overrideWithValue(dio),
          deviceTokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          exV2RealtimeServiceProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(() {
        if (!(adapter.closeGate?.isCompleted ?? true)) {
          adapter.closeGate!.complete();
        }
        container.dispose();
      });
      await container.read(exV2AccountProvider.future);
      for (
        var attempt = 0;
        attempt < 100 && !hub.handlers.containsKey('CloseExecutionCommitted');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final localClose = container
          .read(exV2AccountProvider.notifier)
          .closePosition('position-1');
      for (
        var attempt = 0;
        attempt < 100 && adapter.closePosts < 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      hub.emit('CloseExecutionCommitted', [
        {
          'eventId': 'external-event-1',
          'accountId': 'account-1',
          'version': 2,
          'correlationId': 'external-correlation-1',
          'data': _realtimeCloseSync,
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(exV2AccountProvider).value!.pendingOperationIds,
        contains('position:position-1'),
      );

      adapter.closeGate!.complete();
      await expectLater(localClose, throwsA(isA<ExV2RequestFailure>()));
      final settled = container.read(exV2AccountProvider).value!;
      expect(settled.bootstrap.version, 2);
      expect(settled.positions, isEmpty);
      expect(settled.historyPositions.single.id, 'position-1');
      expect(settled.pendingOperationIds, isEmpty);
    },
  );
}

final class _MemoryTokenStore implements DeviceTokenStore {
  String? token = 'test-token';

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

final class _RealtimeAccountAdapter implements HttpClientAdapter {
  _RealtimeAccountAdapter({
    this.returnCloseSync = false,
    this.closeGate,
    this.polledSummary,
  });

  final bool returnCloseSync;
  final Map<String, Object?>? polledSummary;
  int bootstrapReads = 0;
  int summaryReads = 0;
  int closePosts = 0;
  Completer<void>? nextBootstrapGate;
  Completer<void>? nextHydrationGate;
  Completer<void>? closeGate;
  String? lastIdempotencyKey;
  String? lastCorrelationId;

  Map<String, Object?> closeSyncForLastRequest() {
    final sync = jsonDecode(jsonEncode(_realtimeCloseSync)) as Map;
    final result = sync.cast<String, Object?>();
    final operation = (result['operation']! as Map).cast<String, Object?>();
    operation['idempotencyKey'] = lastIdempotencyKey;
    operation['correlationId'] = lastCorrelationId;
    result['operation'] = operation;
    return result;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/positions/position-1/close') &&
        options.method == 'POST') {
      closePosts += 1;
      lastIdempotencyKey = options.headers['Idempotency-Key']?.toString();
      lastCorrelationId = options.headers['X-Correlation-Id']?.toString();
      await closeGate?.future;
      if (returnCloseSync) {
        final sync = closeSyncForLastRequest();
        final affectedPosition =
            ((sync['affectedPositions']! as List).single as Map)
                .cast<String, Object?>();
        return _json({...affectedPosition, 'sync': sync});
      }
      return _json({
        'code': 'CONCURRENCY_CONFLICT',
        'message': 'Position changed',
      }, statusCode: 409);
    }
    if (path.endsWith('/mobile/bootstrap')) {
      bootstrapReads += 1;
      final gate = nextBootstrapGate;
      nextBootstrapGate = null;
      await gate?.future;
      return _json(_realtimeBootstrap);
    }
    if (path.endsWith('/account/summary')) {
      summaryReads += 1;
      return _json(polledSummary ?? _realtimeBootstrap['summary']!);
    }
    if (path.endsWith('/history/summary')) {
      return _json({
        'deposit': 0,
        'withdrawal': 0,
        'realizedProfit': 0,
        'swap': 0,
        'commission': 0,
        'netChange': 0,
      });
    }
    if (path.endsWith('/settings')) {
      final gate = nextHydrationGate;
      nextHydrationGate = null;
      await gate?.future;
      return _json(<String, Object?>{});
    }
    return _json({'items': <Object?>[]});
  }

  ResponseBody _json(Object body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

final _realtimeBootstrap = <String, Object?>{
  'serverTime': '2026-09-01T09:59:00Z',
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
    'updatedAt': '2026-09-01T09:59:00Z',
  },
  'positions': [
    {
      'id': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'BUY',
      'initialVolume': 0.01,
      'remainingVolume': 0.01,
      'entryPrice': 3300.5,
      'stopLoss': null,
      'takeProfit': null,
      'realizedProfit': 0,
      'status': 'open',
      'createdAt': '2026-09-01T09:59:00Z',
      'closedAt': null,
      'rowVersion': 'position-rv-1',
    },
  ],
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

final _realtimeCloseSync = <String, Object?>{
  'accountId': 'account-1',
  'version': 2,
  'committedAtUtc': '2026-09-01T10:00:00Z',
  'operation': {
    'mode': 'full',
    'idempotencyKey': '33333333-3333-4333-8333-333333333333',
    'correlationId': '44444444-4444-4444-8444-444444444444',
  },
  'affectedPositions': [
    {
      'id': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'BUY',
      'initialVolume': 0.01,
      'remainingVolume': 0,
      'entryPrice': 3300.5,
      'stopLoss': null,
      'takeProfit': null,
      'realizedProfit': 12.5,
      'status': 'closed',
      'createdAt': '2026-09-01T09:59:00Z',
      'closedAt': '2026-09-01T10:00:00Z',
      'rowVersion': 'position-rv-2',
    },
  ],
  'closedPositions': [
    {
      'id': 'position-1',
      'positionId': 'position-1',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'volume': 0.01,
      'openPrice': 3300.5,
      'closePrice': 3301.75,
      'realizedProfit': 12.5,
      'openedAtUtc': '2026-09-01T09:59:00Z',
      'closedAtUtc': '2026-09-01T10:00:00Z',
      'status': 'closed',
    },
  ],
  'orders': [
    {
      'id': 'legacy-order-1',
      'accountCode': 'TEST-100',
      'symbol': 'XAUUSD+',
      'side': 'buy',
      'volume': 0.01,
      'openPrice': 3300.5,
      'closePrice': 3301.75,
      'profit': 12.5,
      'openedAt': '2026-09-01T09:59:00Z',
      'closedAt': '2026-09-01T10:00:00Z',
      'status': 'closed',
    },
  ],
  'deals': [
    {
      'id': 'deal-out-1',
      'orderId': 'order-1',
      'positionId': 'position-1',
      'type': 'out',
      'symbol': 'XAUUSD+',
      'side': 'sell',
      'volume': 0.01,
      'price': 3301.75,
      'profit': 12.5,
      'createdAtUtc': '2026-09-01T10:00:00Z',
    },
  ],
  'accountSummary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 5012.5,
    'equity': 5012.5,
    'profit': 0,
    'margin': 0,
    'freeMargin': 5012.5,
    'marginLevel': 0,
    'updatedAt': '2026-09-01T10:00:00Z',
  },
  'historySummary': {
    'deposit': 0,
    'withdrawal': 0,
    'realizedProfit': 12.5,
    'swap': 0,
    'commission': 0,
    'netChange': 12.5,
  },
};

final _pendingDeposit = <String, Object?>{
  'id': '22222222-2222-4222-8222-222222222222',
  'accountId': 'account-1',
  'amount': 500,
  'currency': 'USD',
  'method': 'demo',
  'reference': 'mobile',
  'status': 'pending',
  'createdAtUtc': '2026-09-01T10:00:00Z',
  'updatedAtUtc': '2026-09-01T10:00:00Z',
  'approvedAtUtc': null,
  'rejectedAtUtc': null,
  'transactionId': null,
  'snapshotVersion': 2,
};

final _approvedDepositDecision = <String, Object?>{
  'deposit': {
    ..._pendingDeposit,
    'status': 'approved',
    'updatedAtUtc': '2026-09-01T10:01:00Z',
    'approvedAtUtc': '2026-09-01T10:01:00Z',
    'transactionId': '66666666-6666-4666-8666-666666666666',
  },
  'transaction': {
    'id': '66666666-6666-4666-8666-666666666666',
    'depositRequestId': '22222222-2222-4222-8222-222222222222',
    'accountId': 'account-1',
    'type': 'deposit',
    'amount': 500,
    'currency': 'USD',
    'status': 'completed',
    'createdAtUtc': '2026-09-01T10:01:00Z',
    'snapshotVersion': 2,
  },
  'accountSummary': {
    'accountId': 'account-1',
    'currency': 'USD',
    'balance': 5500,
    'equity': 5500,
    'profit': 0,
    'margin': 0,
    'freeMargin': 5500,
    'marginLevel': 0,
    'updatedAt': '2026-09-01T10:01:00Z',
  },
  'historySummary': {
    'deposit': 500,
    'withdrawal': 0,
    'realizedProfit': 0,
    'swap': 0,
    'commission': 0,
    'netChange': 500,
  },
  'version': 2,
  'committedAtUtc': '2026-09-01T10:01:00Z',
};

final class _Invocation {
  const _Invocation(this.method, this.args);
  final String method;
  final List<Object?> args;
}

final class _RecordingHubConnection implements HubConnection {
  HubConnectionState? _state = HubConnectionState.disconnected;
  final handlers = <String, void Function(List<Object?>?)>{};
  final invocations = <_Invocation>[];
  ReconnectedCallback? _reconnected;
  int stopCalls = 0;

  void emit(String name, List<Object?> arguments) =>
      handlers[name]?.call(arguments);

  void reconnect() => _reconnected?.call(connectionId: 'reconnected-1');

  @override
  HubConnectionState? get state => _state;

  @override
  void on(String methodName, void Function(List<Object?>?) handler) {
    handlers[methodName] = handler;
  }

  @override
  void onreconnected(ReconnectedCallback callback) {
    _reconnected = callback;
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object?>? args}) async {
    invocations.add(_Invocation(methodName, args ?? const []));
    return null;
  }

  @override
  Future<void> start() async => _state = HubConnectionState.connected;

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _state = HubConnectionState.disconnected;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
