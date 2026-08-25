import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(exV2WalletViewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ví demo')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(exV2AccountProvider),
            child: const Text('Thử lại'),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số dư khả dụng',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${value.wallet.currency} ${_money(value.wallet.availableBalance)}',
                      style: AppTypography.numberLarge,
                    ),
                    if (value.wallet.lockedBalance != 0)
                      Text(
                        'Đang khóa: ${_money(value.wallet.lockedBalance)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/deposit'),
                    icon: const Icon(Icons.add),
                    label: const Text('Nạp demo'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/withdraw'),
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Rút demo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Giao dịch ví',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (value.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: Center(child: Text('Chưa có giao dịch ví')),
              )
            else
              for (final transaction in value.transactions)
                _WalletItem.fromJson(transaction),
          ],
        ),
      ),
    );
  }
}

class _WalletItem extends StatelessWidget {
  const _WalletItem({
    required this.title,
    required this.time,
    required this.amount,
    required this.color,
  });

  factory _WalletItem.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['transactionType'] ?? 'transaction')
        .toString();
    final amountValue = json['amountValue'] ?? json['amount'] ?? 0;
    final amount = amountValue is num ? amountValue.toDouble() : 0.0;
    final status = (json['status'] ?? '').toString();
    final createdAt =
        (json['createdAt'] ?? json['time'] ?? json['updatedAt'] ?? '')
            .toString();
    final negative =
        type.toLowerCase().contains('withdraw') ||
        type.toLowerCase().contains('out');
    return _WalletItem(
      title: type,
      time: status.isEmpty ? createdAt : '$createdAt · $status',
      amount: '${negative ? '-' : '+'}${_money(amount.abs())}',
      color: negative ? AppColors.negative : AppColors.positive,
    );
  }

  final String title;
  final String time;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(time),
    trailing: Text(
      amount,
      style: AppTypography.numberMedium.copyWith(color: color),
    ),
  );
}

String _money(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$buffer.${parts.last}';
}
