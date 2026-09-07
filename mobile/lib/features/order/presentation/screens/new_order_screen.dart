import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/order/presentation/order_failure_message.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/order_ticket_quote_text.dart';

const _marketOrderType = 'Vao lenh thi truong';
const _orderTypes = <String>[
  _marketOrderType,
  'Buy Limit',
  'Sell Limit',
  'Buy Stop',
  'Sell Stop',
  'Buy Stop Limit',
  'Sell Stop Limit',
];
const _fillPolicies = <String>['Fill or Kill', 'Immediate or Cancel', 'Return'];
String _normalizeSide(String side) {
  return side.toLowerCase() == 'sell' ? 'SELL' : 'BUY';
}

double _maxVolumeForSymbol(String symbol) {
  return symbol.startsWith('XAU') ? 100 : 10;
}

double _priceStepForSymbol(String symbol, double price) {
  if (symbol.startsWith('XAU')) return .1;
  if (symbol == 'BTCUSD' || price.abs() >= 1000) return .01;
  if (price.abs() >= 100) return .001;
  return .0001;
}

double _defaultPendingPriceForForm({
  required String type,
  required double bid,
  required double ask,
  required double step,
}) {
  final isAbove = type.startsWith('Sell Limit') || type.startsWith('Buy Stop');
  return isAbove ? ask + step * 10 : bid - step * 10;
}

