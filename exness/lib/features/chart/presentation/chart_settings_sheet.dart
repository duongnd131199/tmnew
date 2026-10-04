import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ex_widgets.dart';

enum ChartPriceSource { bid, ask }

enum ChartProvider { exness, tradingView }

final chartSettingsProvider =
    NotifierProvider<ChartSettingsController, ChartSettings>(
      ChartSettingsController.new,
    );

class ChartSettingsController extends Notifier<ChartSettings> {
  @override
  ChartSettings build() => const ChartSettings();

  void update(ChartSettings value) => state = value;
}

final class ChartSettings {
  const ChartSettings({
    this.priceSource = ChartPriceSource.bid,
    this.provider = ChartProvider.exness,
    this.showPriceLines = true,
    this.showGrid = true,
    this.showTimeScale = true,
    this.showPriceScale = true,
  });

  final ChartPriceSource priceSource;
  final ChartProvider provider;
  final bool showPriceLines;
  final bool showGrid;
  final bool showTimeScale;
  final bool showPriceScale;

  ChartSettings copyWith({
    ChartPriceSource? priceSource,
    ChartProvider? provider,
    bool? showPriceLines,
    bool? showGrid,
    bool? showTimeScale,
    bool? showPriceScale,
  }) => ChartSettings(
    priceSource: priceSource ?? this.priceSource,
    provider: provider ?? this.provider,
    showPriceLines: showPriceLines ?? this.showPriceLines,
    showGrid: showGrid ?? this.showGrid,
    showTimeScale: showTimeScale ?? this.showTimeScale,
    showPriceScale: showPriceScale ?? this.showPriceScale,
  );
}

class ChartSettingsSheet extends StatefulWidget {
  const ChartSettingsSheet({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final ChartSettings settings;
  final ValueChanged<ChartSettings> onChanged;

  @override
  State<ChartSettingsSheet> createState() => _ChartSettingsSheetState();
}

class _ChartSettingsSheetState extends State<ChartSettingsSheet> {
  late ChartSettings _settings = widget.settings;

  void _update(ChartSettings value) {
    setState(() => _settings = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => ExSheet(
    title: 'Thiết lập',
    headerHeight: 49,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      children: [
        const SizedBox(height: 5),
        const _SectionTitle('Tùy chọn biểu đồ'),
        _Group(
          children: [
            _SettingRow(
              icon: Icons.visibility_outlined,
              title: 'Hiển thị trên biểu đồ',
              subtitle: 'Số lệnh mở và 6 mục khác',
              onTap: _showDisplayOptions,
            ),
            _SettingRow(
              icon: Icons.sell_outlined,
              title: 'Nguồn giá',
              trailing: _settings.priceSource == ChartPriceSource.bid
                  ? 'Giá mua'
                  : 'Giá bán',
              onTap: _showPriceSource,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Nhà cung cấp biểu đồ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _Group(
          children: [
            _SettingRow(
              leadingText: 'ex',
              title: 'Exness',
              selected: _settings.provider == ChartProvider.exness,
              onTap: () =>
                  _update(_settings.copyWith(provider: ChartProvider.exness)),
            ),
            _SettingRow(
              leadingText: 'TV',
              title: 'TradingView',
              selected: _settings.provider == ChartProvider.tradingView,
              onTap: () => _update(
                _settings.copyWith(provider: ChartProvider.tradingView),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          'Tùy chọn biểu đồ được áp dụng cho mọi công cụ và tài khoản giao dịch.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 9),
        const _SectionTitle('Truy cập nhanh'),
        _Group(
          children: [
            _SettingRow(
              icon: Icons.calculate_outlined,
              title: 'Máy tính giao dịch',
              onTap: () => _showUnavailable('Máy tính giao dịch'),
            ),
            _SettingRow(
              icon: Icons.monitor_outlined,
              title: 'Phân tích',
              onTap: () => _showUnavailable('Phân tích'),
            ),
            _SettingRow(
              icon: Icons.info_outline,
              title: 'Thông số kỹ thuật',
              onTap: () => _showUnavailable('Thông số kỹ thuật'),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    ),
  );

  Future<void> _showPriceSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Nguồn giá')),
            ListTile(
              title: const Text('Giá mua'),
              trailing: _settings.priceSource == ChartPriceSource.bid
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                _update(_settings.copyWith(priceSource: ChartPriceSource.bid));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Giá bán'),
              trailing: _settings.priceSource == ChartPriceSource.ask
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                _update(_settings.copyWith(priceSource: ChartPriceSource.ask));
                Navigator.pop(context);
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nến lịch sử lấy từ giá Bid; lựa chọn này thay đổi nhãn giá đang theo dõi.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDisplayOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void change(ChartSettings value) {
            _update(value);
            setSheetState(() {});
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Hiển thị trên biểu đồ')),
                SwitchListTile(
                  title: const Text('Giá mua và giá bán'),
                  value: _settings.showPriceLines,
                  onChanged: (value) =>
                      change(_settings.copyWith(showPriceLines: value)),
                ),
                SwitchListTile(
                  title: const Text('Đường lưới'),
                  value: _settings.showGrid,
                  onChanged: (value) =>
                      change(_settings.copyWith(showGrid: value)),
                ),
                SwitchListTile(
                  title: const Text('Trục thời gian'),
                  value: _settings.showTimeScale,
                  onChanged: (value) =>
                      change(_settings.copyWith(showTimeScale: value)),
                ),
                SwitchListTile(
                  title: const Text('Trục giá'),
                  value: _settings.showPriceScale,
                  onChanged: (value) =>
                      change(_settings.copyWith(showPriceScale: value)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUnavailable(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title chưa có dữ liệu từ tài khoản demo.')),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(11),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            children[index],
          ],
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.onTap,
    this.icon,
    this.leadingText,
    this.subtitle,
    this.trailing,
    this.selected = false,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String? leadingText;
  final String? subtitle;
  final String? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: subtitle == null ? 65 : 66,
      child: Row(
        children: [
          const SizedBox(width: 13),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.infoSurface,
            child: leadingText == null
                ? Icon(icon, size: 19, color: AppColors.textSecondary)
                : Text(
                    leadingText!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 12)),
          if (selected) const Icon(Icons.check, size: 20),
          if (!selected && leadingText == null)
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          const SizedBox(width: 13),
        ],
      ),
    ),
  );
}
