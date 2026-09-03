import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_shadows.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/market_watch/domain/market_quote_display.dart';
import 'package:trading_mobile/features/market_watch/domain/market_symbol_policy.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/models/market_candle.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';
import 'package:trading_mobile/shared/widgets/mt_tab_header_fade.dart';
import 'package:trading_mobile/shared/widgets/mt5_toolbar_icons.dart';

class MarketWatchScreen extends ConsumerStatefulWidget {
  const MarketWatchScreen({super.key});

  @override
  ConsumerState<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends ConsumerState<MarketWatchScreen> {
  bool compactMode = false;
  String? revealedSymbol;
  final Map<
    String,
    ({double bid, double ask, DateTime? sourceTimestamp, DateTime receivedAt})
  >
  _receiptTimes = {};
  final _quoteRetention = _MarketQuoteRetention();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeTabIndex = AppTabScope.maybeIndexOf(context);
    if (activeTabIndex != null && activeTabIndex != 0) {
      revealedSymbol = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(demoQuotesProvider);
    final selectedSymbols = ref.watch(marketSymbolsProvider);
    final columns = ref.watch(marketColumnsProvider);
    final visibleQuotes = selectedSymbols
        .map(
          (symbol) =>
              quotes.where((quote) => quote.symbol == symbol).firstOrNull,
        )
        .whereType<DemoQuote>()
        .toList();
    final safeTop = MediaQuery.paddingOf(context).top;
    final headerExtent = safeTop + TabReferenceMetrics.quoteHeaderHeight;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: visibleQuotes.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(top: headerExtent),
                    child: const _EmptyQuotes(),
                  )
                : compactMode
                ? _CompactQuotes(
                    quotes: visibleQuotes,
                    columns: columns,
                    topInset: headerExtent,
                    receivedAtFor: _receivedAtFor,
                    retention: _quoteRetention,
                    onTap: (quote) => _showSymbolMenu(context, quote),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(top: headerExtent),
                    itemCount: visibleQuotes.length,
                    itemBuilder: (context, index) {
                      final quote = visibleQuotes[index];
                      return _SwipeQuoteRow(
                        quote: quote,
                        receivedAtFor: _receivedAtFor,
                        retention: _quoteRetention,
                        revealed: revealedSymbol == quote.symbol,
                        onReveal: () =>
                            setState(() => revealedSymbol = quote.symbol),
                        onHide: () => setState(() => revealedSymbol = null),
                        onTap: () => _showSymbolMenu(context, quote),
                        onOrder: () => context.push(
                          '/order?symbol=${Uri.encodeQueryComponent(quote.symbol)}',
                        ),
                        onDelete: canRemoveMarketSymbol(quote.symbol)
                            ? () => ref
                                  .read(marketSymbolsProvider.notifier)
                                  .remove(quote.symbol)
                            : null,
                        onChart: () =>
                            context.go(_rememberedChartLocation(quote.symbol)),
                      );
                    },
                  ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: headerExtent,
            child: const IgnorePointer(
              child: MtTabHeaderFade(
                decorationKey: Key('market-header-overlay'),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: safeTop,
            right: 0,
            height: TabReferenceMetrics.quoteHeaderHeight,
            child: _QuotesHeader(
              compactMode: compactMode,
              onToggleView: () => setState(() => compactMode = !compactMode),
              onManage: () => context.push(
                compactMode ? '/market/columns' : '/market/edit',
              ),
              onSearch: () => context.push('/market/search'),
            ),
          ),
        ],
      ),
    );
  }

  String _rememberedChartLocation(String symbol) {
    final timeframe = ref
        .read(chartTimeframeSessionProvider.notifier)
        .timeframeFor(symbol);
    return chartLocationForSymbol(symbol, timeframe: timeframe);
  }

  DateTime _receivedAtFor(DemoQuote quote) {
    final retained = _receiptTimes[quote.symbol];
    if (retained != null &&
        retained.bid == quote.bid &&
        retained.ask == quote.ask &&
        retained.sourceTimestamp == quote.sourceTimestamp) {
      return retained.receivedAt;
    }
    final receivedAt = quote.sourceTimestamp ?? ref.read(marketClockProvider)();
    _receiptTimes[quote.symbol] = (
      bid: quote.bid,
      ask: quote.ask,
      sourceTimestamp: quote.sourceTimestamp,
      receivedAt: receivedAt,
    );
    return receivedAt;
  }

  void _showSymbolMenu(BuildContext context, DemoQuote quote) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.dimBarrier,
      builder: (sheetContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.fromLTRB(39.3, 0, 37.3, 0),
        child: Transform.translate(
          offset: const Offset(0, 4.3),
          child: DecoratedBox(
            key: ValueKey('market-symbol-menu-${quote.symbol}'),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.divider, width: .7),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7.7, 26, 7.7, 16.5333333333),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, .6666666667),
                    child: Text(
                      '${displayTradingSymbol(quote.symbol)}: ${quote.name}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'sans-serif',
                        fontSize: 18.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.6333333333),
                  _SheetAction(
                    key: const Key('market-menu-first-action'),
                    label: 'Giao dich',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push(
                        '/order?symbol=${Uri.encodeQueryComponent(quote.symbol)}',
                      );
                    },
                  ),
                  _SheetAction(
                    label: 'Bieu do',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go(_rememberedChartLocation(quote.symbol));
                    },
                  ),
                  _SheetAction(
                    label: 'Chi tiet',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push(
                        '/section?title=${Uri.encodeComponent('Chi tiết ${quote.symbol}')}',
                      );
                    },
                  ),
                  _SheetAction(
                    label: 'Thống kê thị trường',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push(
                        '/section?title=${Uri.encodeComponent('Thống kê ${quote.symbol}')}',
                      );
                    },
                  ),
                  if (supportsDepthOfMarket(quote.symbol))
                    _SheetAction(
                      label: 'Depth of Market',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push(
                          '/section?title=${Uri.encodeComponent('Depth of Market ${quote.symbol}')}',
                        );
                      },
                    ),
                  if (canRemoveMarketSymbol(quote.symbol))
                    _SheetAction(
                      label: 'Xoa',
                      color: AppColors.tradingNegativeText,
                      onTap: () {
                        ref
                            .read(marketSymbolsProvider.notifier)
                            .remove(quote.symbol);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  _SheetAction(
                    label: 'Huy',
                    color: AppColors.textPrimary,
                    bottomGap: 0,
                    onTap: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketQuoteRetention {
  final Map<String, List<MarketCandle>> _dailyCandles = {};
  final Map<String, MarketQuoteDisplay> _displays = {};

  List<MarketCandle>? candlesFor(String symbol) => _dailyCandles[symbol];

  MarketQuoteDisplay? displayFor(String symbol) => _displays[symbol];

  void retain({
    required String symbol,
    required List<MarketCandle> candles,
    required MarketQuoteDisplay display,
    required bool isAvailable,
  }) {
    _dailyCandles[symbol] = candles;
    if (isAvailable) _displays[symbol] = display;
  }
}

class _QuotesHeader extends StatelessWidget {
  const _QuotesHeader({
    required this.compactMode,
    required this.onToggleView,
    required this.onManage,
    required this.onSearch,
  });

  final bool compactMode;
  final VoidCallback onToggleView;
  final VoidCallback onManage;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Calibrated against the canonical 590 x 1280 reference capture.
      height: TabReferenceMetrics.quoteHeaderHeight,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: TabReferenceMetrics.quoteHeaderControlTop,
            child: _RoundToolbarButton(
              key: const Key('market-toggle-view'),
              tooltip: 'View',
              onTap: onToggleView,
              child: const _MarketListIcon(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: TabReferenceMetrics.quoteHeaderTitleTop,
            child: IgnorePointer(
              child: Text(
                'Gia',
                textAlign: TextAlign.center,
                style: AppTypography.forRole(
                  context,
                  ReferenceTextRole.pricesToolbarTitle,
                  colorRole: ReferenceTextColorRole.primary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 72,
            top: TabReferenceMetrics.quoteHeaderControlTop,
            child: _RoundToolbarButton(
              key: const Key('market-manage-button'),
              tooltip: 'Sửa',
              onTap: onManage,
              child: compactMode
                  ? const Icon(
                      CupertinoIcons.square_grid_2x2,
                      key: Key('market-manage-grid-icon'),
                      color: AppColors.textPrimary,
                      size: 19,
                    )
                  : Transform.translate(
                      offset: const Offset(-2.3333333333, -1.1666666667),
                      child: Transform.scale(
                        scaleX: 1.04,
                        scaleY: .94,
                        child: const MtToolbarIcon(
                          MtToolbarIconKind.edit,
                          key: Key('market-manage-edit-icon'),
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            right: 16.5,
            top: TabReferenceMetrics.quoteHeaderControlTop,
            child: _RoundToolbarButton(
              key: const Key('market-search-button'),
              tooltip: 'Tìm kiếm',
              onTap: onSearch,
              child: const _MarketSearchIcon(key: Key('market-search-icon')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketListIcon extends StatelessWidget {
  const _MarketListIcon();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, -1.6666666667),
    child: Transform.scale(
      scaleY: .95,
      child: const CustomPaint(
        size: Size.square(18),
        painter: _MarketListIconPainter(),
      ),
    ),
  );
}

class _MarketListIconPainter extends CustomPainter {
  const _MarketListIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bullet = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;
    final rule = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.square;
    const rows = [3.0, 7.5, 12.0, 16.5];
    for (var index = 0; index < rows.length; index++) {
      final y = rows[index];
      canvas.drawRect(
        Rect.fromCenter(center: Offset(2.5, y), width: 2, height: 2),
        bullet,
      );
      canvas.drawLine(
        Offset(6.2, y),
        Offset(index == rows.length - 1 ? 11.25 : 17.3, y),
        rule,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketListIconPainter oldDelegate) => false;
}

class _MarketSearchIcon extends StatelessWidget {
  const _MarketSearchIcon({super.key});

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-.3333333333, -.6666666667),
    child: Transform.scale(
      scale: 1,
      child: const CustomPaint(
        size: Size.square(29),
        painter: _MarketSearchIconPainter(),
      ),
    ),
  );
}

class _MarketSearchIconPainter extends CustomPainter {
  const _MarketSearchIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12.65, 12.35), 8.35, paint);
    canvas.drawLine(const Offset(18, 17.8), const Offset(24.2, 24), paint);
  }

  @override
  bool shouldRepaint(covariant _MarketSearchIconPainter oldDelegate) => false;
}

class _RoundToolbarButton extends StatelessWidget {
  const _RoundToolbarButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: TabReferenceMetrics.quoteHeaderButtonSize,
            child: Center(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.navigation,
                ),
                child: SizedBox.square(
                  dimension: TabReferenceMetrics.quoteHeaderVisualDiameter,
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactQuotes extends StatelessWidget {
  const _CompactQuotes({
    required this.quotes,
    required this.columns,
    required this.topInset,
    required this.receivedAtFor,
    required this.retention,
    required this.onTap,
  });

  final List<DemoQuote> quotes;
  final List<String> columns;
  final double topInset;
  final DateTime Function(DemoQuote) receivedAtFor;
  final _MarketQuoteRetention retention;
  final ValueChanged<DemoQuote> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final standardLayout =
          columns.length == 3 &&
          columns[0] == 'Chào mua' &&
          columns[1] == 'Chào bán' &&
          columns[2] == 'Ngày %';
      final standardScale = constraints.maxWidth / 384;
      final symbolWidth = standardLayout ? 113 * standardScale : 132.0;
      final columnWidths = standardLayout
          ? <double>[97 * standardScale, 91 * standardScale, 83 * standardScale]
          : <double>[for (final column in columns) _compactColumnWidth(column)];
      final contentWidth =
          symbolWidth +
          columnWidths.fold<double>(0, (width, column) => width + column);
      final tableWidth = contentWidth < constraints.maxWidth
          ? constraints.maxWidth
          : contentWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView.builder(
                  padding: EdgeInsets.only(top: topInset + 31),
                  itemCount: quotes.length,
                  itemBuilder: (context, index) => _CompactQuoteRow(
                    quote: quotes[index],
                    columns: columns,
                    symbolWidth: symbolWidth,
                    columnWidths: columnWidths,
                    receivedAtFor: receivedAtFor,
                    retention: retention,
                    onTap: () => onTap(quotes[index]),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                height: 31,
                child: Row(
                  children: [
                    _CompactHeaderCell(
                      label: 'Cặp ngoại tệ',
                      width: symbolWidth,
                      alignLeft: true,
                    ),
                    for (var index = 0; index < columns.length; index++)
                      _CompactHeaderCell(
                        label: columns[index],
                        width: columnWidths[index],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CompactHeaderCell extends StatelessWidget {
  const _CompactHeaderCell({
    required this.label,
    required this.width,
    this.alignLeft = false,
  });

  final String label;
  final double width;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: EdgeInsets.only(
        left: alignLeft ? 6.7 : 0,
        right: label == 'Ngày %' ? 4 : 6,
      ),
      child: Align(
        alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.tradingSecondaryText,
            fontSize: 11.5,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _CompactQuoteRow extends ConsumerStatefulWidget {
  const _CompactQuoteRow({
    required this.quote,
    required this.columns,
    required this.symbolWidth,
    required this.columnWidths,
    required this.receivedAtFor,
    required this.retention,
    required this.onTap,
  });

  final DemoQuote quote;
  final List<String> columns;
  final double symbolWidth;
  final List<double> columnWidths;
  final DateTime Function(DemoQuote) receivedAtFor;
  final _MarketQuoteRetention retention;
  final VoidCallback onTap;

  @override
  ConsumerState<_CompactQuoteRow> createState() => _CompactQuoteRowState();
}

class _CompactQuoteRowState extends ConsumerState<_CompactQuoteRow> {
  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final live = ref.watch(demoQuoteProvider(quote.symbol)).value ?? quote;
    final snapshot = _watchQuoteDisplay(
      ref,
      live,
      widget.retention.candlesFor(live.symbol),
      widget.retention.displayFor(live.symbol),
      receivedAt: widget.receivedAtFor(live),
    );
    final display = snapshot.display;
    widget.retention.retain(
      symbol: live.symbol,
      candles: snapshot.candles,
      display: display,
      isAvailable: snapshot.isAvailable,
    );
    final dailyColor = !snapshot.isAvailable
        ? AppColors.pricesSecondary
        : (display.pointChange ?? 0) >= 0
        ? AppColors.primary
        : AppColors.pricesNegativeText;
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onTap,
      child: SizedBox(
        height: 33,
        child: Row(
          children: [
            SizedBox(
              width: widget.symbolWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 6.7),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _marketWatchDisplaySymbol(live.symbol),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            for (var index = 0; index < widget.columns.length; index++)
              SizedBox(
                width: widget.columnWidths[index],
                child: Padding(
                  padding: EdgeInsets.only(
                    right: widget.columns[index] == 'Ngày %' ? 4 : 6,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _compactValue(
                        widget.columns[index],
                        live,
                        display,
                        isAvailable: snapshot.isAvailable,
                      ),
                      maxLines: 1,
                      style: TextStyle(
                        color: widget.columns[index] == 'Ngày %'
                            ? dailyColor
                            : AppColors.textPrimary,
                        fontSize: 11.8,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

double _compactColumnWidth(String column) {
  if (column == 'Ngày %' || column == 'Spread') return 64;
  if (column == 'Thời gian') return 82;
  return 96;
}

String _compactValue(
  String column,
  DemoQuote quote,
  MarketQuoteDisplay display, {
  required bool isAvailable,
}) {
  return switch (column) {
    'Chào mua' =>
      isAvailable ? _formatQuoteValue(quote.bid, display.digits) : '--',
    'Chào bán' =>
      isAvailable ? _formatQuoteValue(quote.ask, display.digits) : '--',
    'Ngày %' => _formatPercent(display.percentChange),
    'Giá mua cao' ||
    'Giá bán cao' ||
    'Giá cuối cao' => _formatStatistic(display.high, display.digits),
    'Giá mua thấp' ||
    'Giá bán thấp' ||
    'Giá cuối thấp' => _formatStatistic(display.low, display.digits),
    'Giá cuối' =>
      isAvailable ? _formatQuoteValue(quote.bid, display.digits) : '--',
    'Thời gian' => _formatUtcTime(display.timestamp),
    'Spread' => isAvailable ? display.spreadPoints.toString() : '--',
    _ => '',
  };
}

String _formatQuoteValue(double value, int digits) =>
    value.toStringAsFixed(digits);

class _SwipeQuoteRow extends StatefulWidget {
  const _SwipeQuoteRow({
    required this.quote,
    required this.receivedAtFor,
    required this.retention,
    required this.revealed,
    required this.onReveal,
    required this.onHide,
    required this.onTap,
    required this.onOrder,
    required this.onDelete,
    required this.onChart,
  });

  final DemoQuote quote;
  final DateTime Function(DemoQuote) receivedAtFor;
  final _MarketQuoteRetention retention;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onHide;
  final VoidCallback onTap;
  final VoidCallback onOrder;
  final VoidCallback? onDelete;
  final VoidCallback onChart;

  @override
  State<_SwipeQuoteRow> createState() => _SwipeQuoteRowState();
}

class _SwipeQuoteRowState extends State<_SwipeQuoteRow> {
  static const _orderActionExtent = 142.0;
  static const _deleteActionExtent = 117.0;
  static const _snapFraction = .42;
  static const _flingVelocity = 650.0;
  static const _minimumFlingDistance = 28.0;
  static const _elasticFactor = .22;
  static const _maxElasticOverscroll = 24.0;

  double? _dragStartOffset;
  double? _rawDragOffset;
  double? _visibleDragOffset;
  bool _dragging = false;

  bool get _hasDelete => widget.onDelete != null;
  double get _revealExtent =>
      _hasDelete ? _deleteActionExtent : _orderActionExtent;
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
      widget.onHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = _dragging
        ? (_visibleDragOffset ?? _settledOffset)
        : _settledOffset;
    final rowIsDisplaced = offset.abs() > .5;
    const orderColor = AppColors.surfaceSelected;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _startDrag,
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: _endDrag,
      onHorizontalDragCancel: _cancelDrag,
      child: SizedBox(
        height: TabReferenceMetrics.quoteRowHeight,
        child: Stack(
          children: [
            if (!_hasDelete)
              Positioned(
                right: 83,
                top: 14,
                width: 48,
                height: 48,
                child: _QuoteSwipeAction(
                  key: ValueKey('market-order-${widget.quote.symbol}'),
                  color: orderColor,
                  onTap: widget.onOrder,
                  child: const Icon(
                    CupertinoIcons.add,
                    color: AppColors.tradingSecondaryText,
                    size: 30,
                  ),
                ),
              ),
            if (_hasDelete)
              Positioned(
                right: 65,
                top: 14,
                width: 48,
                height: 48,
                child: _QuoteSwipeAction(
                  key: ValueKey('market-delete-${widget.quote.symbol}'),
                  color: AppColors.tradingNegativeText,
                  onTap: widget.onDelete!,
                  child: const Icon(
                    CupertinoIcons.trash,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            Positioned(
              right: 7,
              top: 14,
              width: 48,
              height: 48,
              child: _QuoteSwipeAction(
                key: ValueKey('market-chart-${widget.quote.symbol}'),
                color: AppColors.primary,
                onTap: widget.onChart,
                child: Transform.translate(
                  offset: const Offset(0, .6666666667),
                  child: Transform.scale(
                    scaleX: .91,
                    scaleY: .86,
                    child: const _SwipeChartIcon(),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(offset, 0, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: rowIsDisplaced
                    ? AppColors.surfaceSelected
                    : AppColors.background,
                borderRadius: rowIsDisplaced
                    ? const BorderRadius.horizontal(right: Radius.circular(26))
                    : BorderRadius.zero,
              ),
              child: _QuoteRow(
                quote: widget.quote,
                receivedAtFor: widget.receivedAtFor,
                retention: widget.retention,
                onTap: widget.revealed ? widget.onHide : widget.onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteSwipeAction extends StatelessWidget {
  const _QuoteSwipeAction({
    required this.color,
    required this.onTap,
    required this.child,
    super.key,
  });

  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Center(child: child),
    ),
  );
}

class _SwipeChartIcon extends StatelessWidget {
  const _SwipeChartIcon();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(22),
    painter: _SwipeChartIconPainter(),
  );
}

class _SwipeChartIconPainter extends CustomPainter {
  const _SwipeChartIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawLine(const Offset(3, 2), const Offset(3, 19), stroke);
    canvas.drawLine(const Offset(3, 19), const Offset(20, 19), stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.5, 10, 3.2, 7),
        const Radius.circular(.7),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11.5, 5, 3.2, 12),
        const Radius.circular(.7),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16.5, 8, 3.2, 9),
        const Radius.circular(.7),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuoteRow extends ConsumerStatefulWidget {
  const _QuoteRow({
    required this.quote,
    required this.receivedAtFor,
    required this.retention,
    required this.onTap,
  });

  final DemoQuote quote;
  final DateTime Function(DemoQuote) receivedAtFor;
  final _MarketQuoteRetention retention;
  final VoidCallback onTap;

  @override
  ConsumerState<_QuoteRow> createState() => _QuoteRowState();
}

class _QuoteRowState extends ConsumerState<_QuoteRow> {
  DemoQuote? _previousTick;
  ReferenceTextColorRole? _lastBidColorRole;
  ReferenceTextColorRole? _lastAskColorRole;
  String? _displaySymbol;
  int? _lastPointChange;

  @override
  Widget build(BuildContext context) {
    final live =
        ref.watch(demoQuoteProvider(widget.quote.symbol)).value ?? widget.quote;
    if (_displaySymbol != live.symbol) {
      _displaySymbol = live.symbol;
      _previousTick = null;
      _lastBidColorRole = null;
      _lastAskColorRole = null;
      _lastPointChange = null;
    }
    final snapshot = _watchQuoteDisplay(
      ref,
      live,
      widget.retention.candlesFor(live.symbol),
      widget.retention.displayFor(live.symbol),
      receivedAt: widget.receivedAtFor(live),
    );
    final display = snapshot.display;
    widget.retention.retain(
      symbol: live.symbol,
      candles: snapshot.candles,
      display: display,
      isAvailable: snapshot.isAvailable,
    );
    final typographyVariant = _quoteTypographyVariant(live.symbol);
    final dailyColorRole = !snapshot.isAvailable
        ? ReferenceTextColorRole.secondary
        : switch (display.pointChange) {
            final points? when points < 0 => ReferenceTextColorRole.negative,
            final points? when points >= 0 => ReferenceTextColorRole.positive,
            _ => ReferenceTextColorRole.secondary,
          };
    late final ReferenceTextColorRole bidColorRole;
    late final ReferenceTextColorRole askColorRole;
    if (!snapshot.isAvailable) {
      _previousTick = null;
      _lastBidColorRole = null;
      _lastAskColorRole = null;
      _lastPointChange = null;
      bidColorRole = ReferenceTextColorRole.secondary;
      askColorRole = ReferenceTextColorRole.secondary;
    } else {
      final retainedTick = _previousTick?.symbol == live.symbol
          ? _previousTick
          : null;
      final tickMoved =
          retainedTick != null &&
          (retainedTick.bid != live.bid || retainedTick.ask != live.ask);
      if (_lastPointChange == null &&
          display.pointChange != null &&
          !tickMoved) {
        _previousTick = null;
        _lastBidColorRole = null;
        _lastAskColorRole = null;
      }
      _lastPointChange = display.pointChange;
      final previous = _previousTick?.symbol == live.symbol
          ? _previousTick
          : null;
      bidColorRole = _tickColorRole(
        current: live.bid,
        previous: previous?.bid,
        retained: _lastBidColorRole,
        initial: dailyColorRole,
      );
      askColorRole = _tickColorRole(
        current: live.ask,
        previous: previous?.ask,
        retained: _lastAskColorRole,
        initial: dailyColorRole,
      );
      _previousTick = live;
      _lastBidColorRole = bidColorRole;
      _lastAskColorRole = askColorRole;
    }
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onTap,
      child: SizedBox(
        height: TabReferenceMetrics.quoteRowHeight,
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: Text.rich(
                key: ValueKey('market-change-${live.symbol}'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: _formatPointChange(display.pointChange),
                      style: AppTypography.forRole(
                        context,
                        ReferenceTextRole.quoteChange,
                        colorRole: ReferenceTextColorRole.secondary,
                        variant: typographyVariant,
                      ),
                    ),
                    TextSpan(
                      text: _formatPercent(display.percentChange),
                      style: AppTypography.forRole(
                        context,
                        ReferenceTextRole.quoteChange,
                        colorRole: dailyColorRole,
                        variant: typographyVariant,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: AppTypography.forRole(
                  context,
                  ReferenceTextRole.quoteChange,
                  colorRole: ReferenceTextColorRole.secondary,
                  variant: typographyVariant,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 27.3333333333,
              child: Text(
                _marketWatchDisplaySymbol(live.symbol),
                key: ValueKey('market-symbol-${live.symbol}'),
                style: AppTypography.forRole(
                  context,
                  ReferenceTextRole.quoteSymbol,
                  colorRole: ReferenceTextColorRole.primary,
                  variant: typographyVariant,
                ),
              ),
            ),
            Positioned(
              left: 7.3333333333,
              top: 51,
              child: Row(
                children: [
                  Text(
                    _formatUtcTime(display.timestamp),
                    key: ValueKey('market-time-${live.symbol}'),
                    style: AppTypography.forRole(
                      context,
                      ReferenceTextRole.quoteTimeMeta,
                      colorRole: ReferenceTextColorRole.secondary,
                      variant: typographyVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _SpreadGlyph(),
                  const SizedBox(width: 4),
                  Text(
                    snapshot.isAvailable
                        ? display.spreadPoints.toString()
                        : '--',
                    key: ValueKey('market-spread-${live.symbol}'),
                    style: AppTypography.forRole(
                      context,
                      ReferenceTextRole.quoteSpreadMeta,
                      colorRole: ReferenceTextColorRole.secondary,
                      variant: typographyVariant,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 103.3,
              top: 16,
              width: 92,
              child: Align(
                alignment: Alignment.centerRight,
                child: _QuotePrice(
                  value: snapshot.isAvailable
                      ? _formatQuoteValue(live.bid, display.digits)
                      : '--',
                  colorRole: bidColorRole,
                  variant: typographyVariant,
                  textKey: ValueKey('market-bid-${live.symbol}'),
                  pipetteKey: ValueKey('market-bid-pipette-${live.symbol}'),
                ),
              ),
            ),
            Positioned(
              right: 7.3,
              top: 16,
              width: 92,
              child: Align(
                alignment: Alignment.centerRight,
                child: _QuotePrice(
                  value: snapshot.isAvailable
                      ? _formatQuoteValue(live.ask, display.digits)
                      : '--',
                  colorRole: askColorRole,
                  variant: typographyVariant,
                  textKey: ValueKey('market-ask-${live.symbol}'),
                  pipetteKey: ValueKey('market-ask-pipette-${live.symbol}'),
                ),
              ),
            ),
            Positioned(
              right: 103.3,
              top: 52,
              child: _QuoteRange(
                label: 'L:',
                value: _formatStatistic(display.low, display.digits),
                labelKey: ValueKey('market-low-label-${live.symbol}'),
                valueKey: ValueKey('market-low-${live.symbol}'),
                variant: typographyVariant,
              ),
            ),
            Positioned(
              right: 7.3,
              top: 52,
              child: _QuoteRange(
                label: 'H:',
                value: _formatStatistic(display.high, display.digits),
                labelKey: ValueKey('market-high-label-${live.symbol}'),
                valueKey: ValueKey('market-high-${live.symbol}'),
                variant: typographyVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ReferenceTextColorRole _tickColorRole({
    required double current,
    required double? previous,
    required ReferenceTextColorRole? retained,
    required ReferenceTextColorRole initial,
  }) {
    if (previous == null) return retained ?? initial;
    if (current > previous) return ReferenceTextColorRole.positive;
    if (current < previous) return ReferenceTextColorRole.negative;
    return retained ?? initial;
  }
}

class _QuoteRange extends StatelessWidget {
  const _QuoteRange({
    required this.label,
    required this.value,
    required this.labelKey,
    required this.valueKey,
    required this.variant,
  });

  final String label;
  final String value;
  final Key labelKey;
  final Key valueKey;
  final TypographyVariantId variant;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        key: labelKey,
        style: AppTypography.forRole(
          context,
          ReferenceTextRole.quoteRangeLabel,
          colorRole: ReferenceTextColorRole.secondary,
          variant: variant,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        value,
        key: valueKey,
        style: AppTypography.forRole(
          context,
          ReferenceTextRole.quoteRangeValue,
          colorRole: ReferenceTextColorRole.secondary,
          variant: variant,
        ),
      ),
    ],
  );
}

class _QuotePrice extends StatelessWidget {
  const _QuotePrice({
    required this.value,
    required this.colorRole,
    required this.variant,
    required this.textKey,
    required this.pipetteKey,
  });

  final String value;
  final ReferenceTextColorRole colorRole;
  final TypographyVariantId variant;
  final Key textKey;
  final Key pipetteKey;

  @override
  Widget build(BuildContext context) {
    final decimalAt = value.lastIndexOf('.');
    final fractionLength = decimalAt < 0 ? 0 : value.length - decimalAt - 1;
    final hasPipette = fractionLength >= 3;
    final pipetteAt = hasPipette ? value.length - 1 : value.length;
    final emphasizedLength = math.min(2, fractionLength - (hasPipette ? 1 : 0));
    final emphasizedAt = pipetteAt - emphasizedLength;
    final leading = value.substring(0, emphasizedAt);
    final emphasized = value.substring(emphasizedAt, pipetteAt);
    final pipette = hasPipette ? value.substring(pipetteAt) : null;
    final majorRole = variant == TypographyVariantId.quoteBtc
        ? ReferenceTextRole.quotePriceBtcMajor
        : ReferenceTextRole.quotePriceMajor;
    final minorRole = variant == TypographyVariantId.quoteBtc
        ? ReferenceTextRole.quotePriceBtcMinor
        : ReferenceTextRole.quotePriceMinor;
    final majorStyle = AppTypography.forRole(
      context,
      majorRole,
      colorRole: colorRole,
      variant: variant,
    );
    final minorStyle = AppTypography.forRole(
      context,
      minorRole,
      colorRole: colorRole,
      variant: variant,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomRight,
      child: Text.rich(
        key: textKey,
        TextSpan(
          children: [
            TextSpan(text: leading, style: majorStyle),
            if (emphasized.isNotEmpty)
              TextSpan(text: emphasized, style: minorStyle),
            if (pipette != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Transform.translate(
                  offset: const Offset(
                    0,
                    TabReferenceMetrics.quotePricePipetteOffsetY,
                  ),
                  child: Text(
                    pipette,
                    key: pipetteKey,
                    style: AppTypography.forRole(
                      context,
                      ReferenceTextRole.quotePricePipette,
                      colorRole: colorRole,
                      variant: variant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        maxLines: 1,
        style: majorStyle,
      ),
    );
  }
}

String _marketWatchDisplaySymbol(String symbol) => displayTradingSymbol(symbol);

TypographyVariantId _quoteTypographyVariant(String symbol) =>
    switch (_marketWatchDisplaySymbol(symbol).toUpperCase()) {
      'XAUUSD' => TypographyVariantId.quoteXau,
      'BTCUSD' => TypographyVariantId.quoteBtc,
      _ => TypographyVariantId.quoteOther,
    };

({MarketQuoteDisplay display, List<MarketCandle> candles, bool isAvailable})
_watchQuoteDisplay(
  WidgetRef ref,
  DemoQuote quote,
  List<MarketCandle>? retainedCandles,
  MarketQuoteDisplay? retainedDisplay, {
  required DateTime receivedAt,
}) {
  final candleState = ref.watch(
    marketCandlesProvider(MarketDataRequest(quote.symbol, 'D1')),
  );
  final candles = candleState.asData?.value ?? retainedCandles ?? const [];
  final isAvailable = isUsableMarketQuote(quote);
  return (
    display: isAvailable
        ? buildMarketQuoteDisplay(
            quote: quote,
            dailyCandles: candles,
            receivedAt: receivedAt,
            retainedDisplay: retainedDisplay,
          )
        : buildUnavailableMarketQuoteDisplay(
            quote: quote,
            receivedAt: receivedAt,
          ),
    candles: candles,
    isAvailable: isAvailable,
  );
}

String _formatPointChange(int? value) {
  if (value == null) return '-- ';
  return value > 0 ? '+$value ' : '$value ';
}

String _formatPercent(double? value) =>
    value == null ? '--' : '${value.toStringAsFixed(2)}%';

String _formatStatistic(double? value, int digits) =>
    value == null ? '--' : value.toStringAsFixed(digits);

String _formatUtcTime(DateTime value) {
  final utc = value.toUtc();
  return '${_twoDigits(utc.hour)}:'
      '${_twoDigits(utc.minute)}:'
      '${_twoDigits(utc.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _SpreadGlyph extends StatelessWidget {
  const _SpreadGlyph();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(1.6666666667, .6666666667),
    child: CustomPaint(
      size: const Size.square(10),
      painter: _SpreadGlyphPainter(),
    ),
  );
}

class _SpreadGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.pricesSpread
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(1, 1), const Offset(1, 4), paint);
    canvas.drawLine(const Offset(1, 4), const Offset(9, 4), paint);
    canvas.drawLine(const Offset(9, 1), const Offset(9, 4), paint);
    canvas.drawLine(const Offset(1, 6), const Offset(1, 9), paint);
    canvas.drawLine(const Offset(1, 6), const Offset(9, 6), paint);
    canvas.drawLine(const Offset(9, 6), const Offset(9, 9), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.bottomGap = 8,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final double bottomGap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(8, 0, 8, bottomGap),
    child: Material(
      color: AppColors.sheetActionSurface,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 47,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
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

class _EmptyQuotes extends StatelessWidget {
  const _EmptyQuotes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Không có mã giao dịch',
        style: TextStyle(color: AppColors.tradingSecondaryText),
      ),
    );
  }
}
