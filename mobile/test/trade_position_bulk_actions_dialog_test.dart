import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/theme/app_colors.dart';
import 'package:trading_mobile/core/theme/app_theme.dart';
import 'package:trading_mobile/features/trade/presentation/widgets/position_bulk_actions_dialog.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

const _selectedPosition = DemoPosition(
  id: '10156857101',
  symbol: 'XAUUSD',
  side: 'BUY',
  volume: 1,
  openPrice: 4622.83,
  currentPrice: 4623.10,
  profit: 27,
);

class _DialogHost extends StatelessWidget {
  const _DialogHost({required this.result, this.position = _selectedPosition});

  final ValueNotifier<PositionBulkActionScope?> result;
  final DemoPosition position;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-position-bulk-dialog'),
        onPressed: () async {
          result.value = await showDialog<PositionBulkActionScope>(
            context: context,
            builder: (_) => PositionBulkActionsDialog(position: position),
          );
        },
        child: const Text('Open'),
      ),
    ),
  );
}

Future<void> _pumpOpenDialog(
  WidgetTester tester,
  ValueNotifier<PositionBulkActionScope?> result, {
  Size size = const Size(384, 848),
  DemoPosition position = _selectedPosition,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: _DialogHost(result: result, position: position),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-position-bulk-dialog')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('position bulk dialog matches the video copy and action order', (
    tester,
  ) async {
    final result = ValueNotifier<PositionBulkActionScope?>(null);
    addTearDown(result.dispose);
    await _pumpOpenDialog(tester, result);

    expect(find.text('Hoạt động hàng loạt'), findsOneWidget);
    expect(find.text('#10156857101 buy 1 XAUUSD 4622.83'), findsOneWidget);
    expect(find.text('Đóng Tất Cả Lệnh Có Trạng Thái'), findsOneWidget);
    expect(
      find.text('Đóng Các Lệnh Có Trạng Thái Đang Có Lời'),
      findsOneWidget,
    );
    expect(find.text('Đóng Buy Lệnh có trạng thái'), findsOneWidget);
    expect(find.text('Đóng XAUUSD Lệnh có trạng thái'), findsOneWidget);
    expect(find.text('Đóng XAUUSD Buy Lệnh có trạng thái'), findsOneWidget);
    expect(find.text('Đóng Các Lệnh Có Trạng Thái Đang Lỗ'), findsNothing);

    final orderedKeys = [
      for (final scope in PositionBulkActionScope.values)
        find.byKey(ValueKey('position-bulk-action-${scope.name}')),
      find.byKey(const Key('position-bulk-cancel')),
    ];
    final topEdges = orderedKeys
        .map((finder) => tester.getTopLeft(finder).dy)
        .toList(growable: false);
    expect(topEdges, orderedEquals([...topEdges]..sort()));
  });

  testWidgets('long server ticket keeps every summary field visible', (
    tester,
  ) async {
    final result = ValueNotifier<PositionBulkActionScope?>(null);
    addTearDown(result.dispose);
    const position = DemoPosition(
      id: '894faaa5-5d41-49bd-8a52-5daf0281d948',
      symbol: 'BTCUSD',
      side: 'BUY',
      volume: .25,
      openPrice: 77348.51,
      currentPrice: 77366.83,
      profit: 458,
    );
    await _pumpOpenDialog(tester, result, position: position);

    final subtitle = find.byKey(const Key('position-bulk-subtitle'));
    final text = tester.widget<Text>(subtitle);
    expect(
      text.data,
      '#894faaa5-5d41-49bd-8a52-5daf0281d948 buy 0.25 BTCUSD 77348.51',
    );
    expect(text.overflow, isNull);
    expect(
      find.ancestor(of: subtitle, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
  });

  for (final scope in PositionBulkActionScope.values) {
    testWidgets('position bulk dialog returns ${scope.name}', (tester) async {
      final result = ValueNotifier<PositionBulkActionScope?>(null);
      addTearDown(result.dispose);
      await _pumpOpenDialog(tester, result);

      await tester.tap(
        find.byKey(ValueKey('position-bulk-action-${scope.name}')),
      );
      await tester.pumpAndSettle();

      expect(result.value, scope);
      expect(
        find.byKey(const Key('position-bulk-actions-dialog')),
        findsNothing,
      );
    });
  }

  testWidgets('position bulk cancel returns no action', (tester) async {
    final result = ValueNotifier<PositionBulkActionScope?>(null);
    addTearDown(result.dispose);
    await _pumpOpenDialog(tester, result);

    await tester.tap(find.byKey(const Key('position-bulk-cancel')));
    await tester.pumpAndSettle();

    expect(result.value, isNull);
    expect(find.byKey(const Key('position-bulk-actions-dialog')), findsNothing);
  });

  for (final dismissal in ['barrier', 'back']) {
    testWidgets('position bulk $dismissal returns no action', (tester) async {
      final result = ValueNotifier<PositionBulkActionScope?>(null);
      addTearDown(result.dispose);
      await _pumpOpenDialog(tester, result);

      if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(4, 40));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();

      expect(result.value, isNull);
      expect(
        find.byKey(const Key('position-bulk-actions-dialog')),
        findsNothing,
      );
    });
  }

  testWidgets('position bulk dialog follows the 384 by 848 geometry', (
    tester,
  ) async {
    final result = ValueNotifier<PositionBulkActionScope?>(null);
    addTearDown(result.dispose);
    await _pumpOpenDialog(tester, result);

    final dialog = find.byKey(const Key('position-bulk-actions-dialog'));
    final dialogRect = tester.getRect(dialog);
    expect(dialogRect.height, closeTo(400, 4));
    expect(dialogRect.left, closeTo(16, 1));
    expect(dialogRect.right, closeTo(371, 1));
    expect(dialogRect.top, inInclusiveRange(236, 240));
    expect(dialogRect.bottom, inInclusiveRange(636, 640));

    final titleRect = tester.getRect(
      find.byKey(const Key('position-bulk-title')),
    );
    final subtitleRect = tester.getRect(
      find.byKey(const Key('position-bulk-subtitle')),
    );
    expect(titleRect.left, closeTo(44, 2));
    expect(subtitleRect.left, closeTo(titleRect.left, 1));

    for (final scope in PositionBulkActionScope.values) {
      final actionRect = tester.getRect(
        find.byKey(ValueKey('position-bulk-action-${scope.name}')),
      );
      expect(actionRect.height, closeTo(44, 1));
      expect(actionRect.left, closeTo(30, 1));
      expect(actionRect.right, closeTo(357, 2));
    }

    final surface = tester.widget<DecoratedBox>(dialog);
    expect((surface.decoration as BoxDecoration).color, AppColors.sheetSurface);
  });

  testWidgets('position bulk dialog matches the approved 384 by 848 golden', (
    tester,
  ) async {
    final result = ValueNotifier<PositionBulkActionScope?>(null);
    addTearDown(result.dispose);
    await _pumpOpenDialog(tester, result);

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/trade/position-bulk-actions-384x848.png'),
    );
  });

  for (final width in [360.0, 430.0]) {
    testWidgets('position bulk dialog does not overflow at width $width', (
      tester,
    ) async {
      final result = ValueNotifier<PositionBulkActionScope?>(null);
      addTearDown(result.dispose);
      await _pumpOpenDialog(tester, result, size: Size(width, 848));

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.byKey(const Key('position-bulk-actions-dialog')))
            .width,
        lessThanOrEqualTo(width - 28),
      );
    });
  }
}
