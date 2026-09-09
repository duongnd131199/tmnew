import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_price_precision.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/order/presentation/order_failure_message.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/order_ticket_quote_text.dart';

class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.positionId, super.key});

  final String positionId;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  double? stopLoss;
  double? takeProfit;
  bool initialized = false;
  bool showActionMenu = false;
  bool submittingProtection = false;
  double? _lastQuoteMidpoint;
  Color _quoteColor = AppColors.tradeNegative;

  void _trackQuoteDirection(DemoQuote? quote) {
    if (quote == null) return;
    final midpoint = (quote.bid + quote.ask) / 2;
    final previous = _lastQuoteMidpoint;
    if (previous != null && midpoint != previous) {
      _quoteColor = midpoint > previous
          ? AppColors.primary
          : AppColors.tradeNegative;
    }
    _lastQuoteMidpoint = midpoint;
  }

  void _selectAction(DemoPosition position, String action) {
    if (action == 'Sửa trạng thái') {
      setState(() => showActionMenu = false);
      return;
    }
    if (action == 'Đóng bởi') {
      setState(() => showActionMenu = false);
      _showCloseByPositions(position);
      return;
    }
    context.push(
      '/order?symbol=${Uri.encodeQueryComponent(position.symbol)}'
      '&type=${Uri.encodeQueryComponent(action)}',
    );
  }

  void _showCloseByPositions(DemoPosition source) {
    final candidates = ref
        .read(demoPositionsProvider)
        .where(
          (position) =>
              position.id != source.id &&
              position.symbol == source.symbol &&
              position.side != source.side,
        )
        .toList(growable: false);
    if (candidates.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Đóng bởi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final candidate in candidates)
              ListTile(
                key: ValueKey('position-detail-close-by-${candidate.id}'),
                title: Text(
                  '#${displayTradingTicketId(candidate.id)} '
                  '${candidate.side.toLowerCase()} '
                  '${_formatVolume(candidate.volume)} '
                  '${displayTradingSymbol(candidate.symbol)}',
                ),
                onTap: () {
                  ref
                      .read(demoTradingProvider.notifier)
                      .closeByPositions(source.id, candidate.id);
                  Navigator.pop(sheetContext);
                  if (mounted) context.pop();
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProtection(DemoPosition position) async {
    if (submittingProtection) return;
    setState(() => submittingProtection = true);
    try {
      if (ref.read(exV2EnabledProvider)) {
        await ref
            .read(exV2AccountProvider.notifier)
            .updatePositionProtection(
              positionId: position.id,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: stopLoss == null,
              clearTakeProfit: takeProfit == null,
            );
      } else {
        final modified = ref
            .read(demoTradingProvider.notifier)
            .modifyPosition(
              position.id,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              clearStopLoss: stopLoss == null,
              clearTakeProfit: takeProfit == null,
            );
        if (!modified) throw StateError('Position is not open');
      }
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => submittingProtection = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              orderFailureMessage(
                error,
                fallback: 'Không thể sửa Cắt lỗ/Chốt lời',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref
        .watch(demoPositionsProvider)
        .where((position) => position.id == widget.positionId);
    if (matches.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: TextButton(
              onPressed: () => context.go('/trade'),
              child: const Text('Vị thế đã được đóng'),
            ),
          ),
        ),
      );
    }
    final position = matches.first;
    if (!initialized) {
      stopLoss = position.stopLoss;
      takeProfit = position.takeProfit;
      initialized = true;
    }
    ref.listen<AsyncValue<DemoQuote>>(demoQuoteProvider(position.symbol), (
      previous,
      next,
    ) {
      next.whenData(
        (quote) => ref
            .read(demoTradingProvider.notifier)
            .updateMarketPrice(
              symbol: position.symbol,
              bid: quote.bid,
              ask: quote.ask,
            ),
      );
    });
    final liveQuote = ref.watch(demoQuoteProvider(position.symbol)).value;
    _trackQuoteDirection(liveQuote);
    final priceDigits = _priceDigits(position.symbol);
    final priceStep = switch (priceDigits) {
      5 => .00001,
      3 => .001,
      _ => .01,
    };
    final bid = liveQuote?.bid ?? position.currentPrice;
    final ask =
        liveQuote?.ask ??
        position.currentPrice +
            (position.symbol == 'BTCUSD'
                ? 17.12
                : position.symbol == 'XAUUSD'
                ? .124
                : .13);
    final changed =
        stopLoss != position.stopLoss || takeProfit != position.takeProfit;
    final referenceTopInset = MediaQuery.paddingOf(
      context,
    ).top.clamp(0.0, 24.0);
    return Scaffold(
      backgroundColor: AppColors.orderTicketSurface,
      body: Padding(
        padding: EdgeInsets.only(top: referenceTopInset),
        child: Column(
          children: [
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  Positioned(
                    left: 17.3333333333,
                    top: 29,
                    child: _BackButton(onTap: () => context.pop()),
                  ),
                  Positioned(
                    left: 70,
                    right: 70,
                    top: 34,
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayTradingSymbol(position.symbol),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              CupertinoIcons.chevron_down,
                              color: AppColors.textPrimary,
                              size: 10,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _symbolDescription(position.symbol),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'sans-serif',
                            fontSize: 11.5,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showActionMenu)
              _PositionActionMenu(
                onSelect: (action) => _selectAction(position, action),
              )
            else ...[
              Material(
                color: AppColors.surface,
                child: InkWell(
                  key: const Key('position-action-field'),
                  onTap: () => setState(() => showActionMenu = true),
                  child: SizedBox(
                    height: 41,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${displayTradingTicketId(position.id)} '
                              '${position.side.toLowerCase()} '
                              '${_formatVolume(position.volume)} '
                              '${displayTradingSymbol(position.symbol)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'sans-serif',
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            color: AppColors.textPrimary,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _ProtectionRow(
                label: 'Cat lo',
                value: stopLoss,
                digits: priceDigits,
                onDecrease: () => setState(
                  () => stopLoss =
                      (stopLoss ?? position.currentPrice) - priceStep,
                ),
                onIncrease: () => setState(
                  () => stopLoss =
                      (stopLoss ?? position.currentPrice) + priceStep,
                ),
                onClear: () => setState(() => stopLoss = null),
              ),
              _ProtectionRow(
                label: 'Chot loi',
                value: takeProfit,
                digits: priceDigits,
                onDecrease: () => setState(
                  () => takeProfit =
                      (takeProfit ?? position.currentPrice) - priceStep,
                ),
                onIncrease: () => setState(
                  () => takeProfit =
                      (takeProfit ?? position.currentPrice) + priceStep,
                ),
                onClear: () => setState(() => takeProfit = null),
              ),
              ColoredBox(
                key: const Key('position-detail-quote-strip'),
                color: AppColors.orderTicketSurface,
                child: SizedBox(
                  height: 55,
                  child: Row(
                    children: [
                      Expanded(
                        child: OrderTicketQuoteText(
                          formattedPrice: bid.toStringAsFixed(priceDigits),
                          usePipette: isGoldTradingSymbol(position.symbol),
                          color: _quoteColor,
                        ),
                      ),
                      Expanded(
                        child: OrderTicketQuoteText(
                          formattedPrice: ask.toStringAsFixed(priceDigits),
                          usePipette: isGoldTradingSymbol(position.symbol),
                          color: _quoteColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.positionModifySurface,
                    disabledBackgroundColor: AppColors.positionModifySurface,
                    foregroundColor: AppColors.positionModifyText,
                    disabledForegroundColor: AppColors.positionModifyText,
                    side: const BorderSide(
                      color: AppColors.positionModifyBorder,
                    ),
                    shape: const RoundedRectangleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: changed && !submittingProtection
                      ? () => _submitProtection(position)
                      : null,
                  child: const Text(
                    'Chinh sua',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: ColoredBox(
                  key: Key('position-detail-lower-surface'),
                  color: AppColors.orderTicketSurface,
                  child: SizedBox.expand(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14, 17, 14, 0),
                        child: Text(
                          'Chot Loi/ Cat Lo phai duoc dat it nhat 0 điểm so voi gia thi\n'
                          'truong. Qua trinh Chot Loi/ Cat Lo se duoc thuc hien boi\n'
                          'broker.',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: AppTypography.condensedFamily,
                            fontSize: 13.2,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PositionActionMenu extends StatelessWidget {
  const _PositionActionMenu({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const _actions = <(String, Color, bool)>[
    ('Vao lenh thi truong', AppColors.textPrimary, false),
    ('Buy Limit', AppColors.primary, false),
    ('Sell Limit', AppColors.tradeNegative, false),
    ('Buy Stop', AppColors.primary, false),
    ('Sell Stop', AppColors.tradeNegative, false),
    ('Buy Stop Limit', AppColors.primary, false),
    ('Sell Stop Limit', AppColors.tradeNegative, false),
    ('Sửa trạng thái', AppColors.textPrimary, true),
    ('Đóng bởi', AppColors.textPrimary, false),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('position-action-menu'),
    color: AppColors.surface,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, color, selected) in _actions)
          Material(
            color: AppColors.surface,
            child: InkWell(
              key: ValueKey(
                'position-action-option-${label.toLowerCase().replaceAll(' ', '-')}',
              ),
              onTap: () => onSelect(label),
              child: SizedBox(
                height: 42,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontFamily: 'sans-serif',
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(
                          CupertinoIcons.check_mark,
                          color: AppColors.primary,
                          size: 23,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const SizedBox.square(
        dimension: 40,
        child: Icon(
          CupertinoIcons.chevron_left,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    ),
  );
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({
    required this.label,
    required this.value,
    required this.digits,
    required this.onDecrease,
    required this.onIncrease,
    required this.onClear,
  });

  final String label;
  final double? value;
  final int digits;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.orderTicketControlSurface,
    child: SizedBox(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 2),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'sans-serif',
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onDecrease,
              child: const SizedBox(
                width: 30,
                height: 38,
                child: Center(
                  child: Text(
                    '−',
                    style: TextStyle(
                      color: AppColors.orderTicketQuote,
                      fontFamily: 'sans-serif',
                      fontSize: 21,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onLongPress: onClear,
              child: SizedBox(
                width: 154,
                child: Transform.translate(
                  offset: const Offset(-1.3333333333, 0),
                  child: Text(
                    value?.toStringAsFixed(digits) ?? 'khong cai dat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == null
                          ? AppColors.orderTicketPlaceholder
                          : AppColors.textPrimary,
                      fontFamily: 'sans-serif',
                      fontSize: 14.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onIncrease,
              child: const SizedBox(
                width: 30,
                height: 38,
                child: Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: AppColors.orderTicketQuote,
                      fontFamily: 'sans-serif',
                      fontSize: 25,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

int _priceDigits(String symbol) {
  if (isGoldTradingSymbol(symbol)) return goldPriceFractionDigits;
  if (symbol == 'BTCUSD') return 2;
  return 5;
}

String _formatVolume(double volume) =>
    volume >= 1 ? volume.toStringAsFixed(0) : volume.toStringAsFixed(2);

String _symbolDescription(String symbol) => switch (symbol) {
  'XAUUSD' || 'XAUUSD+' => 'Gold vs US Dollar',
  'BTCUSD' => 'Bitcoin vs US Dollar Tether',
  'AUDNOK' => 'Australian Dollar vs Norwegian Krone',
  _ => symbol,
};
