import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/features/account_link/data/account_link_repository.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';

final accountLinkRepositoryProvider = Provider<AccountLinkRepository>(
  (ref) => AccountLinkRepository(ref.watch(exV2ApiClientProvider)),
);
