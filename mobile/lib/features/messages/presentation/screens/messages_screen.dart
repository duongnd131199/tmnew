import 'package:flutter/material.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/shared/widgets/trading_drawer.dart';
import 'package:trading_mobile/shared/widgets/mt5_toolbar_icons.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const TradingDrawer(),
      appBar: AppBar(
        leadingWidth: 36,
        titleSpacing: 4,
        leading: Builder(
          builder: (context) => IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: Transform.translate(
              offset: const Offset(2, 0),
              child: const MtToolbarIcon(MtToolbarIconKind.menu),
            ),
          ),
        ),
        title: const Text(
          'Tin nhan',
          style: TextStyle(fontSize: 16.2, fontFamily: 'sans-serif-condensed'),
        ),
        actions: [
          InkWell(
            onTap: () => _showInfo(context),
            child: Center(
              child: Transform.translate(
                offset: const Offset(7, 0),
                child: Transform.scale(
                  scale: .92,
                  child: const Text(
                    'MQID',
                    style: TextStyle(
                      color: Colors.white,
                      backgroundColor: Color(0xFF625D5B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () => _showSearch(context),
            icon: Transform.translate(
              offset: const Offset(-2.2, 0),
              child: Transform.scale(
                scale: .84,
                child: const MtToolbarIcon(
                  MtToolbarIconKind.search,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -33),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyChatIcon(),
                    const SizedBox(height: 10),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(.85, 1, 1),
                      child: const Text(
                        'Khong the sao chep ID',
                        style: TextStyle(
                          color: Color(0xFFC2C2C2),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 19.3),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FilledButton(
                    onPressed: () => _showAuth(context, register: true),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'DANG KY',
                      style: TextStyle(
                        fontSize: 14.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.7),
                Expanded(
                  flex: 2,
                  child: FilledButton.tonal(
                    onPressed: () => _showAuth(context, register: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F5FA),
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(44),
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'DANG NHAP',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

  void _showInfo(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('MetaQuotes ID'),
      content: const Text(
        'Đăng nhập để nhận MetaQuotes ID và đồng bộ tin nhắn.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ĐÓNG'),
        ),
      ],
    ),
  );

  void _showSearch(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tìm kiếm tin nhắn'),
      content: const TextField(
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Nhập nội dung',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('XONG'),
        ),
      ],
    ),
  );

  void _showAuth(
    BuildContext context, {
    required bool register,
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            register ? 'Đăng ký MQL5.community' : 'Đăng nhập MQL5.community',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          const TextField(
            decoration: InputDecoration(labelText: 'Đăng nhập hoặc email'),
          ),
          const SizedBox(height: 12),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Mật khẩu'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(register ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyChatIcon extends StatelessWidget {
  const _EmptyChatIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(120, 120), painter: _EmptyChatIconPainter());
}

class _EmptyChatIconPainter extends CustomPainter {
  const _EmptyChatIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(0, 2);
    final fill = Paint()..color = const Color(0xFFE4E4E4);
    canvas.drawOval(const Rect.fromLTWH(0, 2, 120, 110), fill);
    final tail = Path()
      ..moveTo(22, 96)
      ..lineTo(0, 122)
      ..lineTo(43, 112)
      ..close();
    canvas.drawPath(tail, fill);
    final dot = Paint()..color = Colors.white;
    for (final x in const [31.0, 60.0, 89.0]) {
      canvas.drawCircle(Offset(x, 57), 9.3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
