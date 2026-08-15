# Settings Messages Icon Video Parity Implementation Plan

> **For agentic workers:** Follow test-driven development and verify each RED/GREEN transition before continuing.

**Goal:** Remove the baked notification badge from the `Trao doi va tin nhan` icon and match the clean icon-plus-dynamic-badge composition shown in `IMG_5526.MP4`.

**Architecture:** Preserve `_SettingsRow` as the owner of notification state and overlay geometry. Make `MtSettingsRasterIconKind.messages` deliver only clean icon artwork by removing its contaminated video-crop override.

**Tech Stack:** Flutter, Dart, Riverpod, Flutter widget tests.

## Constraints

- Keep notification count server-driven.
- Do not alter other Settings icons or navigation.
- Do not change the required technology stack.
- Run build, analyze, relevant tests, and full tests.

### Task 1: Reproduce the baked-badge defect

**Files:**
- Modify: `mobile/test/settings_navigation_video_test.dart`

- Add a widget test that renders the real messages raster without `_SettingsRow`.
- Decode the actual `MemoryImage` pixels.
- Assert that the clean icon has no badge-red pixels in its upper-right artwork.
- Run the focused test and confirm RED because the current 43 x 44 asset contains a red `2` badge.

### Task 2: Deliver clean messages artwork

**Files:**
- Modify: `mobile/lib/shared/widgets/mt5_settings_icon_assets.dart`

- Remove only `MtSettingsRasterIconKind.messages` from `_videoEncoded`.
- Keep the clean official messages entry in `_encoded`.
- Run the focused test and confirm GREEN.
- Run the existing Settings layout test to ensure the icon frame and dynamic badge geometry remain unchanged.

### Task 3: Verify visual and functional parity

**Files:**
- Verify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Verify: `mobile/test/settings_navigation_video_test.dart`
- Update if needed: `docs/screens/settings.md`

- Run Settings tests and inspect failures.
- Run `flutter analyze`, the complete Flutter test suite, and `flutter build apk --debug`.
- Run backend build and tests required by `AGENTS.md`.
- Capture the portrait Settings screen and compare with the video reference when the emulator is available.

## Self-review

- The base icon contains no notification number or red badge pixels.
- Exactly one dynamic badge is visible.
- Badge count continues to follow application/server state.
- No unrelated Settings icon or behavior changed.
