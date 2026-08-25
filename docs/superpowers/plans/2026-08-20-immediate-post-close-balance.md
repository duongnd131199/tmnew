# Immediate Post-Close Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the authoritative EX V2 balance as soon as the first valid post-close bootstrap arrives, without waiting for slower History reconciliation.

**Architecture:** Split the existing post-close reconciliation into an early core publication and a later History publication. Both phases remain account/version scoped, preserve optimistic overlays, and use only server-owned financial values; the close mutation is still sent exactly once.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, Dio, flutter_test, LDPlayer/ADB.

**Spec:** `docs/superpowers/specs/2026-08-20-immediate-post-close-balance-design.md`

## Global Constraints

- Do not change the required technology stack.
- Do not calculate or guess balance, realized profit, equity, margin, or free margin in Flutter.
- Send `POST /positions/{positionId}/close` exactly once per close action.
- Retry only canonical GET reads after a committed close.
- Preserve account-generation and bootstrap-version guards.
- Preserve unrelated dirty-worktree changes.
- Do not place or close another live/demo position during implementation verification without explicit authorization.
- Run Flutter analyze, relevant/full tests, APK build, backend build/tests, and LDPlayer launch verification before completion.

---

### Task 1: Add a RED test for the hidden authoritative balance

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart:183`

**Interfaces:**
- Consumes: `ExV2AccountController.closePosition(String, {double? volume})`
- Consumes: `demoAccountProvider`
- Produces: a controlled point after post-close bootstrap succeeds but before History returns

- [ ] **Step 1: Add completion tracking around the existing History gate**

  Add a test named
  `close publishes authoritative balance before delayed history completes`.
  Configure the existing adapter and gates:

  ```dart
  final historyGate = Completer<void>();
  final historyStarted = Completer<void>();
  final adapter = _TradingAdapter()
    ..created = true
    ..postCloseHistoryGate = historyGate
    ..postCloseHistoryStarted = historyStarted;
  final container = _container(adapter);
  addTearDown(() {
    if (!historyGate.isCompleted) historyGate.complete();
    container.dispose();
  });
  await container.read(exV2AccountProvider.future);

  var closeCompleted = false;
  final closing = container
      .read(exV2AccountProvider.notifier)
      .closePosition('server-position-1')
      .whenComplete(() => closeCompleted = true);
  await historyStarted.future;
  ```

- [ ] **Step 2: Assert the required intermediate state**

  Before completing `historyGate`, assert:

  ```dart
  final accountState = container.read(exV2AccountProvider).value!;
  expect(closeCompleted, isFalse);
  expect(adapter.closePosts, 1);
  expect(accountState.positions, isEmpty);
  expect(accountState.balance, closeTo(5306.525, 0.000001));
  expect(
    container.read(demoAccountProvider).balance,
    closeTo(5306.525, 0.000001),
  );
  expect(
    accountState.pendingOperationIds,
    contains('position:server-position-1'),
  );
  ```

  Then release and finish cleanly:

  ```dart
  historyGate.complete();
  await closing;
  ```

- [ ] **Step 3: Run the new test and observe RED**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart --plain-name "close publishes authoritative balance before delayed history completes"
  ```

  Expected: FAIL because the intermediate balance remains `5000.0`; the
  position assertion already passes.

- [ ] **Step 4: Commit only the failing regression test**

  ```powershell
  git add mobile/test/ex_v2_trading_command_test.dart
  git commit -m "test: expose delayed post-close balance"
  ```

