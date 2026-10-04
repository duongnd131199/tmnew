import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exness/core/config/video_demo_mode.dart';
import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/ex_v2_api_client.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/account/data/ex_v2_repository.dart';
import 'package:exness/features/account/presentation/account_screen.dart';
import 'package:exness/features/notifications/data/account_notification.dart';
import 'package:exness/features/notifications/data/notification_provider.dart';
import 'package:exness/features/notifications/presentation/notifications_sheet.dart';
import 'package:exness/features/trading/data/market_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification parser accepts the server read and body fields', () {
    final notification = AccountNotification.fromJson({
      'id': 'n1',
      'title': 'Giao dịch',
      'body': 'Lệnh đã đóng',
      'read': true,
      'createdAt': '2026-09-19T02:00:00Z',
    });

    expect(notification.message, 'Lệnh đã đóng');
    expect(notification.isRead, isTrue);
  });

  testWidgets('notification tap marks a server item read and refreshes it', (
    tester,
  ) async {
    final adapter = _NotificationAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final repository = ExV2Repository(
      ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          notificationsProvider.overrideWith(
            (ref) async => [
              AccountNotification.fromJson({
                'id': 'n1',
                'title': 'Giao dịch',
                'message': 'Lệnh đã đóng',
                'isRead': adapter.isRead,
              }),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mới'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-n1')));
    await tester.pumpAndSettle();

    expect(adapter.putCount, 1);
    expect(adapter.idempotencyKey, isNotEmpty);
    expect(find.text('Đã đọc'), findsOneWidget);
  });

  testWidgets('notification read errors keep the unread item available', (
    tester,
  ) async {
    final adapter = _NotificationAdapter()..failRead = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    final repository = ExV2Repository(
      ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          notificationsProvider.overrideWith(
            (ref) async => [
              AccountNotification.fromJson({
                'id': 'n1',
                'title': 'Giao dịch',
                'isRead': false,
              }),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsSheet())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-n1')));
    await tester.pumpAndSettle();

    expect(find.text('Mới'), findsOneWidget);
    expect(find.text('Không thể đánh dấu đã đọc. Thử lại.'), findsOneWidget);
  });

  testWidgets('account bell opens the EX V2 notification list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          marketQuotesProvider.overrideWith(
            (ref) => Stream.value(
              const MarketFeedState(
                quotes: [],
                status: MarketFeedStatus.connected,
              ),
            ),
          ),
          notificationsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: AccountScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_none).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-sheet')), findsOneWidget);
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  testWidgets('notification load failure gives a retry action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải thông báo'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}

final class _LoggedOutSession extends AccountSessionController {
  @override
  Future<ExV2Bootstrap?> build() async => null;
}

final class _NotificationAdapter implements HttpClientAdapter {
  bool isRead = false;
  bool failRead = false;
  int putCount = 0;
  String? idempotencyKey;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' &&
        options.path.endsWith('/notifications/n1/read')) {
      putCount++;
      idempotencyKey = options.headers['Idempotency-Key']?.toString();
      if (failRead) {
        return _json({'message': 'server unavailable'}, 500);
      }
      isRead = true;
      return _json({}, 200);
    }
    return _json({'message': 'unexpected request'}, 404);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
