import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Recorded empty performance state with locally selectable filters.
class VideoPerformanceScreen extends StatefulWidget {
  const VideoPerformanceScreen({super.key});

  @override
  State<VideoPerformanceScreen> createState() => _VideoPerformanceScreenState();
}

class _VideoPerformanceScreenState extends State<VideoPerformanceScreen> {
  int days = 7;
  String accountFilter = 'Tất cả tài khoản thực';

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('performance-screen'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 46),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          'Hiệu suất',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 15),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Tất cả thời gian trên trang này đều theo múi giờ UTC (GMT+0) và có thể khác so với giờ địa phương của bạn',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            _VideoFilterChip(
              label: accountFilter,
              icon: Icons.keyboard_arrow_down,
              onTap: _selectAccount,
            ),
            const SizedBox(width: 5),
            _VideoFilterChip(
              label: days == 0 ? 'Toàn bộ thời gian' : '$days ngày gần nhất',
              icon: Icons.calendar_today_outlined,
              onTap: _selectDays,
            ),
          ],
        ),
      ),
      const SizedBox(height: 39),
      const Center(
        child: Icon(
          Icons.warning_amber_outlined,
          size: 29,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 7),
      const Center(
        child: Text(
          'Không tìm thấy hoạt động giao dịch nào',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      const Center(
        child: Text(
          'Chọn tài khoản hoặc khoảng thời gian khác nhau.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(height: 13),
      Center(
        child: FilledButton(
          onPressed: () => context.go('/trading'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
            minimumSize: const Size(130, 36),
          ),
          child: const Text('Bắt đầu giao dịch'),
        ),
      ),
    ],
  );

  void _selectDays() => _showOptions(
    'Khoảng thời gian',
    const [
      '7 ngày gần nhất',
      '30 ngày gần nhất',
      '90 ngày gần nhất',
      'Toàn bộ thời gian',
    ],
    (value) => setState(() {
      days = switch (value) {
        '30 ngày gần nhất' => 30,
        '90 ngày gần nhất' => 90,
        'Toàn bộ thời gian' => 0,
        _ => 7,
      };
    }),
  );

  void _selectAccount() => _showOptions('Tài khoản', const [
    'Tất cả tài khoản thực',
    'MỖI NGÀY MỘT TỶ 🍀 · MT5 Pro',
  ], (value) => setState(() => accountFilter = value));

  void _showOptions(
    String title,
    List<String> options,
    ValueChanged<String> onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(title)),
            for (final option in options)
              ListTile(
                title: Text(option),
                trailing:
                    option == accountFilter ||
                        (option ==
                            (days == 0
                                ? 'Toàn bộ thời gian'
                                : '$days ngày gần nhất'))
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  onSelect(option);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoFilterChip extends StatelessWidget {
  const _VideoFilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Icon(icon, size: 14),
        ],
      ),
    ),
  );
}
