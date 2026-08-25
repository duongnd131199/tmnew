# Close Position Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho mọi nút giao dịch trong ticket đóng position gọi cùng một close command authoritative trên EX V2.

**Architecture:** `NewOrderScreen` quyết định callback theo sự hiện diện của `closePositionId`. `_OrderForm` không đổi giao diện; khi có position cần đóng, callback BUY và SELL được định tuyến đến `_closePosition`, còn ticket tạo lệnh mới vẫn gọi `_submit`.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, Flutter widget tests.

## Global Constraints

- Không thay đổi giao diện hiện tại.
- Không thay đổi technology stack.
- Không hard-code token hoặc dữ liệu tài chính.
- Mọi close mutation tiếp tục dùng idempotency và dữ liệu authoritative từ server.

---

### Task 1: Route all close-ticket actions to close command

**Files:**
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.closePosition(String positionId)`.
- Produces: BUY, SELL và thanh cam cùng gọi `_closePosition(DemoPosition)` khi ticket có `closePositionId`.

- [ ] **Step 1: Write failing widget tests**

Thêm test mở `NewOrderScreen(closePositionId: ...)`, nhấn lần lượt
`order-market-sell` và `order-market-buy`, rồi xác nhận adapter nhận đúng một
POST `/positions/{id}/close` và không nhận POST `/orders`.

- [ ] **Step 2: Verify RED**

Run: `flutter test --no-pub test/ex_v2_trading_command_test.dart`

Expected: SELL/BUY currently increment `orderPosts` instead of `closePosts`.

- [ ] **Step 3: Implement minimal callback routing**

Trong `NewOrderScreen.build`, nếu `closePosition != null`, truyền cả `onSell`
và `onBuy` là `() => _closePosition(closePosition)`; nếu không thì giữ nguyên
`_submit('SELL', quote.bid)` và `_submit('BUY', quote.ask)`.

- [ ] **Step 4: Verify GREEN and regressions**

Run targeted test, `flutter analyze --no-pub`, `flutter test --no-pub
--concurrency=1`, `flutter build apk --debug --no-pub`, backend build/test.

- [ ] **Step 5: Install and verify on LDPlayer**

Cài đè APK bằng `adb install -r`, mở một ticket position demo, nhấn một nút
Market và xác nhận completion/history đều là close của ticket đó.

