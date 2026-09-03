import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/utils/trading_symbol_display.dart';
import 'package:trading_mobile/shared/providers/demo_data_provider.dart';

class ChartObjectsScreen extends ConsumerStatefulWidget {
  const ChartObjectsScreen({
    required this.symbol,
    required this.timeframe,
    super.key,
  });

  final String symbol;
  final String timeframe;

  @override
  ConsumerState<ChartObjectsScreen> createState() => _ChartObjectsScreenState();
}

class _ChartObjectsScreenState extends ConsumerState<ChartObjectsScreen> {
  bool allLocked = false;
  bool allVisible = true;

  @override
  Widget build(BuildContext context) {
    final objects = ref.watch(chartObjectsProvider);
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
                        'Đối tượng',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _TogglePill(
                      icon: allLocked
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.lock_open,
                      label: allLocked ? 'Mở khóa tất cả' : 'Khóa tất cả',
                      onTap: () {
                        setState(() => allLocked = !allLocked);
                        ref
                            .read(chartObjectsProvider.notifier)
                            .setAllLocked(allLocked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TogglePill(
                      icon: allVisible
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                      label: allVisible ? 'Ẩn tất cả' : 'Hiện tất cả',
                      onTap: () {
                        setState(() => allVisible = !allVisible);
                        ref
                            .read(chartObjectsProvider.notifier)
                            .setAllVisible(allVisible);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      _ObjectActionRow(
                        label: 'Thêm Đối Tượng',
                        onTap: _showObjectTypes,
                      ),
                      const Divider(
                        height: 1,
                        indent: 18,
                        color: AppColors.divider,
                      ),
                      _ObjectActionRow(
                        label: 'Thêm văn bản',
                        onTap: () => ref
                            .read(chartObjectsProvider.notifier)
                            .add('Văn bản ${objects.length + 1}'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (objects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickObjectButton(
                      icon: const RotatedBox(
                        quarterTurns: 1,
                        child: Icon(Icons.horizontal_rule),
                      ),
                      type: 'Đường dọc',
                      onTap: _addObject,
                    ),
                    _QuickObjectButton(
                      icon: const Icon(Icons.horizontal_rule),
                      type: 'Đường ngang',
                      onTap: _addObject,
                    ),
                    _QuickObjectButton(
                      icon: Transform.rotate(
                        angle: -.785398,
                        child: const Icon(Icons.horizontal_rule),
                      ),
                      type: 'Đường xu hướng',
                      onTap: _addObject,
                    ),
                    _QuickObjectButton(
                      icon: const _AngleObjectIcon(),
                      type: 'Đường đa đoạn',
                      onTap: _addObject,
                    ),
                    _QuickObjectButton(
                      icon: const _ParallelObjectIcon(),
                      type: 'Thước đo',
                      onTap: _addObject,
                    ),
                    _QuickObjectButton(
                      icon: const Icon(Icons.north_east),
                      type: 'Mũi tên',
                      onTap: _addObject,
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: objects.length,
                  itemBuilder: (context, index) {
                    final object = objects[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        object.visible
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: AppColors.primary,
                        size: 19,
                      ),
                      title: Text(object.type),
                      subtitle: Text(
                        '${displayTradingSymbol(widget.symbol)}, '
                        '${widget.timeframe}',
                        style: const TextStyle(
                          color: AppColors.tradingSecondaryText,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => ref
                            .read(chartObjectsProvider.notifier)
                            .remove(object.id),
                        icon: const Icon(
                          CupertinoIcons.minus_circle_fill,
                          color: AppColors.tradingNegativeText,
                          size: 19,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (objects.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 17, 18, 0),
                child: Text(
                  'Giữ trên đối tượng của biểu đồ để chỉnh sửa hoặc xóa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.tradingSecondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showObjectTypes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in const [
              'Đường ngang',
              'Đường dọc',
              'Đường xu hướng',
              'Hình chữ nhật',
            ])
              ListTile(
                title: Text(type, textAlign: TextAlign.center),
                onTap: () {
                  ref.read(chartObjectsProvider.notifier).add(type);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addObject(String type) {
    ref.read(chartObjectsProvider.notifier).add(type);
  }
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

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        height: 31,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _ObjectActionRow extends StatelessWidget {
  const _ObjectActionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 19,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AngleObjectIcon extends StatelessWidget {
  const _AngleObjectIcon();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 24,
    child: CustomPaint(painter: _AngleObjectPainter()),
  );
}

class _AngleObjectPainter extends CustomPainter {
  const _AngleObjectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.square;
    final path = Path()
      ..moveTo(2.5, 18.5)
      ..lineTo(10.5, 8)
      ..lineTo(15.8, 18.5)
      ..close();
    canvas
      ..drawPath(path, paint)
      ..drawLine(const Offset(2.5, 18.5), const Offset(20.5, 18.5), paint)
      ..drawCircle(const Offset(18.5, 7), 2.6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParallelObjectIcon extends StatelessWidget {
  const _ParallelObjectIcon();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 24,
    child: CustomPaint(painter: _ParallelObjectPainter()),
  );
}

class _ParallelObjectPainter extends CustomPainter {
  const _ParallelObjectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas
      ..drawLine(const Offset(4, 3), const Offset(4, 21), paint)
      ..drawLine(const Offset(20, 3), const Offset(20, 21), paint);
    for (final y in const [5.5, 12.0, 18.5]) {
      canvas.drawCircle(Offset(12, y), 2.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickObjectButton extends StatelessWidget {
  const _QuickObjectButton({
    required this.icon,
    required this.type,
    required this.onTap,
  });

  final Widget icon;
  final String type;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('chart-object-$type'),
    tooltip: type,
    onPressed: () => onTap(type),
    icon: IconTheme(
      data: const IconThemeData(color: AppColors.primary),
      child: icon,
    ),
  );
}
