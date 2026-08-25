import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/features/account_sync/application/ex_v2_account_provider.dart';
import 'package:trading_mobile/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets(
    'notifications renders server records instead of fixed messages',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exV2NotificationsProvider.overrideWithValue(
              const AsyncData([
                {
                  'id': 'notification-1',
                  'title': 'XAUUSD+ order update',
                  'message': 'Order XAUUSD+ accepted',
                  'createdAt': '2026-08-13T08:00:00Z',
                  'isRead': false,
                },
              ]),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XAUUSD order update'), findsOneWidget);
      expect(find.text('Order XAUUSD accepted'), findsOneWidget);
      expect(find.textContaining('XAUUSD+'), findsNothing);
      expect(find.textContaining('Equity'), findsNothing);
    },
  );
}
