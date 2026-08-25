import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/chart/presentation/navigation/chart_navigation.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class SymbolSearchScreen extends ConsumerStatefulWidget {
  const SymbolSearchScreen({
    this.selectForChart = false,
    this.chartTimeframe,
    super.key,
  });

  final bool selectForChart;
  final String? chartTimeframe;

  @override
  ConsumerState<SymbolSearchScreen> createState() => _SymbolSearchScreenState();
}

class _SymbolSearchScreenState extends ConsumerState<SymbolSearchScreen> {
  final controller = TextEditingController();
  final Set<String> addedSymbols = <String>{};
  String query = '';
  String? category;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(demoQuotesProvider);
    final selected = ref.watch(marketSymbolsProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final candidates = quotes.where((quote) {
      final matchQuery =
          normalizedQuery.isEmpty ||
          quote.symbol.toLowerCase().contains(normalizedQuery) ||
          quote.name.toLowerCase().contains(normalizedQuery);
      final matchCategory =
          category == null || _folderCategoryOf(quote) == category;
      return matchQuery && matchCategory;
    }).toList();
    final filtered = normalizedQuery.isEmpty
        ? candidates
        : <DemoQuote>[
            ...candidates.where(
              (quote) => quote.symbol.toLowerCase().startsWith(normalizedQuery),
            ),
            ...candidates.where((quote) {
              final symbol = quote.symbol.toLowerCase();
              return !symbol.startsWith(normalizedQuery) &&
                  symbol.contains(normalizedQuery);
            }),
            ...candidates.where(
              (quote) => !quote.symbol.toLowerCase().contains(normalizedQuery),
            ),
          ];
    final quoteBySymbol = <String, DemoQuote>{
      for (final quote in quotes) quote.symbol: quote,
    };
    int selectedCount(String folder) => selected
        .map((symbol) => quoteBySymbol[symbol])
        .whereType<DemoQuote>()
        .where((quote) => _folderCategoryOf(quote) == folder)
        .length;
    final sections = _resultSections(filtered);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    hintText: category ?? 'Nhập cặp ngoại tệ để tìm kiếm',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (query.isNotEmpty)
                          IconButton(
                            key: const Key('symbol-search-clear'),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              controller.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(
                              CupertinoIcons.clear_circled_solid,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ),
                        IconButton(
                          key: const Key('symbol-search-close'),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            context.pop();
                          },
                          icon: const Icon(
                            CupertinoIcons.clear,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 34,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty && category == null
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _FolderRow(
                          label: 'Forex',
                          count: '${selectedCount('Forex')} / 126',
                          onTap: () => setState(() => category = 'Forex'),
                        ),
                        _FolderRow(
                          label: 'Metals',
                          count: '${selectedCount('Metals')} / 10',
                          onTap: () => setState(() => category = 'Metals'),
                        ),
                        _FolderRow(
                          label: 'Indexes',
                          count: '${selectedCount('Indexes')} / 26',
                          onTap: () => setState(() => category = 'Indexes'),
                        ),
                        _FolderRow(
                          label: 'Nasdaq',
                          count: '${selectedCount('Nasdaq')} / 12568',
                          onTap: () => setState(() => category = 'Nasdaq'),
                        ),
                      ],
                    )
                  : category != null
                  ? ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _resultRow(filtered[index], selected),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final section in sections) ...[
                          _ResultSectionHeader(label: section.label),
                          for (final quote in section.quotes)
                            _resultRow(quote, selected),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(DemoQuote quote, List<String> selected) {
    final exists = selected.contains(quote.symbol);
    return _SymbolResultRow(
      quote: quote,
      selected: exists,
      selectedThisSession: addedSymbols.contains(quote.symbol),
      selectForChart: widget.selectForChart,
      onInfo: () => _showSymbolInfo(quote),
      onOpenChart: widget.selectForChart
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              context.go(
                chartLocationForSymbol(
                  quote.symbol,
                  timeframe: widget.chartTimeframe,
                ),
              );
            }
          : null,
      onAdd: () {
        ref.read(marketSymbolsProvider.notifier).add(quote.symbol);
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => addedSymbols.add(quote.symbol));
      },
    );
  }

  void _showSymbolInfo(DemoQuote quote) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                displayTradingSymbol(quote.symbol),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                quote.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _SymbolInfoRow(
                label: 'Chào mua',
                value: quote.bid.toStringAsFixed(quote.bid >= 1000 ? 2 : 5),
              ),
              _SymbolInfoRow(
                label: 'Chào bán',
                value: quote.ask.toStringAsFixed(quote.ask >= 1000 ? 2 : 5),
              ),
              _SymbolInfoRow(
                label: 'Ngày %',
                value:
                    '${quote.changePercent >= 0 ? '+' : ''}'
                    '${quote.changePercent.toStringAsFixed(2)}%',
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ResultSection> _resultSections(List<DemoQuote> quotes) {
    const order = ['Nasdaq|Stock', 'Nasdaq|ETF', 'Metals', 'Forex', 'Indexes'];
    return [
      for (final label in order)
        if (quotes.any((quote) => _resultCategoryOf(quote) == label))
          _ResultSection(
            label: label,
            quotes: quotes
                .where((quote) => _resultCategoryOf(quote) == label)
                .toList(),
          ),
    ];
  }

  String _folderCategoryOf(DemoQuote quote) {
    final resultCategory = _resultCategoryOf(quote);
    if (resultCategory.startsWith('Nasdaq|')) return 'Nasdaq';
    return resultCategory;
  }

  String _resultCategoryOf(DemoQuote quote) {
    if (quote.symbol == 'XAUG') return 'Nasdaq|ETF';
    if (_nasdaqStockSymbols.contains(quote.symbol) ||
        quote.symbol == 'BTCUSD') {
      return 'Nasdaq|Stock';
    }
    if (quote.symbol.startsWith('XAU')) return 'Metals';
    if (quote.symbol == 'US30') return 'Indexes';
    return 'Forex';
  }
}

