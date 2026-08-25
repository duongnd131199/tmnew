# Order Rejection and Zero Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make account `3428` able to place funded demo orders and make every genuine order rejection show its safe server reason instead of only `Không thể đặt lệnh`.

**Architecture:** Keep EX V2 authoritative for funds and trade validation. Restore demo funds through the existing admin/wallet workflow, then route the already-typed client failures through one shared presentation helper used by New Order and Chart; do not change mutation retries, idempotency, or post-success refresh behavior.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, flutter_test, EX V2 REST API, LDPlayer/ADB.

**Spec:** `docs/superpowers/specs/2026-08-20-order-rejection-diagnostics-design.md`

## Global Constraints

- Do not hard-code balance, equity, margin, execution price, or a successful order in Flutter.
- Do not submit a production/real-money order; use only the configured demo account and the minimum supported volume.
- Do not log or display device tokens, passwords, or full request headers.
- Do not retry `POST /orders` automatically.
- Preserve one unique idempotency key per user action.
- Preserve the current behavior where a successful POST survives a failed follow-up bootstrap.
- Do not modify the unrelated legacy `/ex/api/api/*` service.
- Run Flutter analyze, tests, and build plus backend build/tests required by `AGENTS.md` before completion.

---

### Task 1: Prove the rejection path without changing trade state

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`
- Verify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart:433`
- Verify: `mobile/lib/features/account_sync/data/ex_v2_api_client.dart:140`

**Interfaces:**
- Consumes: `Future<ExV2Order> ExV2AccountController.createOrder(...)`
- Produces: regression evidence that HTTP 422 retains `statusCode`, `code`, `message`, and `correlationId` and rolls back only the rejected optimistic row

- [ ] **Step 1: Extend the fake rejection response with diagnostic identity**

  Make the test adapter return:

  ```dart
  return _json(
    {
      'code': 'INSUFFICIENT_MARGIN',
      'message': 'Insufficient free margin',
      'correlationId': 'order-correlation-1',
    },
    statusCode: 422,
  );
  ```

- [ ] **Step 2: Assert the complete typed failure and rollback**

  ```dart
  await expectLater(
    container.read(exV2AccountProvider.notifier).createOrder(
      symbol: 'XAUUSD+',
      side: 'buy',
      volume: 0.01,
    ),
    throwsA(
      isA<ExV2RequestFailure>()
          .having((error) => error.statusCode, 'statusCode', 422)
          .having((error) => error.code, 'code', 'INSUFFICIENT_MARGIN')
          .having(
            (error) => error.correlationId,
            'correlationId',
            'order-correlation-1',
          ),
    ),
  );
  expect(container.read(exV2AccountProvider).value!.orders, isEmpty);
  expect(
    container.read(exV2AccountProvider).value!.pendingOperationIds,
    isEmpty,
  );
  ```

- [ ] **Step 3: Run the focused controller test**

  Run:

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart
  ```

  Expected: PASS without a live order request.

- [ ] **Step 4: Commit the regression evidence**

  ```powershell
  git add mobile/test/ex_v2_trading_command_test.dart
  git commit -m "test: preserve order rejection diagnostics"
  ```

### Task 2: Add one safe order-error presenter

**Files:**
- Create: `mobile/lib/features/order/presentation/order_failure_message.dart`
- Create: `mobile/test/order_failure_message_test.dart`

**Interfaces:**
- Consumes: `ExV2RequestFailure.safeDisplayMessage`, `ExV2ClientFailure.message`
- Produces: `String orderFailureMessage(Object error, {required String fallback})`

- [ ] **Step 1: Write failing presenter tests**

  ```dart
  test('shows structured EX V2 rejection details', () {
    const failure = ExV2RequestFailure(
      statusCode: 422,
      code: 'INSUFFICIENT_MARGIN',
      message: 'Insufficient free margin',
      correlationId: 'order-correlation-1',
    );

    expect(
      orderFailureMessage(failure, fallback: 'Không thể đặt lệnh'),
      contains('Insufficient free margin'),
    );
    expect(
      orderFailureMessage(failure, fallback: 'Không thể đặt lệnh'),
      contains('INSUFFICIENT_MARGIN'),
    );
    expect(
      orderFailureMessage(failure, fallback: 'Không thể đặt lệnh'),
      contains('order-correlation-1'),
    );
  });

  test('keeps generic copy for unknown errors', () {
    expect(
      orderFailureMessage(StateError('secret'), fallback: 'Không thể đặt lệnh'),
      'Không thể đặt lệnh',
    );
  });
  ```

- [ ] **Step 2: Run the test and verify it fails because the helper is absent**

  Run:

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\order_failure_message_test.dart
  ```

  Expected: FAIL because `order_failure_message.dart` does not exist.

