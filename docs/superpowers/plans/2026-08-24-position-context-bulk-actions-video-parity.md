# Position-context Bulk Actions Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khi người dùng chạm một position trong tab Giao dịch rồi chọn `Hoạt động hàng loạt...`, luôn mở đúng dialog theo position và cung cấp đủ năm thao tác đóng lệnh giống video mẫu tại 22.6–32.0 giây.

**Architecture:** Giữ nguyên menu hàng loạt chung ở dấu ba chấm của tiêu đề và toàn bộ luồng pending order. Tạo một dialog trình bày thuần cho ngữ cảnh position, trả về một scope đóng lệnh; `TradeScreen` chỉ điều phối route/modal, còn `DemoTradingController` lọc snapshot position hiện tại và tái sử dụng `closePosition` để giữ nguyên cơ chế demo/EX V2, lịch sử, số dư và đồng bộ hiện có.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Material 3, Flutter widget/golden tests, Android debug APK, LDPlayer/ADB, ASP.NET Core 8 verification.

**Spec:** `giaoDienMau/giaodientrang.MP4` tại 22.6–32.0 giây; `docs/superpowers/specs/2026-08-24-video-white-theme-parity-design.md`; yêu cầu người dùng ngày 2026-08-24 bổ sung hành vi contextual bulk actions và vì vậy chỉ ghi đè non-goal “không đổi behavior” của spec cũ trong phạm vi này.

## Global Constraints

- Không đổi Flutter, Dart, Riverpod, GoRouter, Material 3, Dio, SignalR hoặc ASP.NET Core.
- Chỉ áp dụng menu contextual cho open position được chọn; pending order và menu ba chấm chung của section giữ nguyên hành vi hiện tại.
- Không thêm API, migration hoặc schema backend; mọi close vẫn đi qua `DemoTradingController.closePosition` và luồng EX V2 hiện hữu.
- Không mutate trực tiếp danh sách position trong widget và không tạo giá đóng/profit giả để khớp ảnh.
- Không thay đổi route Đóng trạng thái, Sửa trạng thái, Giao dịch, Depth of Market, Biểu đồ hoặc Close By.
- Giữ silent-feedback policy hiện tại: thao tác có tập đích rỗng chỉ đóng dialog, không hiện snackbar giả; lỗi server tiếp tục do cơ chế EX V2 hiện hữu xử lý/reconcile.
- Năm action contextual luôn xuất hiện theo đúng thứ tự video, kể cả khi hai scope tạm thời chọn cùng một tập position.
- Mỗi action tính target từ `state.positions` ngay lúc bấm, theo thứ tự đang có trong state, để không dùng snapshot cũ từ lúc mở dialog.
- Điều kiện có lời là `profit > 0`; `profit == 0` không thuộc scope có lời.
- Side được so sánh sau khi chuẩn hóa uppercase; label hiển thị title case (`Buy`/`Sell`), subtitle dùng lowercase (`buy`/`sell`). Symbol hiển thị và so sánh đúng chuỗi server cung cấp, bao gồm suffix như `+` nếu có.
- Dùng `AppColors.sheetSurface`, `AppColors.sheetActionSurface`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.destructive`, `AppSpacing` và `AppRadius`; không thêm literal màu mới.
- Viewport đối chiếu chuẩn là 384 × 848 từ video. Vùng app-owned cần khớp hình học; status bar, Dynamic Island, notification banner, giá/P&L realtime và rasterization font hệ điều hành được loại khỏi pixel parity.
- Checkout đang bẩn. Không reset/revert file của người dùng; trước mỗi commit dùng `git diff` và stage theo hunk khi file có thay đổi không thuộc task.
- Sau từng task code: chạy focused Flutter tests, `flutter analyze`, `flutter build apk --debug`, `dotnet build Trading.sln` và `dotnet test Trading.sln --no-build`. Cuối cùng chạy full `flutter test`.

## Reference Contract

Tại frame 27.4–29.0 giây, dialog contextual trên canvas 384 × 848 có các nội dung sau:

1. Tiêu đề trái: `Hoạt động hàng loạt`.
2. Subtitle động: `#<ticket> <side lowercase> <volume> <symbol> <open price>`; ví dụ `#10156857101 buy 1 XAUUSD 4622.83`.
3. `Đóng Tất Cả Lệnh Có Trạng Thái`.
4. `Đóng Các Lệnh Có Trạng Thái Đang Có Lời`.
5. `Đóng Buy Lệnh có trạng thái` hoặc `Đóng Sell Lệnh có trạng thái`.
6. `Đóng XAUUSD Lệnh có trạng thái` với symbol của position đã chọn.
7. `Đóng XAUUSD Buy Lệnh có trạng thái` với symbol và side của position đã chọn.
8. `Hủy`.

