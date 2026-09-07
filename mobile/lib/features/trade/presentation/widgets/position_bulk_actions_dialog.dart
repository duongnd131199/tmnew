import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_radius.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/trade/presentation/trade_formatters.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

enum PositionBulkActionScope {
  all,
  profitable,
  sameSide,
  sameSymbol,
  sameSymbolAndSide,
  closeBySymbol,
}

class PositionBulkActionsDialog extends StatelessWidget {
  const PositionBulkActionsDialog({
    required this.position,
    this.canCloseBy = false,
    super.key,
  });

  final DemoPosition position;
  final bool canCloseBy;

  String get _sideLabel {
    final normalized = position.side.trim().toLowerCase();
    if (normalized.isEmpty) return normalized;
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String get _summary =>
      '#${displayTradingTicketId(position.id)} ${position.side.toLowerCase()} '
      '${formatTradeVolume(position.volume)} '
      '${displayTradingSymbol(position.symbol)} '
      '${formatPositionBulkOpenPrice(position.symbol, position.openPrice)}';

  List<(PositionBulkActionScope, String)> get _actions => [
    (PositionBulkActionScope.all, 'Đóng Tất Cả Lệnh Có Trạng Thái'),
    (
      PositionBulkActionScope.profitable,
      position.profit < 0
          ? 'Đóng Các Lệnh Có Trạng Thái Đang Lỗ'
          : 'Đóng Các Lệnh Có Trạng Thái Đang Có Lời',
    ),
    (PositionBulkActionScope.sameSide, 'Đóng $_sideLabel Lệnh có trạng thái'),
    (
      PositionBulkActionScope.sameSymbol,
      'Đóng ${displayTradingSymbol(position.symbol)} Lệnh có trạng thái',
    ),
    (
      PositionBulkActionScope.sameSymbolAndSide,
      'Đóng ${displayTradingSymbol(position.symbol)} '
          '$_sideLabel Lệnh có trạng thái',
    ),
    if (canCloseBy)
      (
        PositionBulkActionScope.closeBySymbol,
        'Đóng bởi ${displayTradingSymbol(position.symbol)}',
      ),
  ];

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.only(
      left: AppSpacing.md,
      right: AppSpacing.sm,
    ),
    child: Transform.translate(
      offset: const Offset(0, AppSpacing.sm + AppSpacing.xxs / 2),
      child: DecoratedBox(
        key: const Key('position-bulk-actions-dialog'),
        decoration: BoxDecoration(
          color: AppColors.sheetSurface,
          borderRadius: AppRadius.pill,
          border: Border.all(color: AppColors.divider, width: .7),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hoạt động hàng loạt',
                      key: const Key('position-bulk-title'),
                      style: AppTypography.dialogTitle,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    SizedBox(
                      height: 16.8,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _summary,
                          key: const Key('position-bulk-subtitle'),
                          maxLines: 1,
                          softWrap: false,
                          style: AppTypography.dialogSubtitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final (scope, label) in _actions) ...[
                _PositionBulkAction(
                  actionKey: ValueKey('position-bulk-action-${scope.name}'),
                  label: label,
                  destructive: true,
                  onTap: () => Navigator.pop(context, scope),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              _PositionBulkAction(
                actionKey: const Key('position-bulk-cancel'),
                label: 'Hủy',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PositionBulkAction extends StatelessWidget {
  const _PositionBulkAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs / 2),
    child: InkWell(
      borderRadius: AppRadius.pill,
      onTap: onTap,
      child: Container(
        key: actionKey,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.sheetActionSurface,
          borderRadius: AppRadius.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: AppTypography.dialogAction.copyWith(
                color: destructive
                    ? AppColors.destructive
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
