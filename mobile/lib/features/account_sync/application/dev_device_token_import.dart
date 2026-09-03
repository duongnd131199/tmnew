import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/account_sync/data/device_token_store.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';
import 'package:trading_mobile/features/account_sync/data/ex_v2_repository.dart';

typedef DeviceTokenBootstrapValidator = Future<void> Function(String token);

final deviceActivationServiceProvider = Provider<DeviceActivationService>(
  (ref) => DeviceActivationService(ref.watch(deviceTokenStoreProvider)),
);

final deviceTokenBootstrapValidatorProvider =
    Provider<DeviceTokenBootstrapValidator>((ref) {
      final dio = ref.watch(exV2DioProvider);
      return (token) async {
        final client = ExV2ApiClient(dio: dio, tokenReader: () async => token);
        await ExV2Repository(client).bootstrap();
      };
    });
