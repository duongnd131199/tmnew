# Short Trading Ticket IDs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for progress tracking.

**Goal:** Show stable, short, numeric trading ticket IDs everywhere a user can see an order, position, or deal ID, while preserving the server-provided ID for routing and trading API commands.

**Architecture:** Add one deterministic presentation formatter in `core/utils`. Presentation widgets call it only when rendering ticket text. Domain models, provider lookup keys, routes, equality checks, and trading commands retain the original server ID so GUID-backed server operations remain correct.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test.

**Spec:** User-approved in-chat bounded design; there is no standalone specification.

## Global Constraints

- Preserve raw IDs in models, navigation, `ValueKey`s, comparisons, and API calls.
- Preserve an existing numeric ID when it is already at most 11 digits.
- Convert long numeric, GUID, and other non-numeric IDs into a deterministic 11-digit decimal ticket.
- Apply the formatter only to visible trading ticket/order/deal/position IDs.
- Do not convert account login numbers, broker IDs, route parameters, widget keys, or chart annotation identifiers.
- Preserve unrelated user changes in the dirty worktree.

## Task 1: Add and lock the shared display-ID contract

**Files:**

- Create: `mobile/test/trading_ticket_id_test.dart`
- Create: `mobile/lib/core/utils/trading_ticket_id.dart`

- [x] Add failing unit tests with hand-derived assertions for unchanged short numeric IDs, exact 11-digit output, stability, collision resistance for representative fixtures, and empty input.
- [x] Run the focused test and confirm it fails because the formatter does not exist.
- [x] Implement a dependency-free deterministic 64-bit FNV-1a mapping into the 11-digit decimal range.
- [x] Run the focused test and confirm it passes.

## Task 2: Convert visible position and order tickets

**Files:**

- Modify: `mobile/test/trade_position_bulk_actions_dialog_test.dart`
- Modify relevant position/order widget tests discovered during implementation.
- Modify: `mobile/lib/features/trade/presentation/widgets/position_bulk_actions_dialog.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`

- [x] Add or update widget expectations so GUID-backed positions/orders must render an 11-digit ticket and must not expose the GUID.
- [x] Run focused widget tests and confirm the raw-ID implementation fails.
- [x] Apply the shared formatter to the bulk-action dialog, position detail, close-order title, and completed-order ticket.
- [x] Re-run focused tests and confirm they pass.

## Task 3: Convert visible history tickets

**Files:**

- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify relevant history widget tests discovered during implementation.
- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify: `mobile/lib/features/history/presentation/screens/history_detail_screen.dart`

- [x] Add or update history expectations for deal, order, position, and linked-order IDs.
- [x] Run focused history tests and confirm at least one raw-ID assertion fails.
- [x] Apply the shared formatter in the reusable history ticket header, linked-order row, and standalone history detail title.
- [x] Re-run focused history tests and confirm they pass.

## Task 4: Verify, install, and inspect on ip17

**Files:**

- Verify only; no planned production changes.

- [x] Run all ID-related Flutter tests.
- [x] Run `flutter analyze`.
- [x] Run a simulator debug build.
- [x] Install and restart `com.tradingdemo.tradingMobile` on ip17.
- [x] Open a GUID-backed bulk-action surface and visually verify that only a stable 11-digit ticket is shown.
- [x] Review the final diff to confirm raw IDs still reach provider/API operations.
