# MT5 iOS Position Actions Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match official MT5 iPhone position actions in the Trade tab.

**Architecture:** Keep existing routes and visual tokens, but correct interaction routing and mutation semantics. Trade widgets own iOS navigation/selection; the EX V2 controller owns optimistic full/partial close and authoritative reconciliation.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, EX V2 REST API.

## Global Constraints

- Preserve the current technology stack and unrelated UI.
- Server values remain authoritative.
- Do not change the legacy web or production server.
- Use TDD for every behavior change.

---

### Task 1: iOS swipe and Close Position routing

**Files:**
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`

- [ ] Add failing tests for three swipe actions and context Close opening the close ticket.
- [ ] Replace direct context close with `/order?symbol=...&positionId=...`.
- [ ] Render Context, Modify, and Close behind a swiped position and wire their routes.
- [ ] Verify the Trade interaction tests pass.

### Task 2: full and partial close ticket

**Files:**
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/test/ex_v2_trading_command_test.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`

- [ ] Add failing tests that close tickets default to full position volume and forward a smaller selected volume.
- [ ] Add a failing provider test proving partial close keeps a reduced position visible.
- [ ] Initialize ticket volume from the position and pass it to close.
- [ ] Implement optimistic volume reduction and reconcile raw server state for partial close.
- [ ] Verify close UI and controller tests pass.

### Task 3: iOS Close By chooser and remainder

**Files:**
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/test/ex_v2_trading_command_test.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`

- [ ] Add failing UI tests for unavailable Close By and explicit opposite-ticket selection.
- [ ] Add a failing controller test where unequal volumes leave a remainder.
- [ ] Build the opposite-position chooser and submit only after explicit selection.
- [ ] Reconcile Close By using unfiltered server bootstrap state.
- [ ] Verify Trade and controller tests pass.

### Task 4: History out-by mapping

**Files:**
- Modify: `mobile/test/ex_v2_demo_mapper_test.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_demo_mapper.dart`

- [ ] Add a failing mapping test for `out by`/`out_by` deal types.
- [ ] Map close/out variants to exit History entries.
- [ ] Verify mapper and History tests pass.

### Task 5: Full verification and installation

**Files:**
- Verify: `mobile/`
- Verify: `backend/`

- [ ] Run Flutter analyze and the full Flutter suite.
- [ ] Run backend build/tests.
- [ ] Build the APK with caches on drive D.
- [ ] Install on LDPlayer, verify bootstrap, screenshot, and fatal logs.
