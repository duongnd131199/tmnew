# Direct Trade Close Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Đóng trạng thái` on the Trade screen submit the close immediately instead of opening the order ticket.

**Architecture:** Route the action-sheet callback directly to the existing optimistic close controller. Keep ticket-based close entry points unchanged and reuse existing success/error feedback.

**Tech Stack:** Flutter, Dart, Riverpod, EX V2 REST API.

## Global Constraints

- Do not alter the Trade screen layout.
- Do not change the API contract or production server.
- Preserve optimistic removal and authoritative rollback behavior.

---

### Task 1: Direct close behavior

**Files:**
- Modify: `mobile/test/video_interactions_test.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`

**Interfaces:**
- Consumes: `DemoTradingController.closePosition(String)` in local mode.
- Consumes: `ExV2AccountController.closePosition(String)` in server mode.
- Produces: direct action-sheet close with success/error feedback.

- [ ] Add a widget test that taps a position, selects `Đóng trạng thái`, and asserts the position is removed without router navigation.
- [ ] Run the test and verify it fails because the current callback calls `context.push('/order?...')`.
- [ ] Replace ticket navigation with direct optimistic close.
- [ ] Run the targeted Trade and EX V2 close tests.

### Task 2: Verification and installation

**Files:**
- Verify: `mobile/`
- Verify: `backend/`

- [ ] Run analyze and the full Flutter suite.
- [ ] Run backend build/tests.
- [ ] Build the APK using drive-D cache paths.
- [ ] Install it on LDPlayer and verify startup without fatal errors.