Các action 3–7 dùng màu destructive. Dialog khoảng x=16–371, y=238–638 trên frame chuẩn; action pill khoảng 46 px cao, gap khoảng 8 px, radius khoảng 23 px. Giá trị cuối phải được hiệu chỉnh bằng ảnh LDPlayer, không sao chép mù pixel nén từ video.

## Approach Decision

- **Chọn:** dialog contextual độc lập + controller filter API. Cách này tách UI theo video khỏi menu chung, giữ nghiệp vụ ngoài widget và cho phép kiểm thử từng scope.
- **Không chọn:** thêm `DemoPosition?` vào dialog generic hiện tại. Diff nhỏ hơn nhưng tạo hai cấu trúc/action-order trong một hàm và dễ làm hỏng test/menu ba chấm chung.
- **Không chọn:** widget tự lọc ID rồi gọi `closePosition` nhiều lần. Cách này làm UI sở hữu quy tắc tài chính, dễ dùng snapshot cũ và khó tái sử dụng/kiểm thử ở server mode.

---

### Task 1: Khóa contract lọc position trong controller

**Files:**
- Modify: `mobile/test/demo_trading_controller_test.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart:1233`

**Interfaces:**
- Consumes: `DemoTradingState.positions`, `DemoTradingController.closePosition(String positionId, {double? volume, double? realizedProfit})`.
- Produces: `int closeMatchingPositions({bool profitableOnly = false, bool losingOnly = false, String? symbol, String? side})`; giữ `closeAllPositions({bool profitableOnly = false, bool losingOnly = false})` như wrapper tương thích ngược.

- [ ] **Step 1: Viết fixture có thể phân biệt đủ năm scope**

Thêm helper cục bộ trong `demo_trading_controller_test.dart` với bốn position: XAUUSD BUY có lời, XAUUSD BUY lỗ, XAUUSD SELL có lời, EURUSD BUY có lời. Override `demoTradingSeedProvider` bằng state này để mỗi assertion có container mới và không phụ thuộc quote timer.

```dart
DemoTradingState contextualBulkSeed(String accountId) => const DemoTradingState(
  balance: 100000,
  positions: [
    DemoPosition(id: 'x-buy-win', symbol: 'XAUUSD', side: 'BUY', volume: 1,
      openPrice: 4622.83, currentPrice: 4623.10, profit: 27),
    DemoPosition(id: 'x-buy-loss', symbol: 'XAUUSD', side: 'BUY', volume: 2,
      openPrice: 4624.00, currentPrice: 4623.10, profit: -90),
    DemoPosition(id: 'x-sell-win', symbol: 'XAUUSD', side: 'SELL', volume: .5,
      openPrice: 4624.10, currentPrice: 4623.10, profit: 50),
    DemoPosition(id: 'e-buy-win', symbol: 'EURUSD', side: 'BUY', volume: .1,
      openPrice: 1.10, currentPrice: 1.11, profit: 10),
  ],
  deals: [],
);
```

- [ ] **Step 2: Viết các test RED cho filter và tương thích ngược**

Mỗi case dùng container mới. Assert số lượng trả về, ID còn lại và thứ tự history append cho `profitableOnly`, `symbol: 'XAUUSD'`, `side: 'buy'`, kết hợp symbol+side, cùng wrapper cũ `closeAllPositions(losingOnly: true)`.

```dart
final closed = controller.closeMatchingPositions(
  symbol: 'XAUUSD',
  side: 'buy',
);
expect(closed, 2);
expect(
  container.read(demoPositionsProvider).map((item) => item.id),
  orderedEquals(['x-sell-win', 'e-buy-win']),
);
```

