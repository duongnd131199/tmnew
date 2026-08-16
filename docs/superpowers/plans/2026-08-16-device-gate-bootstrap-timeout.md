# Device Gate Bootstrap Timeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chấm dứt spinner vô hạn ở `DeviceGate`, cung cấp Retry an toàn và bảo đảm dấu `+` tại màn Tài khoản mở broker discovery sau khi bootstrap phục hồi.

**Architecture:** `DeviceGate` sở hữu một watchdog giới hạn toàn bộ startup/bootstrap lifecycle thay vì dựa riêng vào timeout của Dio. Timeout chỉ chuyển UI sang fail-closed retry state, không xóa token; structured accountless 409 tiếp tục đi qua onboarding hiện có.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, flutter_test.

## Global Constraints

- Giữ nguyên base URL production `https://trochoi.top/ex/v2/api` và stack Flutter/Riverpod/GoRouter/Dio.
- Không xóa device token khi timeout, lỗi mạng, lỗi parse hoặc lỗi server.
- Chỉ `409 ACTIVE_ACCOUNT_NOT_CONFIGURED` được mở onboarding accountless; mọi lỗi khác fail closed.
- Không tạo broker, server, tài khoản, credential hoặc kết quả liên kết giả.
- Sau task chạy build, analyze và relevant/full tests theo `AGENTS.md`.

---

### Task 1: Token-read timeout và retry

**Files:**
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Test: `mobile/test/device_gate_test.dart`

**Interfaces:**
- Consumes: `DeviceTokenStore.read()`.
- Produces: `DeviceGate.startupTimeout`, UI key `device-token-read-error`, action `_retryTokenRead()`.

- [ ] **Step 1: Viết widget test RED cho token read bị treo**

Thêm fake store có `read()` trả `Completer<String?>().future`, pump `DeviceGate(startupTimeout: Duration(milliseconds: 100))`, pump 101 ms và assert:

```dart
expect(find.byKey(const Key('device-token-read-error')), findsOneWidget);
expect(find.text('Thử lại'), findsOneWidget);
expect(find.text('SERVER APP'), findsNothing);
```

- [ ] **Step 2: Viết widget test RED cho retry token read**

Fake store trả future treo ở lần đầu và `null` ở lần hai. Tap `Thử lại`, pump settle, assert activation screen xuất hiện và `readCalls == 2`.

- [ ] **Step 3: Chạy test xác nhận RED**

Run: `flutter test --no-pub test/device_gate_test.dart`

Expected: compile fail vì `startupTimeout` và key `device-token-read-error` chưa tồn tại.

- [ ] **Step 4: Implement timeout tối thiểu**

Trong `DeviceGate` thêm:

```dart
const DeviceGate({
  required this.child,
  this.onAddAccount,
  this.startupTimeout = const Duration(seconds: 20),
  super.key,
});

final Duration startupTimeout;
```

Trong state, thêm generation để response cũ không ghi đè retry mới:

```dart
int _tokenReadGeneration = 0;
Object? _tokenReadError;

Future<void> _readToken() async {
  final generation = ++_tokenReadGeneration;
  setState(() {
    _loading = true;
    _tokenReadError = null;
  });
  try {
    final token = await ref
        .read(deviceTokenStoreProvider)
        .read()
        .timeout(widget.startupTimeout);
    if (!mounted || generation != _tokenReadGeneration) return;
    setState(() {
      _activated = !ref.read(exV2EnabledProvider) ||
          (token != null && token.trim().isNotEmpty);
      _loading = false;
    });
  } catch (error) {
    if (!mounted || generation != _tokenReadGeneration) return;
    setState(() {
      _tokenReadError = error;
      _loading = false;
    });
  }
}
```

Không gọi `setState` từ `initState` trước frame đầu; `_readToken` chỉ gọi `setState` cho retry hoặc dùng helper nhận biết initial invocation.

Render `_AccountBootstrapUnavailable(key: Key('device-token-read-error'), message: 'Không thể đọc mã thiết bị.', onRetry: _retryTokenRead)` khi `_tokenReadError != null`.

- [ ] **Step 5: Chạy focused tests GREEN**

Run: `flutter test --no-pub test/device_gate_test.dart test/device_activation_service_test.dart`

Expected: tất cả pass.

- [ ] **Step 6: Commit Task 1**

```powershell
git add mobile/lib/features/account_sync/presentation/device_gate.dart mobile/test/device_gate_test.dart
git commit -m "fix: bound device token startup loading"
```

### Task 2: Bootstrap watchdog và retry

**Files:**
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Test: `mobile/test/device_gate_test.dart`

**Interfaces:**
- Consumes: `AsyncValue<ExV2AccountViewState?> exV2AccountProvider`.
- Produces: UI key `account-bootstrap-timeout`, method `_retryBootstrap()`.

- [ ] **Step 1: Viết widget test RED cho bootstrap treo**

Dùng stored token và provider build trả `Completer<ExV2AccountViewState?>().future`. Pump quá `startupTimeout`, assert:

```dart
expect(find.byKey(const Key('account-bootstrap-timeout')), findsOneWidget);
expect(await store.read(), 'test-token');
expect(find.text('SERVER APP'), findsNothing);
```

- [ ] **Step 2: Viết widget test RED cho bootstrap retry**

Override provider bằng fake build đếm lần gọi: lần đầu treo, lần sau trả `_serverState`. Sau timeout tap `Thử lại`, assert `SERVER APP` xuất hiện và build gọi hai lần.

- [ ] **Step 3: Chạy test xác nhận RED**

Run: `flutter test --no-pub test/device_gate_test.dart`

Expected: timeout case vẫn còn `account-bootstrap-loading`.

- [ ] **Step 4: Implement bootstrap watchdog tối thiểu**

Thêm `Timer? _bootstrapTimer`, `bool _bootstrapTimedOut`, `_armBootstrapTimeout()`, `_cancelBootstrapTimeout()` và dispose timer. Khi token tồn tại, arm timer; khi provider data/error, cancel timer. Loading branch render:

```dart
_bootstrapTimedOut
    ? _AccountBootstrapUnavailable(
        key: const Key('account-bootstrap-timeout'),
        message: 'Máy chủ phản hồi quá lâu.',
        onRetry: _retryBootstrap,
      )
    : const _AccountBootstrapLoading()
```

`_retryBootstrap()` reset timeout, arm timer và `ref.invalidate(exV2AccountProvider)` đúng một lần. Không xóa token.

- [ ] **Step 5: Chạy focused tests GREEN và accountless regressions**

Run: `flutter test --no-pub test/device_gate_test.dart test/ex_v2_api_client_test.dart test/ex_v2_repository_test.dart`

Expected: tất cả pass, exact accountless 409 vẫn mở onboarding và 409 khác fail closed.

- [ ] **Step 6: Commit Task 2**

```powershell
git add mobile/lib/features/account_sync/presentation/device_gate.dart mobile/test/device_gate_test.dart
git commit -m "fix: stop indefinite account bootstrap loading"
```

### Task 3: Route regression cho dấu cộng Tài khoản

**Files:**
- Modify: `mobile/test/multi_account_switch_test.dart`
- Modify only if test exposes defect: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`

**Interfaces:**
- Consumes: route `/profile`, key `accounts-add`, route `/accounts/add`.
- Produces: regression chứng minh add-account navigation sau bootstrap recovery.

- [ ] **Step 1: Thêm regression route production**

Tạo fixture với provider ban đầu fail/timeout, sau đó publish `_serverState`, mở `/profile`, tap `accounts-add`, và assert:

```dart
expect(fixture.router.state.uri.path, '/accounts/add');
expect(find.text('BROKER DISCOVERY'), findsOneWidget);
```

- [ ] **Step 2: Chạy focused test**

Run: `flutter test --no-pub test/multi_account_switch_test.dart`

Expected: pass với callback hiện có; nếu fail, sửa tối thiểu `AccountRoundAddButton.onTap`/route rồi chạy lại.

- [ ] **Step 3: Chạy account-link regression suite**

Run: `flutter test --no-pub test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart test/multi_account_switch_test.dart`

Expected: tất cả pass.

- [ ] **Step 4: Commit Task 3**

```powershell
git add mobile/test/multi_account_switch_test.dart mobile/lib/features/profile/presentation/screens/profile_screen.dart
git commit -m "test: cover account add after bootstrap recovery"
```

### Task 4: Full verification và LDPlayer handoff

**Files:**
- Verify only: `mobile/`, `backend/`, LDPlayer `MT5-Dev` index 2.

**Interfaces:**
- Consumes: Task 1–3.
- Produces: APK debug và bằng chứng runtime không còn spinner vô hạn.

- [ ] **Step 1: Flutter analyze**

Run: `flutter analyze --no-pub`

Expected: `No issues found`.

- [ ] **Step 2: Full Flutter tests**

Run: `flutter test --no-pub --concurrency=1`

Expected: tất cả pass.

- [ ] **Step 3: Build APK**

Run: `flutter build apk --debug --no-pub`

Expected: `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Backend build/test theo AGENTS.md**

Run: `dotnet build Trading.sln` và `dotnet test Trading.sln --no-build` trong `backend/`.

Expected: build/test pass; ghi riêng cảnh báo feed nếu có.

- [ ] **Step 5: Cài và kiểm tra MT5-Dev**

Dùng `ldconsole installapp --index 2 --filename <apk>` để giữ app data, mở package `com.tradingdemo.trading_mobile`, chờ tối đa 25 giây. Xác nhận một trong các terminal state xuất hiện: app shell, accountless onboarding, token-read error hoặc bootstrap timeout; không còn spinner vô hạn.

Nếu app shell mở, vào Cài đặt → Tài khoản → `+`, xác nhận broker discovery. Nếu token/account backend không cho vào app shell, ghi đúng state và không claim route E2E.

- [ ] **Step 6: Rà soát cuối**

Run: `git diff --check`, `git status --short`, và kiểm tra chỉ các file task được commit.
