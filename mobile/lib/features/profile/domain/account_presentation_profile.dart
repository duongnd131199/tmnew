enum DemoBrokerBrand { vantage, exness, yodo, metaquotes, unknown }

DemoBrokerBrand resolveDemoBrokerBrand({
  String brokerId = '',
  String companyName = '',
  String serverName = '',
}) {
  final identity = '$brokerId $companyName $serverName'.toLowerCase();
  if (identity.contains('exness')) return DemoBrokerBrand.exness;
  if (identity.contains('yodo')) return DemoBrokerBrand.yodo;
  if (identity.contains('vantage')) return DemoBrokerBrand.vantage;
  if (identity.contains('metaquotes')) return DemoBrokerBrand.metaquotes;
  return DemoBrokerBrand.unknown;
}

final class AccountPresentationMetadata {
  const AccountPresentationMetadata({
    required this.companyName,
    required this.tradingServer,
    required this.accessPoint,
    required this.brand,
    required this.accountMode,
    required this.isMaster,
  });

  final String companyName;
  final String tradingServer;
  final String accessPoint;
  final DemoBrokerBrand brand;
  final String accountMode;
  final bool isMaster;
}

final class DemoAccountProfile {
  const DemoAccountProfile({
    required this.id,
    required this.name,
    required this.company,
    required this.server,
    required this.accessPoint,
    required this.balance,
    required this.brand,
    required this.historyDeposit,
    required this.historyWithdrawal,
    required this.historyProfit,
    required this.historySwap,
    required this.historyCommission,
    required this.historyBalance,
    this.currency = 'USD',
    this.mode = 'Hedge',
    this.isMaster = true,
    this.isDemo = false,
    this.linkedAccountId,
  });

  final String id;
  final String name;
  final String company;
  final String server;
  final String accessPoint;
  final double balance;
  final DemoBrokerBrand brand;
  final String currency;
  final String mode;
  final bool isMaster;
  final bool isDemo;
  final String? linkedAccountId;
  final double historyDeposit;
  final double historyWithdrawal;
  final double historyProfit;
  final double historySwap;
  final double historyCommission;
  final double historyBalance;
}