### Task 2: Publish the first valid post-close core immediately

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart:727`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `_isCoreCloseVisible(...)`
- Produces: `_publishCommittedCloseCore(...) -> void`
- Preserves: pending close marker until History completion

- [ ] **Step 1: Add a focused core-publication helper**

  Add this private method beside `_isCoreCloseVisible`:

  ```dart
  void _publishCommittedCloseCore({
    required ExV2AccountViewState core,
    required _AccountMutationScope scope,
  }) {
    if (!_isMutationScopeCurrent(scope)) return;
    final current = state.value;
    if (current == null ||
        core.bootstrap.account.id != scope.accountId ||
        core.bootstrap.summary.accountId != scope.accountId ||
        core.bootstrap.version < current.bootstrap.version) {
      return;
    }
    final published = _applyOptimisticOverlay(
      _mergeCoreWithHydrated(core, current),
      current,
    );
    state = AsyncData(published);
  }
  ```

  This publishes the server bootstrap but keeps current deals, closed history,
  History summary, presentation metadata, hidden-position protection, and all
  pending operation IDs. Hidden-position protection is cleared only by the
  existing final reconciliation path.

- [ ] **Step 2: Call the helper at the first proven core snapshot**

  In `_retryCommittedCloseHistory`, replace the assignment-only block:

  ```dart
  if (_isCoreCloseVisible(
    core: core,
    positionId: positionId,
    isPartial: isPartial,
    expectedRemainingVolume: expectedRemainingVolume,
  )) {
    latestAuthoritativeCore = core;
    _publishCommittedCloseCore(
      core: core,
      scope: scope,
    );
  }
  ```

  Do this before awaiting `_loadTradingHistorySnapshot(repository)`.

- [ ] **Step 3: Keep History completion atomic**

  Leave the later successful state assignment responsible for replacing
  `deals`, `historyPositions`, and `historySummary` and clearing
  `position:$positionId`. Do not clear the pending marker in the early helper.

- [ ] **Step 4: Run the RED test and require GREEN**

  Run the Task 1 command. Expected: PASS, with `closeCompleted == false` when
  the balance is already `5306.525`.

- [ ] **Step 5: Run existing close race tests**

  ```powershell
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart --plain-name "close history cannot overwrite a newer optimistic command"
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart --plain-name "close history preserves a concurrent position protection edit"
  ```

  Expected: both PASS; the early publication must retain the concurrent
  sending order and protection edit.

- [ ] **Step 6: Commit the minimal provider fix**

  ```powershell
  git add mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_trading_command_test.dart
  git commit -m "fix: publish post-close balance immediately"
  ```

### Task 3: Cover partial close and decouple fake balance from position presence

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart:427`
- Modify: `mobile/test/ex_v2_trading_command_test.dart:1010`

**Interfaces:**
- Extends test helper: `_bootstrap(..., double? balanceOverride)`
- Produces: canonical partial-close balance and remaining-volume coverage

- [ ] **Step 1: Make the fake bootstrap express partial-close balance**

  Add a nullable `balanceOverride` argument and calculate one fake server value:

  ```dart
  Map<String, Object?> _bootstrap({
    required int version,
    required bool withPosition,
    bool withPending = false,
    double remainingVolume = 0.01,
    bool withOppositePosition = false,
    String accountId = 'account-1',
    double? balanceOverride,
  }) {
    final balance = balanceOverride ?? (withPosition ? 5000.0 : 5306.525);
    return {
      // existing fields
      'summary': {
        'accountId': accountId,
        'currency': 'USD',
        'balance': balance,
        'equity': balance,
        'profit': 0,
        'margin': 0,
        'freeMargin': balance,
        'marginLevel': 0,
        'updatedAt': '2026-08-13T14:00:00Z',
      },
      // existing fields
    };
  }
  ```

  For a post-close bootstrap request, pass `balanceOverride` as `5120.0` when
  `remainingVolume > 0` and `< 0.01`, and `5306.525` after a full close.

- [ ] **Step 2: Add an intermediate partial-close assertion**

  Start a close with `volume: 0.004`, block History, and assert before releasing
  the gate:

  ```dart
  final state = container.read(exV2AccountProvider).value!;
  expect(state.positions.single.volume, closeTo(0.006, 0.000001));
  expect(state.balance, closeTo(5120.0, 0.000001));
  expect(container.read(demoAccountProvider).balance, closeTo(5120.0, 0.000001));
  expect(adapter.closePosts, 1);
  ```

- [ ] **Step 3: Run full and partial focused tests**

  ```powershell
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart --plain-name "close publishes authoritative balance before delayed history completes"
  D:\toolchains\flutter\bin\flutter.bat test test\ex_v2_trading_command_test.dart --plain-name "partial close"
  ```

  Expected: all selected tests PASS.

- [ ] **Step 4: Commit partial-close coverage**

  ```powershell
  git add mobile/test/ex_v2_trading_command_test.dart
  git commit -m "test: cover immediate partial-close balance"
  ```

### Task 4: Prove stale, failed, and cross-account reads cannot corrupt balance

**Files:**
- Modify: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Consumes: `_publishCommittedCloseCore(...)`
- Produces: version, history-failure, and active-account regression coverage

- [ ] **Step 1: Strengthen the stale-bootstrap test**

  Gate the second post-close bootstrap. After the first stale response, assert
  the state still has the pre-close `5000.0` balance; after releasing the gate,
  assert it changes once to `5306.525`.

- [ ] **Step 2: Strengthen the history-failure test**

  In `committed close keeps authoritative balance when history endpoint fails`,
  listen to `exV2AccountProvider` and record balances. Assert `5306.525` is
  observed before `closePosition()` completes and is not replaced by `5000.0`
  afterward.

- [ ] **Step 3: Add a cross-account late-response assertion**

  Reuse the existing account-switch adapter mode. Switch the active scope while
  post-close History is gated and assert neither the old account's `5000.0` nor
  `5306.525` is published into the new account state.

- [ ] **Step 4: Assert mutation idempotency in every delayed case**

  Add:

  ```dart
  expect(adapter.closePosts, 1);
  ```

  after each delayed/stale/failure scenario.

