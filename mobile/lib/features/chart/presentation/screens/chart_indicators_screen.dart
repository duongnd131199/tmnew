import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class ChartIndicatorsScreen extends ConsumerWidget {
  const ChartIndicatorsScreen({
    required this.symbol,
    required this.timeframe,
    super.key,
  });

  final String symbol;
  final String timeframe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(chartIndicatorsProvider);
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
                    child: _IndicatorRoundButton(
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const Positioned(
                    left: 70,
                    right: 70,
                    top: 41.5,
                    child: Text(
                      'Các chỉ số',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 38, 20, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _showIndicators(context, ref, selected),
                        child: const SizedBox(
                          height: 48,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Text(
                                  'Cửa sổ chính',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 15.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  CupertinoIcons.add_circled,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (final indicator in selected) ...[
                        const Divider(height: 1, indent: 18),
                        SizedBox(
                          height: 46,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18, right: 7),
                            child: Row(
                              children: [
                                Expanded(child: Text(indicator)),
                                IconButton(
                                  onPressed: () => ref
                                      .read(chartIndicatorsProvider.notifier)
                                      .toggle(indicator),
                                  icon: const Icon(
                                    CupertinoIcons.minus_circle_fill,
                                    color: AppColors.negative,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(38, 8, 38, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Thêm chỉ số, vui lòng nhấn trên tiêu đề của cửa sổ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIndicators(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) {
    const items = [
      'Moving Average',
      'Bollinger Bands',
      'Relative Strength Index',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Thêm chỉ báo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              leading: Icon(Icons.functions, color: AppColors.primary),
            ),
            for (final item in items)
              CheckboxListTile(
                title: Text(item),
                value: selected.contains(item),
                onChanged: (_) {
                  ref.read(chartIndicatorsProvider.notifier).toggle(item);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorRoundButton extends StatelessWidget {
  const _IndicatorRoundButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const SizedBox.square(
        dimension: 40,
        child: Center(
          child: Icon(
            CupertinoIcons.chevron_left,
            color: AppColors.textPrimary,
            size: 27,
          ),
        ),
      ),
    ),
  );
}
