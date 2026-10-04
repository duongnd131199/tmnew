import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/account_session.dart';
import 'account_notification.dart';

final notificationsProvider = FutureProvider<List<AccountNotification>>((
  ref,
) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) return const [];
  final rows = await ref.watch(accountRepositoryProvider).notifications();
  return rows.map(AccountNotification.fromJson).toList(growable: false);
});
