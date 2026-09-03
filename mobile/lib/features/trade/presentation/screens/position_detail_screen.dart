import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 76,
              child: Stack(
                children: [
                  Positioned(
                    left: 18,
                    top: 29,
                    child: _BackButton(onTap: () => context.pop()),
                  ),
                  Positioned(
                    left: 70,
                    right: 70,
                    top: 34,
                    child: Column(
                      children: [
                        Text(
                          '${displayTradingSymbol(position.symbol)}⌄',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _symbolDescription(position.symbol),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      '#${displayTradingTicketId(position.id)} '
                      '${position.side.toLowerCase()} '
                      '${_formatVolume(position.volume)} '
                      '${displayTradingSymbol(position.symbol)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      CupertinoIcons.chevron_down,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            _ProtectionRow(
              label: 'Cắt lỗ',
              value: stopLoss,
              digits: priceDigits,
              onDecrease: () => setState(
                () =>
                    stopLoss = (stopLoss ?? position.currentPrice) - priceStep,
              ),
              onIncrease: () => setState(
                () =>
                    stopLoss = (stopLoss ?? position.currentPrice) + priceStep,
              ),
              onClear: () => setState(() => stopLoss = null),
            ),
            _ProtectionRow(
              label: 'Chốt lời',
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
            SizedBox(
              height: 55,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bid.toStringAsFixed(priceDigits),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.negative,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ask.toStringAsFixed(priceDigits),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.negative,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceSelected,
                  foregroundColor: AppColors.textPrimary,
                  shape: const RoundedRectangleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: changed
                    ? () {
                        ref
                            .read(demoTradingProvider.notifier)
                            .modifyPosition(
                              position.id,
                              stopLoss: stopLoss,
                              takeProfit: takeProfit,
                              clearStopLoss: stopLoss == null,
                              clearTakeProfit: takeProfit == null,
                            );
                        context.pop();
                      }
                    : null,
                child: const Text(
                  'Chỉnh sửa',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                'Chốt Lời/ Cắt Lỗ phải được đặt ít nhất 0 điểm so với giá '
                'thị trường. Quá trình Chốt Lời/ Cắt Lỗ sẽ được thực hiện '
                'bởi broker.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onDecrease,
            child: const SizedBox(
              width: 32,
              height: 36,
              child: Center(
                child: Text('−', style: TextStyle(color: AppColors.primary)),
              ),
            ),
          ),
          GestureDetector(
            onLongPress: onClear,
            child: SizedBox(
              width: 105,
              child: Text(
                value?.toStringAsFixed(digits) ?? 'không cài đặt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onIncrease,
            child: const SizedBox(
              width: 32,
              height: 36,
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(color: AppColors.primary, fontSize: 23),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

int _priceDigits(String symbol) {
  if (symbol == 'XAUUSD') return 3;
  if (symbol == 'XAUUSD+' || symbol == 'BTCUSD') return 2;
  return 5;
}

String _formatVolume(double volume) =>
    volume >= 1 ? volume.toStringAsFixed(0) : volume.toStringAsFixed(2);

String _symbolDescription(String symbol) => switch (symbol) {
  'XAUUSD' || 'XAUUSD+' => 'Gold vs US Dollar',
  'BTCUSD' => 'Bitcoin',
  'AUDNOK' => 'Australian Dollar vs Norwegian Krone',
  _ => symbol,
};
