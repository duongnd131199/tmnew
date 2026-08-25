import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/features/market_watch/domain/market_symbol_policy.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class SymbolEditScreen extends ConsumerStatefulWidget {
  const SymbolEditScreen({super.key});

  @override
  ConsumerState<SymbolEditScreen> createState() => _SymbolEditScreenState();
}

class _SymbolEditScreenState extends ConsumerState<SymbolEditScreen> {
  final Set<String> selectedSymbols = {};

  @override
  Widget build(BuildContext context) {
    final symbols = ref.watch(marketSymbolsProvider);
    selectedSymbols.removeWhere(
      (symbol) => !symbols.contains(symbol) || !canRemoveMarketSymbol(symbol),
    );
    final layoutScale = (MediaQuery.sizeOf(context).width / 384)
        .clamp(.94, 1.12)
        .toDouble();
    final rowHeight = 66 * layoutScale;
    final rowTopPadding = 4 * layoutScale;
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
                    child: _RoundButton(
                      onTap: () => context.pop(),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: AppColors.textPrimary,
                        size: 27,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 41.5,
                    child: IgnorePointer(
                      child: Text(
                        'Giá',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 65,
                    top: 29,
                    child: selectedSymbols.isEmpty
                        ? _RoundButton(
                            onTap: () => context.push('/market/columns'),
                            child: const Icon(
                              Icons.checklist_rounded,
                              color: AppColors.textPrimary,
                              size: 21,
                            ),
                          )
                        : _EditActionsPill(
                            onDelete: () {
                              ref
                                  .read(marketSymbolsProvider.notifier)
                                  .removeAll(selectedSymbols);
                              setState(selectedSymbols.clear);
                            },
                            onColumns: () => context.push('/market/columns'),
                          ),
                  ),
                  Positioned(
                    right: 16,
                    top: 29,
                    child: _RoundButton(
                      onTap: () => context.push('/market/search'),
                      child: const Icon(
                        CupertinoIcons.search,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.only(top: rowTopPadding),
                buildDefaultDragHandles: false,
                itemCount: symbols.length,
                onReorderItem: ref.read(marketSymbolsProvider.notifier).reorder,
                itemBuilder: (context, index) {
                  final symbol = symbols[index];
                  final selectable = canRemoveMarketSymbol(symbol);
                  final selected = selectedSymbols.contains(symbol);
                  return SizedBox(
                    key: ValueKey(symbol),
                    height: rowHeight,
                    child: Stack(
                      children: [
                        if (selectable)
                          Positioned(
                            left: 7 * layoutScale,
                            top: 0,
                            bottom: 0,
                            width: 44 * layoutScale,
                            child: GestureDetector(
                              key: ValueKey('symbol-select-$symbol'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() {
                                selected
                                    ? selectedSymbols.remove(symbol)
                                    : selectedSymbols.add(symbol);
                              }),
                              child: Center(
                                child: Icon(
                                  selected
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 47 * layoutScale,
                          top: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayTradingSymbol(symbol),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 5 * layoutScale,
                          top: 0,
                          bottom: 0,
                          width: 44 * layoutScale,
                          child: ReorderableDragStartListener(
                            index: index,
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.line_horizontal_3,
                                color: AppColors.textTertiary,
                                size: 20,
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
          ],
        ),
      ),
    );
  }
}

class _EditActionsPill extends StatelessWidget {
  const _EditActionsPill({required this.onDelete, required this.onColumns});

  final VoidCallback onDelete;
  final VoidCallback onColumns;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.divider, width: .6),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 89,
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('symbol-edit-delete'),
              onTap: onDelete,
              child: const Center(
                child: Icon(
                  CupertinoIcons.delete,
                  color: AppColors.negative,
                  size: 21,
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onColumns,
              child: const Center(
                child: Icon(
                  Icons.checklist_rounded,
                  color: AppColors.textPrimary,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider, width: .6),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(dimension: 40, child: Center(child: child)),
    ),
  );
}

class MarketColumnsScreen extends ConsumerWidget {
  const MarketColumnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(marketColumnsProvider);
    const optional = [
      'Giá mua cao',
      'Giá mua thấp',
      'Giá bán cao',
      'Giá bán thấp',
      'Giá cuối',
      'Giá cuối cao',
      'Giá cuối thấp',
      'Thời gian',
      'Spread',
    ];
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
                    child: _RoundButton(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: AppColors.textPrimary,
                        size: 27,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 41.5,
                    child: IgnorePointer(
                      child: Text(
                        'Cột',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: visible.length,
                    onReorderItem: ref
                        .read(marketColumnsProvider.notifier)
                        .reorder,
                    itemBuilder: (context, index) {
                      final label = visible[index];
                      return ColoredBox(
                        key: ValueKey(label),
                        color: AppColors.surface,
                        child: _ColumnRow(
                          label: label,
                          remove: true,
                          onTap: () => ref
                              .read(marketColumnsProvider.notifier)
                              .remove(label),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Icon(
                                CupertinoIcons.line_horizontal_3,
                                color: AppColors.textTertiary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ColoredBox(
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        for (final label in optional)
                          if (!visible.contains(label))
                            _ColumnRow(
                              label: label,
                              remove: false,
                              onTap: () => ref
                                  .read(marketColumnsProvider.notifier)
                                  .add(label),
                            ),
                      ],
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

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    required this.label,
    required this.remove,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool remove;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 45,
    child: Row(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            remove
                ? CupertinoIcons.minus_circle_fill
                : CupertinoIcons.add_circled_solid,
            color: remove ? AppColors.negative : const Color(0xFF30D158),
            size: 18,
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
        if (trailing case final Widget trailingWidget) trailingWidget,
      ],
    ),
  );
}
