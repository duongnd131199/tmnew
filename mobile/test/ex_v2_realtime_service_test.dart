import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
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
}

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
