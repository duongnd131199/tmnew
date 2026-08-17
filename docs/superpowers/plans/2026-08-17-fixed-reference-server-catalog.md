# Fixed Reference Server Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiển thị catalog 24 tên server cố định theo video cho `yodo-demo`, trong khi link request vẫn sử dụng server ID thật.

**Architecture:** Tách catalog trình bày vào một helper presentation thuần Dart. `TradingServerScreen` render các option này và `ExistingAccountLoginScreen` chọn alias mặc định; application controller/repository/request model không thay đổi.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter widget tests, Android/LDPlayer.

## Global Constraints

- Chỉ cố định display name cho broker ID `yodo-demo`.
- Mọi alias phải giữ `id`, `brokerId`, `accountType` và `description` của server API thật.
- Không tạo catalog khi API loading, empty hoặc error.
- Không thay backend, base URL, JSON casing, auth/device-token contract hoặc password flow.
- Không log password, device token, Authorization, request body hoặc reconnectGrant.
- Giữ nguyên các thay đổi working tree không liên quan.

---

### Task 1: Test RED cho catalog hiển thị và ID thật

**Files:**
- Modify: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: `TradingServerScreen(brokerId: 'yodo-demo', onSelected: ...)` với `_LiveCatalogRepository` trả một server thật `yodo-demo-01`.
- Produces: widget test bắt buộc tên/thứ tự video và callback ID thật.

- [ ] **Step 1: Thay expectation catalog YODO bằng tên video**

Trong test live catalog, sau khi pump `TradingServerScreen`, assert:

```dart
expect(find.text('Exness-MT5Real20'), findsOneWidget);
expect(find.text('Exness-MT5Real17'), findsOneWidget);
expect(find.text('Exness-MT5Real32'), findsOneWidget);
expect(find.text('YODO-Demo-01'), findsNothing);
expect(find.byIcon(Icons.check_rounded), findsOneWidget);
```

- [ ] **Step 2: Thêm test selection giữ ID thật**

```dart
testWidgets('reference server name keeps the live server identity', (
  tester,
) async {
  MobileTradingServer? selected;
  await _pump(
    tester,
    repository: _LiveCatalogRepository(),
    child: TradingServerScreen(
      brokerId: 'yodo-demo',
      onSelected: (value) => selected = value,
    ),
  );

  await tester.tap(find.text('Exness-MT5Real17'));
  await tester.pump();

  expect(selected?.name, 'Exness-MT5Real17');
  expect(selected?.id, 'yodo-demo-01');
  expect(selected?.brokerId, 'yodo-demo');
});
```

- [ ] **Step 3: Thêm test scroll đến cuối danh sách**

Pump catalog YODO, drag `server-list` lên trên và assert `Exness-MT5Real24` xuất hiện, cùng `ListView.childrenDelegate.estimatedChildCount == 24`.

- [ ] **Step 4: Chạy test và xác nhận RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart --plain-name "live catalog data keeps the video frame responsive"
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart --plain-name "reference server name keeps the live server identity"
```

Expected: FAIL vì production vẫn chỉ render `YODO-Demo-01`.

### Task 2: Catalog presentation thuần Dart

**Files:**
- Create: `mobile/lib/features/account_link/presentation/widgets/reference_server_catalog.dart`
- Test: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Produces: `ReferenceServerOption`, `referenceServerOptions({required String brokerId, required List<MobileTradingServer> servers})`.
- `ReferenceServerOption.server` là alias có ID thật; `rowKey` là duy nhất; `isSelected` xử lý default alias.

- [ ] **Step 1: Tạo model option**

```dart
final class ReferenceServerOption {
  const ReferenceServerOption({
    required this.server,
    required this.rowKey,
    required this.defaultOption,
  });

  final MobileTradingServer server;
  final String rowKey;
  final bool defaultOption;

