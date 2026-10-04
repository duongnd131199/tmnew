import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Local, repeatable market snapshot used to preview the recorded interface.
/// No value in this widget is submitted to an order or treated as a live quote.
class VideoTradingScreen extends StatefulWidget {
  const VideoTradingScreen({super.key});

  @override
  State<VideoTradingScreen> createState() => _VideoTradingScreenState();
}

class _VideoTradingScreenState extends State<VideoTradingScreen> {
  final searchController = TextEditingController();
  final favorites = <String>['BTCUSD', 'XAUUSD+', 'ETHUSD'];
  var selectedCategory = 0;
  var searching = false;
  var editing = false;
  var query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        (selectedCategory == 0
                ? favorites
                : const ['BTCUSD', 'XAUUSD+', 'ETHUSD'])
            .where((symbol) {
              final item = _demoQuotes[symbol]!;
              return query.isEmpty ||
                  item.label.toLowerCase().contains(query.toLowerCase()) ||
                  item.description.toLowerCase().contains(query.toLowerCase());
            })
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
                child: const Text('0,00 USD ⋮'),
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
          padding: const EdgeInsets.fromLTRB(19, 0, 16, 7),
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
                    _VideoCategoryTab(
                      label: 'Mục yêu thích ⭐',
                      selected: selectedCategory == 0,
                      onTap: () => setState(() => selectedCategory = 0),
                    ),
                    _VideoCategoryTab(
                      label: 'Được giao dịch nhiều nhất',
                      leadingInset: 10,
                      selected: selectedCategory == 1,
                      onTap: () => setState(() => selectedCategory = 1),
                    ),
                    _VideoCategoryTab(
                      label: 'Đề xuất',
                      leadingInset: 10,
                      selected: selectedCategory == 2,
                      onTap: () => setState(() => selectedCategory = 2),
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
            child: ListView(
              padding: const EdgeInsets.only(top: 3),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 3),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _VideoChip(
                        label: 'Sắp xếp thủ công',
                        onTap: () => setState(() => editing = true),
                      ),
                      _VideoChip(
                        label: editing ? 'Xong' : 'Chỉnh sửa ✎',
                        onTap: () => setState(() => editing = !editing),
                      ),
                    ],
                  ),
                ),
                for (final symbol in visible)
                  _VideoQuoteRow(
                    quote: _demoQuotes[symbol]!,
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
                if (visible.isEmpty)
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
      ],
    );
  }
}

class _VideoCategoryTab extends StatelessWidget {
  const _VideoCategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingInset = 15,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double leadingInset;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 40,
      margin: EdgeInsets.only(left: leadingInset),
      padding: const EdgeInsets.only(left: 10, right: 6),
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

class _VideoChip extends StatelessWidget {
  const _VideoChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );
}

class _DemoQuote {
  const _DemoQuote({
    required this.symbol,
    required this.label,
    required this.description,
    required this.price,
    required this.change,
    required this.sparkline,
    required this.sparkEnd,
    required this.sparkGuide,
  });
  final String symbol;
  final String label;
  final String description;
  final String price;
  final String change;
  final List<double> sparkline;
  final double sparkEnd;
  final double sparkGuide;
}

const _demoQuotes = <String, _DemoQuote>{
  'BTCUSD': _DemoQuote(
    symbol: 'BTCUSD',
    label: 'BTC',
    description: 'Bitcoin vs US Dollar',
    price: '81.424,77',
    change: '0,67%',
    sparkline: [.04, .14, .25, .29, .29, .21, .18],
    sparkEnd: .4,
    sparkGuide: .32,
  ),
  'XAUUSD+': _DemoQuote(
    symbol: 'XAUUSD+',
    label: 'XAU/USD',
    description: 'Gold vs US Dollar',
    price: '4.378,101',
    change: '0,74%',
    sparkline: [
      .25,
      .29,
      .29,
      .18,
      .04,
      .02,
      .07,
      .11,
      .07,
      .18,
      .21,
      .25,
      .14,
      .02,
      .07,
      .11,
    ],
    sparkEnd: 1,
    sparkGuide: .29,
  ),
  'ETHUSD': _DemoQuote(
    symbol: 'ETHUSD',
    label: 'ETH',
    description: 'Ethereum vs US Dollar',
    price: '2.649,81',
    change: '1,47%',
    sparkline: [.25, .29, .21, .18, .14, .07, .07],
    sparkEnd: .4,
    sparkGuide: .28,
  ),
};

class _VideoQuoteRow extends StatelessWidget {
  const _VideoQuoteRow({
    required this.quote,
    required this.editing,
    required this.favorite,
    required this.onFavorite,
    required this.onMoveUp,
  });
  final _DemoQuote quote;
  final bool editing;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onMoveUp;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: editing
        ? onFavorite
        : () => context.push('/chart/${Uri.encodeComponent(quote.symbol)}'),
    child: Container(
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (editing)
            IconButton(
              icon: Icon(favorite ? Icons.star : Icons.star_border),
              onPressed: onFavorite,
            )
          else
            _VideoSymbolIcon(symbol: quote.symbol),
          const SizedBox(width: 6),
          Expanded(
            flex: 7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quote.description,
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
              flex: 4,
              child: SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: _VideoSparklinePainter(
                    quote.sparkline,
                    quote.sparkEnd,
                    quote.sparkGuide,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(quote.price, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '↑ ${quote.change}',
                    style: const TextStyle(fontSize: 12, color: AppColors.blue),
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

class _VideoSymbolIcon extends StatelessWidget {
  const _VideoSymbolIcon({required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    if (symbol == 'BTCUSD') {
      return const CircleAvatar(
        radius: 10,
        backgroundColor: AppColors.bitcoin,
        child: Text(
          '₿',
          style: TextStyle(color: AppColors.background, fontSize: 14),
        ),
      );
    }
    if (symbol == 'ETHUSD') {
      return const CircleAvatar(
        radius: 10,
        backgroundColor: AppColors.muted,
        child: SizedBox(
          width: 11,
          height: 16,
          child: CustomPaint(painter: _EthereumPainter()),
        ),
      );
    }
    return const SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.muted,
            child: Text(
              '●',
              style: TextStyle(color: AppColors.bronzeEnd, fontSize: 14),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Text('🇺🇸', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _EthereumPainter extends CustomPainter {
  const _EthereumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * .53)
      ..lineTo(size.width / 2, size.height * .67)
      ..lineTo(0, size.height * .53)
      ..close();
    canvas.drawPath(top, Paint()..color = AppColors.ethereum);
    final bottom = Path()
      ..moveTo(0, size.height * .64)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, size.height * .64)
      ..lineTo(size.width / 2, size.height * .79)
      ..close();
    canvas.drawPath(bottom, Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant _EthereumPainter oldDelegate) => false;
}

class _VideoSparklinePainter extends CustomPainter {
  const _VideoSparklinePainter(this.values, this.end, this.guide);
  final List<double> values;
  final double end;
  final double guide;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()..color = AppColors.border;
    canvas.drawLine(
      Offset(3, size.height * guide),
      Offset(size.width, size.height * guide),
      guidePaint,
    );
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = 3 + (size.width - 3) * end * i / (values.length - 1);
      final y = size.height * values[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.end != end ||
      oldDelegate.guide != guide;
}