- [ ] **Step 3: Implement the minimal shared helper**

  ```dart
  import 'package:trading_mobile/features/account_sync/data/ex_v2_api_client.dart';

  String orderFailureMessage(
    Object error, {
    required String fallback,
  }) => switch (error) {
    ExV2RequestFailure failure => failure.safeDisplayMessage,
    ExV2ClientFailure failure => failure.message,
    _ => fallback,
  };
  ```

- [ ] **Step 4: Run and pass the presenter tests**

  Run the same focused test. Expected: PASS.

- [ ] **Step 5: Commit the shared presenter**

  ```powershell
  git add mobile/lib/features/order/presentation/order_failure_message.dart mobile/test/order_failure_message_test.dart
  git commit -m "feat: expose safe order rejection details"
  ```

### Task 3: Use the typed failure on the New Order ticket

**Files:**
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart:118`
- Modify: `mobile/test/video_interactions_test.dart`

**Interfaces:**
- Consumes: `orderFailureMessage(Object, {required String fallback})`
- Produces: safe market and pending rejection SnackBars on New Order

- [ ] **Step 1: Add widget tests for market and pending rejections**

  Override the production providers with the existing fake EX V2 adapter, tap
  the appropriate ticket action, and assert:

  ```dart
  expect(find.textContaining('Insufficient free margin'), findsOneWidget);
  expect(find.textContaining('INSUFFICIENT_MARGIN'), findsOneWidget);
  expect(find.textContaining('order-correlation-1'), findsOneWidget);
  expect(find.text('Không thể đặt lệnh'), findsNothing);
  ```

  For an injected `StateError`, assert the exact fallback remains
  `Không thể đặt lệnh`; use `Không thể đặt lệnh chờ` for the pending action.

- [ ] **Step 2: Run only the new widget tests and verify the structured-message assertions fail**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\video_interactions_test.dart --plain-name "order rejection"
  ```

- [ ] **Step 3: Replace catch-all message loss with the shared presenter**

  In `_submit`:

  ```dart
  } catch (error) {
    if (!mounted) return;
    setState(() => submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          orderFailureMessage(error, fallback: 'Không thể đặt lệnh'),
        ),
      ),
    );
  }
  ```

  Apply the same pattern to `_submitPendingOrder` with fallback
  `Không thể đặt lệnh chờ`.

- [ ] **Step 4: Run and pass the focused widget tests**

  Expected: the typed response is visible and unknown exceptions remain safe.

- [ ] **Step 5: Commit the New Order integration**

  ```powershell
  git add mobile/lib/features/order/presentation/screens/new_order_screen.dart mobile/test/video_interactions_test.dart
  git commit -m "fix: show new-order rejection reason"
  ```

### Task 4: Use the same typed failure on Chart orders

**Files:**
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart:2112`
- Modify: `mobile/test/chart_market_order_dispatch_regression_test.dart`

**Interfaces:**
- Consumes: `orderFailureMessage(Object, {required String fallback})`
- Produces: the same safe rejection semantics for chart market/pending commands

- [ ] **Step 1: Add a source-level regression assertion before the larger chart harness**

  Extend the existing regression test to require both chart command catch
  blocks to call `orderFailureMessage` and to forbid a constant generic
  SnackBar in those blocks:

  ```dart
  expect(marketMethod, contains('orderFailureMessage(error'));
  expect(
    marketMethod,
    isNot(contains("const SnackBar(content: Text('Không thể đặt lệnh'))")),
  );
  ```

- [ ] **Step 2: Run the focused test and verify it fails against the current catch blocks**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\chart_market_order_dispatch_regression_test.dart
  ```

