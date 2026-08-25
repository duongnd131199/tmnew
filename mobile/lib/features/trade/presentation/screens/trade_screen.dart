import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/trade/presentation/trade_formatters.dart';
import 'package:trading_mobile/features/trade/presentation/widgets/position_bulk_actions_dialog.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';

const _tradeSecondaryPrice = Color(0xFFB8B8BD);

enum _PositionMenuResult { bulk }

String _formatTradeNumber(double value, {int fractionDigits = 2}) {
  final parts = value.abs().toStringAsFixed(fractionDigits).split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(' ');
    grouped.write(digits[index]);
  }
  final sign = value < 0 ? '-' : '';
  if (fractionDigits == 0) return '$sign$grouped';
  return '$sign$grouped.${parts.last}';
}

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  String? revealedPositionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeTabIndex = AppTabScope.maybeIndexOf(context);
    if (activeTabIndex != null && activeTabIndex != 2) {
      revealedPositionId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = ref.watch(demoPositionsProvider);
    final pendingOrders = ref.watch(demoPendingOrdersProvider);
    final account = ref.watch(demoAccountProvider);
    final marketSymbols = ref.watch(marketSymbolsProvider);
    final defaultSymbol = marketSymbols.isEmpty
        ? 'XAUUSD+'
        : marketSymbols.first;
    for (final symbol in positions.map((item) => item.symbol).toSet()) {
      ref.listen<AsyncValue<DemoQuote>>(demoQuoteProvider(symbol), (
        previous,
        next,
      ) {
        next.whenData((quote) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(demoTradingProvider.notifier)
                .updateMarketPrice(
                  symbol: symbol,
                  bid: quote.bid,
                  ask: quote.ask,
                );
          });
        });
      });
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TradeHeader(
              totalProfit: account.profit,
              empty: positions.isEmpty && pendingOrders.isEmpty,
              onAccount: () => _showBalanceDialog(context),
              onAdd: () => context.push(
                '/order?symbol=${Uri.encodeQueryComponent(defaultSymbol)}'
                '&source=trade-add',
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.zero,
                itemCount: positions.length + pendingOrders.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return InkWell(
                      key: const Key('trade-account-metrics'),
                      onTap: () => _showBalanceDialog(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          6,
                          9.3333333333,
                          4.6333333333,
                          1.3333333333,
                        ),
                        child: Column(
                          children: [
                            _AccountMetric(
                              label: 'Số dư:',
                              value: _formatAccount(account.balance),
                            ),
                            _AccountMetric(
                              label: 'Von:',
                              value: _formatAccount(account.equity),
                            ),
                            if (positions.isNotEmpty)
                              _AccountMetric(
                                label: 'Tien ky quy:',
                                value: _formatAccount(account.margin),
                              ),
                            _AccountMetric(
                              label: 'Ky quy du:',
                              value: _formatAccount(account.freeMargin),
                            ),
                            if (positions.isNotEmpty)
                              _AccountMetric(
                                label: 'Muc ky quy (%):',
                                value: _formatAccount(account.marginLevel),
                              ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (index == 1) {
                    if (positions.isNotEmpty || pendingOrders.isNotEmpty) {
                      return Container(
                        height: TabReferenceMetrics.tradeSectionHeight,
                        width: double.infinity,
                        color: AppColors.surfaceElevated,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.3333333333,
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Lenh co trang thai',
                              key: Key('trade-section-label'),
                              style: AppTypography.tradeSection,
                            ),
                            const Spacer(),
                            Semantics(
                              label: 'Hoạt động hàng loạt',
                              button: true,
                              child: InkWell(
                                key: const Key('trade-bulk-menu'),
                                onTap: () => _showBulkActions(context, ref),
                                child: SizedBox(
                                  width: 35,
                                  height:
                                      TabReferenceMetrics.tradeSectionHeight,
                                  child: Center(
                                    child: Transform.translate(
                                      offset: const Offset(3.3333333333, 0),
                                      child: const _TradeEllipsisIcon(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const _EmptyTradeState();
                  }
                  final positionIndex = index - 2;
                  if (positionIndex < positions.length) {
                    final position = positions[positionIndex];
                    return _PositionRow(
                      key: ValueKey('trade-position-${position.id}'),
                      position: position,
                      priceDigits: tradePriceDigitsForSymbol(position.symbol),
                      revealed: revealedPositionId == position.id,
                      onTap: () => _showPositionActions(context, ref, position),
                      onReveal: () =>
                          setState(() => revealedPositionId = position.id),
                      onConceal: () {
                        if (revealedPositionId == position.id) {
                          setState(() => revealedPositionId = null);
                        }
                      },
                      onLongPress: () =>
                          _showPositionActions(context, ref, position),
                      onMore: () =>
                          _showPositionActions(context, ref, position),
                      onModify: () => context.push('/position/${position.id}'),
                      onClose: () => context.push(
                        '/order?symbol=${Uri.encodeQueryComponent(position.symbol)}'
                        '&positionId=${position.id}',
                      ),
                    );
                  }
                  final pendingOrderIndex = positionIndex - positions.length;
                  if (pendingOrderIndex < pendingOrders.length) {
                    final order = pendingOrders[pendingOrderIndex];
                    return _PendingOrderRow(
                      key: ValueKey('trade-pending-${order.id}'),
                      order: order,
                      priceDigits: tradePriceDigitsForSymbol(order.symbol),
                      onTap: () =>
                          _showPendingOrderActions(context, ref, order),
                    );
                  }
                  return const SizedBox(
                    key: Key('trade-bottom-safe-gap'),
                    height: 104,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAccount(double value) {
    return _formatTradeNumber(value);
  }

  static void _showBalanceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.dimBarrier,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 38.7),
        child: Transform.translate(
          offset: const Offset(1.3, 3.9666666667),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.sheetSurface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.divider, width: .7),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 29.3, 15, 15.7333333333),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Transform.translate(
                      offset: Offset(0, -1.3333333333),
                      child: Transform.scale(
                        scaleX: .96,
                        scaleY: 1.12,
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Số dư',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'sans-serif',
                            fontSize: 19.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 11.4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Transform.scale(
                      scaleX: 1.01,
                      scaleY: 1.06,
                      alignment: Alignment.topCenter,
                      child: Text(
                        'Nhanh chóng di chuyển đến trang nạp/ rút tiền '
                        'trên trang web của broker',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'sans-serif',
                          fontSize: 16.5,
                          height: 1.42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.6666666667),
                  _DialogAction(
                    label: 'Tien nap',
                    contentOffsetY: -1.3333333333,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      context.push('/deposit');
                    },
                  ),
                  _DialogAction(
                    label: 'Tien rut',
                    contentOffsetY: -1.3333333333,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      context.push('/withdraw');
                    },
                  ),
                  _DialogAction(
                    label: 'Huy',
                    contentOffsetY: -1.3333333333,
                    bottomGap: 0,
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showBulkActions(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.fromLTRB(17.3, 0, 15.3333333333, 0),
        child: Transform.translate(
          offset: const Offset(0, 4.3666666667),
          child: DecoratedBox(
            key: const Key('trade-bulk-actions-dialog'),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.divider, width: .7),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 7.3333333333),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 26.7, 0, 19.7),
                    child: Transform.scale(
                      scaleX: 1.08,
                      scaleY: 1.15,
                      alignment: Alignment.topCenter,
                      child: const Text(
                        'Hoạt động hàng loạt',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'sans-serif',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  _DialogAction(
                    label: 'Đóng Tất Cả Lệnh Có Trạng Thái',
                    destructive: true,
                    height: 46,
                    bottomGap: 9,
                    onTap: () {
                      ref
                          .read(demoTradingProvider.notifier)
                          .closeAllPositions();
                      Navigator.pop(dialogContext);
                    },
                  ),
                  _DialogAction(
                    label: 'Đóng Các Lệnh Có Trạng Thái Đang Có Lời',
                    destructive: true,
                    height: 46,
                    bottomGap: 9,
                    onTap: () {
                      ref
                          .read(demoTradingProvider.notifier)
                          .closeAllPositions(profitableOnly: true);
                      Navigator.pop(dialogContext);
                    },
                  ),
                  _DialogAction(
                    label: 'Đóng Các Lệnh Có Trạng Thái Đang Lỗ',
                    destructive: true,
                    height: 46,
                    bottomGap: 9,
                    onTap: () {
                      ref
                          .read(demoTradingProvider.notifier)
                          .closeAllPositions(losingOnly: true);
                      Navigator.pop(dialogContext);
                    },
                  ),
                  _DialogAction(
                    label: 'Huy',
                    height: 46,
                    bottomGap: 9,
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _executePositionBulkAction(
    WidgetRef ref,
    DemoPosition selected,
    PositionBulkActionScope scope,
  ) {
    final controller = ref.read(demoTradingProvider.notifier);
    return switch (scope) {
      PositionBulkActionScope.all => controller.closeMatchingPositions(),
      PositionBulkActionScope.profitable => controller.closeMatchingPositions(
        profitableOnly: true,
      ),
      PositionBulkActionScope.sameSide => controller.closeMatchingPositions(
        side: selected.side,
      ),
      PositionBulkActionScope.sameSymbol => controller.closeMatchingPositions(
        symbol: selected.symbol,
      ),
      PositionBulkActionScope.sameSymbolAndSide =>
        controller.closeMatchingPositions(
          symbol: selected.symbol,
          side: selected.side,
        ),
    };
  }

  static Future<void> _showPositionActions(
    BuildContext context,
    WidgetRef ref,
    DemoPosition position,
  ) async {
    final oppositePositions = ref
        .read(demoPositionsProvider)
        .where(
          (item) =>
              item.id != position.id &&
              item.symbol == position.symbol &&
              item.side != position.side,
        )
        .toList(growable: false);
    final result = await showModalBottomSheet<_PositionMenuResult>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.sheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  '${displayTradingSymbol(position.symbol)} '
                  '${position.side.toLowerCase()} '
                  '${formatTradeVolume(position.volume)}',
                ),
                subtitle: Text(
                  '${formatTradePrice(position.symbol, position.openPrice)} → '
                  '${formatTradePrice(position.symbol, position.currentPrice)}',
                ),
                trailing: Text(
                  _formatTradeNumber(position.profit),
                  style: TextStyle(
                    color: position.profit >= 0
                        ? AppColors.primary
                        : AppColors.negative,
                    fontSize: 18,
                  ),
                ),
              ),
              _SheetAction(
                label: 'Đóng trạng thái',
                color: AppColors.negative,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/order?symbol=${Uri.encodeQueryComponent(position.symbol)}'
                    '&positionId=${position.id}',
                  );
                },
              ),
              if (oppositePositions.isNotEmpty)
                _SheetAction(
                  label: 'Đóng bởi',
                  color: AppColors.negative,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Future<void>.delayed(Duration.zero, () {
                      if (!context.mounted) return;
                      _showCloseByChooser(
                        context,
                        ref,
                        position,
                        oppositePositions,
                      );
                    });
                  },
                ),
              _SheetAction(
                label: 'Sửa trạng thái',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/position/${position.id}');
                },
              ),
              _SheetAction(
                label: 'Giao dịch',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/order?symbol=${Uri.encodeQueryComponent(position.symbol)}',
                  );
                },
              ),
              _SheetAction(
                label: 'Depth of Market',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/section?title=${Uri.encodeComponent('Depth of Market ${position.symbol}')}',
                  );
                },
              ),
              _SheetAction(
                label: 'Biểu đồ',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(chartLocationForSymbol(position.symbol));
                },
              ),
              _SheetAction(
                label: 'Hoạt động hàng loạt...',
                onTap: () =>
                    Navigator.pop(sheetContext, _PositionMenuResult.bulk),
              ),
              _SheetAction(
                label: 'Hủy',
                color: AppColors.textPrimary,
                onTap: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || result != _PositionMenuResult.bulk) return;
    final scope = await showDialog<PositionBulkActionScope>(
      context: context,
      builder: (_) => PositionBulkActionsDialog(position: position),
    );
    if (!context.mounted || scope == null) return;
    _executePositionBulkAction(ref, position, scope);
  }

  static void _showCloseByChooser(
    BuildContext context,
    WidgetRef ref,
    DemoPosition source,
    List<DemoPosition> candidates,
  ) {
    String? selectedId;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Đóng bởi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${displayTradingSymbol(source.symbol)} '
                  '${source.side.toLowerCase()} '
                  '${formatTradeVolume(source.volume)}  #${source.id}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                RadioGroup<String>(
                  groupValue: selectedId,
                  onChanged: (value) => setSheetState(() => selectedId = value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final candidate in candidates)
                        RadioListTile<String>(
                          key: ValueKey('close-by-candidate-${candidate.id}'),
                          value: candidate.id,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${displayTradingSymbol(candidate.symbol)} '
                            '${candidate.side.toLowerCase()} '
                            '${formatTradeVolume(candidate.volume)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '#${candidate.id}  '
                            '${formatTradePrice(candidate.symbol, candidate.openPrice)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          secondary: Text(
                            _formatTradeNumber(candidate.profit),
                            style: TextStyle(
                              color: candidate.profit >= 0
                                  ? AppColors.primary
                                  : AppColors.negative,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('confirm-close-by'),
                    onPressed: selectedId == null
                        ? null
                        : () {
                            final closed = ref
                                .read(demoTradingProvider.notifier)
                                .closeByPositions(source.id, selectedId!);
                            Navigator.pop(sheetContext);
                            if (!closed) {
                              _showActionResult(
                                context,
                                'Không thể đóng hai vị thế đã chọn',
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.negative,
                      disabledBackgroundColor: AppColors.divider,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Hủy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showPendingOrderActions(
    BuildContext context,
    WidgetRef ref,
    DemoPendingOrder order,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  '${displayTradingSymbol(order.symbol)} '
                  '${order.type.toLowerCase()} '
                  '${order.volume.toStringAsFixed(2)}',
                ),
                subtitle: Text(order.price.toStringAsFixed(2)),
                trailing: const Text(
                  'placed',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
              _SheetAction(
                label: 'Xóa lệnh',
                color: AppColors.negative,
                onTap: () {
                  ref
                      .read(demoTradingProvider.notifier)
                      .cancelPendingOrder(order.id);
                  Navigator.pop(sheetContext);
                },
              ),
              _SheetAction(
                label: 'Sửa lệnh',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPendingPriceDialog(context, ref, order);
                },
              ),
              _SheetAction(
                label: 'Giao dịch',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/order?symbol=${Uri.encodeQueryComponent(order.symbol)}',
                  );
                },
              ),
              _SheetAction(
                label: 'Biểu đồ',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(chartLocationForSymbol(order.symbol));
                },
              ),
              _SheetAction(
                label: 'Hoạt động hàng loạt...',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBulkActions(context, ref);
                },
              ),
              _SheetAction(
                label: 'Hủy',
                color: AppColors.textPrimary,
                onTap: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static void _showActionResult(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(message),
        ),
      );
  }

  static void _showPendingPriceDialog(
    BuildContext context,
    WidgetRef ref,
    DemoPendingOrder order,
  ) {
    final controller = TextEditingController(
      text: order.price.toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${displayTradingSymbol(order.symbol)} ${order.type}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Giá'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                ref
                    .read(demoTradingProvider.notifier)
                    .modifyPendingOrder(order.id, price: price);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('XONG'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _TradeHeader extends StatelessWidget {
  const _TradeHeader({
    required this.totalProfit,
    required this.empty,
    required this.onAccount,
    required this.onAdd,
  });

  final double totalProfit;
  final bool empty;
  final VoidCallback onAccount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TabReferenceMetrics.tradeHeaderHeight,
      child: Stack(
        children: [
          Positioned(
            left: 15.3333333333,
            top: 37,
            child: _TradeCircleButton(
              key: const Key('trade-balance-button'),
              semanticLabel: 'Số dư',
              onTap: onAccount,
              child: Transform.translate(
                offset: const Offset(-.3333333333, 0),
                child: const _TradeCreditCardIcon(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 46.6333333333,
            child: IgnorePointer(
              child: Text(
                empty ? 'USD' : '${_formatTradeNumber(totalProfit)} USD',
                key: const Key('trade-header-profit'),
                textAlign: TextAlign.center,
                style:
                    (empty
                            ? AppTypography.toolbarTitle.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              )
                            : AppTypography.tradeHeaderProfit)
                        .copyWith(
                          color: empty
                              ? AppColors.textPrimary
                              : totalProfit >= 0
                              ? AppColors.primary
                              : AppColors.negative,
                        ),
              ),
            ),
          ),
          Positioned(
            right: 13.3333333333,
            top: 37,
            child: _TradeCircleButton(
              key: const Key('trade-add-button'),
              semanticLabel: 'Lệnh mới',
              onTap: onAdd,
              child: Transform.translate(
                offset: const Offset(.3333333333, -1.6666666667),
                child: const CustomPaint(
                  key: Key('trade-add-glyph'),
                  size: Size.square(24),
                  painter: _TradeAddIconPainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeEllipsisIcon extends StatelessWidget {
  const _TradeEllipsisIcon();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: Size(19.3333333333, 4),
    painter: _TradeEllipsisIconPainter(),
  );
}

class _TradeEllipsisIconPainter extends CustomPainter {
  const _TradeEllipsisIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textTertiary;
    for (final x in const [2.0, 9.6666666667, 17.3333333333]) {
      canvas.drawCircle(Offset(x, 2), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TradeAddIconPainter extends CustomPainter {
  const _TradeAddIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(const Offset(3, 12), const Offset(20, 12), paint);
    canvas.drawLine(const Offset(12, 3), const Offset(12, 20), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TradeCreditCardIcon extends StatelessWidget {
  const _TradeCreditCardIcon();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: Size(22, 16),
    painter: _TradeCreditCardIconPainter(),
  );
}

class _TradeCreditCardIconPainter extends CustomPainter {
  const _TradeCreditCardIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.textTertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1.25, 20, 13.5),
        const Radius.circular(1.5),
      ),
      stroke,
    );
    final details = Paint()..color = AppColors.textTertiary;
    for (final x in const [4.0, 7.4, 10.8, 14.2]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 5, 2.2, 1.5),
          const Radius.circular(.35),
        ),
        details,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 9.75, 13.8, 1.65),
        const Radius.circular(.5),
      ),
      details,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TradeCircleButton extends StatelessWidget {
  const _TradeCircleButton({
    required this.onTap,
    required this.child,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    child: ExcludeSemantics(
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.divider, width: .6),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42.6666666667,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

class _EmptyTradeState extends StatelessWidget {
  const _EmptyTradeState();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 463,
    child: Center(
      child: CustomPaint(
        size: const Size(133, 133),
        painter: _EmptyTradePainter(),
      ),
    ),
  );
}

class _EmptyTradePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 86;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = const Color(0xFFF4F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(8, 57)
      ..lineTo(35, 30)
      ..lineTo(47, 43)
      ..lineTo(79, 10);
    canvas.drawPath(path, paint);
    canvas.drawLine(const Offset(65, 10), const Offset(79, 10), paint);
    canvas.drawLine(const Offset(79, 10), const Offset(79, 25), paint);
    canvas.drawLine(const Offset(14.5, 74), const Offset(34, 55), paint);
    canvas.drawLine(const Offset(37, 74), const Offset(55, 55), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TabReferenceMetrics.tradeMetricRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              key: ValueKey('trade-metric-label-$label'),
              maxLines: 1,
              style: AppTypography.tradeMetric,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  key: ValueKey('trade-metric-value-$label'),
                  maxLines: 1,
                  style: AppTypography.tradeMetric,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatefulWidget {
  const _PositionRow({
    required this.position,
    required this.priceDigits,
    required this.revealed,
    required this.onTap,
    required this.onReveal,
    required this.onConceal,
    required this.onLongPress,
    required this.onMore,
    required this.onModify,
    required this.onClose,
    super.key,
  });

  final DemoPosition position;
  final int priceDigits;
  final bool revealed;
  final VoidCallback onTap;
  final VoidCallback onReveal;
  final VoidCallback onConceal;
  final VoidCallback onLongPress;
  final VoidCallback onMore;
  final VoidCallback onModify;
  final VoidCallback onClose;

  @override
  State<_PositionRow> createState() => _PositionRowState();
}

class _PositionRowState extends State<_PositionRow> {
  static const _revealExtent = 151.0;
  static const _snapFraction = .42;
  static const _flingVelocity = 650.0;
  static const _minimumFlingDistance = 28.0;
  static const _elasticFactor = .22;
  static const _maxElasticOverscroll = 24.0;

  double? _dragStartOffset;
  double? _rawDragOffset;
  double? _visibleDragOffset;
  bool _dragging = false;

  double get _settledOffset => widget.revealed ? -_revealExtent : 0;

  void _startDrag(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _dragStartOffset = _settledOffset;
      _rawDragOffset = _settledOffset;
      _visibleDragOffset = _settledOffset;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    final raw = (_rawDragOffset ?? _settledOffset) + details.delta.dx;
    setState(() {
      _rawDragOffset = raw;
      _visibleDragOffset = _applyElasticResistance(raw);
    });
  }

  double _applyElasticResistance(double offset) {
    if (offset > 0) {
      return (offset * _elasticFactor).clamp(0, _maxElasticOverscroll);
    }
    if (offset < -_revealExtent) {
      final overscroll = (-_revealExtent - offset) * _elasticFactor;
      return -_revealExtent - overscroll.clamp(0, _maxElasticOverscroll);
    }
    return offset;
  }

  void _endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final raw = _rawDragOffset ?? _settledOffset;
    final distance = raw - (_dragStartOffset ?? _settledOffset);
    final flingOpen =
        velocity < -_flingVelocity && distance < -_minimumFlingDistance;
    final flingClosed =
        velocity > _flingVelocity && distance > _minimumFlingDistance;
    final reveal =
        flingOpen || (!flingClosed && raw <= -_revealExtent * _snapFraction);
    _settle(reveal);
  }

  void _cancelDrag() {
    final raw = _rawDragOffset ?? _settledOffset;
    _settle(raw <= -_revealExtent * _snapFraction);
  }

  void _settle(bool reveal) {
    setState(() {
      _dragging = false;
      _dragStartOffset = null;
      _rawDragOffset = null;
      _visibleDragOffset = null;
    });
    if (reveal) {
      widget.onReveal();
    } else {
      widget.onConceal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final priceDigits = widget.priceDigits;
    final revealed = widget.revealed;
    final offset = _dragging
        ? (_visibleDragOffset ?? _settledOffset)
        : _settledOffset;
    final sideColor = position.side == 'BUY'
        ? AppColors.primary
        : AppColors.negative;
    final profitColor = position.profit >= 0
        ? AppColors.primary
        : AppColors.negative;
    final volumeLabel = formatTradeVolume(position.volume);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _startDrag,
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: _endDrag,
      onHorizontalDragCancel: _cancelDrag,
      child: SizedBox(
        height: TabReferenceMetrics.tradePositionRowHeight,
        child: Stack(
          children: [
            Positioned(
              top: 5.3,
              right: 3,
              height: 44,
              width: 145,
              child: ExcludeSemantics(
                excluding: !revealed,
                child: IgnorePointer(
                  ignoring: !revealed,
                  child: ColoredBox(
                    color: AppColors.background,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 45,
                          child: _InlineAction(
                            key: ValueKey('trade-menu-${position.id}'),
                            icon: const Icon(
                              CupertinoIcons.ellipsis,
                              color: Colors.white,
                              size: 22,
                            ),
                            color: const Color(0xFF929FB2),
                            onTap: widget.onMore,
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 45,
                          child: _InlineAction(
                            key: ValueKey('trade-modify-${position.id}'),
                            icon: const Icon(
                              CupertinoIcons.pencil,
                              color: Colors.white,
                              size: 22,
                            ),
                            color: AppColors.primary,
                            onTap: widget.onModify,
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 45,
                          child: _InlineAction(
                            key: ValueKey('trade-close-${position.id}'),
                            icon: const Icon(
                              CupertinoIcons.xmark,
                              color: Colors.white,
                              size: 23,
                            ),
                            color: AppColors.negative,
                            onTap: widget.onClose,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedContainer(
                key: ValueKey('trade-position-surface-${position.id}'),
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(offset, 0, 0),
                color: AppColors.background,
                child: InkWell(
                  onTap: revealed ? widget.onConceal : widget.onTap,
                  onLongPress: widget.onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      6,
                      8.6666666667,
                      4.6333333333,
                      2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -.6666666667),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: Text.rich(
                                    key: ValueKey(
                                      'trade-position-primary-${position.id}',
                                    ),
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${displayTradingSymbol(position.symbol)} ',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              '${position.side.toLowerCase()} '
                                              '$volumeLabel',
                                          style: TextStyle(color: sideColor),
                                        ),
                                      ],
                                    ),
                                    style: AppTypography.tradePositionPrimary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: TabReferenceMetrics
                                      .tradePositionSecondaryTop,
                                  child: Text(
                                    '${position.openPrice.toStringAsFixed(priceDigits)} → '
                                    '${position.currentPrice.toStringAsFixed(priceDigits)}',
                                    key: ValueKey(
                                      'trade-position-secondary-${position.id}',
                                    ),
                                    style: AppTypography.tradePositionSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Transform.translate(
                            offset: const Offset(.6666666667, 0),
                            child: Text(
                              _formatTradeNumber(position.profit),
                              key: ValueKey(
                                'trade-position-profit-${position.id}',
                              ),
                              style: AppTypography.tradePositionProfit.copyWith(
                                color: profitColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(23),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox.expand(child: Center(child: icon)),
    ),
  );
}

class _PendingOrderRow extends StatelessWidget {
  const _PendingOrderRow({
    required this.order,
    required this.priceDigits,
    required this.onTap,
    super.key,
  });

  final DemoPendingOrder order;
  final int priceDigits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onTap,
    child: SizedBox(
      height: TabReferenceMetrics.tradePositionRowHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5.3, 9.2, 7.3, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${displayTradingSymbol(order.symbol)} ',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${order.type.toLowerCase()} '
                              '${order.volume.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: order.side == 'BUY'
                                ? AppColors.primary
                                : AppColors.negative,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.6, height: 1),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    order.price.toStringAsFixed(priceDigits),
                    style: const TextStyle(
                      color: _tradeSecondaryPrice,
                      fontSize: 13.5,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'placed',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.bottomGap = 8,
    this.height = 47,
    this.contentOffsetY = 0,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final double bottomGap;
  final double height;
  final double contentOffsetY;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: height,
      alignment: Alignment.center,
      margin: EdgeInsets.only(bottom: bottomGap),
      decoration: BoxDecoration(
        color: AppColors.sheetActionSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Transform.translate(
        offset: Offset(0, contentOffsetY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.7),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: destructive
                    ? AppColors.destructive
                    : AppColors.textPrimary,
                fontFamily: 'sans-serif',
                fontSize: 18.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 43,
    title: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(color: color),
    ),
    onTap: onTap,
  );
}
