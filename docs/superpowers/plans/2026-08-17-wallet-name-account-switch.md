# Wallet Name and Account Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiển thị đúng tên ví của từng tài khoản và chuyển toàn bộ trạng thái EX V2 sang tài khoản được chạm sau canonical activate HTTP 200.

**Architecture:** Flutter lấy tên từng dòng từ `LinkedTradingAccount.displayName`, giữ `bootstrap.activeAccount.name` cho tài khoản active, và tiếp tục dùng `accountId` làm khóa presentation. Chuyển tài khoản đi qua endpoint activate hiện có; backend serialize mutation theo device và trả canonical bootstrap, sau đó coordinator publish nguyên tử toàn bộ state account-scoped.

**Tech Stack:** Flutter 3/Dart, Riverpod, Dio, GoRouter, ASP.NET Core 8, EF Core/SQL Server, xUnit.

## Global Constraints

- Không đổi base URL hoặc route API hiện có.
- Không bỏ device-token authentication.
- Không giả chuyển UI khi activate chưa trả HTTP 200 canonical.
- Không log password, device token, Authorization, request body đầy đủ hoặc reconnectGrant.
- Giữ nguyên `brokerId=yodo-demo` và `serverId=yodo-demo-01` trong API contract.
- Sau mỗi task chạy build, analyze và relevant tests theo `AGENTS.md`.

---

### Task 1: Map đúng tên ví theo từng linked account

**Files:**
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart:622-641`
- Modify: `mobile/test/multi_account_switch_test.dart:80-220`

**Interfaces:**
- Consumes: `LinkedTradingAccount.displayName`, active `DemoAccountProfile.name`.
- Produces: `_mapLinkedAccount(..., displayName: account.displayName ?? active.name, ...)`.

- [ ] **Step 1: Viết widget test thất bại**

Trong fixture, đặt account A `displayName: 'Ví A'`, account B `displayName: 'Ví B'`; assert Profile hiển thị cả hai tên và không nhân đôi tên A.

```dart
expect(find.text('Ví A'), findsOneWidget);
expect(find.text('Ví B'), findsOneWidget);
```

- [ ] **Step 2: Chạy test để xác minh RED**

Run: `flutter test test/multi_account_switch_test.dart --plain-name "linked accounts keep their own wallet names"`

Expected: FAIL vì account B đang nhận `active.name`.

- [ ] **Step 3: Sửa mapping tối thiểu**

```dart
displayName: account.displayName ?? active.name,
```

- [ ] **Step 4: Chạy test để xác minh GREEN**

Run: `flutter test test/multi_account_switch_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit riêng task**

```powershell
git add mobile/lib/shared/providers/demo_data_provider.dart mobile/test/multi_account_switch_test.dart
git commit -m "fix: map linked account wallet names"
```

### Task 2: Khóa hành vi chuyển tài khoản Flutter theo canonical bootstrap

**Files:**
- Modify: `mobile/test/multi_account_switch_test.dart:220-330`
- Modify only if test exposes a defect: `mobile/lib/shared/providers/demo_data_provider.dart:647-704`
- Modify only if test exposes a defect: `mobile/lib/features/profile/presentation/screens/profile_screen.dart:90-135`
- Modify only if test exposes a defect: `mobile/lib/features/account_link/application/account_activation_coordinator.dart:58-94`

**Interfaces:**
- Consumes: `LinkedTradingAccountsController.activate(String accountId)`.
- Produces: one `PUT /mobile/accounts/{publicAccountId}/activate`, canonical bootstrap publication, refreshed linked-account order.

- [ ] **Step 1: Mở rộng widget test chuyển A → B**

Assert thao tác chạm B gửi đúng public account ID và sau HTTP 200:

```dart
expect(adapter.activatedAccountIds, ['account-b']);
expect(container.read(exV2AccountProvider).requireValue!.bootstrap.account.id,
    'account-b');
expect(container.read(exV2WalletViewProvider).value!.wallet.totalBalance, 20);
expect(container.read(demoPositionsProvider).single.id, 'position-b');
expect(find.text('Ví B'), findsWidgets);
```

- [ ] **Step 2: Thêm test lỗi 409 giữ nguyên A**

```dart
expect(container.read(exV2AccountProvider).requireValue!.bootstrap.account.id,
    'account-a');
expect(find.textContaining('concurrency_conflict'), findsOneWidget);
```

