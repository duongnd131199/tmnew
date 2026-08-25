# Smooth Chart Tab Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Chart tab render immediately, remove the artificial BTCUSD/H1 delay, and warm the default candle history without changing chart visuals or interaction state.

**Architecture:** Keep the existing Flutter `CustomPainter`, Riverpod candle stream, GoRouter indexed shell, and REST/SignalR contracts. Add one small Riverpod warmup provider for the production default chart; the existing non-auto-dispose candle provider then acts as the in-memory stale-while-refresh cache. The chart continues to paint its last `AsyncValue.value` while refreshes run.

**Tech Stack:** Flutter, Riverpod, GoRouter, Dio, Flutter widget/provider tests.

## Global Constraints

- Do not change the required technology stack.
- Do not change the chart layout, gestures, zoom, pan, symbol, timeframe, REST contract, or SignalR contract.
- Do not block app startup or tab navigation while warming candle history.
- Run build, analyze, and relevant tests after implementation.

---

### Task 1: Remove the artificial BTCUSD/H1 loading hold

**Files:**
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`

**Interfaces:**
- Consumes: `marketCandlesProvider(MarketDataRequest)`.
- Produces: chart painter with `loadingPlaceholder == false` as soon as history is available.

- [ ] **Step 1: Change the BTCUSD/H1 widget test to require immediate candles**

Replace the delayed assertions with an assertion that adding H1 history and pumping the next frames makes `loadingPlaceholder` false and exposes visible candles.

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart --plain-name "BTC H1 shows visible candles as soon as history arrives"
```

Expected: FAIL because `_holdBtcH1Loading` remains true for 2,200 ms.

- [ ] **Step 3: Remove the timer-controlled hold**

Delete `_holdBtcH1Loading`, `_btcH1LoadingTimer`, `_releaseBtcH1Loading`, their lifecycle calls, and the symbol/timeframe branches that restart the hold. Keep the painter contract stable by passing `loadingPlaceholder: false`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: PASS without advancing the fake clock by 2,200 ms.

### Task 2: Warm and retain the production default chart history

**Files:**
- Create: `mobile/lib/features/chart/data/chart_market_warmup_provider.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Create: `mobile/test/chart_market_warmup_test.dart`

**Interfaces:**
- Consumes: `marketApiConfigProvider`, `marketCandlesProvider`, and `MarketDataRequest('XAUUSD+', 'H4')`.
- Produces: `chartMarketWarmupProvider` as `FutureProvider<void>`.

- [ ] **Step 1: Write provider and shell behavior tests**

Test that production-enabled configuration subscribes once to the default candle request, disabled configuration does no work, and mounting `AppShell` starts the warmup without delaying navigation.

- [ ] **Step 2: Run the new test and verify RED**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_market_warmup_test.dart
```

Expected: FAIL because `chartMarketWarmupProvider` does not exist and `AppShell` does not subscribe to it.

- [ ] **Step 3: Implement non-blocking Riverpod warmup**

Create a provider equivalent to:

```dart
final chartMarketWarmupProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(marketApiConfigProvider).enabled) return;
  await ref.watch(
    marketCandlesProvider(const MarketDataRequest('XAUUSD+', 'H4')).future,
  );
});
```

Convert `AppShell` to `ConsumerStatefulWidget`/`ConsumerState` and call `ref.watch(chartMarketWarmupProvider)` in `build`. Do not await it and do not render loading/error UI from it.

- [ ] **Step 4: Run the new test and verify GREEN**

Run the command from Step 2. Expected: all warmup tests PASS.

### Task 3: Regression and device acceptance

**Files:**
- Verify only: all modified mobile files.

**Interfaces:**
- Produces: an analyzed, tested, installable Android debug APK.

- [ ] **Step 1: Run chart and navigation regression tests**

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/chart_controls_test.dart test/live_market_candles_test.dart test/market_chart_route_test.dart test/tab_swipe_reset_test.dart test/chart_market_warmup_test.dart
```

- [ ] **Step 2: Run the complete mobile test suite and analyzer**

```powershell
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
```

- [ ] **Step 3: Build and install the APK**

```powershell
D:\toolchains\flutter\bin\flutter.bat build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

- [ ] **Step 4: Manually verify on LDPlayer**

Open the app, wait for the initial Trade screen, tap Chart, and confirm the chart chrome appears immediately. Open BTCUSD/H1 from Prices and confirm there is no fixed 2.2-second placeholder. Switch away and back and confirm timeframe, zoom, and pan remain unchanged.

---

## Self-review

- The explicit 2.2-second regression is covered by Task 1.
- First-open network latency is hidden by non-blocking warmup in Task 2.
- The existing non-auto-dispose `marketCandlesProvider` retains the warmed value; no new persistence package or API is introduced.
- Slow/error warmup never blocks navigation because `AppShell` ignores its `AsyncValue` presentation state.
- Existing visual and interaction contracts are protected by the full chart/navigation regression set.
