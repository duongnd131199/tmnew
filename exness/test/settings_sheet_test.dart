import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exness/features/account/data/account_session.dart';
import 'package:exness/features/account/data/ex_v2_api_client.dart';
import 'package:exness/features/account/data/ex_v2_models.dart';
import 'package:exness/features/account/data/ex_v2_repository.dart';
import 'package:exness/features/profile/presentation/settings_sheet.dart';
import 'package:exness/core/config/video_demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification preference is saved and reread from EX V2', (
    tester,
  ) async {
    final adapter = _SettingsAdapter();
    await _pumpSettings(tester, adapter);

    expect(find.text('Tiếng Việt'), findsOneWidget);
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('trade-notifications-switch'));
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(adapter.putCount, 1);
    expect(adapter.lastBody, {'tradeNotificationsEnabled': true});
    expect(adapter.idempotencyKey, isNotEmpty);
    expect(adapter.getCount, greaterThanOrEqualTo(2));
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });

  testWidgets('failed preference save keeps the confirmed server value', (
    tester,
  ) async {
    final adapter = _SettingsAdapter()..failPut = true;
    await _pumpSettings(tester, adapter);
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('trade-notifications-switch'));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(find.text('Không thể lưu cài đặt thông báo.'), findsOneWidget);
  });

  testWidgets('unimplemented platform security switches cannot be changed', (
    tester,
  ) async {
    final adapter = _SettingsAdapter();
    await _pumpSettings(tester, adapter);

    await tester.scrollUntilVisible(
      find.byKey(const Key('face-id-switch')),
      250,
    );
    expect(
      tester.widget<Switch>(find.byKey(const Key('face-id-switch'))).onChanged,
      isNull,
    );
  });

  testWidgets('long server language fits a narrow settings sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final adapter = _SettingsAdapter()
      ..language = 'Tiếng Việt (Việt Nam) dành cho thiết bị này';
    await _pumpSettings(tester, adapter);

    expect(tester.takeException(), isNull);
  });

  testWidgets('settings from another account are hidden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDemoModeProvider.overrideWith((ref) => false),
          accountSessionProvider.overrideWith(_LoggedOutSession.new),
          accountSettingsProvider.overrideWith(
            (ref) async => (
              accountId: 'previous-account',
              values: {
                'language': 'Previous account language',
                'tradeNotificationsEnabled': true,
              },
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Previous account language'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

final class _LoggedOutSession extends AccountSessionController {
  @override
  Future<ExV2Bootstrap?> build() async => null;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _SettingsAdapter adapter,
) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/ex/v2/api'))
    ..httpClientAdapter = adapter;
  final repository = ExV2Repository(
    ExV2ApiClient(dio: dio, tokenReader: () async => 'device-token'),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoDemoModeProvider.overrideWith((ref) => false),
        accountSessionProvider.overrideWith(_LoggedOutSession.new),
        accountRepositoryProvider.overrideWithValue(repository),
        accountSettingsProvider.overrideWith(
          (ref) async => (
            accountId: null,
            values: await ref.read(accountRepositoryProvider).settings(),
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
    ),
  );
  await tester.pumpAndSettle();
}

final class _SettingsAdapter implements HttpClientAdapter {
  bool enabled = false;
  String language = 'Tiếng Việt';
  bool failPut = false;
  int getCount = 0;
  int putCount = 0;
  Map<String, dynamic>? lastBody;
  String? idempotencyKey;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/settings') && options.method == 'GET') {
      getCount++;
      return _json({
        'language': language,
        'tradeNotificationsEnabled': enabled,
      }, 200);
    }
    if (options.path.endsWith('/settings') && options.method == 'PUT') {
      putCount++;
      idempotencyKey = options.headers['Idempotency-Key']?.toString();
      lastBody = (options.data as Map).cast<String, dynamic>();
      if (failPut) return _json({'message': 'server unavailable'}, 500);
      enabled = lastBody?['tradeNotificationsEnabled'] == true;
      return _json({'tradeNotificationsEnabled': enabled}, 200);
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
