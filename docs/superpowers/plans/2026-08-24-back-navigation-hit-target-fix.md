# Back Navigation Hit-Target Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Make every visible in-app back control respond reliably, with focused regression coverage for the Price-tab failure and every other custom stacked header that shares the same risk.

**Architecture:** Preserve the existing GoRouter `push`/`pop` navigation model. Fix only pointer routing in custom `Stack` headers by making non-interactive centered titles ignore pointer events. Keep all geometry, icons, colors, routes, and screen state unchanged.

**Tech Stack:** Flutter, Dart, flutter_riverpod, go_router, flutter_test.

## Global Constraints

- Preserve the required Flutter/Riverpod/GoRouter stack and existing public interfaces.
- Do not change any icon geometry, colors, text layout, market data, trading behavior, or backend code.
- Preserve unrelated dirty-worktree changes and edit the current file contents only.
- Test route behavior through the same `push` then tap-back flow used by the app.
- A regression test must fail before the production fix and pass afterward.
- After implementation run focused tests, `flutter analyze`, the full Flutter test suite, and an Android APK build.

### Task 1: Add failing back-navigation regression coverage

**Files:**
- Create: `mobile/test/back_navigation_hit_target_test.dart`

- [ ] Build a small `GoRouter` test harness with a parent route and the real affected screen.
- [ ] Cover `SymbolEditScreen` (`/market/edit`), `MarketColumnsScreen` (`/market/columns`), and `ChartObjectsScreen` (`/chart-objects`).
- [ ] Push each child route, tap the visible `CupertinoIcons.chevron_left`, and assert that the router returns to the parent route.
- [ ] Add positive coverage for representative already-safe custom back controls so the audit protects existing behavior.
- [ ] Run the focused test and record the expected failures before touching production code.

### Task 2: Remove pointer interception without visual changes

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/symbol_edit_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/screens/chart_objects_screen.dart`

- [ ] Wrap each non-interactive full-width centered header title that overlaps a back control in `IgnorePointer`.
- [ ] Do not reorder, resize, recolor, or replace any header element.
- [ ] Run `dart format` on changed Dart files.
- [ ] Run the focused regression test and confirm all covered routes pop correctly.

### Task 3: Verify the app-wide back-button audit and deliver a runnable build

**Files:**
- Verify existing tests under `mobile/test/` that cover Profile, Account Detail, account linking, Trade/Position, History, Wallet, search-close, Chart Indicators, and default AppBar back behavior.

- [ ] Run relevant navigation/widget regression tests.
- [ ] Run `flutter analyze`.
- [ ] Run the full `flutter test` suite.
- [ ] Run `flutter build apk --debug`.
- [ ] Install the new APK on `emulator-5560` and manually verify the Price edit/columns back controls plus Chart Objects.
