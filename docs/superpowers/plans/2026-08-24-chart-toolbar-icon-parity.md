# Chart Toolbar Icon Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the normal Chart toolbar icons match the supplied white MT5 reference at the canonical LDPlayer size without changing behavior.

**Architecture:** Retain the current `AppBar`, 38x40 hit targets, callbacks, and code-native painters. Add a measured device-parity test, then make the center positions responsive and tune only icon rendering/typography.

**Tech Stack:** Flutter, Dart, Riverpod/GoRouter (unchanged), Flutter widget tests, Android APK/ADB verification.

**Spec:** `docs/superpowers/specs/2026-08-24-chart-toolbar-icon-parity-design.md`

## Global Constraints

- Read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and `docs/design-system.md` before implementation.
- Do not change the required technology stack.
- Preserve every toolbar callback, route, long-press, state transition, and hit-target size.
- After implementation run relevant tests, analyze, and build.

---

### Task 1: Lock the supplied reference geometry

**Files:**
- Modify: `mobile/test/chart_controls_test.dart`

**Interfaces:**
- Consumes: existing `ChartScreen`, toolbar keys, and `_chartButtonInkMetrics` RGBA capture helper.
- Produces: a 590x1280/DPR 1.5 regression test for global toolbar ink bounds.

- [x] **Step 1: Add a device-size widget test using `MediaQueryData(size: Size(393.3333333333, 853.3333333333), devicePixelRatio: 1.5, padding: EdgeInsets.only(top: 24, bottom: 79))`.**
- [x] **Step 2: Assert the five global physical ink rectangles measured in the design spec.**
- [x] **Step 3: Run the named test and confirm it fails against the current fixed-width/high-position toolbar.**

### Task 2: Implement responsive placement and painter parity

**Files:**
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Test: `mobile/test/chart_controls_test.dart`

**Interfaces:**
- Consumes: available toolbar width, `ChartReferenceTheme`, and existing toolbar callbacks.
- Produces: the same keyed buttons and actions with reference-matched visual ink.

- [x] **Step 1: Wrap the normal toolbar stack in `LayoutBuilder` and derive measured center-control positions from width ratios.**
- [x] **Step 2: Move timeframe and painter ink to the measured vertical baselines while retaining 38x40 hit targets.**
- [x] **Step 3: Tune `Crosshair`, `MtIndicator`, `Objects`, `ChartMode`, and `Windows` painter geometry and toolbar colors.**
- [x] **Step 4: Run the new test after each measured adjustment until it passes.**
- [x] **Step 5: Run existing toolbar geometry, theme-injection, and interaction tests to detect regressions.**

### Task 3: Build and device verification

**Files:**
- Modify only if a measured mismatch remains: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`

**Interfaces:**
- Consumes: passing Flutter source and tests.
- Produces: an installed debug APK and final LDPlayer screenshot.

- [x] **Step 1: Run Dart formatting and scoped/full Flutter analysis.**
- [x] **Step 2: Run the relevant Chart tests and full required build.**
- [x] **Step 3: Install the APK on `emulator-5560`, open Chart, and capture a fresh 590x1280 PNG.**
- [x] **Step 4: Compare toolbar ink against the supplied image and make only measured visual corrections if needed.**
- [x] **Step 5: Re-run analyze, tests, and build after the final correction.**
