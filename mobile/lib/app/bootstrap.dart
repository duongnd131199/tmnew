import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/app/app.dart';
import 'package:trading_mobile/core/config/market_api_config.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/presentation/device_gate.dart';
import 'package:trading_mobile/shared/providers/realtime_market_provider.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
  runApp(
    ProviderScope(
      overrides: [
        marketApiConfigProvider.overrideWithValue(MarketApiConfig.production),
        exV2EnabledProvider.overrideWithValue(true),
        exV2RealtimeEnabledProvider.overrideWithValue(true),
      ],
      child: const DeviceGate(child: TradingApp()),
    ),
  );
}
