import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_shadows.dart';
import 'package:trading_mobile/core/theme/app_typography.dart';
import 'package:trading_mobile/core/theme/reference_typography_profile.dart';
import 'package:trading_mobile/core/theme/tab_reference_metrics.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/chart/data/chart_market_warmup_provider.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';
import 'package:trading_mobile/shared/widgets/mt5_toolbar_icons.dart';
import 'package:trading_mobile/shared/widgets/mt_tab_header_fade.dart';

class AppTabScope extends InheritedWidget {
  const AppTabScope({required this.index, required super.child, super.key});

  final int index;

  static int? maybeIndexOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTabScope>()?.index;

  @override
  bool updateShouldNotify(AppTabScope oldWidget) => index != oldWidget.index;
}

class MtTabTextScope extends StatelessWidget {
  const MtTabTextScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final profile = ReferenceTypographyProfile.maybeOf(context)?.profile;
    if (profile == null || profile == TypographyProfile.reference) return child;
    return DefaultTextStyle.merge(
      style: AppTypography.tabDefault,
      child: child,
    );
  }
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
    ref.listen<AsyncValue<void>>(
      chartMarketWarmupProvider,
      (previous, next) {},
    );
    final accountGeneration = ref.watch(exV2AccountGenerationProvider);
    if (!_accountGenerationInitialized) {
      _accountGenerationInitialized = true;
      _lastAccountGeneration = accountGeneration;
    } else if (_lastAccountGeneration?.value != accountGeneration.value) {
      _lastAccountGeneration = accountGeneration;
      _resettingAccountScope = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_resettingAccountScope) return;
        setState(() => _resettingAccountScope = false);
      });
    } else {
      _lastAccountGeneration = accountGeneration;
    }
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Builder(
        builder: (bodyContext) {
          // Read MediaQuery below Scaffold's extendBody boundary. Scaffold
          // injects the bottom-navigation clearance here; only the oversized
          // device top inset is calibrated to the visual reference.
          final bodyMediaQuery = MediaQuery.of(bodyContext);
          final bodyPadding = bodyMediaQuery.padding;
          final bodyViewPadding = bodyMediaQuery.viewPadding;
          final referenceMediaQuery = bodyMediaQuery.copyWith(
            padding: bodyPadding.copyWith(
              top: math.min(bodyPadding.top, TabReferenceMetrics.topSafeInset),
            ),
            viewPadding: bodyViewPadding.copyWith(
              top: math.min(
                bodyViewPadding.top,
                TabReferenceMetrics.topSafeInset,
              ),
            ),
          );
          return MediaQuery(
            data: referenceMediaQuery,
            child: FadeTransition(
              key: const Key('app-shell-tab-fade'),
              opacity: _tabFade,
              child: _resettingAccountScope
                  ? const ColoredBox(
                      key: Key('account-scope-resetting'),
                      color: AppColors.background,
                    )
                  : KeyedSubtree(
                      key: ValueKey(accountGeneration.value),
                      child: MtTabTextScope(
                        child: AppTabScope(
                          index: widget.navigationShell.currentIndex,
                          child: widget.navigationShell,
                        ),
                      ),
                    ),
            ),
          );
        },
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
    this.selectedColor = AppColors.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationSurface = isDark
        ? AppColors.darkNavigationSurface
        : AppColors.navigationSurface;
    final navigationSelectedSurface = isDark
        ? AppColors.darkNavigationSelectedSurface
        : AppColors.navigationSelectedSurface;
    final navigationUnselected = isDark
        ? AppColors.darkNavigationUnselected
        : AppColors.navigationUnselected;
    final selectionOverhangs =
        TabReferenceMetrics.bottomNavigationSelectionOverhangs(selectedIndex);
    final tradeProfit = ref.watch(
      demoAccountProvider.select((account) => account.profit),
    );
    return SizedBox(
      height: TabReferenceMetrics.bottomNavigationHeight,
      child: ColoredBox(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (selectedIndex != 0)
              const Positioned(
                left: 0,
                top:
                    TabReferenceMetrics.bottomNavigationHeight -
                    TabReferenceMetrics.bottomNavigationFadeHeight,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: MtTabNavigationFade(
                    decorationKey: Key('bottom-navigation-content-fade'),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TabReferenceMetrics.bottomNavigationLeftInset,
                  TabReferenceMetrics.bottomNavigationTopInset,
                  TabReferenceMetrics.bottomNavigationRightInset,
                  TabReferenceMetrics.bottomNavigationBottomInset,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: TabReferenceMetrics.bottomNavigationCapsuleWidth,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: navigationSurface,
                        borderRadius: BorderRadius.circular(
                          TabReferenceMetrics.bottomNavigationCapsuleRadius,
                        ),
                        boxShadow: AppShadows.navigation,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          TabReferenceMetrics.bottomNavigationCapsuleRadius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TabReferenceMetrics
                                .bottomNavigationContentHorizontalInset,
                          ),
                          child: Row(
                            key: ValueKey(selectedIndex),
                            children: List.generate(_items.length, (index) {
                              final selected = selectedIndex == index;
                              final itemSelectedColor =
                                  _items[index].$1 == _MtNavKind.trade
                                  ? tradeProfit < 0
                                        ? AppColors.negative
                                        : selectedColor
                                  : selectedColor;
                              return Expanded(
                                child: Semantics(
                                  key: ValueKey(
                                    'bottom-nav-target-${_items[index].$1.name}',
                                  ),
                                  selected: selected,
                                  label: _items[index].$2,
                                  button: true,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      TabReferenceMetrics
                                          .bottomNavigationInteractionRadius,
                                    ),
                                    onTap: () => onTap(index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: TabReferenceMetrics
                                            .bottomNavigationItemVerticalInset,
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          if (selected)
                                            Positioned(
                                              left: -selectionOverhangs.left,
                                              right: -selectionOverhangs.right,
                                              top:
                                                  TabReferenceMetrics.bottomNavigationSelectionTopInset(
                                                    selectedIndex,
                                                  ),
                                              bottom:
                                                  TabReferenceMetrics.bottomNavigationSelectionBottomInset(
                                                    selectedIndex,
                                                  ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color:
                                                      navigationSelectedSurface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        TabReferenceMetrics
                                                            .bottomNavigationSelectionRadius,
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
                                              unselectedColor:
                                                  navigationUnselected,
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
          ],
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
    required this.unselectedColor,
  });

  final _MtNavKind kind;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final variant = _navigationTypographyVariant(kind, selected);
    final colorRole = selected
        ? selectedColor == AppColors.negative
              ? ReferenceTextColorRole.negative
              : ReferenceTextColorRole.navigationSelected
        : ReferenceTextColorRole.navigationUnselected;
    final labelStyle = AppTypography.forRole(
      context,
      ReferenceTextRole.navigationLabel,
      colorRole: colorRole,
      variant: variant,
    );
    final labelGeometry = AppTypography.geometryForRole(
      context,
      ReferenceTextRole.navigationLabel,
      variant: variant,
    );
    final color = selected
        ? labelStyle.color == selectedColor
              ? labelStyle.color!
              : selectedColor
        : unselectedColor;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: TabReferenceMetrics.bottomNavigationIconTop,
          child: _MtNavIcon(kind, color: color, selected: selected),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: TabReferenceMetrics.bottomNavigationLabelTop,
          child: _applyTypographyGeometry(
            labelGeometry,
            Text(
              label,
              key: ValueKey('bottom-nav-label-${kind.name}'),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: labelStyle.copyWith(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

enum _MtNavKind { quotes, chart, trade, history, settings }

TypographyVariantId _navigationTypographyVariant(
  _MtNavKind kind,
  bool selected,
) => switch ((kind, selected)) {
  (_MtNavKind.quotes, true) => TypographyVariantId.navigationQuotesSelected,
  (_MtNavKind.quotes, false) => TypographyVariantId.navigationQuotesUnselected,
  (_MtNavKind.chart, true) => TypographyVariantId.navigationChartSelected,
  (_MtNavKind.chart, false) => TypographyVariantId.navigationChartUnselected,
  (_MtNavKind.trade, true) => TypographyVariantId.navigationTradeSelected,
  (_MtNavKind.trade, false) => TypographyVariantId.navigationTradeUnselected,
  (_MtNavKind.history, true) => TypographyVariantId.navigationHistorySelected,
  (_MtNavKind.history, false) =>
    TypographyVariantId.navigationHistoryUnselected,
  (_MtNavKind.settings, true) => TypographyVariantId.navigationSettingsSelected,
  (_MtNavKind.settings, false) =>
    TypographyVariantId.navigationSettingsUnselected,
};

Widget _applyTypographyGeometry(TypographyTextGeometry geometry, Widget child) {
  var transformed = child;
  if (geometry.scaleX != 1 || geometry.scaleY != 1) {
    transformed = Transform.scale(
      scaleX: geometry.scaleX,
      scaleY: geometry.scaleY,
      child: transformed,
    );
  }
  if (geometry.dx != 0 || geometry.dy != 0) {
    transformed = Transform.translate(
      offset: Offset(geometry.dx, geometry.dy),
      child: transformed,
    );
  }
  return transformed;
}

class _MtNavIcon extends StatelessWidget {
  const _MtNavIcon(this.kind, {required this.color, required this.selected});

  final _MtNavKind kind;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      key: ValueKey('bottom-nav-icon-${kind.name}'),
      size: const Size.square(TabReferenceMetrics.bottomNavigationIconSize),
      painter: _MtNavIconPainter(kind, color, selected),
    );
    return switch (kind) {
      _MtNavKind.chart => Transform.translate(
        offset: const Offset(
          TabReferenceMetrics.bottomNavigationChartIconOffsetX,
          TabReferenceMetrics.bottomNavigationChartIconOffsetY,
        ),
        child: Transform.scale(
          scaleX: TabReferenceMetrics.bottomNavigationChartIconScaleX,
          scaleY: TabReferenceMetrics.bottomNavigationChartIconScaleY,
          alignment: Alignment.topCenter,
          child: icon,
        ),
      ),
      _MtNavKind.trade => Transform.translate(
        offset: const Offset(
          0,
          TabReferenceMetrics.bottomNavigationTradeIconOffsetY,
        ),
        child: Transform.scale(
          scaleX: TabReferenceMetrics.bottomNavigationTradeIconScaleX,
          scaleY: TabReferenceMetrics.bottomNavigationTradeIconScaleY,
          alignment: Alignment.topLeft,
          child: icon,
        ),
      ),
      _MtNavKind.history => Transform.translate(
        offset: const Offset(
          TabReferenceMetrics.bottomNavigationHistoryIconOffsetX,
          TabReferenceMetrics.bottomNavigationHistoryIconOffsetY,
        ),
        child: Transform.scale(
          scaleX: TabReferenceMetrics.bottomNavigationHistoryIconScaleX,
          scaleY: TabReferenceMetrics.bottomNavigationHistoryIconScaleX,
          alignment: Alignment.topCenter,
          child: icon,
        ),
      ),
      _MtNavKind.quotes => Transform.translate(
        offset: const Offset(
          TabReferenceMetrics.bottomNavigationQuotesIconOffsetX,
          0,
        ),
        child: Transform.scale(
          scaleX: TabReferenceMetrics.bottomNavigationQuotesIconScaleX,
          scaleY: TabReferenceMetrics.bottomNavigationQuotesIconScaleY,
          alignment: Alignment.topCenter,
          child: icon,
        ),
      ),
      _MtNavKind.settings => Transform.translate(
        offset: const Offset(
          TabReferenceMetrics.bottomNavigationSettingsIconOffsetX,
          TabReferenceMetrics.bottomNavigationSettingsIconOffsetY,
        ),
        child: Transform.scale(
          scaleX: TabReferenceMetrics.bottomNavigationSettingsIconScaleX,
          scaleY: TabReferenceMetrics.bottomNavigationSettingsIconScaleY,
          alignment: Alignment.topLeft,
          child: icon,
        ),
      ),
    };
  }
}

class _MtNavIconPainter extends CustomPainter {
  const _MtNavIconPainter(this.kind, this.color, this.selected);

  final _MtNavKind kind;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 27, size.height / 27);
    void draw({required double strokeWidth, required Color layerColor}) {
      final stroke = Paint()
        ..color = layerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fill = Paint()
        ..color = layerColor
        ..style = PaintingStyle.fill;

      switch (kind) {
        case _MtNavKind.quotes:
          // Keep the arrows optically separate. The native glyph is two
          // independent directions (down on the left, up on the right), not a
          // swap/branch icon with touching diagonal rails.
          final downStroke = Paint()
            ..color = stroke.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.strokeWidth + .15
            ..strokeCap = stroke.strokeCap
            ..strokeJoin = stroke.strokeJoin;
          final upStroke = Paint()
            ..color = stroke.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.strokeWidth - .10
            ..strokeCap = stroke.strokeCap
            ..strokeJoin = stroke.strokeJoin;
          canvas.drawLine(
            const Offset(8, 10.5),
            const Offset(8, 22),
            downStroke,
          );
          canvas.drawLine(
            const Offset(3, 17.7),
            const Offset(8, 22),
            downStroke,
          );
          canvas.drawLine(
            const Offset(8, 22),
            const Offset(13, 17.7),
            downStroke,
          );
          canvas.drawLine(
            const Offset(20.3333333333, 16.8),
            const Offset(20.3333333333, 5),
            upStroke,
          );
          canvas.drawLine(
            const Offset(15.8333333333, 9.3),
            const Offset(20.3333333333, 5),
            upStroke,
          );
          canvas.drawLine(
            const Offset(20.3333333333, 5),
            const Offset(24.8333333333, 9.3),
            upStroke,
          );
          break;
        case _MtNavKind.chart:
          stroke.strokeCap = StrokeCap.square;
          canvas.drawLine(
            const Offset(9.2, 2.7),
            const Offset(9.2, 23),
            stroke,
          );
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
              const Rect.fromLTWH(16, 5.8, 4, 11),
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
          canvas.drawRect(const Rect.fromLTWH(3.5, 4, 19.85, 18), stroke);
          final path = Path()
            ..moveTo(7, 17.4)
            ..lineTo(11, 12.1)
            ..lineTo(15.2, 15.7)
            ..lineTo(20.2, 9.6);
          final pathStroke = Paint()
            ..color = stroke.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.strokeWidth + .15
            ..strokeCap = stroke.strokeCap
            ..strokeJoin = stroke.strokeJoin;
          canvas.drawPath(path, pathStroke);
          break;
        case _MtNavKind.history:
          paintMtHistoryClockLayer(
            canvas,
            stroke: stroke,
            fill: fill,
            selected: selected,
          );
          break;
        case _MtNavKind.settings:
          const center = Offset(13.5, 13.5);
          const toothRadii = <double>[8.65, 8.65, 10.65, 10.65, 8.65, 8.65];
          const toothAngles = <double>[-.5, -.31, -.18, .18, .31, .5];
          const toothCount = 6;
          const horizontalCompensation = 1.08;
          const toothStep = math.pi * 2 / toothCount;
          final gear = Path();
          for (var tooth = 0; tooth < toothCount; tooth++) {
            final toothCenter = -math.pi / 2 + tooth * toothStep;
            for (var point = 0; point < toothRadii.length; point++) {
              final angle = toothCenter + toothAngles[point] * toothStep;
              final offset = Offset(
                center.dx +
                    math.cos(angle) *
                        toothRadii[point] *
                        horizontalCompensation,
                center.dy + math.sin(angle) * toothRadii[point],
              );
              if (tooth == 0 && point == 0) {
                gear.moveTo(offset.dx, offset.dy);
              } else {
                gear.lineTo(offset.dx, offset.dy);
              }
            }
          }
          gear.close();
          canvas.drawPath(gear, stroke);
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 6.5, height: 6.9),
            stroke,
          );
          break;
      }
    }

    final (outerWidth, coreWidth, outerAlpha) = switch ((kind, selected)) {
      (_MtNavKind.quotes, false) => (2.70, 1.25, .565),
      (_MtNavKind.quotes, true) => (2.80, 1.25, .565),
      (_MtNavKind.chart, _) => (2.38, 1.50, .565),
      (_MtNavKind.trade, _) => (2.65, 1.35, .565),
      (_MtNavKind.history, _) => (2.78, 1.15, .565),
      (_MtNavKind.settings, _) => (2.65, 1.85, .565),
    };
    draw(
      strokeWidth: outerWidth,
      layerColor: color.withValues(alpha: outerAlpha),
    );
    draw(strokeWidth: coreWidth, layerColor: color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MtNavIconPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected;
}
