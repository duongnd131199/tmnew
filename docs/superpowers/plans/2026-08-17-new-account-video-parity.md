# New Account Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Làm cho luồng thêm tài khoản bám giao diện và hành vi của `giaoDienMau/themmoitk.MP4` trong khi mọi broker, server và account data vẫn đến từ EX V2 API thật.

**Architecture:** Tách toolbar account-link thành một widget full-width dùng chung để loại bỏ lỗi intrinsic-width trong `Column`. Các screen tiếp tục dùng Riverpod controller/repository hiện tại; thay đổi chỉ ở presentation và test hình học, không đổi API hoặc credential flow.

**Tech Stack:** Flutter 3.44+, Dart, Material, Riverpod, GoRouter, flutter_test, Dio-backed EX V2 repository.

## Global Constraints

- Không thay backend, base URL, request model, auth header hoặc device-token contract.
- Không thêm Exness, MetaQuotes, server hoặc account fixture vào production source.
- Password phải giữ nguyên từng ký tự trong controller và không được ghi vào log hoặc artifact.
- UI phải responsive ở 360, 390, 412 và 430 logical pixels.
- Test production behavior phải được chạy RED trước khi sửa source và GREEN sau khi sửa.
- Không ghi log password, device token, Authorization, reconnectGrant hoặc toàn bộ request body.

---

### Task 1: Full-width account-link toolbar

**Files:**
- Create: `mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`
- Test: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: `AccountLinkToolbarButton`, `AccountLinkToolbarAction`, `AppSpacing`, `AppTypography`.
- Produces: `AccountLinkToolbar({required String title, required VoidCallback onBack, Widget? trailing, Key? key})`.

- [ ] **Step 1: Viết test hình học RED cho Brokers**

Thêm helper chạy ở các width 360, 390 và 430, rồi kiểm tra:

```dart
final toolbar = tester.getRect(find.byKey(const Key('account-link-toolbar')));
final back = tester.getRect(find.byKey(const Key('account-link-back-button')));
final title = tester.getRect(find.byKey(const Key('account-link-toolbar-title')));
final qr = tester.getRect(find.byKey(const Key('account-link-qr-button')));
expect(toolbar.width, width);
expect(title.center.dx, closeTo(width / 2, 1));
expect(back.right, lessThan(title.left));
expect(qr.left, greaterThan(title.right));
```

- [ ] **Step 2: Chạy test và xác nhận RED**

Run:

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_catalog_video_test.dart --plain-name "broker toolbar spans the viewport without overlap"
```

Expected: FAIL vì toolbar hiện chỉ rộng bằng intrinsic width của tiêu đề hoặc chưa có key widget dùng chung.

- [ ] **Step 3: Tạo widget toolbar tối thiểu**

Widget phải có cấu trúc:

```dart
class AccountLinkToolbar extends StatelessWidget {
  const AccountLinkToolbar({
    required this.title,
    required this.onBack,
    this.trailing,
    super.key = const Key('account-link-toolbar'),
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 66,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(title, key: const Key('account-link-toolbar-title')),
        Positioned(left: AppSpacing.md, child: AccountLinkToolbarButton(
          action: AccountLinkToolbarAction.back,
          onTap: onBack,
        )),
        if (trailing != null) Positioned(right: AppSpacing.md, child: trailing!),
      ],
    ),
  );
}
```

Style title bằng `AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)`.

- [ ] **Step 4: Dùng toolbar chung trong Brokers và Máy chủ**

`BrokerListScreen` truyền QR button thật vào `trailing`; `TradingServerScreen` không có trailing. Xóa `_BrokerToolbar` và Stack toolbar trùng lặp.

- [ ] **Step 5: Chạy GREEN và regression file**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_catalog_video_test.dart
```

Expected: tất cả test trong file pass.

- [ ] **Step 6: Commit Task 1**

```powershell
git add mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart mobile/test/account_link_catalog_video_test.dart
git commit -m "fix: match account link toolbar geometry"
```

---

### Task 2: Responsive broker and server frames with live data

**Files:**
- Modify: `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`
- Modify: `mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart`
- Test: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: `AccountLinkRepository.brokers({String query})`, `AccountLinkRepository.servers(String brokerId, {String query})`.
- Produces: responsive broker/server frames that render arbitrary API names and IDs without production fixtures.

- [ ] **Step 1: Viết test RED với broker/server động và tên dài**

Repository test trả:

```dart
const MobileBroker(
  id: 'yodo-demo',
  name: 'YODO Demo Markets',
  companyName: 'YODO Markets International Limited',
)
```

và server `yodo-demo-01`. Ở width 360, test `tester.takeException()` là null, row nằm giữa toolbar và search field, title/search không overflow, và không tìm thấy chuỗi `Exness` hoặc `MetaQuotes`.

- [ ] **Step 2: Chạy test và xác nhận RED đúng sai lệch layout**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_catalog_video_test.dart --plain-name "live catalog data keeps the video frame responsive"
```

- [ ] **Step 3: Hiệu chỉnh frame tối thiểu theo video**

- Toolbar giữ chiều cao 66.
- Broker row giữ hit target 72, mark 31, info hit target 43.
- List chỉ có top padding nhỏ và không chèn fixture.
- Search field dùng SafeArea đáy, margin ngang 20–24 và pill border.
- Server list dùng nền `AppColors.surface`, row pitch 56, divider inset 16 và check màu primary.
- Broker/server name dài dùng `maxLines: 1` + ellipsis.

- [ ] **Step 4: Chạy GREEN ở width 360/390/430**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_catalog_video_test.dart
```

