# Server Picker Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Căn màn hình chọn máy chủ khớp frame 14 của `giaoDienMau/themmoitk.MP4` mà không thay dữ liệu API thật.

**Architecture:** Giữ nguyên `TradingServerScreen`, `AccountLinkToolbar`, Riverpod controller và repository. Chỉ hiệu chỉnh metric khoảng thở riêng của màn server; test widget khóa hình học độc lập với source và các test hành vi hiện có bảo vệ scroll/selection.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, Flutter widget tests, Android/LDPlayer, ASP.NET Core 8 verification.

## Global Constraints

- Không thay backend, base URL, API model, auth header hoặc device-token contract.
- Không thêm broker/server fixture vào production source.
- Mọi server name/ID và selected state phải đến từ repository/controller thật.
- Không log password, device token, Authorization, request body hoặc reconnectGrant.
- Chỉ stage các file của task; giữ nguyên thay đổi không liên quan trong working tree.

---

### Task 1: Khóa hình học frame Máy chủ

**Files:**
- Modify: `mobile/test/account_link_catalog_video_test.dart:49`

**Interfaces:**
- Consumes: `TradingServerScreen(brokerId: String)` và key `server-list`.
- Produces: regression test khóa top của danh sách tại 124 logical px sau SafeArea.

- [ ] **Step 1: Sửa test vị trí bằng literal đo từ video**

Trong test `server toolbar spans the viewport without overlap`, thay expectation cũ:

```dart
expect(list.top - screen.top, closeTo(145, 0.1), reason: '$width');
```

bằng:

```dart
expect(list.top - screen.top, closeTo(124, 0.1), reason: '$width');
```

Mutation mà test bắt: spacer bị đổi khỏi 43 logical px, làm danh sách lệch dọc so với frame tham chiếu.

- [ ] **Step 2: Chạy test và xác nhận RED đúng nguyên nhân**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart --plain-name "server toolbar spans the viewport without overlap"
```

Expected: FAIL, actual 145 và expected 124 ở width 360; không phải compile error.

### Task 2: Sửa metric tối thiểu và bảo vệ hành vi

**Files:**
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart:59`
- Test: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: toolbar cao 81 logical px.
- Produces: spacer 43 logical px và `server-list.top == 124` trên mọi width test.

- [ ] **Step 1: Sửa duy nhất spacer**

```dart
const SizedBox(height: 43),
```

Không sửa toolbar dùng chung, itemExtent, repository hoặc row data.

- [ ] **Step 2: Chạy test GREEN cho geometry**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart --plain-name "server toolbar spans the viewport without overlap"
```

Expected: PASS ở width 360, 390 và 430.

- [ ] **Step 3: Chạy toàn bộ test catalog/server**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart test/new_account_video_geometry_test.dart test/account_link_login_video_test.dart
```

Expected: tất cả PASS; scroll, selected server, callback/pop, live YODO data, loading/error/retry và field preservation không hỏng.

- [ ] **Step 4: Cập nhật tài liệu cũ bị supersede**

Trong `docs/superpowers/specs/2026-08-17-new-account-video-parity-design.md` thay metric 64 bằng 43. Trong `docs/superpowers/plans/2026-08-17-new-account-video-parity.md` ghi rõ `server-list.top` là 124.

- [ ] **Step 5: Commit thay đổi**

```powershell
git add -- mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart mobile/test/account_link_catalog_video_test.dart docs/superpowers/specs/2026-08-17-new-account-video-parity-design.md docs/superpowers/plans/2026-08-17-new-account-video-parity.md
git commit -m "fix: align server picker with reference frame"
```

### Task 3: Kiểm định toàn dự án và LDPlayer

**Files:**
- Verify: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Capture: `.codex_tmp/new-account-final/server-picker-parity.png`

**Interfaces:**
- Consumes: APK với metric mới và instance `MT5-Dev` (`emulator-5558`).
- Produces: build/test evidence và screenshot thực tế đã đo.

- [ ] **Step 1: Chạy Flutter analyze và full test**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
```

Expected: analyze 0 issue; test 0 fail.

- [ ] **Step 2: Build APK debug**

```powershell
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Expected: `app-debug.apk` được tạo thành công.

- [ ] **Step 3: Chạy backend build/test theo AGENTS.md**

```powershell
cd backend
dotnet build Trading.sln --no-restore
dotnet test Trading.sln --no-build
```

Expected: 0 build error và 0 test failure.

- [ ] **Step 4: Cài APK cuối và chụp màn Máy chủ**

```powershell
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5558 install -r D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk
```

Mở Cài đặt → Tài khoản → `+` → YODO Demo Markets → Máy chủ. Không nhập credential. Chụp vào `.codex_tmp/new-account-final/server-picker-parity.png`.

- [ ] **Step 5: Đo ảnh và so sánh**

Dùng pixel scan chỉ đọc để xác nhận:

- tham chiếu bắt đầu nền tại y=222;
- APK bắt đầu nền tại y=221–222;
- hàng có pitch 84 px vật lý (56 logical × 1.5);
- lề divider và checkmark khớp theo scale;
- nội dung là YODO thật, không phải fixture.

- [ ] **Step 6: Rà secret/log và diff**

Kiểm tra các file thay đổi không thêm `debugPrint`, `print`, logger, Authorization, device token, request body hoặc reconnectGrant. Chụp màn hình không có login/password.
