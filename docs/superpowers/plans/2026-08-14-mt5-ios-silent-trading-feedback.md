# MT5 iOS Silent Trading Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove non-MT5 technical and success notifications while preserving immediate optimistic state, concise failures, and duplicate-submit protection.

**Architecture:** Keep EX V2 commands, Riverpod optimistic updates, idempotency, rollback, and reconciliation unchanged. Change only presentation feedback: successful commands dismiss their action surface silently, slow commands expose no infrastructure copy, and failures are converted to concise user-facing trading outcomes.

**Tech Stack:** Flutter 3.44+, Riverpod, GoRouter, Dio, flutter_test, ASP.NET Core .NET 8 compatibility verification.

## Global Constraints

- Do not change API contracts, token storage, idempotency, database behavior, or backend deployment.
- Do not change the main layout or navigation.
- Do not expose `server`, `máy chủ`, `đồng bộ`, `vui lòng chờ`, `đã gửi yêu cầu`, URLs, correlation IDs, or exception strings in action feedback.
- Keep input validation, trading rejection, authentication, and connectivity failures visible in concise user-facing language.
- Keep initial loading and empty-state UI.

---

### Task 1: New Order and Close Ticket Feedback

**Files:**
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Test: `mobile/test/video_interactions_test.dart`

**Interfaces:**
- Consumes: `_submitMarketOrder`, `_submitPendingOrder`, `_closePosition`, `submitting`, `_OrderResult`.
- Produces: silent in-flight ticket state and concise failure copy without infrastructure terms.

- [ ] **Step 1: Write failing widget tests**

Add assertions during a gated command and stale close response:

```dart
expect(find.textContaining('server'), findsNothing);
expect(find.textContaining('đồng bộ'), findsNothing);
expect(find.textContaining('Vui lòng chờ'), findsNothing);
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
flutter test test/video_interactions_test.dart
```

Expected: failure because `_OrderResult` and stale-close SnackBar still expose forbidden copy.

- [ ] **Step 3: Implement minimal presentation changes**

Remove the technical waiting text and stale-close synchronization SnackBar. Keep the submitting guard and preserve filled/pending result rendering after a valid response. Replace interpolated exception SnackBars with a concise action outcome such as `Không thể đặt lệnh` or `Không thể đóng vị thế`.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the same command and require all tests in the file to pass.

### Task 2: Trade Action Success Messages

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Test: `mobile/test/video2_cross_tab_test.dart`
- Test: `mobile/test/video_interactions_test.dart`

**Interfaces:**
- Consumes: optimistic methods on `DemoTradingController`.
- Produces: menus that dismiss silently after close-by, bulk close, and cancel.

- [ ] **Step 1: Write failing widget tests**

After a successful trade action, assert no `SnackBar` and no success message:

```dart
expect(find.byType(SnackBar), findsNothing);
expect(find.textContaining('Đã đóng'), findsNothing);
expect(find.textContaining('Đã gửi yêu cầu'), findsNothing);
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
flutter test test/video2_cross_tab_test.dart test/video_interactions_test.dart
```

Expected: failure because `_showActionResult` still creates success SnackBars.

- [ ] **Step 3: Implement silent success behavior**

Remove `_showActionResult` calls from successful close-by, bulk close, and pending-order cancel flows. Keep the action controller calls, optimistic state updates, sheet dismissal, and invalid/no-candidate guards.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the same command and require all tests to pass.

### Task 3: Chart, Position, and Wallet Feedback Policy

**Files:**
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Modify: `mobile/lib/features/wallet/presentation/screens/wallet_request_screen.dart`
- Test: `mobile/test/chart_controls_test.dart`
- Test: `mobile/test/position_detail_functionality_test.dart`
- Test: `mobile/test/wallet_server_data_test.dart`

**Interfaces:**
- Consumes: existing action callbacks and optimistic providers.
- Produces: silent successful mutations and concise validation/failure feedback.

- [ ] **Step 1: Add failing message-policy assertions**

Assert successful actions do not render processing/success SnackBars and errors do not interpolate raw exception values:

```dart
expect(find.textContaining('đang chờ duyệt'), findsNothing);
expect(find.textContaining('Không gửi được yêu cầu:'), findsNothing);
expect(find.textContaining('server'), findsNothing);
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```powershell
flutter test test/chart_controls_test.dart test/position_detail_functionality_test.dart test/wallet_server_data_test.dart
```

- [ ] **Step 3: Apply the feedback policy**

Remove successful action SnackBars. Preserve validation messages. Replace raw `$error` presentation with fixed concise messages. Do not alter providers, HTTP calls, mutation ordering, or navigation.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the same command and require all tests to pass.

### Task 4: Forbidden-Copy Audit and Full Verification

**Files:**
- Modify if required: presentation files under `mobile/lib/features/**/presentation/`
- Test: all mobile and backend tests.

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: verified APK installed on the existing LDPlayer device.

- [ ] **Step 1: Audit user-facing presentation copy**

Run:

```powershell
rg -n -i "server|máy chủ|đồng bộ|vui lòng chờ|đã gửi yêu cầu|đang chờ duyệt" mobile/lib/features --glob "*.dart"
```

Review every match; retain only non-action domain labels or device-gate failures allowed by the spec.

- [ ] **Step 2: Run formatter and analyzer**

```powershell
dart format <changed dart files>
flutter analyze
```

- [ ] **Step 3: Run all tests and backend compatibility checks**

```powershell
flutter test --concurrency=1
dotnet build backend/Trading.sln --no-restore
dotnet test backend/Trading.sln --no-build --no-restore
```

- [ ] **Step 4: Build and install APK**

```powershell
flutter build apk --debug
adb -s emulator-5558 install -r mobile/build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 5: Launch and inspect**

Launch `com.tradingdemo.trading_mobile`, confirm its activity is resumed, and inspect logcat for Flutter exceptions or crashes. Do not create production demo trades solely for acceptance.