- [ ] **Step 3: Chạy test để xác nhận RED**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\demo_trading_controller_test.dart --plain-name "contextual bulk"
```

Expected: FAIL vì `closeMatchingPositions` chưa tồn tại.

- [ ] **Step 4: Cài đặt filter tối thiểu trong controller**

Chuẩn hóa side một lần, chụp ID đích trước khi close để không duyệt một list đang mutate, rồi gọi `closePosition` theo thứ tự state. Giữ wrapper cũ để tất cả caller/test hiện tại tiếp tục hoạt động.

```dart
int closeMatchingPositions({
  bool profitableOnly = false,
  bool losingOnly = false,
  String? symbol,
  String? side,
}) {
  final normalizedSide = side?.trim().toUpperCase();
  final targets = state.positions
      .where((position) =>
          (!profitableOnly || position.profit > 0) &&
          (!losingOnly || position.profit < 0) &&
          (symbol == null || position.symbol == symbol) &&
          (normalizedSide == null || position.side.toUpperCase() == normalizedSide))
      .map((position) => position.id)
      .toList(growable: false);
  for (final id in targets) {
    closePosition(id);
  }
  return targets.length;
}

int closeAllPositions({
  bool profitableOnly = false,
  bool losingOnly = false,
}) => closeMatchingPositions(
  profitableOnly: profitableOnly,
  losingOnly: losingOnly,
);
```

- [ ] **Step 5: Chạy quality gate của task**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\demo_trading_controller_test.dart
flutter analyze
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS; các test `single and bulk closes append history in execution order` hiện hữu vẫn xanh.

- [ ] **Step 6: Commit riêng controller contract nếu worktree cho phép**

Inspect `git diff -- mobile/test/demo_trading_controller_test.dart mobile/lib/shared/providers/demo_data_provider.dart`; stage theo hunk để không lấy thay đổi có sẵn của người dùng, rồi commit `feat(trade): add scoped position bulk close`.

---

### Task 2: Dựng dialog contextual đúng nội dung và hình học video

**Files:**
- Create: `mobile/lib/features/trade/presentation/trade_formatters.dart`
- Create: `mobile/lib/features/trade/presentation/widgets/position_bulk_actions_dialog.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart:28-31`
- Create: `mobile/test/trade_position_bulk_actions_dialog_test.dart`
- Create after visual approval: `mobile/test/goldens/trade/position-bulk-actions-384x848.png`

**Interfaces:**
- Consumes: `DemoPosition`, semantic tokens trong `core/theme`.
- Produces: `enum PositionBulkActionScope { all, profitable, sameSide, sameSymbol, sameSymbolAndSide }`; `PositionBulkActionsDialog({required DemoPosition position})`; kết quả được trả qua `Navigator.pop(context, scope)`.

- [ ] **Step 1: Viết test RED cho copy, thứ tự và dữ liệu động**

Pump `Dialog(child: PositionBulkActionsDialog(position: selected))` ở 384 × 848 với position `#10156857101`, `BUY`, volume `1`, `XAUUSD`, open price `4622.83`. Assert đúng title/subtitle và đúng thứ tự năm destructive labels + `Hủy`; assert không có `Đóng Các Lệnh Có Trạng Thái Đang Lỗ`.

```dart
expect(find.text('Hoạt động hàng loạt'), findsOneWidget);
expect(find.text('#10156857101 buy 1 XAUUSD 4622.83'), findsOneWidget);
expect(find.text('Đóng Buy Lệnh có trạng thái'), findsOneWidget);
expect(find.text('Đóng XAUUSD Lệnh có trạng thái'), findsOneWidget);
expect(find.text('Đóng XAUUSD Buy Lệnh có trạng thái'), findsOneWidget);
expect(find.text('Đóng Các Lệnh Có Trạng Thái Đang Lỗ'), findsNothing);
```

- [ ] **Step 2: Viết test RED cho kết quả từng nút và Hủy**

Mở dialog bằng `showDialog<PositionBulkActionScope>`, tap từng label trong các test parameterized và assert `Future` trả đúng enum. Tap `Hủy` và assert kết quả `null`; tap barrier và back cũng không phát sinh scope.

