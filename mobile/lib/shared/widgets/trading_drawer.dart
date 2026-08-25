import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';

class TradingDrawer extends StatelessWidget {
  const TradingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .82,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.candlestick_chart,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tài khoản Demo',
                              style: TextStyle(fontSize: 18),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '109431355 · Trading Demo',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.only(left: 66),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quản lý tài khoản',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _item(context, Icons.show_chart, 'Giao dịch', '/trade'),
            _item(context, Icons.newspaper_outlined, 'Tin tức', null),
            _item(context, Icons.mail_outline, 'Hộp thư', '/messages'),
            _item(context, Icons.list_alt_outlined, 'Nhật ký', null),
            _item(context, Icons.settings_outlined, 'Cài đặt', '/settings'),
            _item(context, Icons.calendar_month_outlined, 'Lịch kinh tế', null),
            _item(context, Icons.groups_outlined, 'Cộng đồng trader', null),
            _item(context, Icons.send_outlined, 'MQL5 Algo Trading', null),
            _item(context, Icons.help_outline, 'Hướng dẫn sử dụng', null),
            _item(context, Icons.info_outline, 'Về chúng tôi', '/profile'),
          ],
        ),
      ),
    );
  }

  static Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String? route,
  ) {
    return ListTile(
      minLeadingWidth: 32,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        if (route != null) {
          context.go(route);
        } else {
          context.push('/section?title=${Uri.encodeComponent(label)}');
        }
      },
    );
  }
}
