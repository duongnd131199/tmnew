import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class AppTabScope extends InheritedWidget {
  const AppTabScope({required this.index, required super.child, super.key});

  final int index;

  static int? maybeIndexOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTabScope>()?.index;

  @override
  bool updateShouldNotify(AppTabScope oldWidget) => index != oldWidget.index;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late int _lastTabIndex;
  ExV2AccountGeneration? _lastAccountGeneration;
  bool _accountGenerationInitialized = false;
  bool _resettingAccountScope = false;
  late final AnimationController _tabFadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );
  late final Animation<double> _tabFade = CurvedAnimation(
    parent: _tabFadeController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _lastTabIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndex = widget.navigationShell.currentIndex;
    if (_lastTabIndex == currentIndex) return;
    _lastTabIndex = currentIndex;
    _tabFadeController
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _tabFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Warmup is deliberately fire-and-forget from the UI's perspective.
    // Loading or failure must never delay navigation or cover the chart.
    ref.watch(chartMarketWarmupProvider);
    final accountGeneration = ref.watch(exV2AccountGenerationProvider);
    if (!_accountGenerationInitialized) {
      _accountGenerationInitialized = true;
      _lastAccountGeneration = accountGeneration;
    } else if (_lastAccountGeneration != accountGeneration) {
      _lastAccountGeneration = accountGeneration;
      _resettingAccountScope = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_resettingAccountScope) return;
        setState(() => _resettingAccountScope = false);
      });
    }
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: FadeTransition(
        key: const Key('app-shell-tab-fade'),
        opacity: _tabFade,
        child: _resettingAccountScope
            ? const ColoredBox(
                key: Key('account-scope-resetting'),
                color: AppColors.background,
              )
            : KeyedSubtree(
                key: ValueKey((
                  accountGeneration.accountId,
                  accountGeneration.value,
                )),
                child: AppTabScope(
                  index: widget.navigationShell.currentIndex,
                  child: widget.navigationShell,
                ),
              ),
      ),
      bottomNavigationBar: keyboardVisible
          ? null
          : MtBottomNavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onTap: (index) {
                final isCurrentBranch =
                    widget.navigationShell.currentIndex == index;
                if (isCurrentBranch && index == 1) {
                  return;
                }
                widget.navigationShell.goBranch(
                  index,
                  initialLocation: isCurrentBranch,
                );
              },
            ),
    );
  }
}