- [ ] **Step 3: Viết test RED cho geometry/token**

Gắn key `position-bulk-actions-dialog`, `position-bulk-title`, `position-bulk-subtitle`, `position-bulk-action-<scope>` và `position-bulk-cancel`. Ở viewport chuẩn, assert dialog gần x=16, width=352–356, action cao 46 ±1, gap 8–9, title/subtitle trái; inspect decoration dùng semantic sheet/action surface và destructive color. Test thêm viewport rộng 360 và 430 để không overflow.

- [ ] **Step 4: Chạy test để xác nhận RED**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\trade_position_bulk_actions_dialog_test.dart
```

Expected: FAIL vì widget/enum/key chưa tồn tại.

- [ ] **Step 5: Cài đặt widget thuần và formatter hiển thị**

Dialog không đọc provider. Tạo danh sách action cố định theo thứ tự reference, dùng `FittedBox(scaleDown)` chỉ để chống overflow ở symbol dài, và trả enum qua Navigator.

```dart
enum PositionBulkActionScope {
  all,
  profitable,
  sameSide,
  sameSymbol,
  sameSymbolAndSide,
}

String positionBulkSummary(DemoPosition position) =>
    '#${position.id} ${position.side.toLowerCase()} '
    '${formatTradeVolume(position.volume)} ${position.symbol} '
    '${formatTradePrice(position.symbol, position.openPrice)}';
