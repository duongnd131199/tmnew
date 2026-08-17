# History Close Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flutter History show a canonical closed-position row with the correct volume-weighted close price after full close, partial closes, and close-by.

**Architecture:** Add a pure reconciliation utility that joins raw history positions to raw exit deals by normalized position ID and computes an effective close price. Use the utility both during ordinary account hydration and during a bounded, account-scoped post-close refresh so Trade, Deals, and History converge on one server snapshot without inventing financial data.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, Dio, flutter_test.

## Global Constraints

- Do not change the backend, public base URL, authentication, or required technology stack.
- Server position/deal values remain canonical; do not calculate realized profit, balance, or equity in Flutter.
- Do not log financial payloads, credentials, device tokens, or authorization headers.
- Preserve unrelated dirty-worktree changes.
- Write and observe each regression test failing before changing production code.
- Run relevant tests after each task, then full Flutter test, analyze, and APK build at completion.

---

### Task 1: Deterministic history position/deal reconciliation

**Files:**
- Create: `mobile/lib/features/account_sync/data/ex_v2_history_reconciler.dart`
- Create: `mobile/test/ex_v2_history_reconciler_test.dart`

**Interfaces:**
- Consumes: raw `JsonMap` rows returned by `/history/positions` and `/history/deals`.
- Produces: `ExV2HistoryReconciler.enrichClosedPositions(List<JsonMap> positions, List<JsonMap> deals) -> List<JsonMap>` and `ExV2HistoryReconciler.closePrice(JsonMap position, List<JsonMap> deals) -> double?`.

- [ ] **Step 1: Write failing tests for weighted close price and identifier aliases**

Create fixtures with one closed position and two linked exit deals: volume `0.4` at `100` and volume `0.6` at `110`. Assert that `closePrice` is `106`. Repeat with the position using `positionId` instead of `id`, and with differently cased UUID strings.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/ex_v2_history_reconciler_test.dart
```

Expected: FAIL because `ex_v2_history_reconciler.dart` and `ExV2HistoryReconciler` do not exist.

- [ ] **Step 3: Add exit classification and weighted calculation**

Implement a pure utility that:

```dart
abstract final class ExV2HistoryReconciler {
  static List<JsonMap> enrichClosedPositions(
    List<JsonMap> positions,
    List<JsonMap> deals,
  );

  static double? closePrice(JsonMap position, List<JsonMap> deals);
}
```

The calculation must prefer direct `closePrice`/`exitPrice`, normalize `id`/`positionId`, select only linked `out`, `out_by`, `close`, or `exit` deals, and calculate `sum(price * volume) / sum(volume)` when all selected rows have a numeric price and positive volume.

- [ ] **Step 4: Add RED tests for close-by, ambiguous rows, and safe nulls**

Assert that `out_by` contributes to the weighted result, unrelated same-symbol deals are excluded when a position ID exists, open positions are filtered out, and missing price/volume returns null instead of zero.

- [ ] **Step 5: Complete the minimal utility and verify GREEN**

Run the focused test again and require all reconciliation tests to pass.

- [ ] **Step 6: Commit the independently testable utility**

```powershell
git add mobile/lib/features/account_sync/data/ex_v2_history_reconciler.dart mobile/test/ex_v2_history_reconciler_test.dart
git commit -m "fix: reconcile history close prices"
```

### Task 2: Use coherent history snapshots during hydration

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart:279-317`
- Modify: `mobile/test/ex_v2_account_provider_test.dart:85-115`

**Interfaces:**
- Consumes: `ExV2HistoryReconciler.enrichClosedPositions` from Task 1.
- Produces: hydrated `orders`, `deals`, and `historyPositions` that retain their last confirmed values when one history request fails.

- [ ] **Step 1: Add a failing provider test for multi-deal hydration**

Extend the production-history adapter so `/history/positions` returns a closed row without `closePrice`, while `/history/deals` returns two linked exit rows. Assert that the hydrated `DemoHistoryPosition.closePrice` equals their volume-weighted average and that its ID/profit match the closed server position.

- [ ] **Step 2: Add a failing provider test for transient endpoint failure**

Load one confirmed history snapshot, make the adapter fail `/history/deals` or `/history/positions`, call `refresh()`, and assert the previously confirmed list is preserved rather than replaced with an empty list.

