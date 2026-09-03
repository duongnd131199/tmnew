import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({required this.dealId, super.key});
  final String dealId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(displayTradingTicketId(dealId))),
      body: const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _HistoryRow(label: 'Symbol', value: 'EURUSD'),
            _HistoryRow(label: 'Loại lệnh', value: 'Market Buy'),
            _HistoryRow(label: 'Khối lượng', value: '0.20 lot'),
            _HistoryRow(label: 'Giá mở', value: '1.17070'),
            _HistoryRow(label: 'Giá đóng', value: '1.17284'),
            _HistoryRow(label: 'Commission', value: '-\$1.20'),
            _HistoryRow(label: 'Swap', value: '\$0.00'),
            Divider(),
            _HistoryRow(label: 'Lợi nhuận', value: '+\$42.80'),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Text(label, style: AppTypography.bodySmall),
        const Spacer(),
        Text(value, style: AppTypography.numberMedium),
      ],
    ),
  );
}
