import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'trading presentation contains no infrastructure or success notices',
    () {
      const files = [
        'lib/features/order/presentation/screens/new_order_screen.dart',
        'lib/features/trade/presentation/screens/trade_screen.dart',
        'lib/features/trade/presentation/screens/position_detail_screen.dart',
        'lib/features/chart/presentation/screens/chart_screen.dart',
        'lib/features/wallet/presentation/screens/wallet_request_screen.dart',
        'lib/features/profile/presentation/screens/section_screen.dart',
        'lib/features/history/presentation/screens/history_screen.dart',
        'lib/features/authentication/presentation/screens/register_screen.dart',
      ];
      const forbidden = [
        'lịch sử đang đồng bộ',
        'Đã gửi yêu cầu',
        'Đã đóng ',
        'Lệnh đã được xóa',
        'Vị thế đã được sửa',
        'đang chờ duyệt',
        'đã khớp',
        r': $error',
        r'Đã đặt $type',
        'Báo cáo giao dịch đã được tạo',
        'Đã tạo tài khoản demo',
        'Vui lòng chờ...',
        'Lệnh đã được gửi đến server',
      ];

      for (final path in files) {
        final source = File(path).readAsStringSync();
        for (final phrase in forbidden) {
          expect(
            source,
            isNot(contains(phrase)),
            reason: '$path exposes forbidden feedback: $phrase',
          );
        }
      }

      expect(
        File(
          'lib/features/account_sync/presentation/device_gate.dart',
        ).readAsStringSync(),
        isNot(contains('máy chủ đang lỗi')),
      );
      expect(
        File(
          'lib/features/account_sync/data/ex_v2_api_client.dart',
        ).readAsStringSync(),
        isNot(contains('(HTTP ')),
      );
    },
  );
}