- [ ] **Step 3: Chạy test để xác minh hành vi hiện tại**

Run: `flutter test test/multi_account_switch_test.dart`

Expected: success path chỉ GREEN khi toàn bộ wallet/positions/history thuộc B; failure path giữ A.

- [ ] **Step 4: Nếu có assertion RED, sửa đúng lớp gây lỗi**

Không thêm optimistic local switch. Coordinator chỉ gọi `publishBootstrap(... authoritativeAccountSwitch: true)` sau khi ba account identity khớp.

- [ ] **Step 5: Chạy focused suite**

Run: `flutter test test/account_activation_coordinator_test.dart test/multi_account_switch_test.dart test/wallet_server_data_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit riêng task nếu production code thay đổi**

```powershell
git add mobile/test/multi_account_switch_test.dart mobile/lib/shared/providers/demo_data_provider.dart mobile/lib/features/profile/presentation/screens/profile_screen.dart mobile/lib/features/account_link/application/account_activation_coordinator.dart
git commit -m "fix: publish complete account switch state"
```

### Task 3: Sửa persistent `concurrency_conflict` trên production EX V2

**Files:**
- Server repository: locate the handler owning `PUT /api/v2/mobile/accounts/{accountId}/activate` with `rg -n "activate|concurrency_conflict"` before editing.
- Test: SQL Server integration test project that currently covers mobile account activation.
- Update handoff evidence: `docs/ex-v2-account-activation-concurrency-fix.md`.

**Interfaces:**
- Consumes: public account ID, device identity, UUID idempotency/correlation metadata, body `{}`.
- Produces: HTTP 200 `{ account, bootstrap }` with all account identities equal to the selected account.

- [ ] **Step 1: Viết SQL Server integration test RED trên server**

Fixture phải có device D, account A active và B inactive. Gọi activate B và assert HTTP 200, B active trong list/bootstrap, wallet/positions/history đều scoped B.

- [ ] **Step 2: Tái hiện RED và thu correlationId an toàn**

Không in token hoặc body. Expected hiện tại: HTTP 409 `concurrency_conflict`.

- [ ] **Step 3: Sửa transaction activation**

Serialize theo device-selection row, re-read ownership/status sau lock, đổi active link đúng một lần, commit rồi tạo canonical bootstrap từ selection vừa commit. Không dùng row-version của balance/equity làm concurrency token cho active selection.

- [ ] **Step 4: Thêm idempotency và concurrent-request tests**

Cùng key replay cùng HTTP 200; hai key đồng thời có deterministic final active account; rollback không để command kẹt `in_progress`.

- [ ] **Step 5: Chạy build/test server**

Run các lệnh build/test chuẩn của repository server. Expected: 0 error, toàn bộ test pass.

- [ ] **Step 6: Deploy chỉ EX V2**

Backup binary/config, deploy artifact mới và restart chỉ `ex-v2-api.service`. Không restart `ex-api.service`.

- [ ] **Step 7: Public smoke không lộ secret**

`GET /mobile/accounts` → 200; activate inactive → 200; bootstrap/list/wallet/history → 200 và cùng account; activate ngược lại → 200.

- [ ] **Step 8: Ghi bằng chứng và commit server**

Ghi status, correlationId và test totals vào handoff; không ghi secret.

### Task 4: Xác minh và cài APK cuối

**Files:**
- Verify only: `mobile/`
- Artifact: `mobile/build/app/outputs/flutter-apk/app-debug.apk`

**Interfaces:**
- Consumes: Flutter/backend fixes từ Task 1-3.
- Produces: APK đã cài trên `emulator-5558` và smoke evidence.

- [ ] **Step 1: Chạy Flutter verification**

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Expected: analyze clean, 0 failed tests, APK built.

- [ ] **Step 2: Cài đè APK**

```powershell
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5558 install -r build\app\outputs\flutter-apk\app-debug.apk
```

- [ ] **Step 3: Smoke trên UI**

Mở danh sách tài khoản, xác minh tên ví khác nhau, chạm B, xác minh B được highlight và số dư/wallet/positions/history đổi đồng bộ; chạm A và xác minh chiều ngược lại.

- [ ] **Step 4: Kiểm tra artifact/log an toàn**

Không có password/device token thật trong source, test artifact, screenshot semantics hoặc log thu thập.