- [ ] **Step 3: Change both chart catches to preserve the error**

  Use `catch (error)` and pass the error to the shared helper. Keep the market
  fallback `Không thể đặt lệnh` and pending fallback
  `Không thể đặt lệnh chờ`. Do not add a mutation retry or reuse the pending
  command lock for rapid market taps.

- [ ] **Step 4: Run and pass chart order tests**

  ```powershell
  D:\toolchains\flutter\bin\flutter.bat test test\chart_market_order_dispatch_regression_test.dart test\ex_v2_trading_command_test.dart
  ```

- [ ] **Step 5: Commit the Chart integration**

  ```powershell
  git add mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/test/chart_market_order_dispatch_regression_test.dart
  git commit -m "fix: show chart order rejection reason"
  ```

### Task 5: Restore legitimate demo funds for account 3428

**Files:**
- No Flutter source changes.
- Verify: `docs/ex-v2-mobile-integration.md`

**Interfaces:**
- Consumes: the existing EX V2 admin/deposit workflow and active account `3428`
- Produces: a server-owned positive balance/equity/free-margin snapshot

- [ ] **Step 1: Confirm account identity before any financial mutation**

  In the installed app, verify Settings still shows account `3428`. In the EX
  V2 admin, verify the same account is active for this device. Stop if the IDs
  differ.

- [ ] **Step 2: Create one demo deposit through the existing admin/wallet workflow**

  Use the normal demo deposit/approval path already exposed by EX V2. Do not
  edit Flutter constants, direct database rows, or production/real-money
  balances. Record the server transaction ID for rollback/audit.

- [ ] **Step 3: Verify the authoritative snapshot**

  Refresh the app and confirm Trade shows all three values above zero:

  ```text
  Số dư > 0
  Vốn > 0
  Ký quỹ dư > 0
  ```

  Confirm History contains the corresponding server deposit exactly once.

- [ ] **Step 4: Do not commit anything for the operational deposit**

  The deposit is server state, not repository source.

### Task 6: Full verification and one authorized demo-order probe

**Files:**
- Verify only; no additional production files expected.

**Interfaces:**
- Consumes: funded account `3428`, debug APK, running LDPlayer
- Produces: build/test evidence and one confirmed minimum-volume demo order

- [ ] **Step 1: Format and run Flutter verification**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\dart.bat format lib test
  D:\toolchains\flutter\bin\flutter.bat analyze
  D:\toolchains\flutter\bin\flutter.bat test
  D:\toolchains\flutter\bin\flutter.bat build apk --debug
  ```

  Expected: formatting clean, analyze has no issues, all tests pass, and APK
  exists at `D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 2: Run required backend verification without changing EX V2**

  ```powershell
  cd D:\mt5New\backend
  dotnet build Trading.sln
  dotnet test Trading.sln --no-build
  ```

  Expected: build and tests pass. The local backend contains market-feed code,
  not the deployed EX V2 order implementation, so passing it is a regression
  guard rather than proof of the remote order fix.

- [ ] **Step 3: Install without clearing account state**

  ```powershell
  D:\toolchains\android-sdk\platform-tools\adb.exe -s 127.0.0.1:5555 install -r D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk
  ```

- [ ] **Step 4: With explicit authorization, submit exactly one minimum-volume demo market order**

  Use account `3428`, an actively quoted tradable symbol, and volume `0.01`.
  Verify exactly one order/position appears and record its server order ID. Do
  not repeat the tap while awaiting the response.

- [ ] **Step 5: Verify the rejection presentation separately with a fake response**

  Do not manufacture a live insufficient-margin failure after funding. Use the
  automated HTTP 422 adapter tests to prove the safe code/message/correlation
  output.

- [ ] **Step 6: Commit only verified source changes**

  ```powershell
  git status --short
  git add mobile/lib/features/order/presentation/order_failure_message.dart mobile/lib/features/order/presentation/screens/new_order_screen.dart mobile/lib/features/chart/presentation/screens/chart_screen.dart mobile/test/order_failure_message_test.dart mobile/test/video_interactions_test.dart mobile/test/chart_market_order_dispatch_regression_test.dart mobile/test/ex_v2_trading_command_test.dart
  git commit -m "fix: preserve order rejection diagnostics"
  ```

