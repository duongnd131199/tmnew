import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/config/video_demo_mode.dart';
import '../features/account/data/account_session.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PhoneStatusBar(),
          Expanded(child: navigationShell),
          _BottomNavigation(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) {
              if (index == 3) {
                ref.invalidate(accountSessionProvider);
                ref.invalidate(historyDealsProvider);
              }
              navigationShell.goBranch(index);
            },
          ),
        ],
      ),
    );
  }
}

class PhoneStatusBar extends ConsumerWidget {
  const PhoneStatusBar({this.light = false, super.key});

  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(videoDemoModeProvider);
    final now = TimeOfDay.now();
    final foreground = light ? Colors.white : AppColors.textPrimary;
    return SizedBox(
      height: 49,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 29),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  demo ? '16:27' : now.format(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: foreground,
                  ),
                ),
                if (demo) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 12,
                    color: foreground,
                  ),
                ],
              ],
            ),
            Flexible(
              child: Container(
                width: 155,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(22),
                  border: light
                      ? Border.all(color: const Color(0xFF301718))
                      : null,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.negative,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.signal_cellular_alt, size: 15, color: foreground),
                const SizedBox(width: 4),
                Icon(Icons.wifi, size: 16, color: foreground),
                const SizedBox(width: 4),
                if (demo)
                  Container(
                    width: 27,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.positive,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '77',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.battery_full,
                    color: AppColors.positive,
                    size: 20,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-height preview sheet with the recording's dark status area.
Future<T?> showVideoExSheet<T>(
  BuildContext context,
  Widget child, {
  double heightFactor = .925,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          const Positioned(
            top: 54,
            left: 18,
            right: 18,
            height: 17,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF5F6F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PhoneStatusBar(light: true),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const items = [
    (Icons.grid_view_outlined, 'Tài khoản', 'account'),
    (Icons.candlestick_chart, 'Giao dịch', 'trading'),
    (Icons.language_outlined, 'Thông tin\nchuyên sâu', 'insights'),
    (Icons.bar_chart_outlined, 'Hiệu suất', 'performance'),
    (Icons.account_circle_outlined, 'Hồ sơ', 'profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bottom-navigation'),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 17),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                key: Key('nav-${items[index].$3}'),
                onTap: () => onTap(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          items[index].$1,
                          size: 24,
                          color: currentIndex == index
                              ? AppColors.textPrimary
                              : const Color(0xFF989CA1),
                        ),
                        if (index == 4)
                          Positioned(
                            right: -3,
                            top: -1,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.negative,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[index].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        height: 1.1,
                        fontSize: 10,
                        fontWeight: currentIndex == index
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: currentIndex == index
                            ? AppColors.textPrimary
                            : const Color(0xFF989CA1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
