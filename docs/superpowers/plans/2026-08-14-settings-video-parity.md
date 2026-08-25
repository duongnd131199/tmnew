# Settings Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the Settings cards, static copy, typography, and messaging icons to `giaoDienMau/IMG_5526.MP4` without changing API-backed values or tap behavior.

**Architecture:** Keep `SettingsScreen` as the existing Riverpod consumer and preserve all provider reads and routes. Add stable widget keys for visual contracts, replace only the inaccurate connected-status painter, and tune the current card/row presentation against the 288×640 reference viewport.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter widget tests.

## Global Constraints

- Preserve account, unread-count, and language values supplied by EX V2.
- Preserve every existing tap route and API/provider interaction.
- Do not add packages or change the required technology stack.
- Do not copy proprietary logos; recreate the small status glyph with code-native geometry.
- Run build, analyze, and relevant tests after implementation.

---

### Task 1: Lock the reference-facing contracts

**Files:**
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Create: `docs/screens/settings.md`

**Interfaces:**
- Consumes: `SettingsScreen`, the current test keys, and `IMG_5526.MP4` frames.
- Produces: assertions for static reference copy and the two messaging icon surfaces.

- [x] Add widget-test assertions for the reference news subtitle and dedicated keys for the left message icon and right connected icon.
- [x] Run the focused test and confirm it fails because the old news copy/keyed connected glyph remains.
- [x] Record the reference viewport, component groups, API-owned fields, and interaction constraints in `docs/screens/settings.md`.

### Task 2: Match the cards, static text, and messaging icons

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify only if needed: `mobile/lib/shared/widgets/mt5_settings_icon_assets.dart`

**Interfaces:**
- Consumes: `activeDemoAccountProvider`, `exV2AccountProvider`, `MtSettingsRasterIcon`.
- Produces: the same `SettingsScreen` public widget and routes with corrected presentation.

- [x] Change only static reference copy; leave API-derived account, unread-count, and language branches unchanged.
- [x] Tune card/row typography and spacing using the existing widget structure and semantic colors.
- [x] Replace the three-line `_ConnectedIndicatorPainter` with the code-native blue/cyan status glyph from the reference.
- [x] Keep the left message icon at the reference size and align its API-backed badge without changing the badge value.
- [x] Run the focused widget tests and confirm they pass.

### Task 3: Verify compatibility and visual parity

**Files:**
- Verify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Verify: `mobile/test/settings_navigation_video_test.dart`

**Interfaces:**
- Consumes: completed Settings UI.
- Produces: analyzer/test/build evidence and an emulator screenshot.

- [x] Run `dart format` on touched Dart files.
- [x] Run the Settings/navigation tests.
- [x] Run `flutter analyze` and the complete Flutter test suite.
- [x] Build the debug APK.
- [x] Install with `adb install -r`, open Settings, capture a screenshot, and compare it at normalized 288×640 scale while masking API-owned text.
