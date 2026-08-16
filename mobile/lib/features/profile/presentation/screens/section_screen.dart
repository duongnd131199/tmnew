import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final symbol = title.split(' ').last;
    if (title.startsWith('Thuộc tính ') || title.startsWith('Chi tiết ')) {
      return _SymbolPropertiesScreen(title: title, symbol: symbol);
    }
    if (title.startsWith('Depth of Market')) {
      return _DepthOfMarketScreen(title: title, symbol: symbol);
    }
    if (title.startsWith('Thống kê ')) {
      return _MarketStatisticsScreen(title: title, symbol: symbol);
    }

    final items = switch (title) {
      'Tin tức' => [
        'Tin thị trường mới nhất',
        'Phân tích tiền tệ',
        'Thông báo kinh tế',
      ],
      'Nhật ký' => [
        'Ứng dụng đã khởi động',
        'Đã kết nối tài khoản demo',
        'Luồng báo giá hoạt động',
      ],
      'Lịch kinh tế' => [
        'USD · Doanh số bán lẻ',
        'EUR · CPI',
        'GBP · Quyết định lãi suất',
      ],
      'Cộng đồng trader' => ['Tín hiệu', 'Bài viết', 'Nhóm giao dịch'],
      'MQL5 Algo Trading' => ['Expert Advisors', 'Indicators', 'Scripts'],
      _ => ['Nội dung hướng dẫn', 'Thông tin ứng dụng', 'Trợ giúp và hỗ trợ'],
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(
          title: Text(items[index]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[index],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nội dung demo đã sẵn sàng và có thể mở từ hàng này.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SymbolPropertiesScreen extends ConsumerWidget {
  const _SymbolPropertiesScreen({required this.title, required this.symbol});

  final String title;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGold = symbol.startsWith('XAUUSD');
    final accounts = ref.watch(demoAccountsProvider);
    final activeAccountId = ref.watch(activeDemoAccountIdProvider);
    final account = accounts
        .where((candidate) => candidate.id == activeAccountId)
        .firstOrNull;
    final priceSource = account?.company ?? accounts.firstOrNull?.company;
    final displayPriceSource = priceSource == null || priceSource.trim().isEmpty
        ? '—'
        : priceSource;
    final rows = <(String, String)>[
      (isGold ? 'Gold US Dollar' : _symbolName(symbol), ''),
      ('Chu so', isGold ? '2' : '5'),
      ('Kich thuoc hop dong', isGold ? '100' : '1'),
      ('Spread', 'tha noi'),
      ('Muc dat lenh Stops', isGold ? '20' : '0'),
      ('Tien te ky quy', 'USD'),
      ('Loai tien cho loi nhuan', 'USD'),
      ('Phep tinh', 'Don bay cho hop dong'),
      ('Kich co tick', isGold ? '0.00' : '0.01'),
      ('Gia tri tick', '0'),
      ('Che do bieu do', 'Boi gia mua'),
      ('Giao dich', 'Toan quyen truy cap'),
      ('Thuc thi', 'Vao lenh thi truong'),
      ('Che do GTC', 'Good till cancelled'),
      ('Fill Policy', 'Ngay hoac Huy Bo'),
      ('Het han', 'GTC, Hom nay, Duoc xac nhan'),
      ('Cac lenh', 'Tat ca'),
      ('Khoi luong giao dich nho nhat', '0.01'),
      ('Maximal volume', isGold ? '100' : '10'),
      ('Buoc khoi luong', '0.01'),
      ('Gioi han khoi luong', '0.00'),
      ('Loai Swap', 'Theo diem'),
      ('Swap lenh mua', '—'),
      ('Swap lenh ban', '—'),
      ('Phi Swap gap ba', 'Thu Tu'),
      ('Ky quy ban dau', '0.00'),
      ('Ky quy duy tri', '0.00'),
      ('Ky quy phong toa', '—'),
      ('Ty le ky quy', '—'),
      ('Phien bao gia', ''),
      ('Thu Hai', '01:00 - 23:59'),
      ('Thu Ba', '01:00 - 23:59'),
      ('Thu Tu', '01:00 - 23:59'),
      ('Thu Nam', '01:00 - 23:59'),
      ('Thu Sau', '01:00 - 23:59'),
      ('Phien giao dich', ''),
      ('Thu Hai', '01:00 - 23:59'),
      ('Thu Ba', '01:00 - 23:59'),
      ('Thu Tu', '01:00 - 23:59'),
      ('Thu Nam', '01:00 - 23:59'),
      ('Thu Sau', '01:00 - 23:59'),
      ('Nguon gia', displayPriceSource),
      ('Danh muc', 'Metals'),
      ('San giao dich', 'OTC'),
      ('Trang web', ''),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 81,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 37,
                    child: Material(
                      color: const Color(0xFF171719),
                      shape: const CircleBorder(
                        side: BorderSide(color: AppColors.divider, width: .6),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(context),
                        child: SizedBox.square(
                          dimension: 42,
                          child: Transform.translate(
                            offset: const Offset(-.3333333333, .3333333333),
                            child: const Icon(
                              Icons.close,
                              color: AppColors.textPrimary,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 75,
                    right: 75,
                    top: 49,
                    child: Text(
                      symbol,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'sans-serif',
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RawScrollbar(
                radius: const Radius.circular(2),
                thickness: 2.6666666667,
                mainAxisMargin: 12,
                crossAxisMargin: .6666666667,
                thumbColor: const Color(0xFF767678),
                thumbVisibility: true,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    15.3333333333,
                    32.6666666667,
                    13.3333333333,
                    28,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Transform.scale(
                          scaleX: 1.01,
                          scaleY: .875,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            rows[index].$1,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 21.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 38.28,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Transform.scale(
                              scaleX: .985,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                rows[index].$1,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontFamily: 'sans-serif',
                                  fontSize: 17,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 270),
                            child: Transform.translate(
                              offset: const Offset(0, -2.5),
                              child: Text(
                                rows[index].$2,
                                key: _symbolPropertyValueKey(rows[index].$1),
                                maxLines: 2,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontFamily: 'sans-serif',
                                  fontSize: 18.6666666667,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepthOfMarketScreen extends ConsumerStatefulWidget {
  const _DepthOfMarketScreen({required this.title, required this.symbol});

  final String title;
  final String symbol;

  @override
  ConsumerState<_DepthOfMarketScreen> createState() =>
      _DepthOfMarketScreenState();
}

class _DepthOfMarketScreenState extends ConsumerState<_DepthOfMarketScreen> {
  double volume = .01;

  @override
  Widget build(BuildContext context) {
    final fallbackQuote = _symbolQuote(widget.symbol);
    final liveQuote = ref.watch(demoQuoteProvider(widget.symbol)).value;
    final quote = (
      liveQuote?.bid ?? fallbackQuote.$1,
      liveQuote?.ask ?? fallbackQuote.$2,
    );
    final step = widget.symbol.startsWith('XAUUSD') ? .05 : .0001;
    final maximalVolume = widget.symbol.startsWith('XAUUSD') ? 100.0 : 10.0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => volume = (volume - .01).clamp(.01, maximalVolume),
                  ),
                  icon: const Icon(Icons.remove, color: AppColors.primary),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('dom-volume-field'),
                    onTap: () => _editVolume(maximalVolume),
                    child: Center(
                      child: Text(
                        volume.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => volume = (volume + .01).clamp(.01, maximalVolume),
                  ),
                  icon: const Icon(Icons.add, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 14,
              itemBuilder: (context, index) {
                final sell = index < 7;
                final distance = sell ? 7 - index : index - 6;
                final price = sell
                    ? quote.$2 + step * distance
                    : quote.$1 - step * distance;
                final color = sell ? AppColors.negative : AppColors.primary;
                return InkWell(
                  key: ValueKey('dom-level-$index'),
                  onTap: () => _placePendingOrder(sell: sell, price: price),
                  child: SizedBox(
                    height: 45,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            '${(index + 1) * 3}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatPrice(price),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: color, fontSize: 18),
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: Text(
                            '${(14 - index) * 2}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editVolume(double maximalVolume) async {
    var input = volume.toStringAsFixed(2);
    final nextVolume = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khối lượng'),
        content: TextFormField(
          key: const Key('dom-volume-input'),
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d{0,3}([.,]\d{0,2})?'),
            ),
          ],
          onChanged: (value) => input = value,
          onFieldSubmitted: (_) =>
              _submitVolume(dialogContext, input, maximalVolume),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('HỦY'),
          ),
          TextButton(
            key: const Key('dom-volume-confirm'),
            onPressed: () => _submitVolume(dialogContext, input, maximalVolume),
            child: const Text('XONG'),
          ),
        ],
      ),
    );
    if (!mounted || nextVolume == null) return;
    setState(() => volume = nextVolume);
  }

  void _submitVolume(
    BuildContext dialogContext,
    String rawValue,
    double maximalVolume,
  ) {
    final parsed = double.tryParse(rawValue.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    Navigator.pop(dialogContext, parsed.clamp(.01, maximalVolume));
  }

  void _placePendingOrder({required bool sell, required double price}) {
    final type = sell ? 'Sell Limit' : 'Buy Limit';
    ref
        .read(demoTradingProvider.notifier)
        .placePendingOrder(
          symbol: widget.symbol,
          type: type,
          volume: volume,
          price: price,
        );
  }
}

class _MarketStatisticsScreen extends ConsumerWidget {
  const _MarketStatisticsScreen({required this.title, required this.symbol});

  final String title;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackQuote = _symbolQuote(symbol);
    final liveQuote = ref.watch(demoQuoteProvider(symbol)).value;
    final quote = (
      liveQuote?.bid ?? fallbackQuote.$1,
      liveQuote?.ask ?? fallbackQuote.$2,
    );
    final rows = <(String, String)>[
      ('Giá mua', _formatPrice(quote.$1)),
      ('Giá bán', _formatPrice(quote.$2)),
      ('Giá cuối', '—'),
      ('Giá mở cửa', '—'),
      ('Giá cao nhất', '—'),
      ('Giá thấp nhất', '—'),
      ('Khối lượng', '—'),
      ('Số tick', '—'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(
          title: Text(
            rows[index].$1,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Text(rows[index].$2, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

Key? _symbolPropertyValueKey(String label) => switch (label) {
  'Swap lenh mua' => const Key('symbol-property-swap-long-value'),
  'Swap lenh ban' => const Key('symbol-property-swap-short-value'),
  'Ky quy phong toa' => const Key('symbol-property-blocked-margin-value'),
  'Ty le ky quy' => const Key('symbol-property-margin-rate-value'),
  'Nguon gia' => const Key('symbol-property-price-source-value'),
  _ => null,
};

(double, double) _symbolQuote(String symbol) => switch (symbol) {
  'XAUUSD' || 'XAUUSD+' => (2000.00, 2000.20),
  'BTCUSD' => (60000.00, 60010.00),
  'AUDNOK' => (6.83496, 6.83643),
  'USA' => (5.83, 5.84),
  _ => (1.08425, 1.08437),
};

String _symbolName(String symbol) => switch (symbol) {
  'XAUUSD' || 'XAUUSD+' => 'Gold US Dollar',
  'BTCUSD' => 'Bitcoin',
  'AUDNOK' => 'Australian Dollar vs Norwegian Krona',
  'USA' => 'Liberty All-Star Equity Fund',
  _ => symbol,
};

String _formatPrice(double price) {
  if (price >= 1000) return price.toStringAsFixed(2);
  if (price >= 100) return price.toStringAsFixed(3);
  return price.toStringAsFixed(5);
}