- [ ] **Step 5: Commit Task 2**

```powershell
git add mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart mobile/lib/features/account_link/presentation/widgets/account_link_toolbar.dart mobile/test/account_link_catalog_video_test.dart
git commit -m "fix: align live broker and server frames"
```

---

### Task 3: Account form video behavior and geometry

**Files:**
- Modify: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Test: `mobile/test/account_link_login_video_test.dart`

**Interfaces:**
- Consumes: `AccountLinkController.updateLogin`, `updatePassword`, `updateSavePassword`, `selectServer`, `submit`.
- Produces: video-aligned form that preserves raw controller values across the server route.

- [ ] **Step 1: Viết test RED cho frame ở 360/390/430**

Test mở broker động, kiểm tra header Back + mark + name không overflow; section order đúng; server/login/password/save-password rows không overlap; forgot-password và login action nằm đúng thứ tự. Khi `viewInsets.bottom = 300`, input đang focus và action vẫn nằm trong viewport khả dụng.

- [ ] **Step 2: Chạy test RED**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_login_video_test.dart --plain-name "account form matches the reference frame responsively"
```

- [ ] **Step 3: Hiệu chỉnh form tối thiểu**

- Header cao 72, Back hit target 43, broker mark 31 và tên ellipsis.
- Section labels cao 42; registration rows min-height 92; value/input/save rows dùng cùng row frame.
- `SingleChildScrollView` chịu keyboard inset; action nằm ngoài scroll content và SafeArea quản lý đáy.
- Không thay `TextEditingController` synchronization hoặc password transform.

- [ ] **Step 4: Xác minh field preservation và submit contract**

Chạy các test hiện có:

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_login_video_test.dart --plain-name "20 to 28 second route sequence preserves fields and enables login"
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_login_video_test.dart --plain-name "invalid credentials clear only password and stay on the form"
```

- [ ] **Step 5: Chạy toàn bộ file và commit**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_login_video_test.dart
git add mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart mobile/test/account_link_login_video_test.dart
git commit -m "fix: match existing account form video frame"
```

---

### Task 4: End-to-end route parity and data-source guard

**Files:**
- Modify: `mobile/test/account_link_cross_tab_video_test.dart`
- Modify: `mobile/test/account_link_catalog_video_test.dart`
- Modify: `mobile/test/account_link_login_video_test.dart`
- Modify only if a failing test proves necessary: `mobile/lib/app/router.dart`

**Interfaces:**
- Consumes: `/accounts/add`, `/accounts/add/:brokerId`, `/accounts/add/:brokerId/servers`, `/trade`.
- Produces: tested route sequence whose visible business data comes only from repository responses.

- [ ] **Step 1: Viết route test RED/GREEN cho toàn chuỗi video**

Test dùng fake repository với YODO IDs, thực hiện:

```text
/accounts/add
→ tap broker-row-yodo-demo
→ /accounts/add/yodo-demo
→ nhập login/password
→ mở /servers
→ chọn server-row-yodo-demo-01
→ quay lại form với nguyên field
→ submit
→ chờ activate/bootstrap
→ /trade
```

Assertions phải kiểm tra repository nhận đúng IDs động và production UI không tự thêm broker khác.

- [ ] **Step 2: Chạy test mục tiêu và chỉ sửa router nếu test chứng minh cần thiết**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/account_link_cross_tab_video_test.dart test/account_link_catalog_video_test.dart test/account_link_login_video_test.dart
```

- [ ] **Step 3: Quét secret/log regression**

Kiểm tra added lines không chứa lệnh log cho `password`, `deviceToken`, `Authorization`, `reconnectGrant` hoặc request body.

- [ ] **Step 4: Commit Task 4 nếu có thay đổi**

```powershell
git add mobile/test/account_link_cross_tab_video_test.dart mobile/test/account_link_catalog_video_test.dart mobile/test/account_link_login_video_test.dart mobile/lib/app/router.dart
git commit -m "test: cover live new account video flow"
```

---

### Task 5: Full verification and LDPlayer comparison

**Files:**
- Verify: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Create as ignored evidence only: `.codex_tmp/new-account-final/*.png`

**Interfaces:**
- Consumes: completed Flutter source and EX V2 live catalog.
- Produces: analyzer/test/build evidence and LDPlayer screenshots; no source API mutations.

- [ ] **Step 1: Chạy Flutter analyze và toàn bộ tests**

```powershell
cd D:\mt5New\mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
```

- [ ] **Step 2: Build APK**

```powershell
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

- [ ] **Step 3: Chạy backend build/test theo AGENTS.md**

```powershell
cd D:\mt5New\backend
dotnet build Trading.sln --no-restore
dotnet test Trading.sln --no-build
```

- [ ] **Step 4: Cài APK và chụp frame LDPlayer**

Cài APK lên instance `MT5-Dev`, mở Cài đặt → Tài khoản → dấu cộng, sau đó chụp Brokers, form và Máy chủ. Không nhập hoặc ghi lại password trong ảnh/log.

- [ ] **Step 5: Đối chiếu và sửa lệch nếu có**

So sánh các ảnh cuối với frame 08s, 10s, 12s, 14s và 30s. Nếu có lệch hình học, quay lại vòng RED/GREEN tương ứng trước khi build lại.

- [ ] **Step 6: Báo cáo cuối**

Báo cáo root cause, file/dòng sửa, test pass/fail, analyzer, Flutter build, backend build/test, ảnh LDPlayer, commit và xác nhận không thêm secret/log nhạy cảm.
