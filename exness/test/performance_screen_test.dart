import 'dart:convert';
import 'dart:typed_data';

import 'package:exness/core/config/video_demo_mode.dart';

import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/device_token_store.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/account/data/ex_v2_api_client.dart';
import 'package:exness/features/performance/presentation/performance_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('date filter uses exit deals, including partial closes', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          historyDealsProvider.overrideWith(
            (ref) async => [
              {
                'dealType': 'close',
                'createdAtUtc': now
                    .subtract(const Duration(days: 2))
                    .toIso8601String(),
                'profit': 5.5,
              },
              {
                'dealType': 'out_by',
                'createdAtUtc': now
                    .subtract(const Duration(days: 14))
                    .toIso8601String(),
                'profit': -2,
              },
              {
                'dealType': 'partial_close',
                'createdAtUtc': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'profit': 4,
              },
              {
                'dealType': 'open',
                'createdAtUtc': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'profit': 50,
              },
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9,50 USD'), findsOneWidget);
    expect(find.text('2 giao dịch đã đóng'), findsOneWidget);
    expect(find.textContaining('100000001'), findsOneWidget);

    await tester.tap(find.textContaining('7 ngày gần nhất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 ngày gần nhất'));
    await tester.pumpAndSettle();

    expect(find.text('7,50 USD'), findsOneWidget);
    expect(find.text('3 giao dịch đã đóng'), findsOneWidget);
  });

  testWidgets('history failure is shown as an error with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          historyDealsProvider.overrideWith((ref) async {
            throw StateError('network unavailable');
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không tải được dữ liệu hiệu suất'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('all-time performance uses the server aggregate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          historyDealsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ngày gần nhất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toàn bộ thời gian'));
    await tester.pumpAndSettle();

    expect(find.text('99,00 USD'), findsOneWidget);
  });

  testWidgets('all-time aggregate remains available when history fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          historyDealsProvider.overrideWith((ref) async {
            throw StateError('history unavailable');
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ngày gần nhất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toàn bộ thời gian'));
    await tester.pumpAndSettle();

    expect(find.text('99,00 USD'), findsOneWidget);
    expect(find.text('Không tải được dữ liệu hiệu suất'), findsNothing);
  });

  testWidgets(
    'account filter activates a linked account and reloads performance',
    (tester) async {
      var activeId = 'account-1';
      final adapter = _ActivateAdapter(() => activeId = 'account-2');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
        ..httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoDemoModeProvider.overrideWithValue(false),
            accountSessionProvider.overrideWith(
              () => _DynamicSession(() => _bootstrap(accountId: activeId)),
            ),
            historyDealsProvider.overrideWith((ref) async => const []),
            accountCatalogProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'account-1',
                  'login': '100000001',
                  'displayName': 'Account one',
                  'isActive': activeId == 'account-1',
                },
                {
                  'id': 'account-2',
                  'login': '100000002',
                  'displayName': 'Account two',
                  'isActive': activeId == 'account-2',
                },
              ],
            ),
            accountClientProvider.overrideWith(
              (ref) => ExV2ApiClient(
                dio: dio,
                tokenReader: () async => 'device-token',
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('100000001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account two'));
      await tester.pumpAndSettle();

      expect(
        adapter.requests.single.uri.path,
        '/ex/v2/api/mobile/accounts/account-2/activate',
      );
      expect(adapter.requests.single.headers['X-Device-Token'], 'device-token');
      expect(
        find.text('100000002'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
    },
  );

  testWidgets('rejected account activation clears the global session', (
    tester,
  ) async {
    final store = _MemoryTokenStore();
    final adapter = _ActivateAdapter(() {})..status = 401;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWithValue(false),
          deviceTokenStoreProvider.overrideWithValue(store),
          accountSessionProvider.overrideWith(() => _Session(_bootstrap())),
          historyDealsProvider.overrideWith((ref) async => const []),
          accountCatalogProvider.overrideWith(
            (ref) async => [
              {'id': 'account-1', 'login': '100000001'},
              {'id': 'account-2', 'login': '100000002'},
            ],
          ),
          accountClientProvider.overrideWith(
            (ref) => ExV2ApiClient(dio: dio, tokenReader: store.read),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PerformanceScreen)),
    );
    await tester.tap(find.text('100000001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100000002').last);
    await tester.pumpAndSettle();

    expect(store.deleteCalls, 1);
    expect(container.read(accountSessionProvider).value, isNull);
  });
}

final class _MemoryTokenStore implements DeviceTokenStore {
  int deleteCalls = 0;

  @override
  Future<String?> read() async => 'device-token';

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> delete() async => deleteCalls++;
}

final class _Session extends AccountSessionController {
  _Session(this.bootstrap);

  final ExV2Bootstrap bootstrap;

  @override
  Future<ExV2Bootstrap?> build() async => bootstrap;
}

final class _DynamicSession extends AccountSessionController {
  _DynamicSession(this.bootstrap);

  final ExV2Bootstrap Function() bootstrap;

  @override
  Future<ExV2Bootstrap?> build() async => bootstrap();
}

ExV2Bootstrap _bootstrap({String accountId = 'account-1'}) =>
    ExV2Bootstrap.fromJson({
      'serverTime': '2026-09-19T00:00:00Z',
      'version': 2,
      'device': {'id': 'device-1', 'name': 'Demo'},
      'activeAccount': {
        'id': accountId,
        'accountCode': accountId == 'account-1' ? '100000001' : '100000002',
        'name': 'Virtual account',
        'currency': 'USD',
        'status': 'active',
      },
      'summary': {
        'accountId': accountId,
        'currency': 'USD',
        'balance': 12.5,
        'equity': 12.5,
        'profit': 0,
        'margin': 0,
        'freeMargin': 12.5,
        'marginLevel': 0,
        'updatedAt': '2026-09-19T00:00:00Z',
      },
      'positions': [],
      'pendingOrders': [],
      'recentDeals': [],
      'wallet': {
        'currency': 'USD',
        'availableBalance': 0,
        'lockedBalance': 0,
        'totalBalance': 0,
      },
      'performance': {
        'netProfit': 99,
        'grossProfit': 99,
        'grossLoss': 0,
        'floatingProfit': 0,
        'tradingVolume': 0,
        'updatedAt': null,
        'integrityWarnings': 0,
      },
      'connection': {'marketFeedStatus': 'connected', 'lastMarketTickAt': null},
      'integrityWarnings': 0,
    });

final class _ActivateAdapter implements HttpClientAdapter {
  _ActivateAdapter(this.onActivate);

  final void Function() onActivate;
  final List<RequestOptions> requests = [];
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (status == 200) onActivate();
    return ResponseBody.fromString(
      jsonEncode(
        status == 200
            ? <String, Object?>{}
            : {'code': 'device_token_invalid', 'message': 'Rejected'},
      ),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
