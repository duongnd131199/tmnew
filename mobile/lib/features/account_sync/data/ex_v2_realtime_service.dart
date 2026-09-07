import 'dart:async';

import 'package:signalr_hub/signalr_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

final class ExV2RealtimeEvent {
  const ExV2RealtimeEvent({
    required this.name,
    required this.data,
    this.eventId,
    this.correlationId,
    this.version,
    this.accountId,
  });

  final String name;
  final Map<String, dynamic> data;
  final String? eventId;
  final String? correlationId;
  final int? version;
  final String? accountId;
}

final class ExV2RealtimeService {
  ExV2RealtimeService({
    required this.hubUrl,
    required this.tokenReader,
    this.connectionFactory,
  });

  static const eventNames = [
    'OrderCreated',
    'OrderUpdated',
    'OrderCanceled',
    'PositionCreated',
    'PositionUpdated',
    'PositionClosed',
    'DealCreated',
    'CloseExecutionCommitted',
    'DepositRequestUpdated',
    'HistoryUpdated',
    'WalletUpdated',
    'DepositUpdated',
    'WithdrawalUpdated',
    'TransferUpdated',
    'PerformanceUpdated',
    'AccountSummaryUpdated',
    'AccountSnapshotInvalidated',
    'ActiveAccountChanged',
  ];

  final String hubUrl;
  final DeviceTokenReader tokenReader;
  final HubConnection Function()? connectionFactory;
  final _events = StreamController<ExV2RealtimeEvent>.broadcast();
  HubConnection? _connection;
  bool _disposed = false;

  Stream<ExV2RealtimeEvent> get events => _events.stream;

  Future<void> start() async {
    if (_disposed) return;
    final connection = _connection ??= _buildConnection();
    if (connection.state != HubConnectionState.connected) {
      await connection.start();
    }
    await connection.invoke('Subscribe');
  }

  Future<void> refreshAccountSummary() async {
    final connection = _connection;
    if (_disposed ||
        connection == null ||
        connection.state != HubConnectionState.connected) {
      return;
    }
    await connection.invoke('RefreshAccountSummary');
  }

  HubConnection _buildConnection() {
    final connection =
        connectionFactory?.call() ??
        (HubConnectionBuilder()
            .withUrl(
              hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () async =>
                    (await tokenReader())?.trim() ?? '',
                requestTimeout: 8000,
                logMessageContent: false,
              ),
            )
            .withAutomaticReconnect(
              retryDelays: const [0, 1000, 2000, 5000, 10000],
            )
            .build());
    for (final name in eventNames) {
      connection.on(name, (arguments) => _handle(name, arguments));
    }
    connection.onreconnected(({connectionId}) {
      unawaited(_resubscribeAfterReconnect());
    });
    return connection;
  }

  Future<void> _resubscribeAfterReconnect() async {
    try {
      await start();
    } catch (_) {
      // The REST resync below remains authoritative even if hub subscription
      // needs the SignalR client's next reconnect attempt.
    }
    if (_disposed) return;
    _events.add(
      const ExV2RealtimeEvent(
        name: 'RealtimeReconnected',
        data: <String, dynamic>{},
      ),
    );
  }

  void _handle(String name, List<Object?>? arguments) {
    if (_disposed || arguments == null || arguments.isEmpty) return;
    final first = arguments.first;
    if (first is! Map) return;
    final data = first.cast<String, dynamic>();
    final eventIdValue = data['eventId'];
    final correlationIdValue = data['correlationId'];
    final versionValue = data['version'];
    final accountIdValue = data['accountId'];
    _events.add(
      ExV2RealtimeEvent(
        name: name,
        data: data,
        eventId: eventIdValue is String ? eventIdValue : null,
        correlationId: correlationIdValue is String ? correlationIdValue : null,
        version: versionValue is int ? versionValue : null,
        accountId: accountIdValue is String ? accountIdValue : null,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connection?.stop();
    await _events.close();
  }
}
