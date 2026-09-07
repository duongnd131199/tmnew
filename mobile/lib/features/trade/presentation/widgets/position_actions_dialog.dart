import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/trade/presentation/trade_formatters.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

enum PositionAction {
  close,
  closeBy,
  modify,
  trade,
  depthOfMarket,
  chart,
  bulk,
  cancel,
}

class PositionActionsDialog extends StatelessWidget {
  const PositionActionsDialog({
    required this.position,
    required this.canCloseBy,
    super.key,
  });

  final DemoPosition position;
  final bool canCloseBy;

  String get _summary =>
      'Trạng thái: #${displayTradingTicketId(position.id)}\n'
      '${displayTradingSymbol(position.symbol)} '
      '${position.side.toLowerCase()} ${formatTradeVolume(position.volume)}';

  @override
  Widget build(BuildContext context) {
    final actions = <(PositionAction, String, bool)>[
      (PositionAction.close, 'Đóng trạng thái', true),
      if (canCloseBy) (PositionAction.closeBy, 'Đóng bởi', true),
      (PositionAction.modify, 'Sửa trạng thái', false),
      (PositionAction.trade, 'Giao dịch', false),
      (PositionAction.depthOfMarket, 'Depth of Market', false),
      (PositionAction.chart, 'Biểu đồ', false),
      (PositionAction.bulk, 'Hoạt động hàng loạt...', false),
      (PositionAction.cancel, 'Hủy', false),
    ];

    return Dialog(
      elevation: 0,
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Transform.translate(
        offset: const Offset(0, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 287),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                key: const Key('position-actions-dialog'),
                decoration: BoxDecoration(
                  color: AppColors.sheetSurface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.divider, width: .7),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 49,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              _summary,
                              key: const Key('position-actions-summary'),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'sans-serif',
                                fontSize: 15.5,
                                height: 1.35,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var index = 0; index < actions.length; index++) ...[
                        _PositionActionButton(
                          action: actions[index].$1,
                          label: actions[index].$2,
                          destructive: actions[index].$3,
                        ),
                        if (index != actions.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionActionButton extends StatelessWidget {
  const _PositionActionButton({
    required this.action,
    required this.label,
    required this.destructive,
  });

  final PositionAction action;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.positionActionSurface,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      key: ValueKey('position-action-${action.name}'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.pop(context, action),
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: destructive
                  ? AppColors.destructive
                  : AppColors.textPrimary,
              fontFamily: 'sans-serif',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}
