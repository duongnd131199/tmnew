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
  _RealtimeAccountAdapter({this.returnCloseSync = false, this.closeGate});

  final bool returnCloseSync;
  int bootstrapReads = 0;
  int closePosts = 0;
  Completer<void>? nextBootstrapGate;
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
    if (path.endsWith('/settings')) return _json(<String, Object?>{});
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
  int stopCalls = 0;

  void emit(String name, List<Object?> arguments) =>
      handlers[name]?.call(arguments);

  @override
  HubConnectionState? get state => _state;

  @override
  void on(String methodName, void Function(List<Object?>?) handler) {
    handlers[methodName] = handler;
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