```

Tạo `trade_formatters.dart` chứa `tradePriceDigitsForSymbol`, `formatTradePrice`, `formatTradeVolume` và `formatPositionBulkOpenPrice`. Chuyển nguyên logic hiện tại của `_tradePriceDigitsForSymbol`/`_tradeVolumeLabel` sang hai hàm public đầu tương ứng và sửa caller trong `trade_screen.dart` mà không đổi output row. `formatPositionBulkOpenPrice` bắt đầu từ precision symbol hiện tại rồi chỉ trim số `0` ở cuối và dấu chấm rỗng; vì vậy `4622.830` thành `4622.83` đúng reference nhưng chữ số có nghĩa không bị mất.

```dart
String formatPositionBulkOpenPrice(String symbol, double value) {
  final fixed = value.toStringAsFixed(tradePriceDigitsForSymbol(symbol));
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
```

- [ ] **Step 6: Tạo golden chỉ sau khi test geometry xanh và kiểm tra bằng mắt**

Render fixture chuẩn ở 384 × 848, cập nhật golden bằng `flutter test --update-goldens test\trade_position_bulk_actions_dialog_test.dart`, rồi mở cả golden và frame video 29.0 giây để so title baseline, dialog bounds, pill height/gap, radius, barrier và màu. Nếu khác, sửa token/layout rồi tạo lại; không chấp nhận golden chỉ vì test tự sinh pass.

- [ ] **Step 7: Chạy quality gate của task**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\trade_position_bulk_actions_dialog_test.dart
flutter analyze
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS và không overflow ở 360/384/430 logical px.

- [ ] **Step 8: Commit riêng dialog nếu worktree cho phép**

Stage đúng các file formatter/dialog/test/golden và hunk import/helper trong `trade_screen.dart`; commit `feat(trade): add contextual bulk actions dialog`. Không stage thay đổi theme đang có sẵn ngoài các hunk thật sự cần cho dialog.

---

### Task 3: Mở dialog sau khi position sheet đóng hoàn toàn

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart:410-533`
- Modify: `mobile/test/video_interactions_test.dart`

**Interfaces:**
- Consumes: `PositionBulkActionsDialog`, `PositionBulkActionScope`.
- Produces: `_showPositionActions(...) -> Future<void>`; chỉ nhánh `Hoạt động hàng loạt...` trả sentinel `_PositionMenuResult.bulk`, chờ bottom sheet hoàn tất rồi mới gọi `showDialog`.

- [ ] **Step 1: Viết regression test RED cho chuỗi hai modal**

Tap `trade-position-<id>`, xác nhận position sheet hiện, tap `Hoạt động hàng loạt...`, `pumpAndSettle`, rồi assert bottom sheet đã biến mất và chỉ còn một dialog contextual mang đúng ticket. Test lặp lại hai lần để bắt lỗi route race.

```dart
await tester.tap(find.byKey(ValueKey('trade-position-${selected.id}')));
await tester.pumpAndSettle();
await tester.tap(find.text('Hoạt động hàng loạt...'));
await tester.pumpAndSettle();
expect(find.byType(BottomSheet), findsNothing);
expect(find.byKey(const Key('position-bulk-actions-dialog')), findsOneWidget);
expect(find.textContaining('#${selected.id} buy'), findsOneWidget);
```

- [ ] **Step 2: Chạy test để xác nhận RED**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\video_interactions_test.dart --plain-name "selected position opens contextual bulk actions"
```

Expected: FAIL vì code hiện tại pop sheet và gọi dialog generic ngay trong cùng callback, không truyền selected position.

- [ ] **Step 3: Cài đặt hand-off qua kết quả modal**

Đổi `_showPositionActions` thành async. `Hoạt động hàng loạt...` chỉ `Navigator.pop(sheetContext, _PositionMenuResult.bulk)`. Sau `await showModalBottomSheet`, kiểm tra `context.mounted`; nếu kết quả là bulk thì `await showDialog<PositionBulkActionScope>` với selected position. Các callback route/action còn lại giữ nguyên để giảm phạm vi hồi quy.

Đổi dòng mở hiện tại thành `final result = await showModalBottomSheet<_PositionMenuResult>(` và giữ nguyên toàn bộ `builder`/layout hiện hữu. Thay riêng callback bulk bằng:

```dart
onTap: () => Navigator.pop(
  sheetContext,
  _PositionMenuResult.bulk,
),
```

Ngay sau dấu `);` kết thúc `showModalBottomSheet`, thêm:

```dart
if (!context.mounted || result != _PositionMenuResult.bulk) return;
final scope = await showDialog<PositionBulkActionScope>(
  context: context,
  builder: (_) => PositionBulkActionsDialog(position: position),
);
if (!context.mounted || scope == null) return;
_executePositionBulkAction(ref, position, scope);
```

- [ ] **Step 4: Khóa các đường thoát và entry point không liên quan**

Thêm assertion: bấm `Hủy` ở position sheet không mở dialog; bấm `Hủy`, barrier hoặc back ở dialog không mutate; menu dấu ba chấm section vẫn mở `trade-bulk-actions-dialog`; pending-order menu vẫn dùng hành vi hiện tại.

- [ ] **Step 5: Chạy quality gate của task**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\video_interactions_test.dart test\video2_functional_regression_test.dart test\tab_swipe_reset_test.dart
flutter analyze
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS; không có stacked modal, exception `deactivated widget`, hoặc dialog mở phía sau sheet.

- [ ] **Step 6: Commit riêng modal sequencing nếu worktree cho phép**

Inspect và stage theo hunk trong `trade_screen.dart` vì file liên quan tới nhiều chức năng. Commit `fix(trade): sequence position bulk action modal`.

---

### Task 4: Nối năm action contextual vào đúng scope nghiệp vụ

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart:322-533`
- Create: `mobile/test/trade_position_bulk_actions_flow_test.dart`
- Modify: `mobile/test/video2_cross_tab_test.dart:269-346`
- Modify: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `DemoTradingController.closeMatchingPositions`, `PositionBulkActionScope`.
- Produces: `int _executePositionBulkAction(WidgetRef ref, DemoPosition selected, PositionBulkActionScope scope)`; không đổi `_showBulkActions` generic.

- [ ] **Step 1: Viết UI-flow tests RED cho cả năm action**

Dùng fixture mixed ở Task 1. Với mỗi scope, mở đúng chuỗi position → `Hoạt động hàng loạt...` → action; assert dialog đóng, đúng ID biến mất, ID ngoài scope còn nguyên và history append đúng số lượng. Các expected target:

```dart
const expectedClosedIds = {
  PositionBulkActionScope.all: {'x-buy-win', 'x-buy-loss', 'x-sell-win', 'e-buy-win'},
  PositionBulkActionScope.profitable: {'x-buy-win', 'x-sell-win', 'e-buy-win'},
  PositionBulkActionScope.sameSide: {'x-buy-win', 'x-buy-loss', 'e-buy-win'},
  PositionBulkActionScope.sameSymbol: {'x-buy-win', 'x-buy-loss', 'x-sell-win'},
  PositionBulkActionScope.sameSymbolAndSide: {'x-buy-win', 'x-buy-loss'},
};
```

- [ ] **Step 2: Chạy flow test để xác nhận RED**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\trade_position_bulk_actions_flow_test.dart
```

Expected: FAIL vì scope chưa được ánh xạ tới controller.

- [ ] **Step 3: Cài đặt mapping duy nhất từ enum sang controller**

```dart
int _executePositionBulkAction(
  WidgetRef ref,
  DemoPosition selected,
  PositionBulkActionScope scope,
) {
  final controller = ref.read(demoTradingProvider.notifier);
  return switch (scope) {
    PositionBulkActionScope.all => controller.closeMatchingPositions(),
    PositionBulkActionScope.profitable =>
      controller.closeMatchingPositions(profitableOnly: true),
    PositionBulkActionScope.sameSide =>
      controller.closeMatchingPositions(side: selected.side),
    PositionBulkActionScope.sameSymbol =>
      controller.closeMatchingPositions(symbol: selected.symbol),
    PositionBulkActionScope.sameSymbolAndSide =>
      controller.closeMatchingPositions(symbol: selected.symbol, side: selected.side),
  };
}
```

Không đóng selected position riêng trước; mọi action chỉ chạy đúng một controller call để tránh double-close và double-history.

- [ ] **Step 4: Khóa server-mode dispatch đúng tập đích**

Trong `ex_v2_trading_command_test.dart`, seed server state với bốn ID giống fixture mixed, gọi `closeMatchingPositions(symbol: 'XAUUSD', side: 'BUY')`, chờ các future command hoàn tất và assert fake repository chỉ nhận `x-buy-win`, `x-buy-loss` đúng một lần mỗi ID. Assert không có request cho `x-sell-win`/`e-buy-win`; giữ nguyên assertion idempotency và authoritative reconciliation hiện có.

- [ ] **Step 5: Khóa menu chung không hồi quy**

Giữ test hiện hữu ở `video2_cross_tab_test.dart` cho ba action của `trade-bulk-menu`: tất cả, có lời, đang lỗ. Bổ sung assertion dialog chung không có subtitle ticket và không có label symbol/side contextual. Đây là ranh giới bảo vệ các chức năng khác.

- [ ] **Step 6: Chạy quality gate của task**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\trade_position_bulk_actions_flow_test.dart test\demo_trading_controller_test.dart test\video2_cross_tab_test.dart test\history_screen_detail_test.dart test\ex_v2_trading_command_test.dart
flutter analyze
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS; History/balance/account sync hiện hữu không đổi ngoài các position thật sự thuộc scope.

- [ ] **Step 7: Commit riêng flow mapping nếu worktree cho phép**

Stage đúng hunk/file của task và commit `feat(trade): execute contextual bulk close scopes`.

---

### Task 5: Tài liệu hóa và kiểm tra visual trên LDPlayer

**Files:**
- Create: `docs/screens/trade-context-bulk-actions.md`
- Modify: `docs/video-interaction-matrix.md`
- Create: `docs/screenshots/trade-context-bulk/position-actions-final.png`
- Create: `docs/screenshots/trade-context-bulk/bulk-actions-final.png`
- Create: `docs/screenshots/trade-context-bulk/comparison-report.md`

**Interfaces:**
- Consumes: APK đã qua Task 4, video frame 23.4 và 29.0 giây.
- Produces: screen contract, ảnh thiết bị và báo cáo sai lệch/ngoại lệ động có thể kiểm tra lại.

- [ ] **Step 1: Ghi screen contract từ video và code đã chốt**

Tài liệu phải ghi viewport 384 × 848, mốc video, entry/exit sequence, copy/thứ tự sáu nút, mapping năm scope, geometry, semantic colors, excluded dynamic regions và xác nhận pending/header bulk menu ngoài scope.

- [ ] **Step 2: Cập nhật ma trận tương tác**

Thêm section `giaodientrang.MP4` với hai dòng: position → action sheet; `Hoạt động hàng loạt...` → dialog contextual năm scope. Ghi rõ video chỉ quan sát thao tác mở/hủy, còn semantics close được xác định từ label và được kiểm chứng bằng fixture tự động; không khẳng định video đã cho thấy server mutation.

- [ ] **Step 3: Build và cài APK không xóa app data**

Run:

```powershell
cd D:\mt5New\mobile
flutter build apk --debug
D:\LDPlayer\LDPlayer9\adb.exe -s 127.0.0.1:5555 install -r D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk
D:\LDPlayer\LDPlayer9\adb.exe -s 127.0.0.1:5555 shell monkey -p com.tradingdemo.trading_mobile 1
```

Nếu serial khác, chọn đúng development LDPlayer từ `adb devices`; không cài lên MT5 reference emulator và không clear storage.

- [ ] **Step 4: Chụp hai trạng thái và so với video**

Mở Trade, tap cùng một open position, chụp position sheet; tap `Hoạt động hàng loạt...`, chụp dialog. Normalize ảnh app về canvas 384 × 848, mask status bar, notification, ticket/account/live values, rồi đo dialog bounds, title/subtitle baseline, pill height/gap/radius, dim barrier và màu. Báo cáo mọi residual > 2 logical px hoặc sai copy/order; không ghi “100%” nếu còn residual ngoài vùng mask.

- [ ] **Step 5: Smoke test không gây giao dịch ngoài ý muốn**

Trên thiết bị chỉ bấm `Hủy` để kiểm tra visual. Năm close scopes đã được kiểm thử bằng fixture tự động; không đóng lệnh trên tài khoản server đang đăng nhập chỉ để chụp ảnh khi chưa có ủy quyền riêng.

- [ ] **Step 6: Chạy quality gate của task**

Run:

```powershell
cd D:\mt5New\mobile
flutter test test\trade_position_bulk_actions_dialog_test.dart test\trade_position_bulk_actions_flow_test.dart test\video_interactions_test.dart test\video2_cross_tab_test.dart
flutter analyze
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS và hai ảnh final tồn tại, mở được, đúng màn hình.

- [ ] **Step 7: Commit tài liệu/evidence nếu worktree cho phép**

Stage đúng tài liệu và ảnh của task; commit `docs(trade): record contextual bulk action parity`.

---

### Task 6: Full regression gate và handoff

**Files:**
- Verify: `mobile/`
- Verify: `backend/`
- Inspect: toàn bộ diff liên quan task và các file người dùng đang sửa.

**Interfaces:**
- Consumes: tất cả thay đổi Task 1–5.
- Produces: bằng chứng build/analyze/test, xác nhận không đổi stack/backend contract và danh sách residual visual nếu có.

- [ ] **Step 1: Chạy toàn bộ Flutter test sạch**

Run:

```powershell
cd D:\mt5New\mobile
flutter test
```

Expected: PASS; đặc biệt các suite order, position, history, account switch, tab swipe, white theme và chart vẫn xanh.

- [ ] **Step 2: Chạy analyzer và APK build mới**

Run:

```powershell
cd D:\mt5New\mobile
flutter analyze
flutter build apk --debug
```

Expected: analyzer không có issue; APK tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 3: Chạy backend build/test dù không đổi backend**

Run:

```powershell
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: PASS; không có API/OpenAPI/migration diff.

- [ ] **Step 4: Audit phạm vi và dữ liệu nhạy cảm**

Run `git diff --check`, `git diff --stat`, và `git status --short`. Xác nhận không có token/password/account credential mới, không stage file ngoài scope, không sửa pending order/header generic behavior và không ghi đè các thay đổi có sẵn của người dùng.

- [ ] **Step 5: Handoff có bằng chứng**

Báo cáo root cause, file/dòng thay đổi, năm scope và target semantics, focused/full test counts, analyzer, APK, backend build/test, ảnh LDPlayer và residual comparison. Chỉ tuyên bố parity cho dialog/action sequence được video cung cấp; nêu rõ mutation server không được thực hiện thủ công trong bước visual.
