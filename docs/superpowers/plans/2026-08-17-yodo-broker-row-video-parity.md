# YODO Broker Row Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live YODO broker row look exactly like the Exness broker row in the reference video while preserving the real YODO identity for behavior and API requests.

**Architecture:** A scoped presentation projection supplies display labels and mark style to `BrokerListScreen`. The screen keeps the original broker object for callbacks and state mutations, separating visual parity from the data contract.

**Tech Stack:** Flutter, Dart, Riverpod widget tests, Android debug APK, LDPlayer.

## Global Constraints

- The real broker ID remains `yodo-demo`.
- The real server ID remains `yodo-demo-01`.
- No backend or API contract changes.
- No secret or full request logging.
- Preserve unrelated dirty worktree files.

---

### Task 1: Add failing broker-row regression tests

**Files:**
- Modify: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Consumes: live YODO catalog and `BrokerListScreen`.
- Produces: assertions for `Exness Technologies Ltd`, `Exness`, yellow mark, absence of YODO text, and stable `yodo-demo` selection.

- [ ] Replace the old live-catalog YODO display expectation with the exact video labels.
- [ ] Add a selection assertion proving the reference row still yields broker ID `yodo-demo`.
- [ ] Run the focused test and confirm it fails because the picker still renders YODO.

### Task 2: Apply the reference presentation to the broker picker

**Files:**
- Modify: `mobile/lib/features/account_link/presentation/widgets/reference_server_catalog.dart`
- Modify: `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart`

**Interfaces:**
- Produces: `ReferenceBrokerPresentation referenceBrokerPresentation(MobileBroker broker)`.
- Preserves: the original `MobileBroker` in all callbacks and controller calls.

- [ ] Add the scoped presentation model/helper with `Exness Technologies Ltd`, `Exness`, and Exness mark selection for `yodo-demo`.
- [ ] Render the projection in filtering and broker rows without changing callback arguments.
- [ ] Run focused tests and confirm the exact display and stable ID pass.

### Task 3: Verify, build, and install

**Files:**
- No additional production files.

**Interfaces:**
- Consumes: completed broker-row implementation.
- Produces: analyzer, test, build, installed APK, screenshot, and security evidence.

- [ ] Run `flutter analyze`, full `flutter test`, and `flutter build apk --debug`.
- [ ] Run `dotnet build Trading.sln` and `dotnet test Trading.sln --no-build`.
- [ ] Install the APK on `emulator-5558`, open the broker picker, and compare the fresh screenshot with video frame 10.
- [ ] Confirm changed files contain no forbidden secret logging.
