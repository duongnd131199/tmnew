# Reset Horizontal Swipe On Tab Change Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close any horizontally revealed row in the Prices or Trade tab whenever the user leaves that bottom tab, while preserving the tab's other retained state.

**Architecture:** Keep the existing `StatefulShellRoute.indexedStack` so branch state remains alive. `AppShell` will expose its active branch index through a small inherited scope; Prices and Trade will consume that scope and clear only their local revealed-row identifier when their branch becomes inactive.

**Tech Stack:** Flutter, Dart, GoRouter `StatefulShellRoute`, Riverpod, Flutter widget tests.

## Global Constraints

- Do not change the required technology stack.
- Do not reset scroll position, API data, compact mode, selected account, or navigation history.
- Do not change visual dimensions, colors, typography, or swipe animations.
- Run Flutter analyze, Flutter tests, APK build, backend build, and backend tests after the task.

---

### Task 1: Reproduce retained swipe state

**Files:**
- Create: `mobile/test/tab_swipe_reset_test.dart`

**Interfaces:**
- Consumes: `AppShell`, `MarketWatchScreen`, `TradeScreen`, existing bottom navigation labels and row keys.
- Produces: Widget regression tests that assert each revealed row returns to horizontal offset `0` after leaving and returning to its tab.

- [ ] **Step 1: Write failing Prices and Trade tests**

Build a three-branch `StatefulShellRoute.indexedStack`, reveal a Prices row and a Trade position row, navigate away using the bottom bar, return, and assert the row transform is zero.

- [ ] **Step 2: Verify RED**

Run:

```powershell
flutter test test/tab_swipe_reset_test.dart
```

Expected: both tests fail because the current `revealedSymbol` and `revealedPositionId` survive inside the indexed stack.

### Task 2: Publish active bottom-tab state

**Files:**
- Modify: `mobile/lib/shared/widgets/app_shell.dart`

**Interfaces:**
- Produces: `AppTabScope.maybeIndexOf(BuildContext context) -> int?`.

- [ ] **Step 1: Add a minimal inherited scope**

Wrap `navigationShell` with an inherited widget whose value is `navigationShell.currentIndex`. Dependents must rebuild only when that integer changes.

- [ ] **Step 2: Preserve existing shell behavior**

Keep the indexed branches, bottom navigation routing, and fade transition unchanged.

### Task 3: Reset only revealed rows

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Test: `mobile/test/tab_swipe_reset_test.dart`

**Interfaces:**
- Consumes: `AppTabScope.maybeIndexOf`.
- Prices branch index: `0`.
- Trade branch index: `2`.

- [ ] **Step 1: Consume active tab in Prices**

When Prices is inactive, set `revealedSymbol` to `null` during the inherited-dependency update. Leave `compactMode` and list state untouched.

- [ ] **Step 2: Consume active tab in Trade**

When Trade is inactive, set `revealedPositionId` to `null` during the inherited-dependency update. Leave account, positions, list position, and provider state untouched.

- [ ] **Step 3: Verify GREEN**

Run:

```powershell
flutter test test/tab_swipe_reset_test.dart
```

Expected: both tests pass.

### Task 4: Verify and deploy locally

**Files:**
- No production file changes expected.

**Interfaces:**
- Consumes: completed Flutter behavior.
- Produces: analyzed, tested, buildable APK installed on the existing LDPlayer device.

- [ ] **Step 1: Format and analyze**

```powershell
dart format lib test/tab_swipe_reset_test.dart
flutter analyze
```

- [ ] **Step 2: Run Flutter tests and build**

```powershell
flutter test
flutter build apk --debug
```

- [ ] **Step 3: Run backend regression checks**

```powershell
dotnet build Trading.sln --no-restore
dotnet test Trading.sln --no-build
```

- [ ] **Step 4: Install and visually verify**

Install the debug APK on LDPlayer, open the app, reveal a row in Prices and Trade, switch tabs, return, and verify the row is closed with the rest of the tab state retained.
