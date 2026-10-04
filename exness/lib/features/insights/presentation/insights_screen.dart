import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/video_demo_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../account/data/account_session.dart';
import '../../trading/data/market_api.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(videoDemoModeProvider)) {
      return const _VideoInsightsScreen();
    }
    final account = ref.watch(accountSessionProvider).value;
    final feed = ref.watch(
      marketQuotesProvider.select(
        (value) => (
          value.value?.quotes.map((quote) => quote.symbol).join('|') ?? '',
          value.value?.status,
          value.value?.loadError ?? false,
          value.hasError,
          value.isLoading,
        ),
      ),
    );
    final symbols = feed.$1.isEmpty ? <String>{} : feed.$1.split('|').toSet();
    final top = const [
      'BTCUSD',
      'XAUUSD+',
      'ETHUSD',
    ].where(symbols.contains).toList();
    return Column(
      key: const Key('insights-screen'),
      children: [
        SizedBox(
          height: 49,
          child: Center(
            child: OutlinedButton(
              onPressed: () => context.go('/account'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(115, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: AppColors.textPrimary,
              ),
              child: Text(
                account == null
                    ? '-- USD ⋮'
                    : '${formatMoney(account.summary.balance, account.summary.currency)} ⋮',
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 1, 10, 13),
                child: Text(
                  'Thông tin chuyên sâu',
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
                ),
              ),
              _SectionHeading(
                title: 'ĐỀ XUẤT HÀNG ĐẦU',
                onMore: () => context.go('/trading'),
              ),
              SizedBox(
                height: 125,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: [
                    for (final symbol in top) _TopQuoteCard(symbol: symbol),
                    if (top.isEmpty)
                      Center(
                        child: Text(
                          feed.$3 || feed.$4
                              ? 'Không thể tải giá thị trường'
                              : feed.$2 == MarketFeedStatus.reconnecting ||
                                    feed.$2 == MarketFeedStatus.disconnected
                              ? 'Đang kết nối lại dữ liệu giá…'
                              : feed.$5
                              ? 'Đang tải giá thị trường…'
                              : 'Chưa có giá thị trường',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'TÍN HIỆU GIAO DỊCH',
                onMore: () => _showMissingFeed(context, 'Tín hiệu giao dịch'),
              ),
              const _FeedPlaceholder(
                icon: Icons.show_chart,
                title: 'Chưa có dữ liệu tín hiệu giao dịch',
                subtitle: 'Nguồn API hiện tại chưa cung cấp tín hiệu.',
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'NHỮNG SỰ KIỆN SẮP TỚI',
                onMore: () => _showMissingFeed(context, 'Sự kiện sắp tới'),
              ),
              const _FeedPlaceholder(
                icon: Icons.event_outlined,
                title: 'Chưa có dữ liệu sự kiện',
                subtitle: 'Lịch kinh tế sẽ xuất hiện khi có nguồn dữ liệu.',
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'TIN TỨC PHỔ BIẾN',
                onMore: () => _showMissingFeed(context, 'Tin tức phổ biến'),
              ),
              const _FeedPlaceholder(
                icon: Icons.article_outlined,
                title: 'Chưa có tin tức',
                subtitle: 'Nguồn API hiện tại chưa cung cấp bản tin.',
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ],
    );
  }
}

void _showMissingFeed(BuildContext context, String title) {
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: ExEmptyState(
            title: 'Chưa có dữ liệu',
            subtitle: 'Mục này cần nguồn dữ liệu từ API.',
          ),
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.onMore});
  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          InkWell(
            onTap: onMore,
            child: const Text(
              'Hiển thị thêm',
              style: TextStyle(fontSize: 12, color: AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopQuoteCard extends ConsumerWidget {
  const _TopQuoteCard({required this.symbol});
  final String symbol;

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
    return InkWell(
      onTap: () => context.push('/chart/${Uri.encodeComponent(symbol)}'),
      child: Container(
        width: 108,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marketLabel(symbol),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 17),
            Container(
              height: 22,
              alignment: Alignment.center,
              child: const Icon(
                Icons.show_chart,
                color: AppColors.blue,
                size: 55,
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                quote == null
                    ? '--'
                    : stale
                    ? 'Giá cũ'
                    : formatNumber(
                        quote.bid,
                        decimals: symbol == 'XAUUSD+' ? 3 : 2,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 135),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 27, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// A self-contained rendering of the account preview recorded in the supplied
// video. The live feed above remains available when videoDemoModeProvider is
// overridden with false; none of these preview values enter account state.
class _VideoInsightsScreen extends StatelessWidget {
  const _VideoInsightsScreen();

  static const _symbols = <_VideoSymbol>[
    _VideoSymbol('XPD/USD', '1.301,08', '1,02%', '🇺🇸', '●'),
    _VideoSymbol('XAG/USD', '66,260', '1,29%', '🇺🇸', '●'),
    _VideoSymbol('BTC/JPY', '12.776.275', '0,69%', '🇯🇵', '₿'),
    _VideoSymbol('XAU/USD', '4.378,101', '0,74%', '🇺🇸', '●'),
  ];

  static const _signals = <_VideoSignal>[
    _VideoSignal(
      'US30 Ngắn hạn: sự củng cố trong ngắn hạn.',
      '05:08',
      '06:05',
      false,
    ),
    _VideoSignal(
      'USTEC Ngắn hạn: xu hướng tăng trên mức tỷ giá 28',
      '03:40',
      '03:40',
      true,
    ),
  ];

  static const _events = <_VideoEvent>[
    _VideoEvent('🇷🇺', 'RU', 'Bầu cử Quốc hội', '07:00:00 Ngày mai', false),
    _VideoEvent(
      '🇯🇵',
      'JP',
      'Tôn trọng Ngày cao niên',
      '07:00:00 Ngày kia',
      false,
    ),
    _VideoEvent(
      '🇨🇳',
      'CN',
      'Lãi suất cho vay ưu đãi 1 năm',
      '08:15:00 Ngày kia',
      true,
    ),
  ];

  double _scale(BuildContext context) => MediaQuery.sizeOf(context).width / 384;

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return Column(
      key: const Key('insights-screen'),
      children: [
        SizedBox(
          height: 49 * s,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, -3 * s),
              child: SizedBox(
                width: 116 * s,
                child: InkWell(
                  key: const Key('insights-demo-balance'),
                  onTap: () => context.go('/account'),
                  borderRadius: BorderRadius.circular(20 * s),
                  child: Container(
                    height: 33 * s,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(20 * s),
                      boxShadow: const [
                        BoxShadow(color: Color(0x09000000), blurRadius: 3),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '0,00 USD  ⋮',
                        style: TextStyle(
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 44 * s,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18 * s, 0, 0, 0),
                  child: Text(
                    'Thông tin chuyên sâu',
                    style: TextStyle(
                      fontSize: 29 * s,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              _DemoSectionHeader(
                title: 'ĐỀ XUẤT HÀNG ĐẦU',
                scale: s,
                height: 21 * s,
                onMore: () => _showSymbolList(context, s),
              ),
              SizedBox(
                height: 110 * s,
                child: ListView.separated(
                  key: const Key('insights-demo-symbols'),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 15 * s),
                  itemCount: _symbols.length,
                  separatorBuilder: (_, _) => SizedBox(width: 6 * s),
                  itemBuilder: (context, index) => _DemoSymbolCard(
                    symbol: _symbols[index],
                    scale: s,
                    onTap: () => _showSymbol(context, _symbols[index], s),
                  ),
                ),
              ),
              SizedBox(height: 20 * s),
              _DemoSectionHeader(
                title: 'TÍN HIỆU GIAO DỊCH',
                scale: s,
                height: 23 * s,
                onMore: () => _showSignalList(context, s),
              ),
              SizedBox(
                height: 179 * s,
                child: ListView.separated(
                  key: const Key('insights-demo-signals'),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 15 * s),
                  itemCount: _signals.length,
                  separatorBuilder: (_, _) => SizedBox(width: 6 * s),
                  itemBuilder: (context, index) => _DemoSignalCard(
                    signal: _signals[index],
                    scale: s,
                    onTap: () => _showSignal(context, _signals[index], s),
                  ),
                ),
              ),
              SizedBox(height: 20 * s),
              _DemoSectionHeader(
                title: 'NHỮNG SỰ KIỆN SẮP TỚI',
                scale: s,
                height: 23 * s,
                onMore: () => _showEventList(context, s),
              ),
              Container(
                height: 210 * s,
                margin: EdgeInsets.symmetric(horizontal: 15 * s),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8 * s),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < _events.length; index++)
                      Expanded(
                        child: _DemoEventRow(
                          event: _events[index],
                          scale: s,
                          showDivider: index != _events.length - 1,
                          onTap: () => _showEvent(context, _events[index], s),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20 * s),
              _DemoSectionHeader(
                title: 'TIN TỨC PHỔ BIẾN',
                scale: s,
                height: 23 * s,
                onMore: () => _showNews(context, s),
              ),
              _DemoNewsCard(scale: s, onTap: () => _showNews(context, s)),
              SizedBox(height: 25 * s),
            ],
          ),
        ),
      ],
    );
  }

  void _showSymbolList(BuildContext context, double s) {
    showExSheet(
      context,
      ExSheet(
        title: 'Đề xuất hàng đầu',
        child: ListView(
          children: [
            for (final symbol in _symbols)
              ListTile(
                leading: Text(symbol.flag, style: TextStyle(fontSize: 22 * s)),
                title: Text(symbol.name),
                subtitle: Text(
                  '↑ ${symbol.change}',
                  style: const TextStyle(color: AppColors.blue),
                ),
                trailing: Text(symbol.price),
                onTap: () => _showSymbol(context, symbol, s),
              ),
          ],
        ),
      ),
    );
  }

  void _showSymbol(BuildContext context, _VideoSymbol symbol, double s) {
    showExSheet(
      context,
      ExSheet(
        title: symbol.name,
        child: Padding(
          padding: EdgeInsets.all(20 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol.price,
                style: TextStyle(fontSize: 29 * s, fontWeight: FontWeight.w700),
              ),
              Text(
                '↑ ${symbol.change}',
                style: TextStyle(fontSize: 16 * s, color: AppColors.blue),
              ),
              SizedBox(height: 20 * s),
              SizedBox(
                height: 90 * s,
                width: double.infinity,
                child: CustomPaint(painter: const _SparklinePainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignalList(BuildContext context, double s) {
    showExSheet(
      context,
      ExSheet(
        title: 'Tín hiệu giao dịch',
        child: ListView(
          padding: EdgeInsets.all(15 * s),
          children: [
            for (final signal in _signals) ...[
              SizedBox(
                height: 179 * s,
                child: _DemoSignalCard(
                  signal: signal,
                  scale: s,
                  onTap: () => _showSignal(context, signal, s),
                ),
              ),
              SizedBox(height: 12 * s),
            ],
          ],
        ),
      ),
    );
  }

  void _showSignal(BuildContext context, _VideoSignal signal, double s) {
    showExSheet(
      context,
      ExSheet(
        title: 'Tín hiệu giao dịch',
        child: ListView(
          padding: EdgeInsets.all(20 * s),
          children: [
            SizedBox(
              height: 180 * s,
              child: CustomPaint(
                painter: _SignalChartPainter(rising: signal.rising),
              ),
            ),
            SizedBox(height: 20 * s),
            Text(
              signal.title,
              style: TextStyle(fontSize: 21 * s, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8 * s),
            Text(
              'NGẮN HẠN  •  ${signal.displayTime}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventList(BuildContext context, double s) {
    showExSheet(
      context,
      ExSheet(
        title: 'Những sự kiện sắp tới',
        child: ListView(
          children: [
            for (final event in _events)
              SizedBox(
                height: 70 * s,
                child: _DemoEventRow(
                  event: event,
                  scale: s,
                  showDivider: true,
                  onTap: () => _showEvent(context, event, s),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEvent(BuildContext context, _VideoEvent event, double s) {
    showExSheet(
      context,
      ExSheet(
        title: event.title,
        child: Padding(
          padding: EdgeInsets.all(20 * s),
          child: Text(
            '${event.flag}  ${event.country}   ${event.time}',
            style: TextStyle(fontSize: 16 * s),
          ),
        ),
      ),
    );
  }

  void _showNews(BuildContext context, double s) {
    showExSheet(
      context,
      ExSheet(
        title: 'Tin tức phổ biến',
        child: Padding(
          padding: EdgeInsets.all(20 * s),
          child: const Text('Nội dung tin tức trong bản xem trước.'),
        ),
      ),
    );
  }
}

class _VideoSymbol {
  const _VideoSymbol(this.name, this.price, this.change, this.flag, this.icon);
  final String name;
  final String price;
  final String change;
  final String flag;
  final String icon;
}

class _VideoSignal {
  const _VideoSignal(
    this.title,
    this.captureTime,
    this.displayTime,
    this.rising,
  );
  final String title;
  final String captureTime;
  final String displayTime;
  final bool rising;
}

class _VideoEvent {
  const _VideoEvent(
    this.flag,
    this.country,
    this.title,
    this.time,
    this.important,
  );
  final String flag;
  final String country;
  final String title;
  final String time;
  final bool important;
}

class _DemoSectionHeader extends StatelessWidget {
  const _DemoSectionHeader({
    required this.title,
    required this.scale,
    required this.height,
    required this.onMore,
  });
  final String title;
  final double scale;
  final double height;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10 * scale,
                  letterSpacing: 1.5 * scale,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            InkWell(
              onTap: onMore,
              child: Text(
                'Hiển thị thêm',
                style: TextStyle(fontSize: 12 * scale, color: AppColors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSymbolCard extends StatelessWidget {
  const _DemoSymbolCard({
    required this.symbol,
    required this.scale,
    required this.onTap,
  });
  final _VideoSymbol symbol;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('insights-symbol-${symbol.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Container(
        width: 109 * scale,
        padding: EdgeInsets.fromLTRB(
          7 * scale,
          10 * scale,
          6 * scale,
          7 * scale,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8 * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 19 * scale,
                  height: 20 * scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: CircleAvatar(
                          radius: 7 * scale,
                          backgroundColor: symbol.icon == '₿'
                              ? const Color(0xFFF09916)
                              : AppColors.textSecondary,
                          child: Text(
                            symbol.icon,
                            style: TextStyle(
                              fontSize: 9 * scale,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1 * scale,
                        top: 0,
                        child: Text(
                          symbol.flag,
                          style: TextStyle(fontSize: 11 * scale),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 2 * scale),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      symbol.name,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3 * scale),
            SizedBox(
              height: 18 * scale,
              width: double.infinity,
              child: CustomPaint(painter: const _SparklinePainter()),
            ),
            SizedBox(height: 4 * scale),
            Text(
              symbol.price,
              style: TextStyle(
                fontSize: 11.5 * scale,
                height: 1,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2 * scale),
            Text(
              '↑ ${symbol.change}',
              style: TextStyle(
                fontSize: 12 * scale,
                height: 1,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height * .66;
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );
    final points = <double>[
      .74,
      .67,
      .71,
      .62,
      .63,
      .61,
      .56,
      .60,
      .57,
      .52,
      .49,
      .52,
      .53,
      .48,
      .55,
      .56,
      .49,
      .61,
      .57,
      .64,
      .62,
      .65,
      .61,
      .67,
      .65,
      .64,
      .68,
    ];
    final line = Path()..moveTo(0, points.first * size.height);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(
        i * size.width / (points.length - 1),
        points[i] * size.height,
      );
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.blue.withValues(alpha: .11),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.blue
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DemoSignalCard extends StatelessWidget {
  const _DemoSignalCard({
    required this.signal,
    required this.scale,
    required this.onTap,
  });
  final _VideoSignal signal;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('insights-signal-${signal.captureTime}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Container(
        width: 202 * scale,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8 * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x13000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 107 * scale,
              width: double.infinity,
              child: CustomPaint(
                painter: _SignalChartPainter(rising: signal.rising),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 7 * scale),
              child: Text(
                signal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14 * scale,
                  height: 1.18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(7 * scale, 0, 7 * scale, 7 * scale),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5 * scale,
                      vertical: 2 * scale,
                    ),
                    color: const Color(0xFF677C88),
                    child: Text(
                      '➜  NGẮN HẠN',
                      style: TextStyle(
                        fontSize: 9 * scale,
                        letterSpacing: .7 * scale,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    signal.displayTime,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: AppColors.textSecondary,
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

class _SignalChartPainter extends CustomPainter {
  const _SignalChartPainter({required this.rising});
  final bool rising;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 202;
    final w = size.width;
    final h = size.height;
    final text = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    void tiny(String value, Offset offset, Color color, double font) {
      text.text = TextSpan(
        text: value,
        style: TextStyle(
          fontSize: font * scale,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      );
      text.layout(maxWidth: w);
      text.paint(canvas, offset);
    }

    tiny(
      'Saturday, September 19, 2026 1:${rising ? '03:40' : '05:08'} AM CET',
      Offset(7 * scale, 9 * scale),
      AppColors.textPrimary,
      5.5,
    );
    final chartTop = 49 * scale;
    final chartBottom = h - 10 * scale;
    final shade = Path()
      ..moveTo(7 * scale, chartBottom)
      ..lineTo(52 * scale, chartTop + 27 * scale)
      ..lineTo(105 * scale, chartTop + 8 * scale)
      ..lineTo(147 * scale, chartTop + 11 * scale)
      ..lineTo(174 * scale, chartBottom)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0x24ED647D));
    final lowerShade = Path()
      ..moveTo(5 * scale, chartBottom - 1 * scale)
      ..lineTo(76 * scale, chartTop + 26 * scale)
      ..lineTo(148 * scale, chartTop + 27 * scale)
      ..lineTo(177 * scale, chartBottom)
      ..close();
    canvas.drawPath(lowerShade, Paint()..color = const Color(0x12E85175));
    for (final row in <(double, Color)>[
      (.12, const Color(0xFF86C155)),
      (.34, const Color(0xFF86C155)),
      (.55, const Color(0xFF526BA6)),
      (.79, const Color(0xFFC25561)),
      (.96, const Color(0xFFC25561)),
    ]) {
      final y = chartTop + (chartBottom - chartTop) * row.$1;
      canvas.drawLine(
        Offset(5 * scale, y),
        Offset(w - 4 * scale, y),
        Paint()
          ..color = row.$2.withValues(alpha: .78)
          ..strokeWidth = .8 * scale,
      );
    }
    tiny(
      '▬   MA 20 + BB      ▬   MA 50',
      Offset(7 * scale, 31 * scale),
      AppColors.textSecondary,
      5.8,
    );
    tiny(
      'Research © 2026 Trading Central',
      Offset(105 * scale, 31 * scale),
      AppColors.textSecondary,
      4.7,
    );
    final blueMa = Path();
    for (var i = 0; i < 48; i++) {
      final x = (8 + i * 3.6) * scale;
      final normalized = i / 47;
      final y =
          chartTop +
          (rising
                  ? (27 - normalized * 11 + 9 * (normalized - .5).abs())
                  : (36 - normalized * 19 + 19 * normalized * normalized)) *
              scale;
      if (i == 0) {
        blueMa.moveTo(x, y);
      } else {
        blueMa.lineTo(x, y);
      }
    }
    canvas.drawPath(
      blueMa,
      Paint()
        ..color = const Color(0xFF5173AD)
        ..strokeWidth = 1.2 * scale
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < 47; i++) {
      final x = (9 + i * 3.68) * scale;
      final n = i / 46;
      final zig = ((i * 17) % 13 - 6) * .65;
      double raw;
      if (rising) {
        if (n < .18) {
          raw = 14 + 8 * n / .18 + zig;
        } else if (n < .47) {
          raw = 22 + 23 * (n - .18) / .29 + zig;
        } else if (n < .72) {
          raw = 45 - 24 * (n - .47) / .25 + zig;
        } else {
          raw = 21 - 14 * (n - .72) / .28 + zig;
        }
      } else {
        if (n < .20) {
          raw = 37 - 12 * n / .20 + zig;
        } else if (n < .48) {
          raw = 25 - 16 * (n - .20) / .28 + zig;
        } else if (n < .70) {
          raw = 9 + 8 * (n - .48) / .22 + zig;
        } else {
          raw = 17 + 29 * (n - .70) / .30 + zig;
        }
      }
      final y = chartTop + raw.clamp(2, 46) * scale;
      final up = i % 3 != 0;
      final color = up ? const Color(0xFF234D59) : const Color(0xFFC44755);
      canvas.drawLine(
        Offset(x, y - 4.5 * scale),
        Offset(x, y + 4.5 * scale),
        Paint()
          ..color = color
          ..strokeWidth = .75 * scale,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 1.7 * scale,
          height: 3.3 * scale,
        ),
        Paint()..color = color,
      );
    }
    if (!rising) {
      for (final label in <(double, Color, String)>[
        (0, const Color(0xFF75AC49), '54720'),
        (10, const Color(0xFF75AC49), '53000'),
        (20, const Color(0xFF326FC6), '52770'),
        (30, const Color(0xFF344555), '51683'),
        (40, const Color(0xFFC84C59), '50640'),
        (50, const Color(0xFFD9343D), '49900'),
      ]) {
        final y = chartTop - 2 * scale + label.$1 * scale;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w - 42 * scale, y, 42 * scale, 9 * scale),
            Radius.circular(2 * scale),
          ),
          Paint()..color = label.$2,
        );
        tiny(
          label.$3,
          Offset(w - 29 * scale, y + 1 * scale),
          AppColors.background,
          5.8,
        );
      }
    }
    if (rising) {
      final marker = Path()
        ..moveTo(w - 15 * scale, chartTop + 11 * scale)
        ..lineTo(w - 4 * scale, chartTop + 3 * scale)
        ..lineTo(w - 7 * scale, chartTop + 15 * scale)
        ..close();
      canvas.drawPath(marker, Paint()..color = AppColors.blue);
    } else {
      final marker = Path()
        ..moveTo(w - 20 * scale, chartBottom - 22 * scale)
        ..lineTo(w - 7 * scale, chartBottom - 3 * scale)
        ..lineTo(w - 18 * scale, chartBottom - 8 * scale)
        ..close();
      canvas.drawPath(marker, Paint()..color = AppColors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalChartPainter oldDelegate) =>
      oldDelegate.rising != rising;
}

class _DemoEventRow extends StatelessWidget {
  const _DemoEventRow({
    required this.event,
    required this.scale,
    required this.showDivider,
    required this.onTap,
  });
  final _VideoEvent event;
  final double scale;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('insights-event-${event.country}'),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(event.flag, style: TextStyle(fontSize: 18 * scale)),
                SizedBox(width: 6 * scale),
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14 * scale),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3 * scale),
            Row(
              children: [
                Text(
                  event.country,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 10 * scale),
                Container(
                  width: 3 * scale,
                  height: 11 * scale,
                  color: const Color(0xFFF5CB1B),
                ),
                SizedBox(width: 2 * scale),
                Container(
                  width: 3 * scale,
                  height: 11 * scale,
                  color: event.important
                      ? const Color(0xFFF5CB1B)
                      : const Color(0xFF647D92),
                ),
                SizedBox(width: 2 * scale),
                Container(
                  width: 3 * scale,
                  height: 11 * scale,
                  color: const Color(0xFF647D92),
                ),
                SizedBox(width: 7 * scale),
                Text(
                  event.time,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: AppColors.textPrimary,
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

class _DemoNewsCard extends StatelessWidget {
  const _DemoNewsCard({required this.scale, required this.onTap});
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 82 * scale,
        margin: EdgeInsets.symmetric(horizontal: 15 * scale),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Row(
          children: [
            Container(
              width: 60 * scale,
              color: AppColors.infoSurface,
              child: const Center(
                child: Icon(Icons.auto_graph, color: AppColors.blue),
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Text(
                'Tin tức thị trường',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