const _nasdaqStockSymbols = <String>{
  'C',
  'CC',
  'CE',
  'CF',
  'CG',
  'CI',
  'CL',
  'CM',
  'XP',
  'XE',
  'XBP',
  'XEL',
  'XGN',
  'XHR',
  'XLO',
  'XOM',
  'U',
  'UE',
  'UG',
  'UI',
  'UK',
  'UP',
  'UA',
  'UL',
  'USA',
  'USB',
  'USAS',
  'USAU',
  'USEA',
  'USFD',
  'USGO',
  'USIO',
  'USLM',
  'USPH',
  'USNA',
  'USCB',
};

class _ResultSection {
  const _ResultSection({required this.label, required this.quotes});

  final String label;
  final List<DemoQuote> quotes;
}

class _ResultSectionHeader extends StatelessWidget {
  const _ResultSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 31,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 0, 0),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ),
  );
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.folder,
              color: Color(0xFFD69A22),
              size: 18,
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              count,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SymbolResultRow extends StatelessWidget {
  const _SymbolResultRow({
    required this.quote,
    required this.selected,
    required this.selectedThisSession,
    required this.selectForChart,
    required this.onAdd,
    required this.onInfo,
    required this.onOpenChart,
  });

  final DemoQuote quote;
  final bool selected;
  final bool selectedThisSession;
  final bool selectForChart;
  final VoidCallback onAdd;
  final VoidCallback onInfo;
  final VoidCallback? onOpenChart;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey(
      selectForChart
          ? 'symbol-chart-${quote.symbol}'
          : 'symbol-result-${quote.symbol}',
    ),
    onTap: selectForChart ? onOpenChart : (selected ? null : onAdd),
    child: SizedBox(
      height: 51,
      child: Row(
        children: [
          IconButton(
            onPressed: selectForChart ? onOpenChart : (selected ? null : onAdd),
            icon: Icon(
              selectForChart
                  ? Icons.candlestick_chart
                  : selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selectForChart
                  ? AppColors.primary
                  : selected && !selectedThisSession
                  ? AppColors.textSecondary
                  : AppColors.primary,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTradingSymbol(quote.symbol),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.7,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  quote.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.4,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('symbol-info-${quote.symbol}'),
            padding: const EdgeInsets.only(right: 11),
            onPressed: onInfo,
            icon: const Icon(
              CupertinoIcons.info_circle,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SymbolInfoRow extends StatelessWidget {
  const _SymbolInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
