import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AccountSwitchInProgress implements Exception {
  const AccountSwitchInProgress();
}

final class AccountSwitchLease {
  const AccountSwitchLease(this.authority);

  final int authority;
}

final class AccountSwitchGuard {
  var _nextAuthority = 0;
  AccountSwitchLease? _active;

  AccountSwitchLease? tryAcquire() {
    if (_active != null) return null;
    return _active = AccountSwitchLease(++_nextAuthority);
  }

  void release(AccountSwitchLease lease) {
    if (identical(_active, lease)) _active = null;
  }
}

final accountSwitchGuardProvider = Provider<AccountSwitchGuard>(
  (ref) => AccountSwitchGuard(),
);
