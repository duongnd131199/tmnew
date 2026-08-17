import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';

abstract final class ExV2AccountProfileMapper {
  static AccountPresentationMetadata metadata(
    JsonMap settings, {
    ExV2AccountPresentation? presentation,
  }) {
    final companyName =
        _text(settings, const ['brokerCompany', 'companyName', 'company']) ??
        presentation?.companyName ??
        'Trading Account';
    final tradingServer =
        _text(settings, const ['tradingServer', 'mt5Server', 'server']) ??
        presentation?.tradingServer ??
        'Trading Server';
    return AccountPresentationMetadata(
      companyName: companyName,
      tradingServer: tradingServer,
      accessPoint:
          _text(settings, const ['accessPoint', 'mt5AccessPoint']) ??
          presentation?.accessPoint ??
          'Access Point #1',
      brand: _brand('${presentation?.brokerId ?? ''} $companyName'),
      accountMode:
          _text(settings, const ['accountMode', 'positionMode']) ?? 'Hedge',
      isMaster: _bool(settings, 'isMaster') ?? true,
    );
  }

  static DemoAccountProfile map(ExV2AccountViewState state) {
    final account = state.bootstrap.account;
    final presentation = metadata(
      state.settings,
      presentation: state.presentation,
    );
    return DemoAccountProfile(
      id: account.accountCode,
      linkedAccountId: account.id,
      name: account.name,
      company: presentation.companyName,
      server: presentation.tradingServer,
      accessPoint: presentation.accessPoint,
      balance: state.balance,
      brand: presentation.brand,
      currency: account.currency,
      mode: presentation.accountMode,
      isMaster: presentation.isMaster,
      historyDeposit: state.historySummary.deposit,
      historyWithdrawal: state.historySummary.withdrawal,
      historyProfit: state.historySummary.realizedProfit,
      historySwap: state.historySummary.swap,
      historyCommission: state.historySummary.commission,
      historyBalance: state.balance,
      isDemo: true,
    );
  }

  static String? _text(JsonMap settings, List<String> keys) {
    for (final key in keys) {
      final value = settings[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static bool? _bool(JsonMap settings, String key) {
    final value = settings[key];
    if (value is bool) return value;
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      };
    }
    return null;
  }

  static DemoBrokerBrand _brand(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('yodo')) return DemoBrokerBrand.yodo;
    if (normalized.contains('exness')) return DemoBrokerBrand.exness;
    if (normalized.contains('vantage')) return DemoBrokerBrand.vantage;
    return DemoBrokerBrand.unknown;
  }
}
