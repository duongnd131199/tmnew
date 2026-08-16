# Accountless Device Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho phép token thiết bị hợp lệ nhưng chưa có tài khoản active mở luồng thêm tài khoản thật mà không xoá token hoặc tạo dữ liệu giả.

**Architecture:** Xác thực token qua endpoint device-scoped `/mobile/status`, còn `/mobile/bootstrap` chỉ tải dữ liệu account-scoped. `DeviceGate` nhận diện riêng structured 409 `ACTIVE_ACCOUNT_NOT_CONFIGURED` và chuyển sang onboarding CTA mở `/accounts/add`; mọi lỗi khác fail closed.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, flutter_test.

## Global Constraints

- Giữ nguyên Flutter/Riverpod/GoRouter/Dio và base URL `https://trochoi.top/ex/v2/api`.
- Không thêm broker, server, tài khoản hoặc kết quả liên kết giả.
- Không log hoặc hard-code device token.
- Chỉ structured 409 có code chính xác `ACTIVE_ACCOUNT_NOT_CONFIGURED` được coi là trạng thái chưa có tài khoản.
- Sau task phải chạy build, analyze và relevant/full tests theo `AGENTS.md`.

---

### Task 1: Device-scoped status validation

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Test: `mobile/test/ex_v2_repository_test.dart`
- Test: `mobile/test/device_gate_test.dart`

**Interfaces:**
- Produces: `Future<JsonMap> ExV2Repository.status()`.
- Consumes: `ExV2ApiClient.getJson(String path)` và `DeviceActivationService.activate`.

- [ ] **Step 1: Viết test repository RED**

Thêm test tạo `ExV2Repository` với recording adapter, gọi `status()`, rồi assert method `GET`, path `/ex/v2/api/mobile/status` và header `X-Device-Token` đúng token test.

- [ ] **Step 2: Chạy test để xác nhận RED**

Run: `flutter test --no-pub test/ex_v2_repository_test.dart`

Expected: compile fail vì `ExV2Repository.status` chưa tồn tại.

- [ ] **Step 3: Thêm implementation tối thiểu**

```dart
Future<JsonMap> status() => _client.getJson('/mobile/status');
```

Đổi callback validation trong `_DeviceActivationScreen._activate` từ `bootstrap()` sang `status()`.

- [ ] **Step 4: Chạy focused test GREEN**

Run: `flutter test --no-pub test/ex_v2_repository_test.dart test/device_activation_service_test.dart`

Expected: tất cả pass.

### Task 2: Accountless onboarding without fake success

**Files:**
- Modify: `mobile/lib/features/account_sync/presentation/device_gate.dart`
- Test: `mobile/test/device_gate_test.dart`

**Interfaces:**
- Consumes: `ExV2RequestFailure.statusCode`, `ExV2RequestFailure.code`, route `/accounts/add`.
- Produces: trạng thái UI `account-bootstrap-accountless` và action mở catalog thật.

- [ ] **Step 1: Viết widget tests RED**

Thêm test với stored token và `exV2AccountProvider` ném:

```dart
const ExV2RequestFailure(
  statusCode: 409,
  code: 'ACTIVE_ACCOUNT_NOT_CONFIGURED',
  message: 'No active account',
)
```

Assert UI có key `account-bootstrap-accountless`, có nút `Thêm tài khoản`, không có generic error và token không bị xoá. Thêm test mutation: cùng status 409 nhưng code khác phải tiếp tục hiện `account-bootstrap-error`.

- [ ] **Step 2: Chạy test để xác nhận RED**

Run: `flutter test --no-pub test/device_gate_test.dart`

Expected: accountless case đang hiện generic bootstrap error.

- [ ] **Step 3: Implement accountless branch tối thiểu**

Thêm predicate typed:

```dart
bool _isAccountNotConfigured(Object error) =>
    error is ExV2RequestFailure &&
    error.statusCode == 409 &&
    error.code == 'ACTIVE_ACCOUNT_NOT_CONFIGURED';
```

Trong error branch, chỉ với predicate này render màn onboarding. Khi bấm CTA, chuyển gate sang child app rồi điều hướng GoRouter đến `/accounts/add`; không can thiệp controller catalog/link.

- [ ] **Step 4: Chạy test GREEN và regression tập trung**

Run: `flutter test --no-pub test/device_gate_test.dart test/ex_v2_api_client_test.dart test/ex_v2_repository_test.dart test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart`

Expected: tất cả pass.

### Task 3: Verification and device handoff

**Files:**
- Verify only: `mobile/`

**Interfaces:**
- Consumes: toàn bộ thay đổi Task 1–2.
- Produces: APK debug đã kiểm chứng và báo cáo giới hạn backend rõ ràng.

- [ ] **Step 1: Analyze**

Run: `flutter analyze --no-pub`

Expected: `No issues found`.

- [ ] **Step 2: Full Flutter tests**

Run: `flutter test --no-pub --concurrency=1`

Expected: tất cả test pass.

- [ ] **Step 3: Build APK**

Run: `flutter build apk --debug --no-pub`

Expected: tạo `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Device check**

Cài APK bằng `adb install -r`, mở `com.tradingdemo.trading_mobile`, xác nhận token hợp lệ/accountless thấy CTA và CTA tới broker catalog. Nếu live server chưa có `/mobile/status` hoặc năm linked-account endpoint, ghi đúng HTTP failure; không claim E2E success.

- [ ] **Step 5: Commit scoped files**

Stage đúng design, plan, production files và tests của task; kiểm tra `git diff --cached --check`, rồi commit với message `fix: allow accountless device onboarding`.