String _choiceKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('(^-+|-+\$)'), '');
}

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({
    required this.symbol,
    this.initialSide = 'buy',
    this.initialOrderType = _marketOrderType,
    this.closePositionId,
    this.tradeAddReferenceLayout = false,
    super.key,
  });

  final String symbol;
  final String initialSide;
  final String initialOrderType;
  final String? closePositionId;
  final bool tradeAddReferenceLayout;

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  double volume = 0.01;
  double? stopLoss;
  double? takeProfit;
  double? pendingPrice;
  bool submitting = false;
  late String selectedSide;
  String orderType = _marketOrderType;
  String fillPolicy = _fillPolicies.first;
  String? completedSide;
  double? completedPrice;
  double? completedVolume;
  String? completedOrderId;
  String? completedOrderType;
  bool completedByClosing = false;
  bool completedPendingOrder = false;
  double? _lastBid;
  double? _lastAsk;
  Color _bidColor = AppColors.tradeNegative;
  Color _askColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    selectedSide = _normalizeSide(widget.initialSide);
    orderType = _orderTypes.contains(widget.initialOrderType)
        ? widget.initialOrderType
        : _marketOrderType;
    if (orderType != _marketOrderType) {
      selectedSide = orderType.startsWith('Buy') ? 'BUY' : 'SELL';
    }
    if (widget.tradeAddReferenceLayout && widget.closePositionId == null) {
      volume = widget.symbol.trim().toUpperCase().startsWith('XAU') ? 1 : .01;
    }
    final closePositionId = widget.closePositionId;
    if (closePositionId != null) {
      final position = ref
          .read(demoPositionsProvider)
          .where((item) => item.id == closePositionId)
          .firstOrNull;
      if (position != null) {
        volume = position.volume < .01 ? position.volume : .01;
      }
    }
  }

  void _trackQuoteDirections(double bid, double ask) {
    if (_lastBid case final previous? when previous != bid) {
      _bidColor = bid > previous ? AppColors.primary : AppColors.tradeNegative;
    }
    if (_lastAsk case final previous? when previous != ask) {
      _askColor = ask > previous ? AppColors.primary : AppColors.tradeNegative;
    }
    _lastBid = bid;
    _lastAsk = ask;
  }

  @override
  void didUpdateWidget(covariant NewOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSide != widget.initialSide &&
        completedSide == null &&
        !submitting) {
      selectedSide = _normalizeSide(widget.initialSide);
    }
  }

  String _format(double value) {
    if (value >= 1000) return value.toStringAsFixed(2);
    if (value >= 100) return value.toStringAsFixed(3);
    return value.toStringAsFixed(5);
  }

  Future<void> _returnToTradeAfterCompletion() async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    router.go('/trade');
  }

  Future<void> _submit(String side, DemoQuote quote) async {
    if (submitting) return;
    final price = side == 'BUY' ? quote.ask : quote.bid;
    setState(() {
      submitting = true;
      selectedSide = side;
    });
    try {
      if (ref.read(exV2EnabledProvider)) {
        final order = await ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: widget.symbol,
              side: side,
              volume: volume,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              reconcileBeforeReturning: true,
            );
        if (!mounted) return;
        setState(() {
          submitting = false;
          completedSide = side;
          completedPrice = order.executedPrice ?? price;
          completedVolume = volume;
          completedOrderId = order.id;
          completedOrderType = _marketOrderType;
          completedPendingOrder = order.status.toLowerCase() != 'filled';
        });
        await _returnToTradeAfterCompletion();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final orderId = ref
          .read(demoTradingProvider.notifier)
          .placeOrder(
            symbol: widget.symbol,
            side: side,
            volume: volume,
            executedPrice: price,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
          );
      setState(() {
        submitting = false;
        completedSide = side;
        completedPrice = price;
        completedVolume = volume;
        completedOrderId = orderId;
        completedOrderType = _marketOrderType;
        completedPendingOrder = false;
      });
      await _returnToTradeAfterCompletion();
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderFailureMessage(error, fallback: 'Khong the dat lenh'),
          ),
        ),
      );
    }
  }

  Future<void> _submitPendingOrder(DemoQuote quote) async {
    final price = pendingPrice;
    if (submitting || price == null || orderType == _marketOrderType) return;
    final side = orderType.startsWith('Buy') ? 'BUY' : 'SELL';
    setState(() {
      submitting = true;
      selectedSide = side;
    });
    try {
      if (ref.read(exV2EnabledProvider)) {
        final normalized = orderType.toLowerCase();
        final order = await ref
            .read(exV2AccountProvider.notifier)
            .createOrder(
              symbol: widget.symbol,
              side: side,
              volume: volume,
              type: normalized.contains('stop') ? 'stop' : 'limit',
              requestedPrice: price,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              reconcileBeforeReturning: true,
            );
        if (!mounted) return;
        setState(() {
          submitting = false;
          completedSide = side;
          completedPrice = order.requestedPrice ?? price;
          completedVolume = volume;
          completedOrderId = order.id;
          completedOrderType = orderType;
          completedPendingOrder = order.status.toLowerCase() != 'filled';
        });
        await _returnToTradeAfterCompletion();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final orderId = ref
          .read(demoTradingProvider.notifier)
          .placePendingOrder(
            symbol: widget.symbol,
            type: orderType,
            volume: volume,
            price: price,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
          );
      setState(() {
        submitting = false;
        completedSide = side;
        completedPrice = price;
        completedVolume = volume;
        completedOrderId = orderId;
        completedOrderType = orderType;
        completedPendingOrder = true;
      });
      await _returnToTradeAfterCompletion();
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderFailureMessage(error, fallback: 'Khong the dat lenh cho'),
          ),
        ),
      );
    }
  }

  Future<void> _closePosition(DemoPosition position) async {
    if (submitting) return;
    setState(() => submitting = true);
    try {
      double closePrice = position.currentPrice;
      if (ref.read(exV2EnabledProvider)) {
        final closeDeal = await ref
            .read(exV2AccountProvider.notifier)
            .closePosition(
              position.id,
              volume: volume < position.volume ? volume : null,
            );
        if (closeDeal == null) {
          if (!mounted) return;
          context.go('/trade');
          return;
        }
        closePrice = closeDeal.price;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final closed = ref
            .read(demoTradingProvider.notifier)
            .closePosition(position.id, volume: volume);
        if (!closed) {
          setState(() => submitting = false);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        submitting = false;
        completedByClosing = true;
        completedSide = position.side == 'BUY' ? 'SELL' : 'BUY';
        completedPrice = closePrice;
        completedVolume = volume;
        completedOrderId = position.id;
        completedOrderType = 'Close';
        completedPendingOrder = false;
      });
      await _returnToTradeAfterCompletion();
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderFailureMessage(error, fallback: 'Khong the dong vi the'),
          ),
        ),
      );
    }
  }

  Future<void> _selectOrderType(DemoQuote quote) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Loai lenh',
        selected: orderType,
        options: _orderTypes,
        optionKeyPrefix: 'order-type-option',
      ),
    );
    if (!mounted || selected == null || selected == orderType) return;
    setState(() {
      orderType = selected;
      if (selected == _marketOrderType) {
        pendingPrice = null;
      } else {
        selectedSide = selected.startsWith('Buy') ? 'BUY' : 'SELL';
        pendingPrice = _defaultPendingPrice(selected, quote);
      }
    });
  }

  Future<void> _selectFillPolicy() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Fill Policy',
        selected: fillPolicy,
        options: _fillPolicies,
        optionKeyPrefix: 'order-fill-option',
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => fillPolicy = selected);
  }

  Future<void> _editVolume(double maxVolume) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _VolumeEditorSheet(initialValue: volume, maxVolume: maxVolume),
    );
    if (!mounted || selected == null) return;
    setState(() => volume = selected.clamp(.01, maxVolume).toDouble());
  }

  double _defaultPendingPrice(String type, DemoQuote quote) {
    final step = _priceStepForSymbol(widget.symbol, quote.bid) * 10;
    final isAbove =
        type.startsWith('Sell Limit') || type.startsWith('Buy Stop');
    final value = isAbove ? quote.ask + step : quote.bid - step;
    return double.parse(_format(value));
  }

  @override
  Widget build(BuildContext context) {
    final initial = ref
        .watch(demoQuotesProvider)
        .firstWhere((quote) => quote.symbol == widget.symbol);
    final quote = ref.watch(demoQuoteProvider(widget.symbol)).value ?? initial;
    _trackQuoteDirections(quote.bid, quote.ask);
    if (orderType != _marketOrderType && pendingPrice == null) {
      pendingPrice = _defaultPendingPrice(orderType, quote);
    }
    final closePosition = widget.closePositionId == null
        ? null
        : ref
              .watch(demoPositionsProvider)
              .where(
                (position) =>
                    position.id == widget.closePositionId &&
                    position.symbol == widget.symbol,
              )
              .firstOrNull;
    final maxVolume =
        closePosition?.volume ?? _maxVolumeForSymbol(widget.symbol);
    final orderContent = completedSide == null
        ? _OrderForm(
            symbol: widget.symbol,
            symbolName: initial.name,
            volume: volume,
            maxVolume: maxVolume,
            bid: quote.bid,
            ask: quote.ask,
            bidColor: _bidColor,
            askColor: _askColor,
            submitting: submitting,
            selectedSide: selectedSide,
            orderType: orderType,
            fillPolicy: fillPolicy,
            onBack: () => context.pop(),
            onVolumeChanged: (value) =>
                setState(() => volume = value.clamp(.01, maxVolume).toDouble()),
            onVolumeTap: () => _editVolume(maxVolume),
            onOrderTypeTap: () => _selectOrderType(quote),
            onFillPolicyTap: _selectFillPolicy,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            onStopLossChanged: (value) => setState(() => stopLoss = value),
            onTakeProfitChanged: (value) => setState(() => takeProfit = value),
            onSell: () => _submit('SELL', quote),
            onBuy: () => _submit('BUY', quote),
            pendingPrice: pendingPrice,
            onPendingPriceChanged: (value) =>
                setState(() => pendingPrice = value),
            onPlacePendingOrder: () => _submitPendingOrder(quote),
            closePosition: closePosition,
            referenceLayout: widget.tradeAddReferenceLayout,
            referencePresentation: true,
            onClosePosition: closePosition == null
                ? null
                : () => _closePosition(closePosition),
            format: _format,
          )
        : _OrderCompleted(
            symbol: widget.symbol,
            symbolName: initial.name,
            side: completedSide!,
            volume: completedVolume ?? volume,
            price: completedPrice!,
            orderId: completedOrderId!,
            orderType: completedOrderType ?? _marketOrderType,
            pendingOrder: completedPendingOrder,
            closedPosition: completedByClosing,
            referenceLayout: true,
            onBack: () => context.go('/trade'),
            format: _format,
          );
    final referenceTopInset = MediaQuery.paddingOf(
      context,
    ).top.clamp(0.0, 24.0);
    final ticketKey = widget.tradeAddReferenceLayout
        ? const Key('trade-add-order-ticket')
        : widget.closePositionId != null
        ? const Key('position-close-order-ticket')
        : const Key('regular-order-ticket');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.orderTicketSurface,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.orderTicketSurface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.orderTicketSurface,
        body: Padding(
          padding: EdgeInsets.only(top: referenceTopInset),
          child: SizedBox.expand(key: ticketKey, child: orderContent),
        ),
      ),
    );
  }
}

