import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/config/video_demo_mode.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import 'video_trading_screen.dart';

import 'package:exness/features/trading/data/market_api.dart';

class TradingScreen extends ConsumerStatefulWidget {
  const TradingScreen({super.key});

  @override
  ConsumerState<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends ConsumerState<TradingScreen> {
  final searchController = TextEditingController();
  final favorites = <String>['BTCUSD', 'XAUUSD+', 'ETHUSD'];
  int category = 0;
  bool searching = false;
  bool editing = false;
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(videoDemoModeProvider)) {
      return const VideoTradingScreen();
    }
    final account = ref.watch(accountSessionProvider).value;
    final feed = ref.watch(
      marketQuotesProvider.select(
        (value) => (
          value.value?.quotes.map((quote) => quote.symbol).join('|') ?? '',
          value.value?.status,
          value.value?.loadError ?? false,
          value.isLoading,
          value.hasError,
        ),
      ),
    );
    final quoteSymbols = feed.$1.isEmpty ? <String>[] : feed.$1.split('|');
    final ordered = category == 0
        ? favorites
        : category == 1
        ? ['BTCUSD', 'XAUUSD+', 'ETHUSD', ...quoteSymbols]
        : quoteSymbols;
    final symbols = <String>{...ordered}
        .where(
          (symbol) =>
              query.isEmpty ||
              marketLabel(symbol).toLowerCase().contains(query.toLowerCase()) ||
              symbol.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    return Column(
      key: const Key('trading-screen'),
      children: [
        SizedBox(
          height: 49,
          child: Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.go('/account'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(115, 31),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  account == null
                      ? '-- USD ⋮'
                      : '${formatMoney(account.summary.balance, account.summary.currency)} ⋮',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.go('/account'),
                icon: const Icon(Icons.alarm_outlined, size: 21),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 0, 16, 11),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Giao dịch',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Tìm công cụ giao dịch',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    searching = false;
                    query = '';
                    searchController.clear();
                  }),
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryTab(
                      label: 'Mục yêu thích ⭐',
                      selected: category == 0,
                      onTap: () => setState(() => category = 0),
                    ),
                    _CategoryTab(
                      label: 'Được giao dịch nhiều nhất',
                      selected: category == 1,
                      onTap: () => setState(() => category = 1),
                    ),
                    _CategoryTab(
                      label: 'Đề xuất',
                      selected: category == 2,
                      onTap: () => setState(() => category = 2),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('trading-search'),
                onPressed: () => setState(() {
                  searching = !searching;
                  if (!searching) {
                    query = '';
                    searchController.clear();
                  }
                }),
                icon: const Icon(Icons.search, size: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.canvas,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(marketQuotesProvider);
                for (final symbol in symbols) {
                  ref.invalidate(marketCandlesProvider((symbol, 'M1')));
                }
                await ref.read(marketQuotesProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 5),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(
                          label: 'Sắp xếp thủ công',
                          onTap: () => setState(() => editing = true),
                        ),
                        _SmallChip(
                          label: editing ? 'Xong' : 'Chỉnh sửa ✎',
                          onTap: () => setState(() => editing = !editing),
                        ),
                      ],
                    ),
                  ),
                  if (feed.$3 || feed.$5)
                    const Padding(
                      padding: EdgeInsets.all(15),
                      child: Text(
                        'Không thể cập nhật giá. Kéo xuống để thử lại.',
                      ),
                    ),
                  if (feed.$4 && quoteSymbols.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(15, 3, 15, 8),
                      child: Text('Đang tải giá thị trường…'),
                    ),
                  if (feed.$2 == MarketFeedStatus.reconnecting ||
                      feed.$2 == MarketFeedStatus.disconnected)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(15, 3, 15, 8),
                      child: Text('Đang kết nối lại dữ liệu giá…'),
                    ),
                  for (final symbol in symbols)
                    _QuoteRow(
                      symbol: symbol,
                      editing: editing,
                      favorite: favorites.contains(symbol),
                      onFavorite: () => setState(() {
                        favorites.contains(symbol)
                            ? favorites.remove(symbol)
                            : favorites.add(symbol);
                      }),
                      onMoveUp: () => setState(() {
                        final index = favorites.indexOf(symbol);
                        if (index > 0) {
                          favorites.removeAt(index);
                          favorites.insert(index - 1, symbol);
                        }
                      }),
                    ),
                  if (symbols.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('Không tìm thấy công cụ giao dịch'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(left: 15),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _QuoteRow extends ConsumerWidget {
  const _QuoteRow({
    required this.symbol,
    required this.editing,
    required this.favorite,
    required this.onFavorite,
    required this.onMoveUp,
  });

  final String symbol;
  final bool editing;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onMoveUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(
      marketQuotesProvider.select(
        (value) => (
          value.value?.quoteFor(symbol),
          value.value?.isStale(symbol) ?? false,
        ),
      ),
    );
    final quote = price.$1;
    final stale = price.$2;
    final candles = ref.watch(marketCandlesProvider((symbol, 'M1'))).value;
    final last = candles == null || candles.isEmpty ? null : candles.last;
    final previous = candles == null || candles.length < 2
        ? null
        : candles[candles.length - 2];
    final change =
        stale || quote == null || previous == null || previous.close == 0
        ? null
        : (quote.bid - previous.close) / previous.close * 100;
    return InkWell(
      onTap: editing
          ? onFavorite
          : () => context.push('/chart/${Uri.encodeComponent(symbol)}'),
      child: Container(
        height: 67,
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (editing)
              IconButton(
                icon: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  color: favorite ? AppColors.accent : AppColors.textSecondary,
                ),
                onPressed: onFavorite,
              )
            else
              _SymbolIcon(symbol: symbol),
            const SizedBox(width: 6),
            Expanded(
              flex: 7,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marketLabel(symbol),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (symbol) {
                      'BTCUSD' => 'Bitcoin vs US Dollar',
                      'XAUUSD+' => 'Gold vs US Dollar',
                      'ETHUSD' => 'Ethereum vs US Dollar',
                      _ => symbol,
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!editing) ...[
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values:
                          candles?.map((c) => c.close).toList() ??
                          (last == null ? [] : [last.close]),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      quote == null || stale
                          ? '--'
                          : formatNumber(
                              quote.bid,
                              decimals: symbol == 'XAUUSD+' ? 3 : 2,
                            ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stale
                          ? 'Giá cũ'
                          : change == null
                          ? '--'
                          : '${change >= 0 ? '↑' : '↓'} ${formatNumber(change.abs())}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: change == null || change >= 0
                            ? AppColors.blue
                            : AppColors.negative,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: onMoveUp,
              ),
          ],
        ),
      ),
    );
  }
}

class _SymbolIcon extends StatelessWidget {
  const _SymbolIcon({required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 23,
      height: 23,
      child: Center(
        child: Text(
          symbol == 'BTCUSD'
              ? '₿'
              : symbol == 'ETHUSD'
              ? '◆'
              : '🌐',
          style: TextStyle(
            fontSize: symbol == 'BTCUSD' ? 20 : 17,
            color: symbol == 'BTCUSD'
                ? Colors.orange
                : symbol == 'ETHUSD'
                ? const Color(0xFF454A52)
                : AppColors.blue,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()..color = AppColors.border;
    canvas.drawLine(
      Offset(0, size.height * .6),
      Offset(size.width, size.height * .6),
      guide,
    );
    if (values.length < 2) return;
    final subset = values.length > 28
        ? values.sublist(values.length - 28)
        : values;
    final min = subset.reduce((a, b) => a < b ? a : b);
    final max = subset.reduce((a, b) => a > b ? a : b);
    final span = max - min == 0 ? 1.0 : max - min;
    final path = Path();
    for (var i = 0; i < subset.length; i++) {
      final x = size.width * i / (subset.length - 1);
      final y = size.height * (.84 - .68 * (subset[i] - min) / span);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
