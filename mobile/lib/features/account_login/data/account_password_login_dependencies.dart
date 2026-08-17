import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trading_mobile/features/account_login/data/account_password_login_repository.dart';
import 'package:trading_mobile/features/account_login/data/installation_id_store.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';

final installationIdStoreProvider = Provider<InstallationIdStore>(
  (ref) => const SecureInstallationIdStore(FlutterSecureStorage()),
);

final accountPasswordLoginRepositoryProvider =
    Provider<AccountPasswordLoginRepository>(
      (ref) => AccountPasswordLoginRepository(ref.watch(exV2ApiClientProvider)),
    );