class _OrderForm extends StatelessWidget {
  const _OrderForm({
    required this.symbol,
    required this.symbolName,
    required this.volume,
    required this.maxVolume,
    required this.bid,
    required this.ask,
    required this.bidColor,
    required this.askColor,
    required this.submitting,
    required this.selectedSide,
    required this.orderType,
    required this.fillPolicy,
    required this.onBack,
    required this.onVolumeChanged,
    required this.onVolumeTap,
    required this.onOrderTypeTap,
    required this.onFillPolicyTap,
    required this.stopLoss,
    required this.takeProfit,
    required this.onStopLossChanged,
    required this.onTakeProfitChanged,
    required this.onSell,
    required this.onBuy,
    required this.pendingPrice,
    required this.onPendingPriceChanged,
    required this.onPlacePendingOrder,
    required this.closePosition,
    required this.referenceLayout,
    required this.referencePresentation,
    required this.onClosePosition,
    required this.format,
  });

  final String symbol;
  final String symbolName;
  final double volume;
  final double maxVolume;
  final double bid;
  final double ask;
  final Color bidColor;
  final Color askColor;
  final bool submitting;
  final String selectedSide;
  final String orderType;
  final String fillPolicy;
  final VoidCallback onBack;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onVolumeTap;
  final VoidCallback onOrderTypeTap;
  final VoidCallback onFillPolicyTap;
  final double? stopLoss;
  final double? takeProfit;
  final ValueChanged<double?> onStopLossChanged;
  final ValueChanged<double?> onTakeProfitChanged;
  final VoidCallback onSell;
  final VoidCallback onBuy;
  final double? pendingPrice;
  final ValueChanged<double?> onPendingPriceChanged;
  final VoidCallback onPlacePendingOrder;
  final DemoPosition? closePosition;
  final bool referenceLayout;
  final bool referencePresentation;
  final VoidCallback? onClosePosition;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final protectionStep = _priceStepForSymbol(symbol, bid);
    final pendingOrder = orderType != _marketOrderType;
    final usesReferencePresentation = referencePresentation;
    return Column(
      children: [
        _OrderHeader(
          symbol: symbol,
          symbolName: symbolName,
          onBack: onBack,
          referenceLayout: usesReferencePresentation,
        ),
        _OptionRow(
          key: const Key('order-type-field'),
          label: orderType,
          onTap: onOrderTypeTap,
          referenceLayout: usesReferencePresentation,
          height: usesReferencePresentation ? 41 : 40,
        ),
        ColoredBox(
          color: usesReferencePresentation
              ? AppColors.orderTicketControlSurface
              : Colors.transparent,
          child: SizedBox(
            height: usesReferencePresentation ? 44 : 46,
            child: Row(
              children: [
                _StepButton(
                  label: referenceLayout ? '-5' : '-0.5',
                  onTap: () =>
                      onVolumeChanged(volume - (referenceLayout ? 5 : .5)),
                  referenceLayout: usesReferencePresentation,
                ),
                _StepButton(
                  label: referenceLayout ? '-1' : '-0.1',
                  onTap: () =>
                      onVolumeChanged(volume - (referenceLayout ? 1 : .1)),
                  referenceLayout: usesReferencePresentation,
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('order-volume-field'),
                    onTap: onVolumeTap,
                    child: Center(
                      child: Text(
                        volume.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: usesReferencePresentation
                              ? 'sans-serif'
                              : null,
                          fontSize: usesReferencePresentation ? 14.5 : 14,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  label: referenceLayout ? '+1' : '+0.1',
                  onTap: () =>
                      onVolumeChanged(volume + (referenceLayout ? 1 : .1)),
                  referenceLayout: usesReferencePresentation,
                ),
                _StepButton(
                  label: referenceLayout ? '+5' : '+0.5',
                  onTap: () =>
                      onVolumeChanged(volume + (referenceLayout ? 5 : .5)),
                  referenceLayout: usesReferencePresentation,
                ),
              ],
            ),
          ),
        ),
        if (pendingOrder)
          _ProtectionRow(
            label: 'Gia',
            value: pendingPrice,
            format: format,
            decreaseKey: const Key('order-pending-price-decrease'),
            increaseKey: const Key('order-pending-price-increase'),
            valueKey: const Key('order-pending-price-value'),
            onDecrease: () => onPendingPriceChanged(
              ((pendingPrice ?? bid) - protectionStep)
                  .clamp(protectionStep, double.infinity)
                  .toDouble(),
            ),
            onIncrease: () =>
                onPendingPriceChanged((pendingPrice ?? ask) + protectionStep),
            onClear: () => onPendingPriceChanged(
              _defaultPendingPriceForForm(
                type: orderType,
                bid: bid,
                ask: ask,
                step: protectionStep,
              ),
            ),
            referenceLayout: usesReferencePresentation,
          ),
        _ProtectionRow(
          label: 'Cat lo',
          value: stopLoss,
          format: format,
          decreaseKey: const Key('order-sl-decrease'),
          increaseKey: const Key('order-sl-increase'),
          valueKey: const Key('order-sl-value'),
          onDecrease: () =>
              onStopLossChanged((stopLoss ?? bid) - protectionStep),
          onIncrease: () =>
              onStopLossChanged((stopLoss ?? bid) + protectionStep),
          onClear: () => onStopLossChanged(null),
          referenceLayout: usesReferencePresentation,
        ),
        _ProtectionRow(
          label: 'Chot loi',
          value: takeProfit,
          format: format,
          decreaseKey: const Key('order-tp-decrease'),
          increaseKey: const Key('order-tp-increase'),
          valueKey: const Key('order-tp-value'),
          onDecrease: () =>
              onTakeProfitChanged((takeProfit ?? ask) - protectionStep),
          onIncrease: () =>
              onTakeProfitChanged((takeProfit ?? ask) + protectionStep),
          onClear: () => onTakeProfitChanged(null),
          referenceLayout: usesReferencePresentation,
        ),
        _OptionRow(
          key: const Key('order-fill-policy-field'),
          label: 'Fill Policy',
          value: fillPolicy,
          onTap: onFillPolicyTap,
          referenceLayout: usesReferencePresentation,
          height: usesReferencePresentation ? 38 : 40,
        ),
        SizedBox(
          key: const Key('order-quote-strip'),
          height: usesReferencePresentation ? 55 : 49,
          child: Row(
            children: [
              Expanded(
                child: OrderTicketQuoteText(
                  formattedPrice: format(bid),
                  color: closePosition != null
                      ? AppColors.textPrimary
                      : referenceLayout
                      ? AppColors.orderTicketQuote
                      : bidColor,
                ),
              ),
              Expanded(
                child: OrderTicketQuoteText(
                  formattedPrice: format(ask),
                  color: closePosition != null
                      ? AppColors.textPrimary
                      : referenceLayout
                      ? AppColors.orderTicketQuote
                      : askColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: usesReferencePresentation ? 39 : 40,
          child: pendingOrder
              ? _PendingOrderButton(
                  type: orderType,
                  volume: volume,
                  enabled:
                      !submitting &&
                      pendingPrice != null &&
                      volume >= .01 &&
                      volume <= maxVolume,
                  onTap: onPlacePendingOrder,
                )
              : Row(
                  children: [
                    Expanded(
                      child: _MarketOrderButton(
                        side: 'SELL',
                        label: 'Sell by Market',
                        color: usesReferencePresentation
                            ? AppColors.orderTicketSell
                            : const Color(0xFFC8212B),
                        selected: selectedSide == 'SELL',
                        onTap: submitting ? null : onSell,
                        referenceLayout: usesReferencePresentation,
                      ),
                    ),
                    Expanded(
                      child: _MarketOrderButton(
                        side: 'BUY',
                        label: 'Buy by Market',
                        color: usesReferencePresentation
                            ? AppColors.orderTicketBuy
                            : const Color(0xFF156AC8),
                        selected: selectedSide == 'BUY',
                        onTap: submitting ? null : onBuy,
                        referenceLayout: usesReferencePresentation,
                      ),
                    ),
                  ],
                ),
        ),
        if (closePosition case final position?)
          _PositionCloseBanner(
            position: position,
            volume: volume,
            onTap: submitting ? null : onClosePosition,
          ),
        Padding(
          key: const Key('order-market-warning'),
          padding: EdgeInsets.fromLTRB(
            12,
            usesReferencePresentation ? 17 : 10,
            12,
            0,
          ),
          child: Text(
            'Chú ý !!! Giao dịch được thực thi ở các điều kiện thị trường, '
            'có thể có sự khác biệt về giá so với giá yêu cầu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: usesReferencePresentation ? 'sans-serif' : null,
              fontSize: usesReferencePresentation ? 13.2 : 11.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionCloseBanner extends StatelessWidget {
  const _PositionCloseBanner({
    required this.position,
    required this.volume,
    this.onTap,
  });

  final DemoPosition position;
  final double volume;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.tradeSwipeClose,
    child: InkWell(
      key: const Key('order-close-position'),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        alignment: Alignment.center,
        child: Text(
          'Đóng #${displayTradingTicketId(position.id)} '
          '${position.side.toLowerCase()} '
          '${volume.toStringAsFixed(2)} ở Thị Trường với mức '
          '${position.profit < 0 ? 'Lỗ' : 'Lợi nhuận'} '
          '${position.profit.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'sans-serif',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
      ),
    ),
  );
}

class _OrderCompleted extends StatelessWidget {
  const _OrderCompleted({
    required this.symbol,
    required this.symbolName,
    required this.side,
    required this.volume,
    required this.price,
    required this.orderId,
    required this.orderType,
    required this.pendingOrder,
    required this.closedPosition,
    required this.referenceLayout,
    required this.onBack,
    required this.format,
  });

  final String symbol;
  final String symbolName;
  final String side;
  final double volume;
  final double price;
  final String orderId;
  final String orderType;
  final bool pendingOrder;
  final bool closedPosition;
  final bool referenceLayout;
  final VoidCallback onBack;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OrderHeader(
          symbol: symbol,
          symbolName: symbolName,
          onBack: onBack,
          completed: true,
          referenceLayout: referenceLayout,
        ),
        const SizedBox(height: 31),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: closedPosition
                      ? '#${displayTradingTicketId(orderId)} close '
                      : pendingOrder
                      ? '#${displayTradingTicketId(orderId)} '
                            '${orderType.toLowerCase()} '
                      : '#${displayTradingTicketId(orderId)} market ',
                ),
                TextSpan(
                  text: side.toLowerCase(),
                  style: TextStyle(
                    color: side == 'BUY'
                        ? AppColors.primary
                        : AppColors.negative,
                  ),
                ),
                TextSpan(
                  text:
                      ' ${volume.toStringAsFixed(2)} '
                      '${displayTradingSymbol(symbol)} at\n'
                      '${format(price)}\nhoan tat',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 17,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.symbol,
    required this.symbolName,
    required this.onBack,
    this.completed = false,
    this.referenceLayout = false,
  });

  final String symbol;
  final String symbolName;
  final VoidCallback onBack;
  final bool completed;
  final bool referenceLayout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: referenceLayout ? 80 : 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: referenceLayout ? 17.3333333333 : -15,
            top: 29,
            child: _HeaderCircle(
              key: const Key('order-back-button'),
              onTap: onBack,
              child: const Icon(
                CupertinoIcons.chevron_left,
                color: AppColors.textPrimary,
                size: 27,
              ),
            ),
          ),
          Positioned(
            left: 70,
            right: 70,
            top: 34,
            child: Column(
              key: const Key('order-header-title'),
              children: [
                if (referenceLayout)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTradingSymbol(symbol),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
                  )
                else
                  Text(
                    '${displayTradingSymbol(symbol)}⌄',
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
                  symbol == 'BTCUSD'
                      ? 'Bitcoin vs US Dollar Tether'
                      : symbolName,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: referenceLayout ? 'sans-serif' : null,
                    fontSize: referenceLayout ? 11.5 : 10.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (completed)
            Positioned(
              right: 18,
              top: 29,
              child: _HeaderCircle(
                onTap: onBack,
                color: AppColors.primary,
                child: const Icon(
                  CupertinoIcons.check_mark,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.onTap,
    required this.child,
    this.color = AppColors.surface,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(dimension: 40, child: Center(child: child)),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.onTap,
    required this.referenceLayout,
    required this.height,
    this.value,
    super.key,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool referenceLayout;
  final double height;

  @override
  Widget build(BuildContext context) => Material(
    color: referenceLayout
        ? AppColors.orderTicketControlSurface
        : Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: referenceLayout
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontFamily: referenceLayout ? 'sans-serif' : null,
                    fontSize: referenceLayout ? 15 : 13.5,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: referenceLayout ? 'sans-serif' : null,
                    fontSize: referenceLayout ? 14.5 : 12.5,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_down,
                color: AppColors.textPrimary,
                size: referenceLayout ? 14 : 13,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MarketOrderButton extends StatelessWidget {
  const _MarketOrderButton({
    required this.side,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.referenceLayout,
  });

  final String side;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final bool referenceLayout;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('order-side-${side.toLowerCase()}'),
    selected: selected,
    button: true,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: referenceLayout || selected ? 1 : .88,
      child: Material(
        key: ValueKey('order-market-${side.toLowerCase()}'),
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected && !referenceLayout)
                const Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: 2,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: referenceLayout ? 'sans-serif' : null,
                    fontSize: referenceLayout ? 16 : 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PendingOrderButton extends StatelessWidget {
  const _PendingOrderButton({
    required this.type,
    required this.volume,
    required this.enabled,
    required this.onTap,
  });

  final String type;
  final double volume;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('order-place-pending'),
    color: enabled ? const Color(0xFF156AC8) : AppColors.surface,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Center(
        child: Text(
          '$type ${volume.toStringAsFixed(2)}',
          style: TextStyle(
            color: enabled ? Colors.white : AppColors.textTertiary,
            fontSize: 13.5,
          ),
        ),
      ),
    ),
  );
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.selected,
    required this.options,
    required this.optionKeyPrefix,
  });

  final String title;
  final String selected;
  final List<String> options;
  final String optionKeyPrefix;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .78,
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in options)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        key: ValueKey('$optionKeyPrefix-${_choiceKey(option)}'),
                        dense: true,
                        title: Text(
                          option,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        trailing: option == selected
                            ? const Icon(
                                CupertinoIcons.check_mark,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VolumeEditorSheet extends StatefulWidget {
  const _VolumeEditorSheet({
    required this.initialValue,
    required this.maxVolume,
  });

  final double initialValue;
  final double maxVolume;

  @override
  State<_VolumeEditorSheet> createState() => _VolumeEditorSheetState();
}

class _VolumeEditorSheetState extends State<_VolumeEditorSheet> {
  late final TextEditingController controller;
  double? parsedValue;

  @override
  void initState() {
    super.initState();
    controller =
        TextEditingController(text: widget.initialValue.toStringAsFixed(2))
          ..selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.initialValue.toStringAsFixed(2).length,
          );
    parsedValue = widget.initialValue;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _parse(String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    final followsLotStep =
        parsed != null &&
        ((parsed * 100) - (parsed * 100).round()).abs() < 1e-8;
    setState(() {
      parsedValue =
          parsed != null &&
              followsLotStep &&
              parsed >= .01 &&
              parsed <= widget.maxVolume
          ? parsed
          : null;
    });
  }

  void _submit() {
    final value = parsedValue;
    if (value != null) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Khoi luong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tu 0.01 den ${widget.maxVolume.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('order-volume-input'),
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: _parse,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                errorText: parsedValue == null
                    ? 'Khoi luong khong hop le'
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Huy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('order-volume-done'),
                    onPressed: parsedValue == null ? null : _submit,
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onTap,
    required this.referenceLayout,
  });

  final String label;
  final VoidCallback onTap;
  final bool referenceLayout;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: referenceLayout
                ? AppColors.orderTicketQuote
                : AppColors.primary,
            fontFamily: referenceLayout ? 'sans-serif' : null,
            fontSize: referenceLayout ? 14.5 : 13.5,
            fontWeight: referenceLayout ? FontWeight.w600 : null,
          ),
        ),
      ),
    ),
  );
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({
    required this.label,
    required this.value,
    required this.format,
    required this.decreaseKey,
    required this.increaseKey,
    required this.valueKey,
    required this.onDecrease,
    required this.onIncrease,
    required this.onClear,
    required this.referenceLayout,
  });

  final String label;
  final double? value;
  final String Function(double value) format;
  final Key decreaseKey;
  final Key increaseKey;
  final Key valueKey;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onClear;
  final bool referenceLayout;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: referenceLayout
        ? AppColors.orderTicketControlSurface
        : Colors.transparent,
    child: SizedBox(
      height: referenceLayout ? 38 : 36,
      child: Padding(
        padding: referenceLayout
            ? const EdgeInsets.only(left: 8, right: 2)
            : const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: referenceLayout ? 'sans-serif' : null,
                fontSize: referenceLayout ? 14.5 : 13.5,
              ),
            ),
            const Spacer(),
            InkWell(
              key: decreaseKey,
              onTap: onDecrease,
              child: SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '−',
                    style: TextStyle(
                      color: referenceLayout
                          ? AppColors.orderTicketQuote
                          : AppColors.primary,
                      fontFamily: referenceLayout ? 'sans-serif' : null,
                      fontSize: referenceLayout ? 21 : 20,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              key: valueKey,
              onLongPress: onClear,
              child: SizedBox(
                width: referenceLayout ? 154 : 116,
                child: Transform.translate(
                  offset: referenceLayout
                      ? const Offset(-1.3333333333, 0)
                      : Offset.zero,
                  child: Text(
                    value == null ? 'khong cai dat' : format(value!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == null
                          ? referenceLayout
                                ? AppColors.orderTicketPlaceholder
                                : AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontFamily: referenceLayout ? 'sans-serif' : null,
                      fontSize: referenceLayout ? 14.5 : 12.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              key: increaseKey,
              onTap: onIncrease,
              child: SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: referenceLayout
                          ? AppColors.orderTicketQuote
                          : AppColors.primary,
                      fontFamily: referenceLayout ? 'sans-serif' : null,
                      fontSize: referenceLayout ? 25 : 23,
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
