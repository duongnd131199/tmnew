import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_spacing.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/chart/presentation/screens/chart_screen.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/app_shell.dart';
import 'package:trading_mobile/shared/widgets/mt_tab_header_fade.dart';
import 'package:trading_mobile/shared/widgets/mt_price_range_text.dart';

final RegExp _historyTimestampPattern = RegExp(
  r'^(\d{4})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
);

int _historyPriceDigitsForSymbol(String symbol) {
  final normalized = symbol.toUpperCase();
  if (normalized == 'XAUUSD+' || normalized == 'BTCUSD') return 2;
  if (normalized == 'XAUUSD' || normalized.endsWith('JPY')) return 3;
  return 5;
}

String _historyVolumeLabel(double volume) =>
    volume.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

typedef _HistorySummaryRow = ({String keyId, String label, String value});

TextStyle _historyRoleStyle(
  BuildContext context,
  ReferenceTextRole role,
  ReferenceTextColorRole colorRole,
  TypographyVariantId variant,
) => AppTypography.forRole(
  context,
  role,
  colorRole: colorRole,
  variant: variant,
);

ReferenceTextColorRole _historySideColorRole(String side) =>
    side.toUpperCase().contains('SELL') || side.toLowerCase().contains('sell')
    ? ReferenceTextColorRole.negative
    : ReferenceTextColorRole.blueAction;

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int tab = 0;
  bool descending = true;
  _HistorySortCriterion sortCriterion = _HistorySortCriterion.defaultOrder;
  _HistoryPeriod period = _HistoryPeriod.sixMonths;
  DateTimeRange? customRange;
  String? symbolFilter;
  final ScrollController _positionsController = ScrollController();
  final ScrollController _ordersController = ScrollController();
  final ScrollController _dealsController = ScrollController();
  final _positionFilterCache = _HistoryFilterCache<DemoHistoryPosition>();
  final _orderFilterCache = _HistoryFilterCache<DemoOrder>();
  final _dealFilterCache = _HistoryFilterCache<DemoDeal>();
  final Map<String, DateTime?> _parsedHistoryTimes = {};
  String? _anchoredAccountId;
  int? _anchoredHistoryLength;
  bool _historyBranchActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = AppTabScope.maybeIndexOf(context) == 3;
    if (isActive && !_historyBranchActive && ref.read(exV2EnabledProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || AppTabScope.maybeIndexOf(context) != 3) return;
        unawaited(
          ref
              .read(exV2AccountProvider.notifier)
              .refresh(queueAfterInFlight: true),
        );
      });
    }
    _historyBranchActive = isActive;
  }

  @override
  void dispose() {
    _positionsController.dispose();
    _ordersController.dispose();
    _dealsController.dispose();
    super.dispose();
  }

  void _syncPositionsBottomAnchor(String accountId, int historyLength) {
    final accountChanged = _anchoredAccountId != accountId;
    final historyChanged = _anchoredHistoryLength != historyLength;
    if (!accountChanged && !historyChanged) return;

    final wasNearBottom =
        !_positionsController.hasClients ||
        _positionsController.position.maxScrollExtent -
                _positionsController.position.pixels <=
            2;
    _anchoredAccountId = accountId;
    _anchoredHistoryLength = historyLength;
    if (accountChanged || (historyChanged && wasNearBottom)) {
      _scheduleBottomAnchor(accountId, historyLength: historyLength);
    }
  }

  void _scheduleBottomAnchor(String accountId, {required int historyLength}) {
    _stabilizeBottomAnchor(
      accountId,
      historyLength: historyLength,
      expectedPixels: null,
      remainingChecks: 2,
    );
  }

  void _stabilizeBottomAnchor(
    String accountId, {
    required int historyLength,
    required double? expectedPixels,
    required int remainingChecks,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _anchoredAccountId != accountId ||
          _anchoredHistoryLength != historyLength) {
        return;
      }
      if (_positionsController.hasClients) {
        final position = _positionsController.position;
        final userHasNotMoved =
            expectedPixels == null ||
            (position.pixels - expectedPixels).abs() <= 0.01;
        if (!userHasNotMoved) return;

        final maxScrollExtent = position.maxScrollExtent;
        if ((position.pixels - maxScrollExtent).abs() > 0.01) {
          _positionsController.jumpTo(maxScrollExtent);
        }
        if (remainingChecks > 0) {
          _stabilizeBottomAnchor(
            accountId,
            historyLength: historyLength,
            expectedPixels: maxScrollExtent,
            remainingChecks: remainingChecks - 1,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final content = switch (tab) {
      0 => _buildPositionsHistory(),
      1 => _buildOrdersHistory(),
      _ => _buildDealsHistory(),
    };
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: safeTop + TabReferenceMetrics.historyHeaderExtent,
            child: const IgnorePointer(
              child: MtTabHeaderFade(
                decorationKey: Key('history-header-overlay'),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: safeTop,
            right: 0,
            height: TabReferenceMetrics.historyHeaderExtent,
            child: _HistoryHeader(
              tab: tab,
              onTabChanged: (value) => setState(() => tab = value),
              onSort: _showSort,
              onPeriod: _showPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsHistory() {
    final accountProfile = ref.watch(activeDemoAccountProvider);
    final tradingBalance = ref.watch(
      demoTradingProvider.select((trading) => trading.balance),
    );
    final entries = _sortedPositionHistory(
      _filteredHistory(
        cache: _positionFilterCache,
        source: ref.watch(demoHistoryPositionsProvider),
        symbolOf: (entry) => entry.title,
        timeOf: (entry) => entry.time,
      ),
    );
    _syncPositionsBottomAnchor(accountProfile.id, entries.length);
    return _PositionsHistory(
      controller: _positionsController,
      entries: entries,
      descending: sortCriterion == _HistorySortCriterion.defaultOrder
          ? descending
          : true,
      profile: accountProfile,
      tradingBalance: tradingBalance,
      onEntryTap: _showPositionDetails,
    );
  }

  List<DemoHistoryPosition> _sortedPositionHistory(
    List<DemoHistoryPosition> source,
  ) {
    if (sortCriterion == _HistorySortCriterion.defaultOrder) return source;
    final indexed = source.indexed.toList(growable: false);
    indexed.sort((left, right) {
      final result = _comparePositionHistory(left.$2, right.$2);
      if (result != 0) return descending ? -result : result;
      return left.$1.compareTo(right.$1);
    });
    return [for (final item in indexed) item.$2];
  }

  int _comparePositionHistory(
    DemoHistoryPosition left,
    DemoHistoryPosition right,
  ) {
    return switch (sortCriterion) {
      _HistorySortCriterion.defaultOrder => 0,
      _HistorySortCriterion.symbol => left.title.toUpperCase().compareTo(
        right.title.toUpperCase(),
      ),
      _HistorySortCriterion.ticket => _compareTicketIds(left.id, right.id),
      _HistorySortCriterion.type => _positionTypeSortKey(
        left,
      ).compareTo(_positionTypeSortKey(right)),
      _HistorySortCriterion.volume => (left.volume ?? 0).compareTo(
        right.volume ?? 0,
      ),
      _HistorySortCriterion.openTime =>
        (left.openedAt ??
                _historyTime(left.time) ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              right.openedAt ??
                  _historyTime(right.time) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      _HistorySortCriterion.closeTime =>
        (left.closedAt ??
                _historyTime(left.time) ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              right.closedAt ??
                  _historyTime(right.time) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
      _HistorySortCriterion.profit => left.profit.compareTo(right.profit),
    };
  }

  String _positionTypeSortKey(DemoHistoryPosition entry) {
    if (entry.isBalance) return 'BALANCE';
    return entry.side?.toUpperCase() ?? '';
  }

  int _compareTicketIds(String left, String right) {
    final leftDisplay = displayTradingTicketId(left);
    final rightDisplay = displayTradingTicketId(right);
    final leftNumber = BigInt.tryParse(leftDisplay);
    final rightNumber = BigInt.tryParse(rightDisplay);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    return leftDisplay.compareTo(rightDisplay);
  }

  Widget _buildOrdersHistory() {
    final orders = _sortedOrderHistory(
      _filteredHistory(
        cache: _orderFilterCache,
        source: ref.watch(demoOrdersProvider),
        symbolOf: (order) => order.symbol,
        timeOf: (order) => order.time,
      ),
    );
    return _OrdersHistory(
      controller: _ordersController,
      orders: orders,
      descending: sortCriterion == _HistorySortCriterion.defaultOrder
          ? descending
          : true,
      onOrderTap: _showOrderDetails,
    );
  }

  List<DemoOrder> _sortedOrderHistory(List<DemoOrder> source) {
    if (sortCriterion == _HistorySortCriterion.defaultOrder) return source;
    return _stableSorted(source, (left, right) {
      return switch (sortCriterion) {
        _HistorySortCriterion.defaultOrder => 0,
        _HistorySortCriterion.symbol => left.symbol.toUpperCase().compareTo(
          right.symbol.toUpperCase(),
        ),
        _HistorySortCriterion.ticket => _compareTicketIds(left.id, right.id),
        _HistorySortCriterion.type =>
          '${left.side} ${left.type}'.toUpperCase().compareTo(
            '${right.side} ${right.type}'.toUpperCase(),
          ),
        _HistorySortCriterion.volume => left.volume.compareTo(right.volume),
        _HistorySortCriterion.openTime || _HistorySortCriterion.closeTime =>
          (_historyTime(left.time) ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                _historyTime(right.time) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              ),
        _HistorySortCriterion.profit => 0,
      };
    });
  }

  Widget _buildDealsHistory() {
    final deals = _sortedDealHistory(
      _filteredHistory(
        cache: _dealFilterCache,
        source: ref.watch(demoDealsProvider),
        symbolOf: (deal) => deal.symbol,
        timeOf: (deal) => deal.time,
      ),
    );
    return _DealsHistory(
      controller: _dealsController,
      deals: deals,
      descending: sortCriterion == _HistorySortCriterion.defaultOrder
          ? descending
          : true,
      profile: ref.watch(activeDemoAccountProvider),
      onDealTap: _showDealDetails,
    );
  }

  List<DemoDeal> _sortedDealHistory(List<DemoDeal> source) {
    if (sortCriterion == _HistorySortCriterion.defaultOrder) return source;
    return _stableSorted(source, (left, right) {
      return switch (sortCriterion) {
        _HistorySortCriterion.defaultOrder => 0,
        _HistorySortCriterion.symbol => left.symbol.toUpperCase().compareTo(
          right.symbol.toUpperCase(),
        ),
        _HistorySortCriterion.ticket => _compareTicketIds(left.id, right.id),
        _HistorySortCriterion.type =>
          '${left.side} ${left.entry}'.toUpperCase().compareTo(
            '${right.side} ${right.entry}'.toUpperCase(),
          ),
        _HistorySortCriterion.volume => left.volume.compareTo(right.volume),
        _HistorySortCriterion.openTime || _HistorySortCriterion.closeTime =>
          (_historyTime(left.time) ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                _historyTime(right.time) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              ),
        _HistorySortCriterion.profit => left.profit.compareTo(right.profit),
      };
    });
  }

  List<T> _stableSorted<T>(List<T> source, int Function(T, T) compare) {
    final indexed = source.indexed.toList(growable: false);
    indexed.sort((left, right) {
      final result = compare(left.$2, right.$2);
      if (result != 0) return descending ? -result : result;
      return left.$1.compareTo(right.$1);
    });
    return [for (final item in indexed) item.$2];
  }

  List<T> _filteredHistory<T>({
    required _HistoryFilterCache<T> cache,
    required List<T> source,
    required String Function(T entry) symbolOf,
    required String Function(T entry) timeOf,
  }) {
    final now = DateTime.now();
    return cache.resolve(
      source: source,
      period: period,
      customRange: customRange,
      symbolFilter: symbolFilter,
      include: (entry) {
        return (symbolFilter == null || symbolOf(entry) == symbolFilter) &&
            _withinPeriod(timeOf(entry), now);
      },
    );
  }

  Future<void> _showSort() {
    return showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Đóng sắp xếp',
      barrierColor: AppColors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => _HistorySortMenu(
        criterion: sortCriterion,
        descending: descending,
        onChanged: (criterion, isDescending) {
          if (!mounted) return;
          setState(() {
            sortCriterion = criterion;
            descending = isDescending;
          });
        },
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final size = MediaQuery.sizeOf(context);
        final horizontalScale = (size.width / 384).clamp(.9, 1.12);
        final anchor = Offset(
          6 * horizontalScale,
          MediaQuery.paddingOf(context).top,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment(
              2 * anchor.dx / size.width - 1,
              2 * anchor.dy / size.height - 1,
            ),
            scale: Tween<double>(begin: .16, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showPeriod() async {
    final selected = await Navigator.of(context, rootNavigator: true)
        .push<_HistoryFilterResult>(
          MaterialPageRoute(
            builder: (context) => _HistoryFilterScreen(
              period: period,
              symbol: symbolFilter,
              symbols: ref
                  .read(demoQuotesProvider)
                  .map((quote) => quote.symbol)
                  .toList(),
            ),
          ),
        );
    if (!mounted || selected == null) return;
    if (selected.period == _HistoryPeriod.custom) {
      final now = DateTime.now();
      final selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 10),
        lastDate: now,
        initialDateRange:
            customRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      );
      if (!mounted || selectedRange == null) return;
      setState(() {
        period = selected.period;
        symbolFilter = selected.symbol;
        customRange = selectedRange;
      });
      return;
    }
    setState(() {
      period = selected.period;
      symbolFilter = selected.symbol;
    });
  }

  bool _withinPeriod(String label, DateTime now) {
    final time = _historyTime(label);
    if (time == null) return true;
    final start = switch (period) {
      _HistoryPeriod.today => DateTime(now.year, now.month, now.day),
      _HistoryPeriod.lastWeek => now.subtract(const Duration(days: 7)),
      _HistoryPeriod.lastMonth => DateTime(now.year, now.month - 1, now.day),
      _HistoryPeriod.lastThreeMonths => DateTime(
        now.year,
        now.month - 3,
        now.day,
      ),
      _HistoryPeriod.sixMonths => DateTime(now.year, now.month - 6, now.day),
      _HistoryPeriod.lastYear => DateTime(now.year - 1, now.month, now.day),
      _HistoryPeriod.custom =>
        customRange?.start ?? DateTime.fromMillisecondsSinceEpoch(0),
    };
    if (period == _HistoryPeriod.custom && customRange != null) {
      final end = customRange!.end.add(const Duration(days: 1));
      return !time.isBefore(start) && time.isBefore(end);
    }
    return !time.isBefore(start);
  }

  DateTime? _historyTime(String label) {
    return _parsedHistoryTimes.putIfAbsent(label, () {
      final match = _historyTimestampPattern.firstMatch(label);
      if (match == null) return null;
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
    });
  }

  Future<void> _showDealDetails(DemoDeal deal) async {
    final action = await showModalBottomSheet<_HistoryDetailAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.background.withValues(alpha: .28),
      builder: (sheetContext) => _DealDetailSheet(
        deal: deal,
        onChart: () =>
            Navigator.pop(sheetContext, _HistoryDetailAction.openChart),
      ),
    );
    if (!mounted || action != _HistoryDetailAction.openChart) return;
    await _openHistoryChart(deal.symbol);
  }

  Future<void> _showOrderDetails(DemoOrder order) async {
    final action = await showModalBottomSheet<_HistoryDetailAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.background.withValues(alpha: .28),
      builder: (sheetContext) => _OrderDetailSheet(
        order: order,
        onChart: () =>
            Navigator.pop(sheetContext, _HistoryDetailAction.openChart),
      ),
    );
    if (!mounted || action != _HistoryDetailAction.openChart) return;
    await _openHistoryChart(order.symbol);
  }

  Future<void> _showPositionDetails(DemoHistoryPosition entry) async {
    if (entry.isBalance) return;
    final action = await showModalBottomSheet<_HistoryDetailAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.background.withValues(alpha: .28),
      builder: (sheetContext) => _PositionHistoryDetailSheet(
        entry: entry,
        onChart: () =>
            Navigator.pop(sheetContext, _HistoryDetailAction.openChart),
      ),
    );
    if (!mounted || action != _HistoryDetailAction.openChart) return;
    await _openHistoryChart(entry.title);
  }

  Future<void> _openHistoryChart(String symbol) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _HistoryChartPage(symbol: symbol),
      ),
    );
  }
}

enum _HistoryDetailAction { openChart }

class _HistoryFilterCache<T> {
  List<T>? _source;
  _HistoryPeriod? _period;
  DateTimeRange? _customRange;
  String? _symbolFilter;
  List<T>? _result;

  List<T> resolve({
    required List<T> source,
    required _HistoryPeriod period,
    required DateTimeRange? customRange,
    required String? symbolFilter,
    required bool Function(T entry) include,
  }) {
    final cachedResult = _result;
    if (cachedResult != null &&
        identical(_source, source) &&
        _period == period &&
        _customRange == customRange &&
        _symbolFilter == symbolFilter) {
      return cachedResult;
    }

    final result = source.where(include).toList(growable: false);
    _source = source;
    _period = period;
    _customRange = customRange;
    _symbolFilter = symbolFilter;
    _result = result;
    return result;
  }
}

enum _HistoryPeriod {
  today('Hôm nay'),
  lastWeek('Tuần vừa rồi'),
  lastMonth('Tháng vừa qua'),
  lastThreeMonths('3 tháng vừa qua'),
  sixMonths('6 tháng vừa qua'),
  lastYear('Năm vừa rồi'),
  custom('Tùy chỉnh');

  const _HistoryPeriod(this.label);
  final String label;
}

class _HistoryFilterResult {
  const _HistoryFilterResult({required this.period, required this.symbol});

  final _HistoryPeriod period;
  final String? symbol;
}

class _HistoryFilterScreen extends StatefulWidget {
  const _HistoryFilterScreen({
    required this.period,
    required this.symbol,
    required this.symbols,
  });

  final _HistoryPeriod period;
  final String? symbol;
  final List<String> symbols;

  @override
  State<_HistoryFilterScreen> createState() => _HistoryFilterScreenState();
}

class _HistoryFilterScreenState extends State<_HistoryFilterScreen> {
  late _HistoryPeriod period = widget.period;
  late String? symbol = widget.symbol;

  Future<void> _showSymbolPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Symbol',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _SymbolFilterRow(
                      label: 'Tất cả Symbols',
                      selected: symbol == null,
                      onTap: () => Navigator.pop(sheetContext, ''),
                    ),
                    for (final item in widget.symbols)
                      _SymbolFilterRow(
                        label: displayTradingSymbol(item),
                        selected: symbol == item,
                        onTap: () => Navigator.pop(sheetContext, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => symbol = selected.isEmpty ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
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
                    child: _CircleButton(
                      onTap: () => Navigator.pop(
                        context,
                        _HistoryFilterResult(period: period, symbol: symbol),
                      ),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: AppColors.textPrimary,
                        size: 27,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 70,
                    right: 70,
                    top: 41.5,
                    child: Text(
                      'Lịch sử',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18.7, 4, 18.7, 24),
                children: [
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      key: const Key('history-symbol-filter'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: _showSymbolPicker,
                      child: SizedBox(
                        height: 49,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              const Text(
                                'Symbol:',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                symbol == null
                                    ? 'Tất cả Symbols'
                                    : displayTradingSymbol(symbol!),
                                style: const TextStyle(
                                  color: AppColors.tradingSecondaryText,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < _HistoryPeriod.values.length;
                          index++
                        )
                          InkWell(
                            onTap: () {
                              final selected = _HistoryPeriod.values[index];
                              if (selected == _HistoryPeriod.custom) {
                                Navigator.pop(
                                  context,
                                  _HistoryFilterResult(
                                    period: selected,
                                    symbol: symbol,
                                  ),
                                );
                              } else {
                                setState(() => period = selected);
                              }
                            },
                            child: Container(
                              height: 49.5,
                              decoration:
                                  index == _HistoryPeriod.values.length - 1
                                  ? null
                                  : const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.divider,
                                          width: .5,
                                        ),
                                      ),
                                    ),
                              child: Row(
                                children: [
                                  Text(
                                    _HistoryPeriod.values[index].label,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_HistoryPeriod.values[index] == period)
                                    const Icon(
                                      CupertinoIcons.check_mark,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {},
                      child: SizedBox(
                        height: 62,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tạo báo cáo giao dịch',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15.2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    period.label,
                                    style: const TextStyle(
                                      color: AppColors.tradingSecondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                color: AppColors.textTertiary,
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
          ],
        ),
      ),
    );
  }
}

class _SymbolFilterRow extends StatelessWidget {
  const _SymbolFilterRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: selected
        ? const Icon(CupertinoIcons.check_mark, color: AppColors.primary)
        : null,
    onTap: onTap,
  );
}

enum _HistorySortCriterion {
  defaultOrder('default', 'Mặc định'),
  symbol('symbol', 'Cặp ngoại tệ'),
  ticket('ticket', 'Ticket'),
  type('type', 'Loại'),
  volume('volume', 'Khối lượng'),
  openTime('open-time', 'Thời gian mở'),
  closeTime('close-time', 'Thời gian đóng'),
  profit('profit', 'Lợi nhuận');

  const _HistorySortCriterion(this.keyName, this.label);

  final String keyName;
  final String label;
}

class _HistorySortMenu extends StatefulWidget {
  const _HistorySortMenu({
    required this.criterion,
    required this.descending,
    required this.onChanged,
  });

  final _HistorySortCriterion criterion;
  final bool descending;
  final void Function(_HistorySortCriterion criterion, bool descending)
  onChanged;

  @override
  State<_HistorySortMenu> createState() => _HistorySortMenuState();
}

class _HistorySortMenuState extends State<_HistorySortMenu> {
  late _HistorySortCriterion criterion = widget.criterion;
  late bool descending = widget.descending;

  void _select(_HistorySortCriterion next) {
    setState(() {
      if (next == _HistorySortCriterion.defaultOrder) {
        criterion = next;
        descending = true;
      } else if (next == criterion) {
        descending = !descending;
      } else {
        criterion = next;
        descending = true;
      }
    });
    widget.onChanged(criterion, descending);
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final size = MediaQuery.sizeOf(context);
    final horizontalScale = (size.width / 384).clamp(.9, 1.12);
    final verticalScale = (size.height / 848).clamp(.9, 1.12);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            key: const Key('history-sort-menu'),
            left: 6 * horizontalScale,
            top: safeTop,
            width: 292 * horizontalScale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30 * horizontalScale),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x34000000),
                    blurRadius: 24 * horizontalScale,
                    offset: Offset(0, 8 * verticalScale),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30 * horizontalScale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColoredBox(
                      color: AppColors.historySortHeaderSurface,
                      child: SizedBox(
                        height: 34 * verticalScale,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 18 * horizontalScale,
                            ),
                            child: Text(
                              'Sắp xếp theo',
                              style: TextStyle(
                                color: AppColors.historySortHeading,
                                fontSize: 16 * horizontalScale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final item in _HistorySortCriterion.values)
                      _HistorySortRow(
                        criterion: item,
                        selected: criterion == item,
                        descending: descending,
                        horizontalScale: horizontalScale,
                        verticalScale: verticalScale,
                        onTap: () => _select(item),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySortRow extends StatelessWidget {
  const _HistorySortRow({
    required this.criterion,
    required this.selected,
    required this.descending,
    required this.horizontalScale,
    required this.verticalScale,
    required this.onTap,
  });

  final _HistorySortCriterion criterion;
  final bool selected;
  final bool descending;
  final double horizontalScale;
  final double verticalScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('history-sort-option-${criterion.keyName}'),
      onTap: onTap,
      child: Container(
        height: 49.5 * verticalScale,
        margin: EdgeInsets.symmetric(horizontal: 14 * horizontalScale),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.historySortDivider, width: .5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 4 * horizontalScale),
            Expanded(
              child: Text(
                criterion.label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16 * horizontalScale,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(
                key: ValueKey('history-sort-indicator-${criterion.keyName}'),
                criterion == _HistorySortCriterion.defaultOrder
                    ? CupertinoIcons.check_mark
                    : descending
                    ? CupertinoIcons.arrow_down
                    : CupertinoIcons.arrow_up,
                color: AppColors.primary,
                size:
                    (criterion == _HistorySortCriterion.defaultOrder
                        ? 20
                        : 16) *
                    horizontalScale,
              ),
            SizedBox(width: horizontalScale),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.tab,
    required this.onTabChanged,
    required this.onSort,
    required this.onPeriod,
  });

  final int tab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSort;
  final VoidCallback onPeriod;

  @override
  Widget build(BuildContext context) {
    const labels = ['Lenh co trang thai', 'Cac lenh', 'Cac giao dich'];
    const variants = [
      TypographyVariantId.historyPositions,
      TypographyVariantId.historyOrders,
      TypographyVariantId.historyDeals,
    ];
    return SizedBox(
      height: TabReferenceMetrics.historyHeaderExtent,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 30,
            child: _CircleButton(
              key: const Key('history-sort-button'),
              dimension: 42.6666666667,
              onTap: onSort,
              child: const _SortHistoryIcon(),
            ),
          ),
          Positioned(
            left: 70.5,
            right: 65.8333333333,
            top: 30,
            height: 44,
            child: Container(
              key: const Key('history-segmented-control'),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: AppColors.divider, width: .6),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 1.3333333333, 3, 2),
                child: Row(
                  children: List.generate(labels.length, (index) {
                    final selected = tab == index;
                    final segment = Semantics(
                      key: ValueKey('history-tab-$index'),
                      button: true,
                      selected: selected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onTabChanged(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: !selected
                                  ? 0
                                  : index == 0
                                  ? TabReferenceMetrics
                                        .historyFirstSelectedLeftOffset
                                  : TabReferenceMetrics
                                        .historySelectedSideInset,
                              right: !selected
                                  ? 0
                                  : index == 0
                                  ? TabReferenceMetrics
                                        .historyFirstSelectedRightInset
                                  : index == 2
                                  ? TabReferenceMetrics
                                        .historyDealsSelectedRightInset
                                  : TabReferenceMetrics
                                        .historySelectedSideInset,
                              top: 0,
                              bottom: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.historySegmentSelected
                                      : AppColors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            Align(
                              alignment: index == 2
                                  ? const Alignment(0, -.1)
                                  : Alignment.center,
                              child: Text(
                                labels[index],
                                key: ValueKey('history-segment-label-$index'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _historyRoleStyle(
                                  context,
                                  index == 2
                                      ? ReferenceTextRole.historyDealsSegment
                                      : ReferenceTextRole.historySegment,
                                  ReferenceTextColorRole.primary,
                                  variants[index],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (index == 0) {
                      return SizedBox(width: 80, child: segment);
                    }
                    return Expanded(child: segment);
                  }),
                ),
              ),
            ),
          ),
          Positioned(
            right: 13,
            top: 30,
            child: _CircleButton(
              key: const Key('history-period-button'),
              dimension: 42.6666666667,
              onTap: onPeriod,
              child: Transform.translate(
                offset: const Offset(0, .3333333333),
                child: Transform.scale(
                  scaleX: .95,
                  scaleY: .95,
                  child: const _HistoryPeriodIcon(
                    key: Key('history-period-icon'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.onTap,
    required this.child,
    this.dimension = 40,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final double dimension;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: dimension,
        child: Center(child: child),
      ),
    ),
  );
}

class _SortHistoryIcon extends StatelessWidget {
  const _SortHistoryIcon();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(.6666666667, -.3333333333),
    child: Transform.scale(
      scaleX: .8,
      scaleY: .95,
      child: CustomPaint(
        key: const Key('history-sort-icon'),
        size: const Size(22, 20),
        painter: _SortHistoryIconPainter(),
      ),
    ),
  );
}

class _SortHistoryIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;
    final arrow = Path()
      ..moveTo(5, 1.7)
      ..lineTo(9.5, 6.25)
      ..lineTo(6.25, 6.25)
      ..lineTo(6.25, 13.5)
      ..lineTo(9.5, 13.5)
      ..lineTo(5, 18)
      ..lineTo(.5, 13.5)
      ..lineTo(3.75, 13.5)
      ..lineTo(3.75, 6.25)
      ..lineTo(.5, 6.25)
      ..close();
    canvas.drawPath(arrow, paint);
    for (final y in const [4.0, 8.5, 13.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(13, y, 7.6, 2.25),
          const Radius.circular(.35),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HistoryPeriodIcon extends StatelessWidget {
  const _HistoryPeriodIcon({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: const [
      // Retain the platform icon node for compatibility with existing
      // interaction finders while the reference-accurate painter is visible.
      Icon(CupertinoIcons.clock, color: AppColors.transparent, size: 24),
      CustomPaint(size: Size.square(24), painter: _HistoryPeriodIconPainter()),
    ],
  );
}

class _HistoryPeriodIconPainter extends CustomPainter {
  const _HistoryPeriodIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 12), 8.9, ring);

    final hands = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(12, 6.35)
      ..lineTo(12, 12.35)
      ..lineTo(15.55, 15.55);
    canvas.drawPath(path, hands);
  }

  @override
  bool shouldRepaint(covariant _HistoryPeriodIconPainter oldDelegate) => false;
}

class _DealsHistory extends StatelessWidget {
  const _DealsHistory({
    required this.controller,
    required this.deals,
    required this.descending,
    required this.profile,
    required this.onDealTap,
  });

  final ScrollController controller;
  final List<DemoDeal> deals;
  final bool descending;
  final DemoAccountProfile profile;
  final ValueChanged<DemoDeal> onDealTap;

  @override
  Widget build(BuildContext context) {
    final summaryRowCount = profile.historyWithdrawal == 0 ? 5 : 6;
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = TabReferenceMetrics.historyRowHeightFor(textScaler);
    final summaryRowHeight = TabReferenceMetrics.historySummaryRowHeightFor(
      textScaler,
    );
    final stacksSecondary = TabReferenceMetrics.historyStacksSecondary(
      textScaler,
    );
    final secondaryTop = stacksSecondary
        ? TabReferenceMetrics.historySecondaryTopFor(textScaler)
        : TabReferenceMetrics.historyDealSecondaryTop;
    final trailingSecondaryTop = stacksSecondary
        ? TabReferenceMetrics.historyTrailingSecondaryTopFor(textScaler)
        : TabReferenceMetrics.historyDealSecondaryTop;
    final primaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historyPrimary,
      ReferenceTextColorRole.primary,
      TypographyVariantId.historyDeals,
    );
    final secondaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historySecondary,
      ReferenceTextColorRole.secondary,
      TypographyVariantId.historyDeals,
    );
    final trailingSecondaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historyTrailingSecondary,
      ReferenceTextColorRole.secondary,
      TypographyVariantId.historyDeals,
    );
    return _HistoryPersistentScrollbar(
      scrollbarKey: const Key('history-deals-scrollbar'),
      indicatorKey: const Key('history-deals-scrollbar-indicator'),
      controller: controller,
      rowCount: deals.length,
      canonicalRowCount: 20,
      canonicalThumbExtent: TabReferenceMetrics.historyDealsThumbExtent,
      child: ListView.builder(
        key: const PageStorageKey('history-deals-list'),
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          6,
          _historyListTopPadding(context),
          5.3333333333,
          87.3333333333,
        ),
        itemCount: deals.length + 2,
        itemExtentBuilder: (index, _) {
          if (index < deals.length) {
            return rowHeight;
          }
          if (index == deals.length) return 2;
          return 1.3333333333 + summaryRowCount * summaryRowHeight;
        },
        itemBuilder: (context, index) {
          if (index < deals.length) {
            final deal = deals[descending ? index : deals.length - index - 1];
            final showsRealizedProfit = deal.entry.toLowerCase().startsWith(
              'out',
            );
            return Semantics(
              button: true,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: ValueKey('history-deal-${deal.id}'),
                  onTap: () => onDealTap(deal),
                  child: SizedBox(
                    height: rowHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: TabReferenceMetrics.historyPrimaryTop,
                          child: _HistoryPrimaryPair(
                            leading: Text.rich(
                              key: ValueKey('history-deals-primary-$index'),
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: displayTradingSymbol(deal.symbol),
                                    style: primaryStyle,
                                  ),
                                  _historyActionSpan(
                                    context: context,
                                    text:
                                        ' ${deal.side.toLowerCase()}, '
                                        '${deal.entry}',
                                    colorRole: _historySideColorRole(deal.side),
                                    variant: TypographyVariantId.historyDeals,
                                    key: ValueKey(
                                      'history-deals-action-$index',
                                    ),
                                    inline: stacksSecondary,
                                  ),
                                ],
                              ),
                              style: primaryStyle,
                              softWrap: false,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: showsRealizedProfit
                                ? Text(
                                    _formatMoney(deal.profit),
                                    key: ValueKey(
                                      'history-deals-trailing-primary-$index',
                                    ),
                                    style: _historyRoleStyle(
                                      context,
                                      ReferenceTextRole.historyTrailingPrimary,
                                      deal.profit < 0
                                          ? ReferenceTextColorRole.negative
                                          : ReferenceTextColorRole.positive,
                                      TypographyVariantId.historyDeals,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: secondaryTop,
                          child: Text(
                            '${_historyVolumeLabel(deal.volume)} at '
                            '${deal.price.toStringAsFixed(_historyPriceDigitsForSymbol(deal.symbol))}',
                            key: ValueKey('history-deals-secondary-$index'),
                            style: secondaryStyle,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: trailingSecondaryTop,
                          child: Text(
                            deal.time,
                            key: ValueKey(
                              'history-deals-trailing-secondary-$index',
                            ),
                            style: trailingSecondaryStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (index == deals.length) {
            return const SizedBox(height: 2);
          }
          return _SummaryRows(
            variant: TypographyVariantId.historyDeals,
            rows: [
              (
                keyId: 'Tien nap',
                label: 'Tien nap',
                value: _formatMoney(profile.historyDeposit),
              ),
              if (profile.historyWithdrawal != 0)
                (
                  keyId: 'Tien rut',
                  label: 'Tien rut',
                  value: _formatMoney(profile.historyWithdrawal),
                ),
              (
                keyId: 'Loi nhuan',
                label: 'Loi nhuan',
                value: _formatMoney(profile.historyProfit),
              ),
              (
                keyId: 'Phi qua dem',
                label: 'Phi qua dem',
                value: _formatMoney(profile.historySwap),
              ),
              (
                keyId: 'Hoa hong',
                label: 'Hoa hong',
                value: _formatMoney(profile.historyCommission),
              ),
              (
                keyId: 'Số dư',
                label: 'Số dư',
                value: _formatMoney(profile.historyBalance),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrdersHistory extends StatelessWidget {
  const _OrdersHistory({
    required this.controller,
    required this.orders,
    required this.descending,
    required this.onOrderTap,
  });

  final ScrollController controller;
  final List<DemoOrder> orders;
  final bool descending;
  final ValueChanged<DemoOrder> onOrderTap;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = TabReferenceMetrics.historyRowHeightFor(textScaler);
    final summaryRowHeight = TabReferenceMetrics.historySummaryRowHeightFor(
      textScaler,
    );
    final stacksSecondary = TabReferenceMetrics.historyStacksSecondary(
      textScaler,
    );
    final secondaryTop = stacksSecondary
        ? TabReferenceMetrics.historySecondaryTopFor(textScaler)
        : TabReferenceMetrics.historySecondaryTop;
    final trailingSecondaryTop = stacksSecondary
        ? TabReferenceMetrics.historyTrailingSecondaryTopFor(textScaler)
        : TabReferenceMetrics.historySecondaryTop;
    final primaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historyPrimary,
      ReferenceTextColorRole.primary,
      TypographyVariantId.historyOrders,
    );
    final secondaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historySecondary,
      ReferenceTextColorRole.secondary,
      TypographyVariantId.historyOrders,
    );
    final trailingSecondaryStyle = _historyRoleStyle(
      context,
      ReferenceTextRole.historyTrailingSecondary,
      ReferenceTextColorRole.secondary,
      TypographyVariantId.historyOrders,
    );
    return _HistoryPersistentScrollbar(
      scrollbarKey: const Key('history-orders-scrollbar'),
      indicatorKey: const Key('history-orders-scrollbar-indicator'),
      controller: controller,
      rowCount: orders.length,
      canonicalRowCount: 19,
      canonicalThumbExtent: TabReferenceMetrics.historyOrdersThumbExtent,
      endThumbGrowth: TabReferenceMetrics.historyOrdersEndThumbGrowth,
      child: ListView.builder(
        key: const PageStorageKey('history-orders-list'),
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          6,
          _historyListTopPadding(context),
          5.3333333333,
          81.3333333333,
        ),
        itemCount: orders.length + 2,
        itemExtentBuilder: (index, _) {
          if (index < orders.length) {
            return rowHeight;
          }
          if (index == orders.length) return 3;
          return 1.3333333333 + 3 * summaryRowHeight;
        },
        itemBuilder: (context, index) {
          if (index < orders.length) {
            final order =
                orders[descending ? index : orders.length - index - 1];
            return Semantics(
              button: true,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: ValueKey('history-order-${order.id}'),
                  onTap: () => onOrderTap(order),
                  child: SizedBox(
                    height: rowHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: TabReferenceMetrics.historyPrimaryTop,
                          child: _HistoryPrimaryPair(
                            leading: Text.rich(
                              key: ValueKey('history-orders-primary-$index'),
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: displayTradingSymbol(order.symbol),
                                    style: primaryStyle,
                                  ),
                                  _historyActionSpan(
                                    context: context,
                                    text: ' ${_orderTypeLabel(order)}',
                                    colorRole: _historySideColorRole(
                                      order.side,
                                    ),
                                    variant: TypographyVariantId.historyOrders,
                                    key: ValueKey(
                                      'history-orders-action-$index',
                                    ),
                                    inline: stacksSecondary,
                                  ),
                                ],
                              ),
                              style: primaryStyle,
                              softWrap: false,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _historyOrderStatusLabel(order.status),
                              key: ValueKey(
                                'history-orders-trailing-primary-$index',
                              ),
                              style: _historyRoleStyle(
                                context,
                                ReferenceTextRole.historyTrailingPrimary,
                                ReferenceTextColorRole.historyStatus,
                                TypographyVariantId.historyOrders,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: secondaryTop,
                          child: Text(
                            _orderVolumeLabel(order),
                            key: ValueKey('history-orders-secondary-$index'),
                            style: secondaryStyle,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: trailingSecondaryTop,
                          child: Text(
                            order.time,
                            key: ValueKey(
                              'history-orders-trailing-secondary-$index',
                            ),
                            style: trailingSecondaryStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (index == orders.length) {
            return const SizedBox(height: 3);
          }
          return _SummaryRows(
            variant: TypographyVariantId.historyOrders,
            rows: [
              (
                keyId: 'Tong cong',
                label: 'Tong cong',
                value: '${orders.length}',
              ),
              (
                keyId: 'Filled',
                label: 'Filled',
                value:
                    '${orders.where((item) => item.status == 'filled').length}',
              ),
              (
                keyId: 'Bi huy',
                label: 'Bi huy',
                value:
                    '${orders.where((item) => item.status == 'canceled').length}',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryPersistentScrollbar extends StatefulWidget {
  const _HistoryPersistentScrollbar({
    required this.scrollbarKey,
    required this.indicatorKey,
    required this.controller,
    required this.rowCount,
    required this.canonicalRowCount,
    required this.canonicalThumbExtent,
    this.endThumbGrowth = 0,
    required this.child,
  });

  final Key scrollbarKey;
  final Key indicatorKey;
  final ScrollController controller;
  final int rowCount;
  final int canonicalRowCount;
  final double canonicalThumbExtent;
  final double endThumbGrowth;
  final Widget child;

  @override
  State<_HistoryPersistentScrollbar> createState() =>
      _HistoryPersistentScrollbarState();
}

class _HistoryPersistentScrollbarState
    extends State<_HistoryPersistentScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    _scheduleMetricsRefresh();
  }

  @override
  void didUpdateWidget(covariant _HistoryPersistentScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
    _scheduleMetricsRefresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _scheduleMetricsRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RawScrollbar(
          key: widget.scrollbarKey,
          controller: widget.controller,
          interactive: false,
          thumbVisibility: true,
          fadeDuration: Duration.zero,
          thickness: TabReferenceMetrics.historyScrollbarWidth,
          crossAxisMargin: TabReferenceMetrics.historyScrollbarRightInset,
          radius: Radius.zero,
          thumbColor: AppColors.transparent,
          child: widget.child,
        ),
        if (widget.rowCount > 0 &&
            widget.controller.hasClients &&
            widget.controller.position.maxScrollExtent > 0)
          _buildIndicator(context),
      ],
    );
  }

  Widget _buildIndicator(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = TabReferenceMetrics.historyRowHeightFor(textScaler);
    final trackTop =
        MediaQuery.paddingOf(context).top +
        TabReferenceMetrics.historyHeaderExtent;
    final trackBottom =
        MediaQuery.sizeOf(context).height -
        TabReferenceMetrics.historyScrollbarBottomInset;
    final trackExtent = (trackBottom - trackTop).clamp(0.0, double.infinity);
    final referenceScale =
        widget.canonicalRowCount *
        TabReferenceMetrics.historyRowHeight /
        (widget.rowCount * rowHeight);
    final rowScrollExtent = math.max(
      widget.rowCount * rowHeight - trackExtent,
      0.0,
    );
    final fraction = rowScrollExtent == 0
        ? 0.0
        : (widget.controller.position.pixels / rowScrollExtent).clamp(0.0, 1.0);
    final thumbExtent = math.min(
      trackExtent,
      math.max(
        24.0,
        (widget.canonicalThumbExtent + widget.endThumbGrowth * fraction) *
            referenceScale,
      ),
    );
    final thumbTop = trackTop + (trackExtent - thumbExtent) * fraction;
    final leadingEdgeInset = fraction >= .999
        ? TabReferenceMetrics.historyScrollbarEndEdgeInset
        : 0.0;
    return Positioned(
      key: widget.indicatorKey,
      top: thumbTop + leadingEdgeInset,
      right: TabReferenceMetrics.historyScrollbarRightInset,
      width: TabReferenceMetrics.historyScrollbarWidth,
      height: thumbExtent - leadingEdgeInset,
      child: const IgnorePointer(child: _HistoryScrollbarInk()),
    );
  }
}

class _HistoryScrollbarInk extends StatelessWidget {
  const _HistoryScrollbarInk();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ColoredBox(color: Color(0x15000000))),
        Expanded(child: ColoredBox(color: Color(0x5A000000))),
        Expanded(child: ColoredBox(color: Color(0x57000000))),
        Expanded(child: ColoredBox(color: Color(0xFFB1B1B1))),
        Expanded(child: ColoredBox(color: Color(0xFFB1B1B1))),
      ],
    );
  }
}

class _PositionsHistory extends StatelessWidget {
  const _PositionsHistory({
    required this.controller,
    required this.entries,
    required this.descending,
    required this.profile,
    required this.tradingBalance,
    required this.onEntryTap,
  });

  final ScrollController controller;
  final List<DemoHistoryPosition> entries;
  final bool descending;
  final DemoAccountProfile profile;
  final double tradingBalance;
  final ValueChanged<DemoHistoryPosition> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final realizedAdjustment = tradingBalance - profile.balance;
    final summaryRowCount = profile.historyWithdrawal == 0 ? 5 : 6;
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = TabReferenceMetrics.historyRowHeightFor(textScaler);
    final summaryRowHeight = TabReferenceMetrics.historySummaryRowHeightFor(
      textScaler,
    );
    return Scrollbar(
      key: const Key('history-positions-scrollbar'),
      controller: controller,
      interactive: true,
      thumbVisibility: false,
      thickness: 2,
      radius: const Radius.circular(2),
      child: ListView.builder(
        key: const PageStorageKey('history-positions-list'),
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          6,
          _historyListTopPadding(context),
          5.3333333333,
          TabReferenceMetrics.bottomNavigationFadeHeight,
        ),
        itemCount: entries.length + 1,
        itemExtentBuilder: (index, _) => index < entries.length
            ? rowHeight
            : 1.3333333333 + summaryRowCount * summaryRowHeight,
        itemBuilder: (context, index) {
          if (index < entries.length) {
            final entry =
                entries[descending ? index : entries.length - index - 1];
            return _HistoryPositionRow(
              entry: entry,
              roleIndex: index,
              onTap: entry.isBalance ? null : () => onEntryTap(entry),
            );
          }
          return _SummaryRows(
            variant: TypographyVariantId.historyBalance,
            rows: [
              (
                keyId: 'Tien nap',
                label: 'Tien nap',
                value: _formatMoney(profile.historyDeposit),
              ),
              if (profile.historyWithdrawal != 0)
                (
                  keyId: 'Tien rut',
                  label: 'Tien rut',
                  value: _formatMoney(profile.historyWithdrawal),
                ),
              (
                keyId: 'Loi nhuan',
                label: 'Loi nhuan',
                value: _formatMoney(profile.historyProfit + realizedAdjustment),
              ),
              (
                keyId: 'Phi qua dem',
                label: 'Phi qua dem',
                value: _formatMoney(profile.historySwap),
              ),
              (
                keyId: 'Hoa hong',
                label: 'Hoa hong',
                value: _formatMoney(profile.historyCommission),
              ),
              (
                keyId: 'Số dư',
                label: 'Số dư',
                value: _formatMoney(
                  profile.historyBalance + realizedAdjustment,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryPositionRow extends StatelessWidget {
  const _HistoryPositionRow({
    required this.entry,
    required this.roleIndex,
    required this.onTap,
  });

  final DemoHistoryPosition entry;
  final int roleIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final volume = entry.volume;
    final volumeLabel = volume == null ? '' : _historyVolumeLabel(volume);
    final priceDigits = _historyPriceDigitsForSymbol(entry.title);
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = TabReferenceMetrics.historyRowHeightFor(textScaler);
    final stacksSecondary = TabReferenceMetrics.historyStacksSecondary(
      textScaler,
    );
    final leadingSecondaryTop = stacksSecondary
        ? TabReferenceMetrics.historySecondaryTopFor(textScaler)
        : entry.isBalance
        ? TabReferenceMetrics.historySecondaryTop
        : TabReferenceMetrics.historyPriceRangeTop;
    final trailingSecondaryTop = stacksSecondary
        ? TabReferenceMetrics.historyTrailingSecondaryTopFor(textScaler)
        : TabReferenceMetrics.historySecondaryTop;
    final variant = entry.isBalance
        ? TypographyVariantId.historyBalance
        : TypographyVariantId.historyPositions;
    final primaryRole = entry.isBalance
        ? ReferenceTextRole.historyBalancePrimary
        : ReferenceTextRole.historyPrimary;
    final trailingPrimaryRole = entry.isBalance
        ? ReferenceTextRole.historyBalanceTrailingPrimary
        : ReferenceTextRole.historyTrailingPrimary;
    final primaryStyle = _historyRoleStyle(
      context,
      primaryRole,
      ReferenceTextColorRole.primary,
      variant,
    );
    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          key: ValueKey('history-position-${entry.id}'),
          onTap: onTap,
          child: SizedBox(
            height: rowHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: TabReferenceMetrics.historyPrimaryTop,
                  child: _HistoryPrimaryPair(
                    leading: Text.rich(
                      key: ValueKey('history-positions-primary-$roleIndex'),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: displayTradingSymbol(entry.title),
                            style: primaryStyle,
                          ),
                          if (!entry.isBalance)
                            _historyActionSpan(
                              context: context,
                              text:
                                  ' ${entry.side?.toLowerCase() ?? ''} $volumeLabel',
                              colorRole: _historySideColorRole(
                                entry.side ?? '',
                              ),
                              variant: TypographyVariantId.historyPositions,
                              key: ValueKey(
                                'history-positions-action-$roleIndex',
                              ),
                              inline: stacksSecondary,
                            ),
                        ],
                      ),
                      style: primaryStyle,
                      softWrap: false,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatMoney(entry.profit),
                      key: ValueKey(
                        'history-positions-trailing-primary-$roleIndex',
                      ),
                      style: _historyRoleStyle(
                        context,
                        trailingPrimaryRole,
                        entry.profit < 0
                            ? ReferenceTextColorRole.negative
                            : ReferenceTextColorRole.positive,
                        variant,
                      ),
                    ),
                  ),
                ),
                if (entry.isBalance)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: leadingSecondaryTop,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.subtitle ?? '',
                                key: ValueKey(
                                  'history-positions-secondary-$roleIndex',
                                ),
                                style: _historyRoleStyle(
                                  context,
                                  ReferenceTextRole.historyBalanceSecondary,
                                  ReferenceTextColorRole.secondary,
                                  TypographyVariantId.historyBalance,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(
                                  0,
                                  constraints.maxWidth - AppSpacing.xxs,
                                ),
                              ),
                              child: Text(
                                entry.time,
                                key: ValueKey(
                                  'history-positions-trailing-secondary-$roleIndex',
                                ),
                                style: _historyRoleStyle(
                                  context,
                                  ReferenceTextRole.historyBalanceSecondary,
                                  ReferenceTextColorRole.secondary,
                                  TypographyVariantId.historyBalance,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else ...[
                  Positioned(
                    left: 0,
                    top: leadingSecondaryTop,
                    child: MtPriceRangeText(
                      openPrice:
                          entry.openPrice?.toStringAsFixed(priceDigits) ?? '—',
                      closePrice:
                          entry.closePrice?.toStringAsFixed(priceDigits) ?? '—',
                      textKey: ValueKey(
                        'history-positions-secondary-$roleIndex',
                      ),
                      style: _historyRoleStyle(
                        context,
                        ReferenceTextRole.historyPriceRange,
                        ReferenceTextColorRole.secondary,
                        TypographyVariantId.historyPositions,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: trailingSecondaryTop,
                    child: Text(
                      entry.time,
                      key: ValueKey(
                        'history-positions-trailing-secondary-$roleIndex',
                      ),
                      style: _historyRoleStyle(
                        context,
                        ReferenceTextRole.historyTrailingSecondary,
                        ReferenceTextColorRole.secondary,
                        TypographyVariantId.historyPositions,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InlineSpan _historyActionSpan({
  required BuildContext context,
  required String text,
  required ReferenceTextColorRole colorRole,
  required TypographyVariantId variant,
  required Key key,
  bool inline = false,
}) {
  final style = _historyRoleStyle(
    context,
    ReferenceTextRole.historyAction,
    colorRole,
    variant,
  );
  if (inline) return TextSpan(text: text, style: style);
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Text(text, key: key, style: style),
  );
}

class _HistoryPrimaryPair extends StatelessWidget {
  const _HistoryPrimaryPair({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leading),
        const SizedBox(width: AppSpacing.xxs),
        trailing,
      ],
    );
  }
}

String _formatMoney(double value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring((end - 3).clamp(0, end), end));
  }
  return '${value < 0 ? '-' : ''}${groups.join(' ')}.${parts.last}';
}

class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.rows, required this.variant});

  final List<_HistorySummaryRow> rows;
  final TypographyVariantId variant;

  @override
  Widget build(BuildContext context) {
    final rowHeight = TabReferenceMetrics.historySummaryRowHeightFor(
      MediaQuery.textScalerOf(context),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 1.3333333333),
      child: Column(
        children: [
          for (final row in rows)
            SizedBox(
              key: ValueKey('history-summary-${row.keyId}'),
              height: rowHeight,
              child: Row(
                children: [
                  Expanded(child: _historySummaryLabel(context, row, variant)),
                  Expanded(
                    child: Text(
                      row.value,
                      key: row.keyId == 'Loi nhuan'
                          ? const Key('history-report-profit-value')
                          : ValueKey('history-summary-value-${row.keyId}'),
                      style: _historyRoleStyle(
                        context,
                        ReferenceTextRole.historySummaryValue,
                        ReferenceTextColorRole.primary,
                        variant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _historySummaryLabel(
  BuildContext context,
  _HistorySummaryRow row,
  TypographyVariantId variant,
) {
  return Text(
    row.label,
    key: ValueKey('history-summary-label-${row.keyId}'),
    style: _historyRoleStyle(
      context,
      row.keyId == 'Tong cong'
          ? ReferenceTextRole.historyOrderSummaryTotal
          : ReferenceTextRole.historySummary,
      ReferenceTextColorRole.primary,
      variant,
    ),
  );
}

class _DealDetailSheet extends StatelessWidget {
  const _DealDetailSheet({required this.deal, required this.onChart});

  final DemoDeal deal;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    final orderId = deal.orderId.isEmpty ? deal.id : deal.orderId;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5.3, 0, 5.3, 26),
        child: KeyedSubtree(
          key: ValueKey('history-deal-detail-${deal.id}'),
          child: Column(
            key: const Key('history-detail-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryDetailTicketHeader(
                symbol: deal.symbol,
                action: '${deal.side.toLowerCase()}, ${deal.entry}',
                ticket: deal.id,
              ),
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 4,
                      top: 9,
                      child: Text(
                        '${_historyVolumeLabel(deal.volume)} at '
                        '${deal.price.toStringAsFixed(_historyPriceDigitsForSymbol(deal.symbol))}',
                        style: _HistoryDetailStyles.value,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 40,
                      child: Text(deal.time, style: _HistoryDetailStyles.value),
                    ),
                    Positioned(
                      left: 4,
                      right: 4,
                      top: 69,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HistoryDetailPair(
                              label: 'Lệnh:',
                              value: displayTradingTicketId(orderId),
                              valueOffset: 80,
                            ),
                          ),
                          const Expanded(
                            child: _HistoryDetailPair(
                              label: 'Phí qua đêm:',
                              value: '-',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 4,
                      right: 4,
                      top: 91,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HistoryDetailPair(
                              label: 'Trạng thái:',
                              value: deal.status,
                              valueOffset: 80,
                            ),
                          ),
                          const Expanded(
                            child: _HistoryDetailPair(
                              label: 'Phí:',
                              value: '-',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _HistoryChartButton(onTap: onChart),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order, required this.onChart});

  final DemoOrder order;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5.3, 0, 5.3, 26),
        child: KeyedSubtree(
          key: ValueKey('history-order-detail-${order.id}'),
          child: Column(
            key: const Key('history-detail-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryDetailTicketHeader(
                symbol: order.symbol,
                action: _orderTypeLabel(order),
                ticket: order.id,
              ),
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 4,
                      right: 4,
                      top: 9,
                      child: Row(
                        children: [
                          Text(
                            _orderVolumeLabel(order),
                            style: _HistoryDetailStyles.value,
                          ),
                          const Spacer(),
                          Text(
                            order.status,
                            style: _HistoryDetailStyles.status,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 40,
                      child: Text(
                        order.time,
                        style: _HistoryDetailStyles.value,
                      ),
                    ),
                    const Positioned(
                      left: 4,
                      width: 146,
                      top: 69,
                      child: _HistoryDetailPair(label: 'S/L:', value: '-'),
                    ),
                    const Positioned(
                      left: 4,
                      width: 146,
                      top: 91,
                      child: _HistoryDetailPair(label: 'T/P:', value: '-'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _HistoryChartButton(onTap: onChart),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionHistoryDetailSheet extends StatelessWidget {
  const _PositionHistoryDetailSheet({
    required this.entry,
    required this.onChart,
  });

  final DemoHistoryPosition entry;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    final volume = entry.volume ?? 0;
    final volumeLabel = _historyVolumeLabel(volume);
    final priceDigits = _historyPriceDigitsForSymbol(entry.title);
    final side = entry.side?.toLowerCase() ?? '';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5.3, 0, 5.3, 26),
        child: KeyedSubtree(
          key: ValueKey('history-position-detail-${entry.id}'),
          child: Column(
            key: const Key('history-detail-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryDetailTicketHeader(
                symbol: entry.title,
                action: '$side $volumeLabel',
                ticket: entry.id,
              ),
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 4,
                      right: 4,
                      top: 9,
                      child: Row(
                        children: [
                          MtPriceRangeText(
                            openPrice:
                                entry.openPrice?.toStringAsFixed(priceDigits) ??
                                '—',
                            closePrice:
                                entry.closePrice?.toStringAsFixed(
                                  priceDigits,
                                ) ??
                                '—',
                            style: _HistoryDetailStyles.value,
                          ),
                          const Spacer(),
                          Text(
                            _formatMoney(entry.profit),
                            style: TextStyle(
                              color: entry.profit < 0
                                  ? AppColors.tradingNegativeText
                                  : AppColors.primary,
                              fontSize: 15.2,
                              height: 1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 40,
                      child: Text(
                        entry.time,
                        style: _HistoryDetailStyles.value,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      right: 4,
                      top: 69,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HistoryDetailPair(
                              label: 'Khối lượng:',
                              value: volumeLabel,
                            ),
                          ),
                          Expanded(
                            child: _HistoryDetailPair(
                              label: 'Trạng thái:',
                              value: 'đã đóng',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _HistoryChartButton(onTap: onChart),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailTicketHeader extends StatelessWidget {
  const _HistoryDetailTicketHeader({
    required this.symbol,
    required this.action,
    required this.ticket,
  });

  final String symbol;
  final String action;
  final String ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 6,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${displayTradingSymbol(symbol)} ',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: action,
                    style: TextStyle(color: _sideColor(action)),
                  ),
                ],
              ),
              key: const Key('history-detail-title'),
              style: const TextStyle(fontSize: 14.2, height: 1),
            ),
          ),
          Positioned(
            right: 4,
            top: 6,
            child: Text(
              '#${displayTradingTicketId(ticket)}',
              style: const TextStyle(
                color: AppColors.tradingSecondaryText,
                fontSize: 13.4,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 27,
            child: Text(
              _symbolDescription(symbol),
              style: const TextStyle(
                color: AppColors.tradingSecondaryText,
                fontSize: 13.4,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailPair extends StatelessWidget {
  const _HistoryDetailPair({
    required this.label,
    required this.value,
    this.valueOffset,
  });

  final String label;
  final String value;
  final double? valueOffset;

  @override
  Widget build(BuildContext context) {
    if (valueOffset case final offset?) {
      return SizedBox(
        height: 14,
        child: Stack(
          children: [
            Text(label, style: _HistoryDetailStyles.label),
            Positioned(
              left: offset,
              child: Text(value, style: _HistoryDetailStyles.label),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Text(label, style: _HistoryDetailStyles.label),
        const Spacer(),
        Text(value, style: _HistoryDetailStyles.label),
      ],
    );
  }
}

class _HistoryChartButton extends StatelessWidget {
  const _HistoryChartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: const Key('history-detail-chart'),
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: const SizedBox(
          height: 49,
          width: double.infinity,
          child: Center(
            child: Text(
              'Biểu đồ',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 17,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _HistoryDetailStyles {
  static const value = TextStyle(
    color: AppColors.tradingSecondaryText,
    fontSize: 15.2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const label = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 13.5,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const status = TextStyle(
    color: AppColors.primary,
    fontSize: 15.2,
    height: 1,
  );
}

class _HistoryChartPage extends StatelessWidget {
  const _HistoryChartPage({required this.symbol});

  final String symbol;

  static const _locations = [
    '/market',
    '/chart',
    '/trade',
    '/history',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ChartScreen(
        key: const Key('history-chart-screen'),
        symbol: symbol,
        initialTimeframe: 'D1',
      ),
      bottomNavigationBar: MtBottomNavigationBar(
        selectedIndex: 1,
        onTap: (index) {
          if (index == 1) return;
          if (index == 3) {
            Navigator.of(context, rootNavigator: true).maybePop();
            return;
          }
          context.go(_locations[index]);
        },
      ),
    );
  }
}

double _historyListTopPadding(BuildContext context) =>
    MediaQuery.paddingOf(context).top +
    TabReferenceMetrics.historyHeaderExtent +
    TabReferenceMetrics.historyListTopGap;

Color _sideColor(String side) =>
    side.toUpperCase().contains('SELL') || side.toLowerCase().contains('sell')
    ? AppColors.tradingNegativeText
    : AppColors.historyPositiveText;

String _orderTypeLabel(DemoOrder order) => order.type == 'Market'
    ? order.side.toLowerCase()
    : order.type.toLowerCase();

String _historyOrderStatusLabel(String status) =>
    status.toLowerCase() == 'canceled' ? 'Bi huy' : status;

String _orderVolumeLabel(DemoOrder order) =>
    '${_historyVolumeLabel(order.volume)} / '
    '${_historyVolumeLabel(order.status == 'filled' ? order.volume : 0)} '
    'at ${order.type == 'Market' ? 'market' : order.requestedPrice.toStringAsFixed(_historyPriceDigitsForSymbol(order.symbol))}';

String _symbolDescription(String symbol) => switch (symbol) {
  'XAUUSD' || 'XAUUSD+' => 'Gold US Dollar',
  _ => symbol,
};
