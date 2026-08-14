import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/profile/presentation/widgets/account_visuals.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(demoAccountsProvider);
    final serverAccount = ref.watch(exV2AccountProvider).value;
    final activeId =
        serverAccount?.accountCode ?? ref.watch(activeDemoAccountIdProvider);
    ref.watch(demoTradingProvider);
    final tradingController = ref.read(demoTradingProvider.notifier);
    final byId = {for (final account in accounts) account.id: account};
    final order = switch (activeId) {
      '425302695' => const ['425302695', '28210230', '463696038', '425297911'],
      '463696038' => const ['463696038', '425302695', '28210230', '425297911'],
      '425297911' => const ['425297911', '425302695', '28210230', '463696038'],
      _ => const ['28210230', '463696038', '425302695', '425297911'],
    };
    final ordered = serverAccount != null
        ? accounts
        : order.map((id) => byId[id]!).toList(growable: false);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 81,
              child: Stack(
                children: [
                  Positioned(
                    left: 15.3333333333,
                    top: 37,
                    child: KeyedSubtree(
                      key: const Key('accounts-back'),
                      child: AccountRoundBackButton(onTap: () => context.pop()),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 49,
                    child: IgnorePointer(
                      child: Text(
                        'Tài khoản',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 13.3333333333,
                    top: 37,
                    child: KeyedSubtree(
                      key: const Key('accounts-add'),
                      child: AccountRoundAddButton(
                        onTap: serverAccount == null
                            ? () => context.push('/register')
                            : () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 9),
                itemCount: ordered.length,
                itemBuilder: (context, index) {
                  final account = ordered[index];
                  return _AccountRow(
                    key: ValueKey('account-${account.id}'),
                    account: account,
                    displayBalance:
                        tradingController
                            .stateForAccount(account.id)
                            ?.balance ??
                        account.balance,
                    active: account.id == activeId,
                    onTap: account.id == activeId
                        ? () => context.push('/account-detail')
                        : () {
                            final controller = ref.read(
                              activeDemoAccountIdProvider.notifier,
                            );
                            context.pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              controller.select(account.id);
                            });
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.displayBalance,
    required this.active,
    required this.onTap,
    super.key,
  });

  final DemoAccountProfile account;
  final double displayBalance;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? AppColors.accountSelectedSurface : AppColors.background,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 97,
        child: Row(
          children: [
            const SizedBox(width: 15.3333333333),
            AccountBrokerMark(brand: account.brand),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.primary : AppColors.textPrimary,
                      fontFamily: 'sans-serif',
                      fontSize: 19.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${account.id} - ${account.server}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontFamily: 'sans-serif',
                      fontSize: 16.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatAccountBalance(displayBalance)} '
                    '${account.currency}, ${account.mode}',
                    maxLines: 1,
                    style: TextStyle(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontFamily: 'sans-serif',
                      fontSize: 16.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              const SizedBox.square(
                dimension: 21,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AccountChevronRight(),
                ),
              ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    ),
  );
}

String _formatAccountBalance(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(' ');
    grouped.write(digits[index]);
  }
  return '$grouped.${parts.last}';
}