class MtBottomNavigationBar extends ConsumerWidget {
  const MtBottomNavigationBar({
    required this.selectedIndex,
    required this.onTap,
    this.selectedColor = const Color(0xFF25A8F3),
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color selectedColor;

  static const _items = [
    (_MtNavKind.quotes, 'Gia'),
    (_MtNavKind.chart, 'Bieu do'),
    (_MtNavKind.trade, 'Giao dich'),
    (_MtNavKind.history, 'Lich su'),
    (_MtNavKind.settings, 'Cai dat'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesChartChrome = selectedIndex == 1;
    final tradeProfit = ref.watch(
      demoAccountProvider.select((account) => account.profit),
    );
    return SizedBox(
      height: 79,
      child: ColoredBox(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            2.1666666667,
            0,
            15.6333333333,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 346,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: usesChartChrome
                      ? const Color(0xFF121212)
                      : const Color(0xFF19191A),
                  border: Border.all(
                    color: usesChartChrome
                        ? const Color(0xFF2D2D2F)
                        : const Color(0xFF373739),
                    width: .7,
                  ),
                  borderRadius: BorderRadius.circular(31),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(31),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      key: ValueKey(selectedIndex),
                      children: List.generate(_items.length, (index) {
                        final selected = selectedIndex == index;
                        final itemSelectedColor =
                            _items[index].$1 == _MtNavKind.trade
                            ? tradeProfit < 0
                                  ? const Color(0xFFE84C4C)
                                  : selectedColor
                            : selectedColor;
                        return Expanded(
                          child: Semantics(
                            selected: selected,
                            label: _items[index].$2,
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(29),
                              onTap: () => onTap(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3.2,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (selected)
                                      Positioned(
                                        left: usesChartChrome
                                            ? -3.3333333333
                                            : -2,
                                        right: usesChartChrome
                                            ? -1.3333333333
                                            : -2,
                                        top: 0,
                                        bottom: 0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: usesChartChrome
                                                ? const Color(0xFF2D2D2D)
                                                : const Color(0xFF333333),
                                            borderRadius: BorderRadius.circular(
                                              27,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: _NavItem(
                                        kind: _items[index].$1,
                                        label: _items[index].$2,
                                        selected: selected,
                                        selectedColor: itemSelectedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.kind,
    required this.label,
    required this.selected,
    required this.selectedColor,
  });

  final _MtNavKind kind;
  final String label;
  final bool selected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : Colors.white;
    final baseLabelScaleX = switch (kind) {
      _MtNavKind.quotes => .96,
      _MtNavKind.chart => .94,
      _MtNavKind.trade => .97,
      _MtNavKind.settings => .96,
      _ => 1.0,
    };
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(top: 8.7666666667, child: _MtNavIcon(kind, color: color)),
        Positioned(
          left: 0,
          right: 0,
          top: 35.7333333333,
          child: Transform.translate(
            offset: Offset(switch (kind) {
              _MtNavKind.quotes => 1,
              _MtNavKind.chart => -.6666666667,
              _MtNavKind.trade => -.6666666667,
              _MtNavKind.history => 2,
              _MtNavKind.settings => 0,
            }, 0),
            child: Transform.scale(
              scaleX: baseLabelScaleX,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontFamily: 'sans-serif',
                  fontSize: 10.8,
                  height: 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _MtNavKind { quotes, chart, trade, history, settings }

class _MtNavIcon extends StatelessWidget {
  const _MtNavIcon(this.kind, {required this.color});

  final _MtNavKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (kind == _MtNavKind.settings) {
      return Transform.translate(
        offset: const Offset(0, -.6666666667),
        child: Transform.scale(
          scaleX: .98,
          scaleY: 1.04,
          alignment: Alignment.topLeft,
          child: Icon(
            Icons.settings_outlined,
            key: const ValueKey('bottom-nav-icon-settings'),
            size: 23,
            color: color,
          ),
        ),
      );
    }
    final icon = CustomPaint(
      key: ValueKey('bottom-nav-icon-${kind.name}'),
      size: const Size(23, 23),
      painter: _MtNavIconPainter(kind, color),
    );
    return switch (kind) {
      _MtNavKind.chart => Transform.translate(
        offset: const Offset(-1.3333333333, 0),
        child: Transform.scale(
          scaleX: 1,
          scaleY: .93,
          alignment: Alignment.bottomLeft,
          child: icon,
        ),
      ),
      _MtNavKind.trade => Transform.translate(
        offset: const Offset(0, .3333333333),
        child: Transform.scale(scaleY: 1.12, child: icon),
      ),
      _MtNavKind.history => Transform.translate(
        offset: const Offset(1.5, .3333333333),
        child: Transform.scale(scaleX: 1, child: icon),
      ),
      _MtNavKind.quotes => Transform.scale(
        scaleX: 1.04,
        alignment: Alignment.topLeft,
        child: icon,
      ),
      _ => icon,
    };
  }
}

class _MtNavIconPainter extends CustomPainter {
  const _MtNavIconPainter(this.kind, this.color);

  final _MtNavKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 27, size.height / 27);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _MtNavKind.quotes:
        stroke.strokeWidth = 2.35;
        // Keep the arrows optically separate. The native glyph is two
        // independent directions (down on the left, up on the right), not a
        // swap/branch icon with touching diagonal rails.
        canvas.drawLine(const Offset(8, 9), const Offset(8, 22), stroke);
        canvas.drawLine(const Offset(3, 17.7), const Offset(8, 22), stroke);
        canvas.drawLine(const Offset(8, 22), const Offset(13, 17.7), stroke);
        canvas.drawLine(const Offset(19, 17.7), const Offset(19, 5), stroke);
        canvas.drawLine(const Offset(14, 9.3), const Offset(19, 5), stroke);
        canvas.drawLine(const Offset(19, 5), const Offset(24, 9.3), stroke);
        break;
      case _MtNavKind.chart:
        stroke.strokeWidth = 1.9;
        stroke.strokeCap = StrokeCap.square;
        canvas.drawLine(const Offset(9.2, 2.7), const Offset(9.2, 23), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.6, 9, 6.4, 10.7),
            const Radius.circular(.35),
          ),
          fill,
        );
        canvas.drawLine(
          const Offset(18.4, 2.7),
          const Offset(18.4, 5.8),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 5.8, 4.8, 11),
            const Radius.circular(.35),
          ),
          stroke,
        );
        canvas.drawLine(
          const Offset(18.4, 16.8),
          const Offset(18.4, 20.2),
          stroke,
        );
        break;
      case _MtNavKind.trade:
        stroke.strokeWidth = 2.05;
        canvas.drawRect(const Rect.fromLTWH(3.5, 4, 20, 18), stroke);
        final path = Path()
          ..moveTo(6.2, 18.2)
          ..lineTo(11, 12.1)
          ..lineTo(15.2, 15)
          ..lineTo(21, 8);
        canvas.drawPath(path, stroke);
        break;
      case _MtNavKind.history:
        stroke.strokeWidth = 2.05;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(13.5, 13.5), radius: 10.2),
          math.pi * .9777777778,
          math.pi * 1.7611111111,
          false,
          stroke,
        );
        final arrow = Path()
          ..moveTo(.6, 13.3)
          ..lineTo(5, 11.05)
          ..lineTo(4.75, 15.05)
          ..close();
        canvas.drawPath(arrow, fill);
        canvas.drawLine(
          const Offset(13.85, 14.25),
          const Offset(13.85, 9),
          stroke,
        );
        canvas.drawLine(
          const Offset(13.85, 14.25),
          const Offset(17.6, 18.35),
          stroke,
        );
        break;
      case _MtNavKind.settings:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MtNavIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
