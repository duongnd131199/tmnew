import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../account/data/ex_v2_models.dart';
import '../data/wallet_transaction.dart';

final walletTransactionsProvider = FutureProvider<List<WalletTransaction>>((
  ref,
) async {
  final session = await ref.watch(accountSessionProvider.future);
  if (session == null) return const [];
  final rows = await ref.watch(accountRepositoryProvider).walletTransactions();
  return rows.map(WalletTransaction.fromJson).toList(growable: false);
});

class WalletSheet extends ConsumerWidget {
  const WalletSheet({required this.wallet, super.key});

  final ExV2Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(walletTransactionsProvider);
    return ExSheet(
      title: 'Ví nạp tiền',
      child: Column(
        key: const Key('wallet-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số dư ví demo',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatMoney(wallet.totalBalance, wallet.currency),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _BalanceLine(
                      label: 'Khả dụng',
                      value: formatMoney(
                        wallet.availableBalance,
                        wallet.currency,
                      ),
                    ),
                    _BalanceLine(
                      label: 'Đang giữ',
                      value: formatMoney(wallet.lockedBalance, wallet.currency),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              'Lịch sử giao dịch',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: ExEmptyState(
                  title: 'Không thể tải giao dịch ví',
                  action: TextButton(
                    onPressed: () => ref.invalidate(walletTransactionsProvider),
                    child: const Text('Thử lại'),
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: ExEmptyState(title: 'Chưa có giao dịch ví'),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) =>
                          _TransactionRow(items[index], wallet.currency),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.transaction, this.fallbackCurrency);

  final WalletTransaction transaction;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final amount = transaction.signedAmount;
    final currency = transaction.currency ?? fallbackCurrency;
    final amountText = amount == null
        ? 'Chưa có số tiền'
        : '${transaction.hasKnownDirection && amount > 0 ? '+' : ''}'
              '${formatMoney(amount, currency)}';
    final date = transaction.createdAt?.toLocal();
    final subtitle = [
      if (transaction.status.isNotEmpty) transaction.status,
      if (date != null)
        '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}',
    ].join(' · ');
    return ListTile(
      key: transaction.id.isEmpty ? null : Key('wallet-${transaction.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      title: Text(transaction.title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Text(
        amountText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: amount == null || !transaction.hasKnownDirection
              ? AppColors.textSecondary
              : amount < 0
              ? AppColors.negative
              : AppColors.positive,
        ),
      ),
    );
  }
}