  bool isSelected(MobileTradingServer? selected) {
    if (selected == null || selected.id != server.id) return false;
    if (selected.name == server.name) return true;
    return defaultOption &&
        !referenceServerDisplayNames.contains(selected.name);
  }
}
```

- [ ] **Step 2: Tạo danh sách 24 tên theo spec**

Khai báo `referenceServerDisplayNames` theo đúng thứ tự 1–24 trong spec. Không sinh tên bằng pattern hoặc sort lại.

- [ ] **Step 3: Tạo options giữ nguyên identity API**

Với broker khác `yodo-demo`, trả một option cho mỗi server API và `rowKey == server.id`. Với `yodo-demo`, nếu catalog rỗng thì trả rỗng; nếu có dữ liệu thì tạo 24 alias từ `servers.first`, sao chép tất cả identity/metadata và dùng `rowKey: '${source.id}-reference-$index'`.

- [ ] **Step 4: Không thêm logging hoặc dependency**

Helper là hàm thuần, không đọc network/storage và không ghi log.

### Task 3: Tích hợp screen và form

**Files:**
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Test: `mobile/test/account_link_catalog_video_test.dart`
- Test: `mobile/test/account_link_login_video_test.dart`

**Interfaces:**
- Consumes: `referenceServerOptions`.
- Produces: danh sách video, default form alias và callback server giữ ID API.

- [ ] **Step 1: Render options thay vì raw servers**

Trong `TradingServerScreen.build`, tạo:

```dart
final options = referenceServerOptions(
  brokerId: widget.brokerId,
  servers: servers,
);
```

Dùng `options.length`, `option.server`, `option.rowKey` và `option.isSelected(state?.selectedServer)` cho ListView.

- [ ] **Step 2: Cho `_ServerRow` nhận row key duy nhất**

Thêm `required String rowKey`; row key là `server-row-$rowKey`, divider key là `server-divider-$rowKey`. Generic catalog vẫn giữ key cũ vì `rowKey == server.id`.

- [ ] **Step 3: Default form dùng alias đầu**

Trong `_loadServers`, khi chưa selected và catalog không rỗng, lấy `referenceServerOptions(...).first.server` và truyền vào controller. Vì alias sao chép ID thật, submit không đổi.

- [ ] **Step 4: Chạy GREEN và regression**

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart test/account_link_controller_test.dart
```

Expected: tên/thứ tự/scroll/selected/callback pass; request controller vẫn gửi `serverId: yodo-demo-01`.

- [ ] **Step 5: Commit**

```powershell
git add -- mobile/lib/features/account_link/presentation/widgets/reference_server_catalog.dart mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart mobile/test/account_link_catalog_video_test.dart
git commit -m "feat: match reference server catalog"
```

### Task 4: Full verification và LDPlayer

**Files:**
- Verify: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Capture: `.codex_tmp/new-account-final/server-catalog-fixed-top.png`
- Capture: `.codex_tmp/new-account-final/server-catalog-fixed-scroll.png`

**Interfaces:**
- Consumes: APK cuối và instance `emulator-5558`.
- Produces: test/build/screenshot evidence.

- [ ] **Step 1: Flutter verification**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

- [ ] **Step 2: Backend verification theo AGENTS.md**

```powershell
cd backend
dotnet build Trading.sln --no-restore
dotnet test Trading.sln --no-build
```

- [ ] **Step 3: Cài và smoke UI không credential**

Cài APK bằng `adb install -r`, mở luồng chọn server, chụp top list và sau khi cuộn. Không nhập login/password.

- [ ] **Step 4: Đối chiếu video**

Xác nhận top list y=222; 13 hàng đầu khớp frame 14; phần sau khớp frame 16; first checkmark và scrollbar hiện đúng; form hiển thị alias đã chọn.

- [ ] **Step 5: Secret/diff scan**

Rà file thay đổi không thêm log password, device token, Authorization, request body hoặc reconnectGrant. Chỉ stage file thuộc task.
