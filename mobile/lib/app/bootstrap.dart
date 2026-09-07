import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/app/app.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/presentation/device_gate.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/chart_view_session_store.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
  const chartViewSessionStore = SecureChartViewSessionStore(
    FlutterSecureStorage(),
  );
  runApp(
    await createBootstrapScope(
      chartViewSessionStore: chartViewSessionStore,
      child: const DeviceGate(child: TradingApp()),
    ),
  );
}

Future<ProviderScope> createBootstrapScope({
  required ChartViewSessionStore chartViewSessionStore,
  required Widget child,
}) async {
  final chartViewSession = await chartViewSessionStore.read();
  return ProviderScope(
    overrides: [
      marketApiConfigProvider.overrideWithValue(MarketApiConfig.production),
      exV2EnabledProvider.overrideWithValue(true),
      exV2RealtimeEnabledProvider.overrideWithValue(true),
      exV2FastAccountSummarySyncProvider.overrideWithValue(true),
      chartViewSessionStoreProvider.overrideWithValue(chartViewSessionStore),
      chartViewSessionSeedProvider.overrideWithValue(chartViewSession),
    ],
    child: child,
  );
}
