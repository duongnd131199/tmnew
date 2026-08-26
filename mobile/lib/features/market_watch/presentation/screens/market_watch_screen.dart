import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/chart/application/chart_timeframe_session.dart';
import 'package:trading_mobile/features/chart/data/market_data_provider.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/features/market_watch/domain/market_symbol_policy.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';
import 'package:trading_mobile/shared/widgets/mt5_toolbar_icons.dart';

class MarketWatchScreen extends ConsumerStatefulWidget {
  const MarketWatchScreen({super.key});

  @override
  ConsumerState<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends ConsumerState<MarketWatchScreen> {
  bool compactMode = false;
  String? revealedSymbol;

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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _QuotesHeader(
              compactMode: compactMode,
              onToggleView: () => setState(() => compactMode = !compactMode),
              onManage: () => context.push(
                compactMode ? '/market/columns' : '/market/edit',
              ),
              onSearch: () => context.push('/market/search'),
            ),
            Expanded(
              child: visibleQuotes.isEmpty
                  ? const _EmptyQuotes()
                  : compactMode
                  ? _CompactQuotes(
                      quotes: visibleQuotes,
                      columns: columns,
                      onTap: (quote) => _showSymbolMenu(context, quote),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: visibleQuotes.length,
                      itemBuilder: (context, index) {
                        final quote = visibleQuotes[index];
                        return _SwipeQuoteRow(
                          quote: quote,
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
                          onChart: () => context.go(
                            _rememberedChartLocation(quote.symbol),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _rememberedChartLocation(String symbol) {
    final timeframe = ref
        .read(chartTimeframeSessionProvider.notifier)
        .timeframeFor(symbol);
    return chartLocationForSymbol(symbol, timeframe: timeframe);
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
                      color: AppColors.negative,
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
            left: 15.3,
            top: 30,
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
            top: 41.5,
            child: IgnorePointer(
              child: const Text(
                'Gia',
                textAlign: TextAlign.center,
                style: AppTypography.toolbarTitle,
              ),
            ),
          ),
          Positioned(
            right: 66.7,
            top: 30,
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
                      offset: const Offset(-1.3333333333, -.5),
                      child: Transform.scale(
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
            right: 13.3,
            top: 30,
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
    offset: const Offset(0, -1),
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
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    const rows = [3.0, 7.25, 11.0, 14.5];
    for (var index = 0; index < rows.length; index++) {
      final y = rows[index];
      canvas.drawRect(
        Rect.fromCenter(center: Offset(2.5, y), width: 2.2, height: 2.2),
        bullet,
      );
      canvas.drawLine(
        Offset(6.2, y),
        Offset(index == rows.length - 1 ? 11.25 : 15.8, y),
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
    offset: Offset.zero,
    child: Transform.scale(
      scale: .91,
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
      ..strokeWidth = 2.3
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
    );
  }
}

class _CompactQuotes extends StatelessWidget {
  const _CompactQuotes({
    required this.quotes,
    required this.columns,
    required this.onTap,
  });

  final List<DemoQuote> quotes;
  final List<String> columns;
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
          child: Column(
            children: [
              SizedBox(
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
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: quotes.length,
                  itemBuilder: (context, index) => _CompactQuoteRow(
                    quote: quotes[index],
                    columns: columns,
                    symbolWidth: symbolWidth,
                    columnWidths: columnWidths,
                    onTap: () => onTap(quotes[index]),
                  ),
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
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _CompactQuoteRow extends ConsumerWidget {
  const _CompactQuoteRow({
    required this.quote,
    required this.columns,
    required this.symbolWidth,
    required this.columnWidths,
    required this.onTap,
  });

  final DemoQuote quote;
  final List<String> columns;
  final double symbolWidth;
  final List<double> columnWidths;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(demoQuoteProvider(quote.symbol)).value ?? quote;
    final meta = _QuoteMeta.fromTick(
      live,
      receivedAt: ref.read(marketClockProvider)(),
    );
    final dailyColor = meta.points >= 0
        ? AppColors.primary
        : AppColors.negative;
    return InkWell(
      onTap: onTap,
      onLongPress: onTap,
      child: SizedBox(
        height: 33,
        child: Stack(
          children: [
            if (live.symbol.startsWith('XAUUSD'))
              const Positioned(
                left: 0,
                top: 0,
                child: _QuoteCorner(color: AppColors.primary),
              ),
            Row(
              children: [
                SizedBox(
                  width: symbolWidth,
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
                for (var index = 0; index < columns.length; index++)
                  SizedBox(
                    width: columnWidths[index],
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: columns[index] == 'Ngày %' ? 4 : 6,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _compactValue(columns[index], live, meta),
                          maxLines: 1,
                          style: TextStyle(
                            color: columns[index] == 'Ngày %'
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

String _compactValue(String column, DemoQuote quote, _QuoteMeta meta) {
  return switch (column) {
    'Chào mua' => _formatQuoteValue(quote.bid),
    'Chào bán' => _formatQuoteValue(quote.ask),
    'Ngày %' => meta.percent,
    'Giá mua cao' || 'Giá bán cao' || 'Giá cuối cao' => meta.high,
    'Giá mua thấp' || 'Giá bán thấp' || 'Giá cuối thấp' => meta.low,
    'Giá cuối' => _formatQuoteValue(quote.bid),
    'Thời gian' => meta.time,
    'Spread' => meta.spread,
    _ => '',
  };
}

String _formatQuoteValue(double value) {
  return value.toStringAsFixed(2);
}

class _SwipeQuoteRow extends StatefulWidget {
  const _SwipeQuoteRow({
    required this.quote,
    required this.revealed,
    required this.onReveal,
    required this.onHide,
    required this.onTap,
    required this.onOrder,
    required this.onDelete,
    required this.onChart,
  });

  final DemoQuote quote;
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
                    color: AppColors.textSecondary,
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
                  color: AppColors.negative,
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
  const _QuoteRow({required this.quote, required this.onTap});

  final DemoQuote quote;
  final VoidCallback onTap;

  @override
  ConsumerState<_QuoteRow> createState() => _QuoteRowState();
}

class _QuoteRowState extends ConsumerState<_QuoteRow> {
  DemoQuote? _previousTick;
  Color _lastBidColor = AppColors.primary;
  Color _lastAskColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final live =
        ref.watch(demoQuoteProvider(widget.quote.symbol)).value ?? widget.quote;
    final meta = _QuoteMeta.fromTick(
      live,
      receivedAt: ref.read(marketClockProvider)(),
    );
    final previous = _previousTick?.symbol == live.symbol
        ? _previousTick
        : null;
    final bidColor = _tickColor(
      current: live.bid,
      previous: previous?.bid,
      retained: _lastBidColor,
    );
    final askColor = _tickColor(
      current: live.ask,
      previous: previous?.ask,
      retained: _lastAskColor,
    );
    _previousTick = live;
    _lastBidColor = bidColor;
    _lastAskColor = askColor;
    final dailyColor = meta.points >= 0
        ? AppColors.primary
        : AppColors.negative;
    final isBtcUsd = live.symbol == 'BTCUSD';
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onTap,
      child: SizedBox(
        height: TabReferenceMetrics.quoteRowHeight,
        child: Stack(
          children: [
            if (live.symbol.startsWith('XAUUSD'))
              const Positioned(
                left: 0,
                top: 0,
                child: _QuoteCorner(color: AppColors.primary),
              ),
            Positioned(
              left: 8,
              top: 5.3333333333,
              child: Text.rich(
                key: ValueKey('market-change-${live.symbol}'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: meta.points > 0
                          ? '+${meta.points} '
                          : '${meta.points} ',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextSpan(
                      text: meta.percent,
                      style: AppTypography.tabColorInk(
                        context,
                        TextStyle(color: dailyColor),
                      ),
                    ),
                  ],
                ),
                style: AppTypography.quoteChange,
              ),
            ),
            Positioned(
              left: 8,
              top: isBtcUsd ? 24.0666666667 : 25.4,
              child: Text(
                _marketWatchDisplaySymbol(live.symbol),
                key: ValueKey('market-symbol-${live.symbol}'),
                style: isBtcUsd
                    ? AppTypography.quoteSymbol.copyWith(fontSize: 15)
                    : AppTypography.quoteSymbol,
              ),
            ),
            Positioned(
              left: 7.3333333333,
              top: isBtcUsd
                  ? TabReferenceMetrics.quoteBtcMetaTop
                  : 47.3333333333,
              child: Transform.scale(
                scaleY: .86,
                alignment: Alignment.topLeft,
                child: Row(
                  children: [
                    if (isBtcUsd)
                      const SizedBox(
                        key: ValueKey('market-delay-BTCUSD'),
                        width: 11.3333333333,
                        child: Icon(
                          CupertinoIcons.clock,
                          color: AppColors.textSecondary,
                          size: 11.3333333333,
                        ),
                      ),
                    Text(
                      meta.time,
                      key: ValueKey('market-time-${live.symbol}'),
                      style: AppTypography.quoteTimeMeta,
                    ),
                    SizedBox(width: isBtcUsd ? 1.3333333333 : 5.6666666667),
                    const _SpreadGlyph(),
                    const SizedBox(width: 4),
                    Text(
                      meta.spread,
                      key: ValueKey('market-spread-${live.symbol}'),
                      style: AppTypography.quoteTimeMeta,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 86.6333333333,
              top: 15.6666666667,
              width: 76,
              child: Align(
                alignment: Alignment.centerRight,
                child: _quotePriceInk(
                  isBtcUsd: isBtcUsd,
                  child: _QuotePrice(
                    value: _formatPrice(live.bid),
                    color: bidColor,
                    textKey: ValueKey('market-bid-${live.symbol}'),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 7.3,
              top: 15.6666666667,
              width: 76,
              child: Align(
                alignment: Alignment.centerRight,
                child: _quotePriceInk(
                  isBtcUsd: isBtcUsd,
                  child: _QuotePrice(
                    value: _formatPrice(live.ask),
                    color: askColor,
                    textKey: ValueKey('market-ask-${live.symbol}'),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 86.8,
              top: isBtcUsd
                  ? TabReferenceMetrics.quoteBtcMetaTop + 2
                  : 49.3333333333,
              child: Transform.scale(
                scaleY: .86,
                alignment: Alignment.topRight,
                child: Text(
                  'L: ${meta.low}',
                  key: ValueKey('market-low-${live.symbol}'),
                  style: AppTypography.quoteRangeMeta,
                ),
              ),
            ),
            Positioned(
              right: 7.3333333333,
              top: isBtcUsd
                  ? TabReferenceMetrics.quoteBtcMetaTop + 2
                  : 49.3333333333,
              child: Transform.translate(
                offset: Offset(
                  isBtcUsd ? TabReferenceMetrics.quoteBtcHighOffsetX : 0,
                  0,
                ),
                child: Transform.scale(
                  scaleY: .86,
                  alignment: Alignment.topRight,
                  child: Text(
                    'H: ${meta.high}',
                    key: ValueKey('market-high-${live.symbol}'),
                    style: isBtcUsd
                        ? AppTypography.quoteBtcHighMeta
                        : AppTypography.quoteRangeMeta,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tickColor({
    required double current,
    required double? previous,
    required Color retained,
  }) {
    if (previous == null) return retained;
    if (current > previous) return AppColors.primary;
    if (current < previous) return AppColors.negative;
    return retained;
  }

  String _formatPrice(double value) => value.toStringAsFixed(2);
}

Widget _quotePriceInk({required bool isBtcUsd, required Widget child}) {
  if (!isBtcUsd) return child;
  return Transform.translate(
    offset: const Offset(0, TabReferenceMetrics.quoteBtcPriceOffsetY),
    child: Transform.scale(
      scaleY: TabReferenceMetrics.quoteBtcPriceScaleY,
      alignment: Alignment.bottomRight,
      child: child,
    ),
  );
}

class _QuotePrice extends StatelessWidget {
  const _QuotePrice({
    required this.value,
    required this.color,
    required this.textKey,
  });

  final String value;
  final Color color;
  final Key textKey;

  @override
  Widget build(BuildContext context) {
    final splitAt = value.length > 2 ? value.length - 2 : 0;
    final leading = value.substring(0, splitAt);
    final pipDigits = value.substring(splitAt);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomRight,
      child: Text.rich(
        key: textKey,
        TextSpan(
          children: [
            TextSpan(text: leading, style: AppTypography.quotePriceMajor),
            TextSpan(text: pipDigits, style: AppTypography.quotePriceMinor),
          ],
        ),
        maxLines: 1,
        style: TextStyle(color: color, height: 1),
      ),
    );
  }
}

String _marketWatchDisplaySymbol(String symbol) =>
    symbol == 'BTCUSD' ? 'BTC' : displayTradingSymbol(symbol);

class _QuoteMeta {
  const _QuoteMeta({
    required this.points,
    required this.percent,
    required this.time,
    required this.spread,
    required this.low,
    required this.high,
  });

  factory _QuoteMeta.fromTick(DemoQuote quote, {DateTime? receivedAt}) {
    final digits = _priceDigits(quote);
    final factor = switch (digits) {
      2 => 100.0,
      3 => 1000.0,
      4 => 10000.0,
      _ => 100000.0,
    };
    final percentFactor = 1 + quote.changePercent / 100;
    final inferredPreviousClose = percentFactor.abs() < .0000001
        ? quote.bid
        : quote.bid / percentFactor;
    final referenceClose = quote.previousClose ?? inferredPreviousClose;
    final points = ((quote.bid - referenceClose) * factor).round();
    final percent = '${quote.changePercent.toStringAsFixed(2)}%';
    final spread = ((quote.ask - quote.bid).abs() * factor).round().toString();
    final rangeValues = [referenceClose, quote.bid, quote.ask];
    final dailyLow =
        quote.dailyLow ??
        rangeValues.reduce((value, next) => value < next ? value : next);
    final dailyHigh =
        quote.dailyHigh ??
        rangeValues.reduce((value, next) => value > next ? value : next);
    final tickTime = (receivedAt ?? DateTime.now()).subtract(
      const Duration(hours: 4),
    );

    return _QuoteMeta(
      points: points,
      percent: percent,
      time:
          '${_twoDigits(tickTime.hour)}:'
          '${_twoDigits(tickTime.minute)}:'
          '${_twoDigits(tickTime.second)}',
      spread: spread,
      low: _fixed(dailyLow, digits),
      high: _fixed(dailyHigh, digits),
    );
  }

  static int _priceDigits(DemoQuote quote) {
    if (quote.symbol.startsWith('XAU') || quote.symbol == 'BTCUSD') return 2;
    if (quote.bid.abs() >= 100) return 3;
    return 5;
  }

  static String _fixed(double value, int digits) =>
      value.toStringAsFixed(digits);

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  final int points;
  final String percent;
  final String time;
  final String spread;
  final String low;
  final String high;
}

class _QuoteCorner extends StatelessWidget {
  const _QuoteCorner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, TabReferenceMetrics.quoteCornerOffsetY),
    child: CustomPaint(
      size: const Size(
        TabReferenceMetrics.quoteCornerWidth,
        TabReferenceMetrics.quoteCornerHeight,
      ),
      painter: _QuoteCornerPainter(color),
    ),
  );
}

class _QuoteCornerPainter extends CustomPainter {
  const _QuoteCornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _QuoteCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

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
      ..color = AppColors.textSecondary
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
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