- [ ] **Step 3: Run provider tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/ex_v2_account_provider_test.dart
```

Expected: weighted price is null or the history collection is erased after the injected failure.

- [ ] **Step 4: Replace inline matching with the reconciler**

Import the Task 1 utility. Map `historyPositions` from `enrichClosedPositions(historyRows, dealRows)` and remove the duplicated private `_historyClosePrice`, `_isHistoryExitDeal`, and `_historyDate` functions.

- [ ] **Step 5: Preserve confirmed history on per-endpoint failure**

Represent each history request as success or failure instead of converting failure to an empty successful response. When a request fails, retain the matching collection from the `base` state; an actual successful empty response must still clear it.

- [ ] **Step 6: Verify provider GREEN and run mapper regression tests**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/ex_v2_account_provider_test.dart test/ex_v2_demo_mapper_test.dart test/ex_v2_models_test.dart
```

- [ ] **Step 7: Commit coherent hydration**

```powershell
git add mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_account_provider_test.dart
git commit -m "fix: preserve coherent trading history"
```

### Task 3: Reconcile Deals and History after a committed close

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart:479-680`
- Modify: `mobile/test/ex_v2_trading_command_test.dart:163-307`

**Interfaces:**
- Consumes: repository `historyDeals()` and `historyPositions()` plus the Task 1 reconciler.
- Produces: post-close state where `positions`, `deals`, and `historyPositions` are published together; an account-scoped bounded retry handles server history lag.

- [ ] **Step 1: Write a failing full-close synchronization test**

Make the trading adapter expose the closed history position and two linked exit deals after `POST /close`. Await `closePosition`, then assert the live position is absent, both exit deals are present, one closed history position exists, and its weighted close price matches the deal volumes.

- [ ] **Step 2: Write a failing delayed-history test**

Configure the first history snapshot after close to omit the closed row/deals and the next snapshot to include them. Assert bounded reconciliation eventually publishes the closed row with a non-null close price without restoring the Trade position.

- [ ] **Step 3: Run trading command tests and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded test/ex_v2_trading_command_test.dart
```

Expected: `historyPositions` remains empty or has null `closePrice` after the committed close.

- [ ] **Step 4: Load and publish a coherent post-close history snapshot**

Extend `_mergeCoreWithHydrated` with an optional `historyPositions` argument. After server bootstrap confirms the mutation, fetch deals and history positions together, reconcile them, and publish both lists in one `AsyncData` state update.

- [ ] **Step 5: Add bounded account-scoped delayed reconciliation**

For full close only, schedule a small fixed retry sequence when the closed history row or resolved close price is missing. Before and after every await, require `_isMutationScopeCurrent(scope)`. Stop immediately once the target history row has a non-null close price. Do not roll back a committed position when retries fail.

- [ ] **Step 6: Verify GREEN and all trading/history widget regressions**

```powershell
D:\toolchains\flutter\bin\flutter.bat test --reporter expanded --concurrency=1 test/ex_v2_trading_command_test.dart test/ex_v2_account_provider_test.dart test/history_screen_detail_test.dart test/video_interactions_test.dart test/chart_market_order_dispatch_regression_test.dart
```

- [ ] **Step 7: Commit post-close synchronization**

```powershell
git add mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_trading_command_test.dart
git commit -m "fix: synchronize closed positions with history"
```

### Task 4: Full verification and emulator inspection

**Files:**
- Verify: `mobile/`
- Inspect: generated APK and current LDPlayer UI without placing a real order unless separately authorized.

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: fresh test/analyze/build evidence and a user-facing report.

- [ ] **Step 1: Run the full Flutter test suite**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test
```

Require zero failures and record the exact pass count.

- [ ] **Step 2: Run static analysis**

```powershell
D:\toolchains\flutter\bin\flutter.bat analyze
```

Require `No issues found`.

- [ ] **Step 3: Build the Android APK**

```powershell
D:\toolchains\flutter\bin\flutter.bat build apk --debug
```

Require exit code 0 and verify `mobile/build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 4: Inspect the History screen on LDPlayer**

Install/launch the verified APK using the existing emulator workflow and capture the History screen. Do not place or close a production/demo account order without explicit authorization; automated fixtures provide mutation coverage.

- [ ] **Step 5: Review the diff and report**

Confirm only scoped files changed, no secrets or financial payload logs were added, and report root cause, weighted-price behavior, files/lines, RED/GREEN evidence, test totals, analyze result, build result, and the remaining limitation that no live account was mutated.