- [ ] **Step 5: Run the complete trading command file**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test --concurrency=1 test\ex_v2_trading_command_test.dart
  ```

  Expected: all tests PASS and no close test reports more than one POST.

- [ ] **Step 6: Commit safety coverage**

  ```powershell
  git add mobile/test/ex_v2_trading_command_test.dart
  git commit -m "test: guard immediate close balance races"
  ```

### Task 5: Verify the Trade-facing provider and navigation behavior

**Files:**
- Modify: `mobile/test/video_interactions_test.dart`
- Verify: `mobile/lib/shared/providers/demo_data_provider.dart:1503`
- Verify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart:80`
- Verify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart:241`

**Interfaces:**
- Consumes: `demoAccountProvider.balance`
- Produces: proof that Trade renders provider changes without manual refresh or reopening

- [ ] **Step 1: Add a Trade widget provider-update test**

  Pump `TradeScreen` using the existing provider container, capture the initial
  balance text, publish a same-account `ExV2AccountViewState` whose bootstrap
  balance is `5306.525`, pump one frame, and assert the Trade metric changes to
  the formatted `5306.53` without recreating the widget or changing tabs.

- [ ] **Step 2: Run the new widget test RED/GREEN cycle**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\flutter.bat test test\video_interactions_test.dart --plain-name "Trade redraws balance from a committed close snapshot"
  ```

  Expected before production change: the isolated provider-rendering portion
  already passes. Combined with Task 1, this proves the defect is publication
  timing rather than `TradeScreen` caching; no Trade widget change is needed.

- [ ] **Step 3: Preserve close-ticket behavior**

  Run the existing ticket close tests and verify the success/fallback routes
  are unchanged. Do not add a timer, local balance calculation, or manual
  `setState` to `TradeScreen`.

- [ ] **Step 4: Commit only if a new test was added**

  ```powershell
  git add mobile/test/video_interactions_test.dart
  git commit -m "test: verify Trade balance provider refresh"
  ```

### Task 6: Full verification and LDPlayer evidence

**Files:**
- Verify only; no additional source changes expected.

**Interfaces:**
- Consumes: debug APK and running LDPlayer
- Produces: build/test evidence and a visual post-close balance check

- [ ] **Step 1: Format only touched Dart files**

  ```powershell
  cd D:\mt5New\mobile
  D:\toolchains\flutter\bin\dart.bat format lib\features\account_sync\application\ex_v2_account_provider.dart test\ex_v2_trading_command_test.dart test\video_interactions_test.dart
  ```

- [ ] **Step 2: Run Flutter verification**

  ```powershell
  D:\toolchains\flutter\bin\flutter.bat analyze
  D:\toolchains\flutter\bin\flutter.bat test --concurrency=1 test\ex_v2_trading_command_test.dart test\video_interactions_test.dart test\history_screen_detail_test.dart
  D:\toolchains\flutter\bin\flutter.bat test --concurrency=1
  D:\toolchains\flutter\bin\flutter.bat build apk --debug
  ```

  Expected: analyze clean, focused/full tests pass, and APK exists at
  `D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 3: Run required backend regression checks**

  ```powershell
  cd D:\mt5New\backend
  dotnet build Trading.sln
  dotnet test Trading.sln --no-build
  ```

  Expected: build and all backend tests pass. The deployed EX V2 order source
  is not in this local backend, so no backend change is planned for this defect.

- [ ] **Step 4: Install without clearing account state**

  ```powershell
  D:\toolchains\android-sdk\platform-tools\adb.exe -s 127.0.0.1:5555 install -r D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk
  ```

- [ ] **Step 5: Verify safely before any financial command**

  Launch the app, confirm the correct demo account is active, and capture the
  pre-close Trade balance. Do not create or close a position unless the user
  explicitly authorizes that state-changing probe.

- [ ] **Step 6: With explicit authorization, close exactly one minimum-volume demo position**

  Record the displayed balance before tapping close. After the server confirms,
  verify Trade shows the new balance on the first rendered frame after the
  updated bootstrap, without switching tabs, reopening Trade, or manual
  refresh. Confirm History may finish later but cannot revert the new balance.

- [ ] **Step 7: Capture and report evidence**

  Save before/after screenshots under
  `D:\mt5New\docs\screenshots\post-close-balance\`, report timestamps and the
  server order/position ID, and confirm exactly one close was submitted.

- [ ] **Step 8: Review the final diff**

  ```powershell
  cd D:\mt5New
  git diff --check
  git status --short
  git diff -- mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_trading_command_test.dart mobile/test/video_interactions_test.dart
  ```

  Verify there are no tokens, credentials, request bodies, unrelated UI edits,
  or automatic mutation retries.
