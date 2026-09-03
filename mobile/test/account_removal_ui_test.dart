import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sessions/application/account_removal_service.dart';
import 'package:trading_mobile/features/profile/presentation/screens/account_detail_screen.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

void main() {
  testWidgets('delete row opens device-only confirmation and cancel is safe', (
    tester,
  ) async {
    final service = _FakeRemovalService();
    await _pumpDetail(tester, service: service);

    await _openRemovalDialog(tester);

    expect(find.text('Xóa tài khoản khỏi thiết bị?'), findsOneWidget);
    expect(
      find.textContaining('Dữ liệu tài khoản trên máy chủ vẫn được giữ'),
      findsOneWidget,
    );
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    expect(find.byKey(const Key('account-detail-screen')), findsOneWidget);
  });

  testWidgets('pending removal disables a second request', (tester) async {
    final gate = Completer<AccountRemovalResult>();
    final service = _FakeRemovalService(gate: gate);
    await _pumpDetail(tester, service: service);
    await _openRemovalDialog(tester);

    await tester.tap(find.text('Xóa'));
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, 1);
    final rowInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('account-delete-row')),
        matching: find.byType(InkWell),
      ),
    );
    expect(rowInkWell.onTap, isNull);
    expect(service.calls, 1);

    gate.complete(AccountRemovalResult.signedOut);
    await tester.pumpAndSettle();
  });

  testWidgets('successful replacement switch pops back from account detail', (
    tester,
  ) async {
    final service = _FakeRemovalService(result: AccountRemovalResult.switched);
    await _pumpDetail(tester, service: service, withParentRoute: true);

    await tester.tap(find.byKey(const Key('open-detail')));
    await tester.pumpAndSettle();
    await _openRemovalDialog(tester);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.byKey(const Key('account-detail-screen')), findsNothing);
    expect(find.text('ACCOUNT LIST'), findsOneWidget);
  });

  testWidgets('removal failure stays on detail and shows a safe message', (
    tester,
  ) async {
    final service = _FakeRemovalService(error: StateError('secret failure'));
    await _pumpDetail(tester, service: service);
    await _openRemovalDialog(tester);

    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.byKey(const Key('account-detail-screen')), findsOneWidget);
    expect(
      find.text('Không thể xóa tài khoản khỏi thiết bị. Thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret failure'), findsNothing);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required AccountRemovalService service,
  bool withParentRoute = false,
}) async {
  final home = withParentRoute
      ? Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open-detail'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountDetailScreen(),
                  ),
                ),
                child: const Text('ACCOUNT LIST'),
              ),
            ),
          ),
        )
      : const AccountDetailScreen();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeDemoAccountProvider.overrideWithValue(_account),
        accountRemovalServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRemovalDialog(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('account-detail-scroll')),
    const Offset(0, -420),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('account-delete-row')));
  await tester.pumpAndSettle();
}

final class _FakeRemovalService implements AccountRemovalService {
  _FakeRemovalService({
    this.result = AccountRemovalResult.signedOut,
    this.error,
    this.gate,
  });

  final AccountRemovalResult result;
  final Object? error;
  final Completer<AccountRemovalResult>? gate;
  int calls = 0;

  @override
  Future<AccountRemovalResult> removeActiveAccount() async {
    calls += 1;
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return result;
  }
}

const _account = DemoAccountProfile(
  id: '100001',
  name: 'Account A',
  company: 'Example Markets',
  server: 'Example-Demo',
  accessPoint: 'Access Point #1',
  balance: 100,
  brand: DemoBrokerBrand.unknown,
  historyDeposit: 0,
  historyWithdrawal: 0,
  historyProfit: 0,
  historySwap: 0,
  historyCommission: 0,
  historyBalance: 100,
);
