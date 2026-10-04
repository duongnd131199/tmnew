import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';

/// A local preview of the recorded account flow. No values here are used for
/// orders, balances, or server requests.
class VideoAccountScreen extends StatefulWidget {
  const VideoAccountScreen({super.key});

  @override
  State<VideoAccountScreen> createState() => _VideoAccountScreenState();
}

class _VideoAccountScreenState extends State<VideoAccountScreen> {
  int selectedTab = 0;
  bool newestFirst = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('account-screen'),
      children: [
        _VideoAccountHeader(
          onHistory: () => setState(() => selectedTab = 2),
          onNotification: () => showExSheet(
            context,
            const ExSheet(
              title: 'Thông báo',
              child: Center(child: Text('Chưa có thông báo')),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 15),
              const _VideoPromotionBanner(),
              const SizedBox(height: 15),
              _VideoAccountCard(
                onDetails: () => _showVideoAccountDetailSheet(context),
              ),
              const SizedBox(height: 16),
              _VideoAccountTabs(
                selected: selectedTab,
                onSelected: (value) => setState(() => selectedTab = value),
                onSort: () => setState(() => newestFirst = !newestFirst),
              ),
              if (selectedTab == 2)
                _VideoClosedHistory(newestFirst: newestFirst)
              else
                _VideoRecommendations(
                  message: selectedTab == 0
                      ? 'Không có lệnh mở. Tìm cơ hội giao dịch tiếp theo:'
                      : 'Không có lệnh chờ. Tìm cơ hội giao dịch tiếp theo:',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoAccountHeader extends StatelessWidget {
  const _VideoAccountHeader({
    required this.onHistory,
    required this.onNotification,
  });

  final VoidCallback onHistory;
  final VoidCallback onNotification;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: Stack(
        children: [
          Positioned(
            right: 9,
            top: 0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.alarm_outlined, size: 21),
                  onPressed: onHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none, size: 22),
                  onPressed: onNotification,
                ),
              ],
            ),
          ),
          const Positioned(
            left: 19,
            bottom: 20,
            child: Text(
              'Tài khoản',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 13,
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.muted,
                minimumSize: const Size(29, 29),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.more_vert, size: 16),
              onPressed: () => showExSheet(
                context,
                const ExSheet(
                  title: 'Tài khoản',
                  child: Center(child: Text('MỖI NGÀY MỘT TỶ 🍀')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPromotionBanner extends StatelessWidget {
  const _VideoPromotionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E9F8),
        border: Border.all(color: const Color(0xFFD0D6E7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '0.06 USD và 0.06 EXD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Phần thưởng sau 60 ngày sắp được\nghi có',
                    style: TextStyle(fontSize: 12, height: 1.32),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 78,
            height: 94,
            child: CustomPaint(painter: _PrizePainter()),
          ),
        ],
      ),
    );
  }
}

class _PrizePainter extends CustomPainter {
  const _PrizePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final chrome = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF2C303A),
          Color(0xFFD6D7DC),
          Color(0xFFFFFFFF),
          Color(0xFF787A84),
          Color(0xFF262932),
        ],
        stops: [0, .2, .48, .75, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final white = Paint()..color = const Color(0xFFF8F8FB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(17, 16, 21, 55),
        const Radius.circular(2),
      ),
      chrome,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(42, 13, 23, 63),
        const Radius.circular(2),
      ),
      chrome,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(19, 37, 18, 25),
        const Radius.circular(1),
      ),
      white,
    );
    for (final center in const [
      Offset(23, 19),
      Offset(45, 21),
      Offset(49, 40),
      Offset(27, 71),
      Offset(58, 71),
    ]) {
      canvas.drawCircle(
        center,
        8,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.35, -.35),
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFF8D8F98),
              Color(0xFF15171D),
              Color(0xFFBFC2C9),
            ],
            stops: const [0, .32, .7, 1],
          ).createShader(Rect.fromCircle(center: center, radius: 8)),
      );
      canvas.drawCircle(center.translate(-2, -2), 1.5, white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VideoAccountCard extends StatelessWidget {
  const _VideoAccountCard({required this.onDetails});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'MỖI NGÀY MỘT TỶ 🍀',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '# 109740422',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
              const Spacer(),
              InkWell(
                key: const Key('account-details'),
                onTap: onDetails,
                borderRadius: BorderRadius.circular(16),
                child: const CircleAvatar(
                  radius: 14.5,
                  backgroundColor: AppColors.muted,
                  child: Icon(
                    Icons.settings_outlined,
                    size: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Wrap(
            spacing: 4,
            children: [_VideoTag('MT5'), _VideoTag('Pro')],
          ),
          const SizedBox(height: 15),
          const Text(
            '0,00 USD',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RoundAction(
                  icon: Icons.candlestick_chart_outlined,
                  label: 'Giao dịch',
                  highlight: true,
                  onTap: () => context.go('/trading'),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.arrow_circle_down_outlined,
                  label: 'Nạp tiền',
                  onTap: () => _showPreviewAction(context, 'Nạp tiền'),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.arrow_circle_up_outlined,
                  label: 'Rút tiền',
                  onTap: () => _showPreviewAction(context, 'Rút tiền'),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.swap_horiz,
                  label: 'Chuyển tiền',
                  onTap: () => _showPreviewAction(context, 'Chuyển tiền'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoTag extends StatelessWidget {
  const _VideoTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.muted,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}

class _VideoAccountTabs extends StatelessWidget {
  const _VideoAccountTabs({
    required this.selected,
    required this.onSelected,
    required this.onSort,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            InkWell(
              key: Key('account-tab-$i'),
              onTap: () => onSelected(i),
              child: Container(
                height: 39,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected == i
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  const ['Mở', 'Đang chờ', 'Đã đóng'][i],
                  style: TextStyle(
                    fontSize: 13,
                    color: selected == i
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: selected == i
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          const Spacer(),
          InkWell(
            key: const Key('account-history-sort'),
            onTap: onSort,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.swap_vert,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRecommendations extends StatelessWidget {
  const _VideoRecommendations({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(message, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: const [
                _VideoRecommendationCard('XAU/USD', '4.378,101', '0,74%'),
                _VideoRecommendationCard('BTC', '81.425,03', '0,67%'),
                _VideoRecommendationCard('ETH', '2.649,63', '1,46%'),
                _VideoRecommendationCard('XAG/USD', '41,486', '0,42%'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRecommendationCard extends StatelessWidget {
  const _VideoRecommendationCard(this.symbol, this.price, this.change);
  final String symbol;
  final String price;
  final String change;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/chart/${Uri.encodeComponent(symbol == 'XAU/USD'
            ? 'XAUUSD+'
            : symbol == 'BTC'
            ? 'BTCUSD'
            : symbol == 'ETH'
            ? 'ETHUSD'
            : 'XAGUSD')}',
      ),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              symbol,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (symbol == 'XAU/USD' || symbol == 'XAG/USD')
              const _GoldUsdIcon(size: 26)
            else
              Text(
                symbol == 'BTC' ? '₿' : '◆',
                style: TextStyle(
                  color: symbol == 'BTC'
                      ? const Color(0xFFF19421)
                      : const Color(0xFF62686C),
                  fontSize: 21,
                ),
              ),
            const SizedBox(height: 3),
            Text(price, style: const TextStyle(fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '↑ $change',
                style: const TextStyle(color: AppColors.blue, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldUsdIcon extends StatelessWidget {
  const _GoldUsdIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 9,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            child: Text('🇺🇸', style: TextStyle(fontSize: size * .75)),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: size * .70,
              height: size * .70,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFD3B677),
                shape: BoxShape.circle,
              ),
              child: const Text('▪', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoDeal {
  const _VideoDeal(this.open, this.close, this.profit, {this.buy = false});
  final String open;
  final String close;
  final String profit;
  final bool buy;
}

const _videoDeals = <_VideoDeal>[
  _VideoDeal('4.373,622', '4.391,496', '-17,88'),
  _VideoDeal('4.373,381', '4.391,496', '-18,12'),
  _VideoDeal('4.373,328', '4.391,496', '-18,17'),
  _VideoDeal('4.371,771', '4.373,716', '+1,95', buy: true),
  _VideoDeal('4.368,733', '4.371,828', '-3,10'),
  _VideoDeal('4.368,718', '4.371,828', '-3,11'),
  _VideoDeal('4.368,718', '4.371,828', '-3,11'),
  _VideoDeal('4.368,770', '4.371,828', '-3,06'),
  _VideoDeal('4.368,727', '4.371,828', '-3,10'),
  _VideoDeal('4.368,727', '4.371,828', '-3,10'),
  _VideoDeal('4.368,715', '4.371,828', '-3,11'),
  _VideoDeal('4.368,505', '4.371,828', '-3,32'),
  _VideoDeal('4.368,656', '4.371,828', '-3,17'),
  _VideoDeal('4.368,718', '4.371,828', '-3,11'),
  _VideoDeal('4.368,954', '4.371,828', '-2,88'),
];

class _VideoClosedHistory extends StatelessWidget {
  const _VideoClosedHistory({required this.newestFirst});
  final bool newestFirst;

  @override
  Widget build(BuildContext context) {
    final deals = newestFirst ? _videoDeals : _videoDeals.reversed;
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 24, 29, 4),
            child: Row(
              children: const [
                Text('9/9/26', style: TextStyle(fontSize: 12)),
                Spacer(),
                Text(
                  '-40,75 USD',
                  style: TextStyle(fontSize: 12, color: AppColors.negative),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              children: [for (final deal in deals) _VideoClosedRow(deal: deal)],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoClosedRow extends StatelessWidget {
  const _VideoClosedRow({required this.deal});
  final _VideoDeal deal;

  @override
  Widget build(BuildContext context) {
    final profitColor = deal.buy ? AppColors.positive : AppColors.negative;
    return InkWell(
      onTap: () => showExSheet(
        context,
        ExSheet(
          title: 'XAU/USD',
          child: ListView(
            children: [
              ExListRow(
                icon: Icons.trending_up,
                title: 'Vị thế',
                trailing: Text(deal.buy ? 'Mua' : 'Bán'),
              ),
              const ExListRow(
                icon: Icons.candlestick_chart,
                title: 'Khối lượng',
                trailing: Text('0,01 lô'),
              ),
              ExListRow(
                icon: Icons.price_change,
                title: 'Giá mở',
                trailing: Text(deal.open),
              ),
              ExListRow(
                icon: Icons.price_change,
                title: 'Giá đóng',
                trailing: Text(deal.close),
              ),
              ExListRow(
                icon: Icons.payments_outlined,
                title: 'Lãi/Lỗ',
                trailing: Text('${deal.profit} USD'),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const _GoldUsdIcon(size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'XAU/USD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: deal.buy ? 'Mua 0,01 lô' : 'Bán 0,01 lô',
                          style: TextStyle(
                            color: deal.buy
                                ? AppColors.blue
                                : AppColors.negative,
                          ),
                        ),
                        TextSpan(
                          text: ' ở mức ${deal.open}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${deal.profit} USD',
                  style: TextStyle(color: profitColor, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deal.close,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!deal.buy) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        color: AppColors.dangerSurface,
                        child: const Text(
                          'NGD',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.negative,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VideoAccountDetailSheet extends StatefulWidget {
  const VideoAccountDetailSheet({super.key});

  @override
  State<VideoAccountDetailSheet> createState() =>
      _VideoAccountDetailSheetState();
}

void _showVideoAccountDetailSheet(BuildContext context) {
  showVideoExSheet<void>(
    context,
    const VideoAccountDetailSheet(),
    heightFactor: .926,
  );
}

class _VideoAccountDetailSheetState extends State<VideoAccountDetailSheet> {
  int selected = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.background,
            child: Column(
              children: [
                SizedBox(
                  height: 65,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned(
                        top: 17,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'MỖI NGÀY MỘT TỶ 🍀',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 15,
                        top: 11,
                        child: InkWell(
                          key: const Key('account-detail-close'),
                          onTap: () => Navigator.pop(context),
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.close,
                              size: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: InkWell(
                          key: Key('account-detail-tab-$i'),
                          onTap: () => setState(() => selected = i),
                          child: Container(
                            height: 49,
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(
                              left: i == 0 ? 15 : 0,
                              right: i == 1 ? 15 : 0,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: selected == i
                                      ? AppColors.textPrimary
                                      : AppColors.border,
                                  width: selected == i ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                i == 0 ? 'Tài khoản quỹ' : 'Thiết lập',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected == i
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected == i
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 22, 15, 30),
              children: selected == 0 ? _funds(context) : _settings(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _funds(BuildContext context) => [
    const _VideoDetailTable(
      rowHeight: 39,
      rows: [
        _VideoDetailRow('Số dư', '0,00 USD'),
        _VideoDetailRow('Vốn luân chuyển', '0,00 USD'),
        _VideoDetailRow('Lời/Lỗ dao động', '+0.00 USD'),
        _VideoDetailRow('Khung', '0,00 USD'),
        _VideoDetailRow('Tiền Ký Quỹ Khả Dụng', '0,00 USD'),
        _VideoDetailRow('Mức ký quỹ', '-'),
        _VideoDetailRow('Đòn bẩy', '1:2000'),
      ],
    ),
    const SizedBox(height: 15),
    const _VideoDetailTable(
      rows: [_VideoDetailRow('Quản lý sao kê', '', arrow: true)],
    ),
    const SizedBox(height: 15),
    Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: RoundAction(
              icon: Icons.arrow_circle_down_outlined,
              label: 'Nạp tiền',
              onTap: () => _showPreviewAction(context, 'Nạp tiền'),
            ),
          ),
          Expanded(
            child: RoundAction(
              icon: Icons.arrow_circle_up_outlined,
              label: 'Rút tiền',
              onTap: () => _showPreviewAction(context, 'Rút tiền'),
            ),
          ),
          Expanded(
            child: RoundAction(
              icon: Icons.swap_horiz,
              label: 'Chuyển tiền',
              onTap: () => _showPreviewAction(context, 'Chuyển tiền'),
            ),
          ),
          Expanded(
            child: RoundAction(
              icon: Icons.history,
              label: 'Giao dịch',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _settings(BuildContext context) => [
    const _VideoDetailTable(
      rows: [
        _VideoDetailRow('Loại', '', tags: true),
        _VideoDetailRow('Số', '# 109740422'),
        _VideoDetailRow('Tên', 'MỖI NGÀY MỘT TỶ 🍀', arrow: true),
      ],
    ),
    const SizedBox(height: 27),
    const _VideoSectionTitle('PRO ACCOUNT'),
    const SizedBox(height: 7),
    const _VideoDetailTable(
      rowHeight: 41,
      rows: [
        _VideoDetailRow('Không có hoa hồng', ''),
        _VideoDetailRow('Chênh lệch tối thiểu', '0,10'),
        _VideoDetailRow('Đòn bẩy tối đa', '1:2000', arrow: true),
        _VideoDetailRow('Loại khớp lệnh', 'Thị trường', arrow: true),
      ],
    ),
    const SizedBox(height: 29),
    const _VideoSectionTitle('NỀN TẢNG GIAO DỊCH – METATRADER 5'),
    const SizedBox(height: 5),
    const _VideoDetailTable(
      rowHeight: 45,
      rows: [
        _VideoDetailRow('Đăng nhập', '109740422', copyable: true),
        _VideoDetailRow('Máy chủ', 'Exness-MT5Real6', copyable: true),
        _VideoDetailRow('Đổi mật khẩu giao dịch', '', arrow: true),
        _VideoDetailRow('Xem nhật ký giao dịch', '', arrow: true),
      ],
    ),
  ];
}

class _VideoSectionTitle extends StatelessWidget {
  const _VideoSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _VideoDetailRow {
  const _VideoDetailRow(
    this.title,
    this.value, {
    this.arrow = false,
    this.copyable = false,
    this.tags = false,
  });
  final String title;
  final String value;
  final bool arrow;
  final bool copyable;
  final bool tags;
}

class _VideoDetailTable extends StatelessWidget {
  const _VideoDetailTable({required this.rows, this.rowHeight = 42});
  final List<_VideoDetailRow> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            InkWell(
              onTap: rows[index].copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: rows[index].value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép')),
                      );
                    }
                  : null,
              child: Container(
                height: rowHeight,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: index == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[index].title,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (rows[index].tags)
                      const Wrap(
                        spacing: 4,
                        children: [_VideoTag('MT5'), _VideoTag('Pro')],
                      )
                    else
                      Text(
                        rows[index].value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (rows[index].copyable) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.copy_outlined, size: 16),
                    ],
                    if (rows[index].arrow) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showPreviewAction(BuildContext context, String title) {
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: const Center(child: Text('Tính năng này sẽ được kết nối sau.')),
    ),
  );
}
