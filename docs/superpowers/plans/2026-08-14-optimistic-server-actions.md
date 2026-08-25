# Optimistic Server Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mọi mutation trong app phản hồi giao diện ngay, chạy API nền, hợp nhất dữ liệu server khi thành công và rollback khi thất bại.

**Architecture:** `ExV2AccountController` là nguồn optimistic state duy nhất cho dữ liệu server. Mỗi command chụp snapshot, áp patch đồng bộ, gửi request với metadata idempotent, tải targeted data để xác nhận, sau đó chạy full reconciliation nền. Dữ liệu tiền không được client tự tính làm nguồn chuẩn.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, EX V2 REST/SignalR.

## Global Constraints

- Không thay đổi bố cục giao diện.
- Server vẫn là nguồn chuẩn cho giá khớp, balance, equity và history.
- Không gửi trùng mutation; giữ nguyên Idempotency-Key khi retry cùng thao tác.
- Rollback đúng entity khi request thất bại.
- Không làm mất state optimistic do SignalR refresh đến muộn.

---

### Task 1: Optimistic mutation state foundation

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_view_state.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/ex_v2_account_provider_test.dart`

- [ ] Thêm pending operation IDs và helper snapshot/patch/rollback.
- [ ] Test patch xuất hiện trước khi HTTP future hoàn thành.
- [ ] Test HTTP failure restores the exact previous entity lists.
- [ ] Test stale SignalR refresh cannot restore a removed entity.

### Task 2: Trade commands

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`
- Test: `mobile/test/demo_trading_controller_test.dart`

- [ ] Optimistic create market/pending placeholders.
- [ ] Optimistic close/partial close/close-by and bulk close.
- [ ] Optimistic modify protection/order and cancel/bulk cancel.
- [ ] Targeted bootstrap/deal/order reconciliation; full hydrate unawaited.

### Task 3: Wallet, notifications and settings

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/features/wallet/presentation/screens/wallet_request_screen.dart`
- Modify: `mobile/lib/features/notifications/presentation/screens/notifications_screen.dart`
- Test: `mobile/test/wallet_server_data_test.dart`
- Test: `mobile/test/notifications_server_data_test.dart`

- [ ] Deposit/withdraw/transfer appear immediately as local `sending` rows.
- [ ] Notification read/read-all updates immediately and rolls back on error.
- [ ] Settings updates immediately and rolls back on error.

### Task 4: Verification and device acceptance

- [ ] Run Flutter analyze and full tests.
- [ ] Build APK and backend build/tests.
- [ ] Install with `adb install -r`.
- [ ] Verify close response appears immediately and final data matches History.

