import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_link/application/account_link_controller.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/presentation/screens/existing_account_login_screen.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

void main() {
  testWidgets('account form header matches the video toolbar elevation', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountLinkRepositoryProvider.overrideWithValue(
            _GeometryRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ExistingAccountLoginScreen(brokerId: 'yodo-demo'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final header = tester.getRect(
      find.byKey(const Key('existing-account-header')),
    );
    final back = tester.getRect(
      find.byKey(const Key('account-link-back-button')),
    );
    final brokerMark = tester.getRect(
      find.byKey(const Key('broker-mark-yodo-demo')),
    );

    expect(header.height, 81);
    expect(back.top - header.top, closeTo(37, 0.1));
    expect(brokerMark.center.dy, closeTo(back.center.dy, 0.1));
    expect(find.text('YODO Demo Markets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _GeometryRepository implements AccountLinkRepository {
  @override
  Future<List<MobileBroker>> brokers({String query = ''}) async => const [
    MobileBroker(
      id: 'yodo-demo',
      name: 'YODO Demo Markets',
      companyName: 'YODO Markets International Limited',
    ),
  ];

  @override
  Future<List<MobileTradingServer>> servers(
    String brokerId, {
    String query = '',
  }) async => const [
    MobileTradingServer(
      id: 'yodo-demo-01',
      name: 'YODO-Demo-01',
      brokerId: 'yodo-demo',
    ),
  ];

  @override
  Future<List<LinkedTradingAccount>> accounts() async => const [];

  @override
  Future<LinkAccountResult> link(
    LinkAccountRequest request, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();

  @override
  Future<ActivateLinkedAccountResult> activate(
    String accountId, {
    required ExV2CommandMetadata metadata,
  }) => throw UnimplementedError();
}
