import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';

abstract final class ExV2AccountProfileMapper {
  static AccountPresentationMetadata metadata(JsonMap settings) {
    return AccountPresentationMetadata(
      companyName:
          _text(settings, const ['brokerCompany', 'companyName', 'company']) ??
          'Exness Technologies Ltd',
      tradingServer:
          _text(settings, const ['tradingServer', 'mt5Server', 'server']) ??
          'Exness-MT5Real20',
      accessPoint:
          _text(settings, const ['accessPoint', 'mt5AccessPoint']) ??
          'Access Point #9',
      brand: DemoBrokerBrand.exness,
      accountMode:
          _text(settings, const ['accountMode', 'positionMode']) ?? 'Hedge',
      isMaster: _bool(settings, 'isMaster') ?? true,
    );
  }

  static DemoAccountProfile map(ExV2AccountViewState state) {
    final account = state.bootstrap.account;
    final presentation = metadata(state.settings);
    return DemoAccountProfile(
      id: account.accountCode,
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
}
