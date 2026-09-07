import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/profile/application/ex_v2_account_profile_mapper.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

void main() {
  test('missing presentation metadata never exposes unavailable copy', () {
    final state = _accountState(
      accountCode: '100001',
      name: 'Server account',
      status: 'active',
      balance: 154763.90,
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.id, '100001');
    expect(profile.name, 'Server account');
    expect(profile.balance, 154763.90);
    expect(profile.currency, 'USD');
    expect(profile.company, 'Trading Account');
    expect(profile.server, 'Trading Server');
    expect(profile.accessPoint, 'Access Point #1');
    expect(profile.brand, DemoBrokerBrand.unknown);
    expect(profile.company, isNot('active'));
    expect(profile.server, isNot('trochoi.top'));
    expect(profile.accessPoint, isNot('EX V2'));
  });

  test('activated linked-account metadata is visible before hydration', () {
    final state = _accountState(
      accountCode: '200002',
      name: 'Second account',
      status: 'active',
      balance: 25,
      presentation: const ExV2AccountPresentation(
        brokerId: 'broker-second',
        companyName: 'Second Broker Ltd',
        serverId: 'server-second',
        tradingServer: 'Second-Live-02',
      ),
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.company, 'Second Broker Ltd');
    expect(profile.server, 'Second-Live-02');
    expect(profile.brand, DemoBrokerBrand.unknown);
  });

  test('YODO linked-account metadata selects the YODO presentation', () {
    final state = _accountState(
      accountCode: '200003',
      name: 'Mỗi Ngày Một Tỷ 🍀',
      status: 'active',
      balance: 25,
      presentation: const ExV2AccountPresentation(
        brokerId: 'yodo-demo',
        companyName: 'YODO Demo Markets',
        serverId: 'yodo-demo-01',
        tradingServer: 'YODO-Demo-01',
      ),
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.company, 'YODO Demo Markets');
    expect(profile.server, 'YODO-Demo-01');
    expect(profile.accessPoint, 'Access Point #1');
    expect(profile.brand, DemoBrokerBrand.yodo);
  });

  test('MetaQuotes account metadata resolves the MetaQuotes brand', () {
    final state = _accountState(
      accountCode: '1115000232',
      name: 'HaiAa NamAa',
      status: 'active',
      balance: 100000,
      presentation: const ExV2AccountPresentation(
        brokerId: 'metaquotes-demo',
        companyName: 'MetaQuotes Ltd.',
        serverId: 'metaquotes-demo',
        tradingServer: 'MetaQuotes-Demo',
      ),
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.brand.name, 'metaquotes');
  });

  test('stored broker identity replaces generic server placeholders', () {
    final state = _accountState(
      accountCode: '1115000232',
      name: 'HaiAa NamAa',
      status: 'active',
      balance: 100000,
      settings: const {
        'brokerCompany': 'Trading Account',
        'tradingServer': 'Trading Server',
      },
      presentation: const ExV2AccountPresentation(
        brokerId: 'metaquotes-demo',
        companyName: 'MetaQuotes Ltd.',
        serverId: 'metaquotes-demo',
        tradingServer: 'MetaQuotes-Demo',
      ),
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.company, 'MetaQuotes Ltd.');
    expect(profile.server, 'MetaQuotes-Demo');
    expect(profile.brand.name, 'metaquotes');
  });

  test('canonical settings metadata wins over activated metadata', () {
    final state = _accountState(
      accountCode: 'LIVE-7',
      name: 'Live account',
      status: 'active',
      balance: 25,
      settings: const {
        'brokerCompany': 'Canonical Broker Ltd',
        'tradingServer': 'Canonical-MT5Live01',
        'accessPoint': 'Access Point #4',
        'accountMode': 'Netting',
        'isMaster': false,
      },
      presentation: const ExV2AccountPresentation(
        brokerId: 'broker-second',
        companyName: 'Second Broker Ltd',
        serverId: 'server-second',
        tradingServer: 'Second-Live-02',
      ),
    );

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.company, 'Canonical Broker Ltd');
    expect(profile.server, 'Canonical-MT5Live01');
    expect(profile.accessPoint, 'Access Point #4');
    expect(profile.mode, 'Netting');
    expect(profile.isMaster, isFalse);
  });

  test('profile balance ignores optimistic local close valuation', () {
    final state =
        _accountState(
          accountCode: 'LIVE-8',
          name: 'Authoritative account',
          status: 'active',
          balance: 1000,
        ).copyWith(
          positions: const [],
          pendingCloseValuationPositions: const [
            DemoPosition(
              id: 'position-1',
              symbol: 'XAUUSD+',
              side: 'BUY',
              volume: 1,
              openPrice: 100,
              currentPrice: 102,
              profit: 200,
            ),
          ],
          liveValuationPositionIds: const {'position-1'},
        );

    expect(state.balance, 1200);

    final profile = ExV2AccountProfileMapper.map(state);

    expect(profile.balance, 1000);
    expect(profile.historyBalance, 1000);
  });
}

ExV2AccountViewState _accountState({
  required String accountCode,
  required String name,
  required String status,
  required double balance,
  Map<String, dynamic> settings = const {},
  ExV2AccountPresentation? presentation,
}) {
  final bootstrap = ExV2Bootstrap.fromJson({
    'serverTime': '2026-08-14T08:00:00Z',
    'version': 3,
    'device': {'id': 'device-1', 'name': 'Phone'},
    'activeAccount': {
      'id': 'account-1',
      'accountCode': accountCode,
      'name': name,
      'currency': 'USD',
      'status': status,
    },
    'summary': {
      'accountId': 'account-1',
      'currency': 'USD',
      'balance': balance,
      'equity': balance,
      'profit': 0,
      'margin': 0,
      'freeMargin': balance,
      'marginLevel': 0,
      'updatedAt': '2026-08-14T08:00:00Z',
    },
    'positions': <Object?>[],
    'pendingOrders': <Object?>[],
    'recentDeals': <Object?>[],
    'wallet': {
      'currency': 'USD',
      'availableBalance': balance,
      'lockedBalance': 0,
      'totalBalance': balance,
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
  });

  return ExV2AccountViewState.fromBootstrap(
    bootstrap,
    presentation: presentation,
  ).copyWith(settings: settings);
}
