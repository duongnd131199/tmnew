import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_link/domain/account_link_models.dart';
import 'package:trading_mobile/features/account_link/domain/linked_account_presentation.dart';

void main() {
  const account = LinkedTradingAccount(
    id: 'account-1',
    brokerId: 'yodo-demo',
    brokerName: 'YODO Demo Markets',
    serverId: 'yodo-demo-01',
    serverName: 'YODO-Demo-01',
    login: '109740422',
    isActive: true,
  );

  test('uses the exact server label selected while linking', () {
    const selected = LinkedAccountPresentation(
      companyName: 'Exness Technologies Ltd',
      serverName: 'Exness-MT5Real15',
    );

    final result = resolveLinkedAccountPresentation(account, selected);

    expect(result.companyName, 'Exness Technologies Ltd');
    expect(result.serverName, 'Exness-MT5Real15');
    expect(
      '${result.companyName} ${result.serverName}'.toLowerCase(),
      isNot(contains('yodo')),
    );
  });

  test(
    'captures the visible selected server instead of technical API names',
    () {
      const broker = MobileBroker(id: 'yodo-demo', name: 'YODO Demo Markets');
      const server = MobileTradingServer(
        id: 'yodo-demo-01',
        name: 'Exness-MT5Real15',
        brokerId: 'yodo-demo',
      );

      final result = presentationForSelectedServer(broker, server);

      expect(result.companyName, 'Exness Technologies Ltd');
      expect(result.serverName, 'Exness-MT5Real15');
    },
  );

  test('technical YODO values fall back to the visible server catalog', () {
    final result = resolveLinkedAccountPresentation(account, null);

    expect(result.companyName, 'Exness Technologies Ltd');
    expect(result.serverName, 'Exness-MT5Trial5');
    expect(
      '${result.companyName} ${result.serverName}'.toLowerCase(),
      isNot(contains('yodo')),
    );
  });
}
