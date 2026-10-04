import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/config/video_demo_mode.dart';
import '../../../core/widgets/ex_widgets.dart';
import '../../trading/data/market_api.dart';
import '../../notifications/presentation/notifications_sheet.dart';
import '../data/account_session.dart';
import '../data/ex_v2_api_client.dart';
import '../data/ex_v2_models.dart';
import 'video_account_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(videoDemoModeProvider)) {
      return const VideoAccountScreen();
    }
    final sessionState = ref.watch(accountSessionProvider);
    final session = sessionState.value;
    return Column(
      key: const Key('account-screen'),
      children: [
        _AccountHeader(
          onHistory: () => setState(() => _selectedTab = 2),
          onNotification: () =>
              showExSheet(context, const NotificationsSheet()),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketQuotesProvider);
              if (session != null) {
                await ref.read(accountSessionProvider.notifier).refresh();
                ref.invalidate(historyPositionsProvider);
              }
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16),
                const _PromotionBanner(),
                const SizedBox(height: 15),
                _AccountCard(
                  session: session,
                  isLoading: sessionState.isLoading,
                  onDetails: () => showExSheet(
                    context,
                    AccountDetailSheet(session: session),
                  ),
                  onLogin: () => showAccountLoginSheet(context),
                ),
                const SizedBox(height: 17),
                _AccountTabs(
                  selected: _selectedTab,
                  onSelected: (value) => setState(() => _selectedTab = value),
                ),
                _AccountTabBody(selected: _selectedTab, session: session),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onHistory, required this.onNotification});

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
                  child: Center(child: Text('Quản lý tài khoản trong Hồ sơ')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.only(left: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E9F8),
        border: Border.all(color: const Color(0xFFD0D6E7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ưu đãi và phần thưởng',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Thông tin ưu đãi sẽ hiển thị khi có dữ liệu',
                  style: TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: Stack(
              children: [
                Positioned(
                  top: 17,
                  left: 12,
                  child: Transform.rotate(
                    angle: -.12,
                    child: Container(
                      width: 29,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFF969AA5),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 38,
                  child: Transform.rotate(
                    angle: .12,
                    child: Container(
                      width: 25,
                      height: 63,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF878A95),
                            Colors.white,
                            Color(0xFF9A9FAA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.session,
    required this.isLoading,
    required this.onDetails,
    required this.onLogin,
  });

  final ExV2Bootstrap? session;
  final bool isLoading;
  final VoidCallback onDetails;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
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
              Expanded(
                child: Text(
                  session?.account.name.toUpperCase() ?? 'TÀI KHOẢN DEMO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (session != null)
                Text(
                  '# ${session!.account.accountCode}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              IconButton.filledTonal(
                key: const Key('account-details'),
                onPressed: onDetails,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.muted,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(29, 29),
                ),
                icon: const Icon(Icons.settings_outlined, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(spacing: 4, children: const [_Tag('MT5'), _Tag('Demo')]),
          const SizedBox(height: 18),
          Text(
            session == null
                ? isLoading
                      ? 'Đang tải…'
                      : '-- USD'
                : formatMoney(
                    session!.summary.balance,
                    session!.summary.currency,
                  ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (session == null)
            InkWell(
              onTap: onLogin,
              child: const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  'Đăng nhập tài khoản demo',
                  style: TextStyle(color: AppColors.blue, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: RoundAction(
                  icon: Icons.candlestick_chart,
                  label: 'Giao dịch',
                  highlight: true,
                  onTap: () => context.go('/trading'),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.arrow_circle_down_outlined,
                  label: 'Nạp tiền',
                  onTap: () => _moneyAction(context, 'Nạp tiền', session),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.arrow_circle_up_outlined,
                  label: 'Rút tiền',
                  onTap: () => _moneyAction(context, 'Rút tiền', session),
                ),
              ),
              Expanded(
                child: RoundAction(
                  icon: Icons.swap_horiz,
                  label: 'Chuyển tiền',
                  onTap: () => _moneyAction(context, 'Chuyển tiền', session),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

void _moneyAction(BuildContext context, String title, ExV2Bootstrap? session) {
  if (session == null) {
    showAccountLoginSheet(context);
    return;
  }
  showExSheet(
    context,
    ExSheet(
      title: title,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Vui lòng dùng tài khoản demo đã đăng nhập để tiếp tục.'),
      ),
    ),
  );
}

class _AccountTabs extends StatelessWidget {
  const _AccountTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

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
          const Icon(Icons.swap_vert, size: 19, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _AccountTabBody extends ConsumerWidget {
  const _AccountTabBody({required this.selected, required this.session});

  final int selected;
  final ExV2Bootstrap? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selected == 2) {
      final history = ref.watch(historyPositionsProvider);
      return history.when(
        data: (rows) => rows.isEmpty
            ? const _NoOrders('Không có giao dịch đã đóng')
            : _ClosedHistory(rows: rows),
        error: (error, _) =>
            const _NoOrders('Không tải được lịch sử giao dịch'),
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (selected == 1) {
      final orders = session?.pendingOrders ?? const <ExV2Order>[];
      if (orders.isEmpty) return const _NoOrders('Không có lệnh đang chờ');
      return Column(
        children: [
          for (final order in orders)
            ListTile(
              title: Text(marketLabel(order.symbol)),
              subtitle: Text('${order.side} ${formatNumber(order.volume)} lô'),
              trailing: Text(
                order.requestedPrice == null
                    ? '--'
                    : formatNumber(order.requestedPrice!, decimals: 3),
              ),
            ),
        ],
      );
    }
    final positions = session?.positions ?? const <ExV2Position>[];
    if (positions.isNotEmpty) {
      return Column(
        children: [
          for (final position in positions)
            ListTile(
              title: Text(marketLabel(position.symbol)),
              subtitle: Text(
                '${position.side} ${formatNumber(position.remainingVolume)} lô',
              ),
              trailing: Text(
                formatMoney(position.realizedProfit, session!.account.currency),
              ),
            ),
        ],
      );
    }
    return const _NoOrders('Không có lệnh mở. Tìm cơ hội giao dịch tiếp theo:');
  }
}

class _NoOrders extends ConsumerWidget {
  const _NoOrders(this.message);
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(marketQuotesProvider).value;
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
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                for (final symbol in const ['XAUUSD+', 'BTCUSD', 'ETHUSD'])
                  _RecommendationCard(
                    symbol: symbol,
                    quote: feed?.isStale(symbol) == true
                        ? null
                        : feed?.quoteFor(symbol),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.symbol, required this.quote});
  final String symbol;
  final MarketQuote? quote;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/chart/${Uri.encodeComponent(symbol)}'),
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
              marketLabel(symbol),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              symbol == 'BTCUSD'
                  ? '₿'
                  : symbol == 'ETHUSD'
                  ? '◆'
                  : '🌐',
              style: TextStyle(
                color: symbol == 'BTCUSD' ? Colors.orange : AppColors.blue,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quote == null ? '--' : formatNumber(quote!.bid, decimals: 3),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedHistory extends StatelessWidget {
  const _ClosedHistory({required this.rows});
  final List<JsonMap> rows;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows];
    sorted.sort((a, b) => _historyDate(b).compareTo(_historyDate(a)));
    final grouped = <String, List<JsonMap>>{};
    for (final row in sorted) {
      final date = _historyDate(row).toLocal();
      final key =
          '${date.day}/${date.month}/${date.year.toString().substring(2)}';
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 24, 29, 4),
            child: Row(
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text(
                  formatMoney(
                    entry.value.fold<double>(
                      0,
                      (sum, row) => sum + _profit(row),
                    ),
                    'USD',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        entry.value.fold<double>(
                              0,
                              (sum, row) => sum + _profit(row),
                            ) <
                            0
                        ? AppColors.negative
                        : AppColors.positive,
                  ),
                ),
              ],
            ),
          ),
          for (final row in entry.value) _ClosedRow(row: row),
        ],
      ],
    );
  }
}

class _ClosedRow extends StatelessWidget {
  const _ClosedRow({required this.row});
  final JsonMap row;

  @override
  Widget build(BuildContext context) {
    final symbol = '${row['symbol'] ?? '--'}';
    final side = '${row['side'] ?? ''}'.toUpperCase();
    final profit = _profit(row);
    final volume = row['volume'] ?? row['initialVolume'];
    final entry = row['openPrice'] ?? row['entryPrice'];
    final exit = row['closePrice'] ?? row['exitPrice'];
    return InkWell(
      onTap: () => showExSheet(
        context,
        ExSheet(
          title: marketLabel(symbol),
          child: ListView(
            children: [
              ExListRow(
                icon: Icons.receipt_long,
                title: 'Vị thế',
                trailing: Text(side),
              ),
              ExListRow(
                icon: Icons.candlestick_chart,
                title: 'Khối lượng',
                trailing: Text('$volume'),
              ),
              ExListRow(
                icon: Icons.price_change,
                title: 'Giá mở',
                trailing: Text('$entry'),
              ),
              ExListRow(
                icon: Icons.price_change,
                title: 'Giá đóng',
                trailing: Text('$exit'),
              ),
              ExListRow(
                icon: Icons.payments_outlined,
                title: 'Lãi/Lỗ',
                trailing: Text(formatMoney(profit, 'USD')),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        height: 71,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const Text('🌐', style: TextStyle(fontSize: 19)),
            const SizedBox(width: 7),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    '${side == 'BUY' ? 'Mua' : 'Bán'} ${volume ?? '--'} lô ở mức ${entry is num ? formatNumber(entry, decimals: 3) : '--'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: side == 'BUY'
                          ? AppColors.blue
                          : AppColors.negative,
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
                  '${profit > 0 ? '+' : ''}${formatMoney(profit, 'USD')}',
                  style: TextStyle(
                    color: profit < 0 ? AppColors.negative : AppColors.positive,
                    fontSize: 14,
                  ),
                ),
                Text(
                  exit is num ? formatNumber(exit, decimals: 3) : '--',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

DateTime _historyDate(JsonMap row) {
  for (final key in const [
    'closedAt',
    'closedAtUtc',
    'createdAt',
    'createdAtUtc',
    'time',
  ]) {
    final raw = row[key];
    if (raw is String) {
      final value = DateTime.tryParse(raw);
      if (value != null) return value;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

double _profit(JsonMap row) {
  final value = row['profit'] ?? row['realizedProfit'];
  return value is num ? value.toDouble() : 0;
}

class AccountDetailSheet extends StatefulWidget {
  const AccountDetailSheet({required this.session, super.key});
  final ExV2Bootstrap? session;

  @override
  State<AccountDetailSheet> createState() => _AccountDetailSheetState();
}

class _AccountDetailSheetState extends State<AccountDetailSheet> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ExSheet(
      title: session?.account.name.toUpperCase() ?? 'TÀI KHOẢN',
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: InkWell(
                    key: Key('account-detail-tab-$i'),
                    onTap: () => setState(() => selected = i),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 15),
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
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: selected == 0
                  ? _fundsContent(context, session)
                  : _settingsContent(context, session),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fundsContent(BuildContext context, ExV2Bootstrap? session) {
    final summary = session?.summary;
    return [
      _DetailTable(
        rows: [
          (
            'Số dư',
            summary == null
                ? '--'
                : formatMoney(summary.balance, summary.currency),
          ),
          (
            'Vốn luân chuyển',
            summary == null
                ? '--'
                : formatMoney(summary.equity, summary.currency),
          ),
          (
            'Lời/Lỗ dao động',
            summary == null
                ? '--'
                : formatMoney(summary.profit, summary.currency),
          ),
          (
            'Khung',
            summary == null
                ? '--'
                : formatMoney(summary.margin, summary.currency),
          ),
          (
            'Tiền Ký Quỹ Khả Dụng',
            summary == null
                ? '--'
                : formatMoney(summary.freeMargin, summary.currency),
          ),
          (
            'Mức ký quỹ',
            summary == null ? '--' : formatNumber(summary.marginLevel),
          ),
          ('Đòn bẩy', '--'),
        ],
      ),
      const SizedBox(height: 15),
      _DetailTable(rows: const [('Quản lý sao kê', '›')]),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            RoundAction(
              icon: Icons.arrow_circle_down_outlined,
              label: 'Nạp tiền',
              onTap: () => _moneyAction(context, 'Nạp tiền', session),
            ),
            RoundAction(
              icon: Icons.arrow_circle_up_outlined,
              label: 'Rút tiền',
              onTap: () => _moneyAction(context, 'Rút tiền', session),
            ),
            RoundAction(
              icon: Icons.swap_horiz,
              label: 'Chuyển tiền',
              onTap: () => _moneyAction(context, 'Chuyển tiền', session),
            ),
            RoundAction(
              icon: Icons.history,
              label: 'Giao dịch',
              onTap: () {
                Navigator.pop(context);
                context.go('/account');
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _settingsContent(BuildContext context, ExV2Bootstrap? session) {
    return [
      _DetailTable(
        rows: [
          ('Loại', 'MT5 Demo'),
          ('Số', session?.account.accountCode ?? '--'),
          ('Tên', session?.account.name ?? '--'),
          ('Không có hoa hồng', '--'),
          ('Chênh lệch tối thiểu', '--'),
          ('Đòn bẩy tối đa', '--'),
          ('Loại khớp lệnh', '--'),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'NỀN TẢNG GIAO DỊCH – METATRADER 5',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _DetailTable(
        rows: [
          ('Đăng nhập', session?.account.accountCode ?? '--'),
          ('Máy chủ', '--'),
          ('Đổi mật khẩu giao dịch', '›'),
          ('Xem nhật ký giao dịch', '›'),
        ],
        copyable: true,
      ),
    ];
  }
}

class _DetailTable extends StatelessWidget {
  const _DetailTable({required this.rows, this.copyable = false});
  final List<(String, String)> rows;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: copyable && i < 2 && rows[i].$2 != '--'
                  ? () {
                      Clipboard.setData(ClipboardData(text: rows[i].$2));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép')),
                      );
                    }
                  : null,
              child: Container(
                height: 39,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(rows[i].$2, style: const TextStyle(fontSize: 12)),
                    if (copyable && i < 2) ...[
                      const SizedBox(width: 7),
                      const Icon(Icons.copy, size: 15),
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

Future<void> showAccountLoginSheet(BuildContext context) =>
    showExSheet<void>(context, const _AccountLoginSheet());

class _AccountLoginSheet extends ConsumerStatefulWidget {
  const _AccountLoginSheet();

  @override
  ConsumerState<_AccountLoginSheet> createState() => _AccountLoginSheetState();
}

class _AccountLoginSheetState extends ConsumerState<_AccountLoginSheet> {
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExSheet(
      title: 'Đăng nhập tài khoản demo',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Đăng nhập bằng tài khoản demo đang dùng với MT5.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: loginController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tài khoản',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu giao dịch',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Máy chủ: YODO-Demo-01',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text(submitting ? 'Đang đăng nhập…' : 'Đăng nhập'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref
          .read(accountSessionProvider.notifier)
          .login(
            login: loginController.text,
            password: passwordController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception is ExV2RequestFailure
              ? exception.safeDisplayMessage
              : exception is FormatException
              ? exception.message
              : 'Không thể đăng nhập. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
