import 'package:trading_mobile/features/account_sync/application/ex_v2_account_view_state.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/features/account_link/presentation/widgets/reference_server_catalog.dart';
import 'package:trading_mobile/features/profile/domain/account_presentation_profile.dart';

abstract final class ExV2AccountProfileMapper {
  static AccountPresentationMetadata metadata(
    JsonMap settings, {
    ExV2AccountPresentation? presentation,
  }) {
    final preferSelectedPresentation = usesReferenceServerPresentation(
      presentation?.brokerId ?? '',
    );
    final settingsCompany = _text(settings, const [
      'brokerCompany',
      'companyName',
      'company',
    ]);
    final settingsServer = _text(settings, const [
      'tradingServer',
      'mt5Server',
      'server',
    ]);
    final preferPresentationCompany =
        preferSelectedPresentation || _isPlaceholder(settingsCompany);
    final preferPresentationServer =
        preferSelectedPresentation || _isPlaceholder(settingsServer);
    final companyName = preferPresentationCompany
        ? presentation?.companyName ?? settingsCompany ?? 'Trading Account'
        : settingsCompany ?? presentation?.companyName ?? 'Trading Account';
    final tradingServer = preferPresentationServer
        ? presentation?.tradingServer ?? settingsServer ?? 'Trading Server'
        : settingsServer ?? presentation?.tradingServer ?? 'Trading Server';
    return AccountPresentationMetadata(
      companyName: companyName,
      tradingServer: tradingServer,
      accessPoint:
          _text(settings, const ['accessPoint', 'mt5AccessPoint']) ??
          presentation?.accessPoint ??
          'Access Point #1',
      brand: resolveDemoBrokerBrand(
        brokerId: presentation?.brokerId ?? '',
        companyName: companyName,
        serverName: tradingServer,
      ),
      accountMode:
          _text(settings, const ['accountMode', 'positionMode']) ?? 'Hedge',
      isMaster: _bool(settings, 'isMaster') ?? true,
    );
  }

  static DemoAccountProfile map(ExV2AccountViewState state) {
    final account = state.bootstrap.account;
    final authoritativeBalance = state.bootstrap.summary.balance;
    final historySummary = state.displayHistorySummary;
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
      balance: authoritativeBalance,
      brand: presentation.brand,
      currency: account.currency,
      mode: presentation.accountMode,
      isMaster: presentation.isMaster,
      historyDeposit: historySummary.deposit,
      historyWithdrawal: historySummary.withdrawal,
      historyProfit: historySummary.realizedProfit,
      historySwap: historySummary.swap,
      historyCommission: historySummary.commission,
      historyBalance: authoritativeBalance,
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

  static bool _isPlaceholder(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'trading account' || normalized == 'trading server';
  }
}
