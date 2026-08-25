# Settings Exact Copy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all static Settings-tab copy match the unaccented strings visible in the reference video without replacing API data.

**Architecture:** Keep the current `SettingsScreen`, Riverpod providers, and routes. Change only displayed static strings and the language fallback, then update tests and screen documentation to lock the reference contract.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter widget tests.

## Global Constraints

- Account, unread-count, and non-empty language values from EX V2 remain authoritative.
- Card geometry, icons, and tap behavior stay unchanged.
- No package or technology-stack changes.
- Verification must include analyze, full tests, debug APK build, and LDPlayer screenshot.

---

### Task 1: Add the failing exact-copy contract

**Files:**
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Modify: `mobile/test/video_button_coverage_test.dart`

**Interfaces:**
- Consumes: `SettingsScreen` and `MtBottomNavigationBar`.
- Produces: widget assertions for every static string in the design table.

- [x] Replace accented expectations with the exact unaccented literals and assert the old accented strings are absent.
- [x] Update key/semantics finders to use the new visible labels.
- [x] Run the focused tests and confirm they fail against the current accented production copy.

### Task 2: Apply the minimal copy fix

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `docs/screens/settings.md`

**Interfaces:**
- Consumes: existing API provider values and route callbacks.
- Produces: exact reference copy, with `language` preferred when non-empty and `Tieng Viet` used otherwise.

- [x] Replace each static Settings label/subtitle with its exact reference literal.
- [x] Change only the Settings bottom-tab label to `Cai dat`.
- [x] Preserve API language when non-empty and add the exact fallback for null/blank values.
- [x] Update the screen documentation's copy table.
- [x] Run the focused tests and confirm they pass.

### Task 3: Verify on the full app

**Files:**
- Verify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Verify: `mobile/lib/shared/widgets/app_shell.dart`

**Interfaces:**
- Consumes: completed copy changes.
- Produces: analyzer/test/build evidence and emulator screenshot.

- [x] Format touched Dart files.
- [x] Run `flutter analyze` and the complete Flutter test suite.
- [x] Build the debug APK.
- [x] Install with `adb install -r`, open Settings, and capture a fresh screenshot.
