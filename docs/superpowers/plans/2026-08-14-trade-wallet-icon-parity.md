# Trade Wallet Icon Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the Trade header wallet button visible in every trading state and match the populated-state reference in `IMG_5526.MP4`.

**Architecture:** Preserve the existing `_TradeCircleButton` and `_TradeCreditCardIcon` implementation. Remove only the state condition that suppresses the button, then protect empty and populated states with widget tests.

**Tech Stack:** Flutter, Riverpod, CustomPainter, Flutter widget tests.

## Global Constraints

- Do not change the technology stack, API contracts, account data, trading state, or wallet actions.
- Do not change the centered profit label or right add button.
- Match the reference frame at approximately 17.2 seconds.
- Run build, analyze, and relevant tests.

---

### Task 1: Reproduce the populated-state visibility bug

**Files:**
- Modify: `mobile/test/video2_functional_regression_test.dart`

**Interfaces:**
- Consumes: `TradeScreen`, populated demo account state.
- Produces: a regression assertion for `Key('trade-balance-button')` in populated state.

- [ ] Add a widget test that selects an account with open positions, pumps `TradeScreen`, and expects one 42.666×42.666 wallet button.
- [ ] Tap the button and assert the existing balance dialog opens.
- [ ] Run the focused test and confirm RED because the button is absent.

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test/video2_functional_regression_test.dart --plain-name "populated trade keeps the video wallet button visible"
```

### Task 2: Make the wallet button state-independent

**Files:**
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`

**Interfaces:**
- Preserves: `_TradeCircleButton`, `_TradeCreditCardIcon`, `onAccount`.
- Changes: button visibility no longer depends on `empty`.

- [ ] Remove the `if (empty)` guard around the left-positioned wallet button.
- [ ] Keep its exact key, semantics, coordinates, size, painter, and callback.
- [ ] Run the focused test and confirm GREEN.
- [ ] Run the existing empty-state balance-button test and confirm it remains GREEN.

### Task 3: Verify visual and functional parity

**Files:**
- Verify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Verify: `mobile/test/video2_functional_regression_test.dart`

- [ ] Run Trade and video regression tests.
- [ ] Run `flutter analyze` and the complete test suite.
- [ ] Run `flutter build apk --debug`.
- [ ] Install with `adb install -r` without deleting app data.
- [ ] Capture the populated Trade screen and compare the left button against the video reference.

## Self-review

- Empty, position, and pending visibility use one widget path.
- No duplicate button or alternate icon implementation is introduced.
- Existing wallet dialog behavior remains the test boundary.
- No backend/API or account-value changes are included.
