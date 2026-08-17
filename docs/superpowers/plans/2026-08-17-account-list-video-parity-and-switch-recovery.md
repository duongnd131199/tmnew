# Account List Video Parity and Switch Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove incorrect `Unavailable` presentation, match the reference account rows with live account identity, and preserve authoritative account switching.

**Architecture:** Join the canonical active bootstrap to linked-account presentation by exact public account ID. Keep financial state bootstrap-owned, keep list-only presentation separate, and require server-confirmed activate bootstrap before switching state.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio test adapters, Android debug APK.

## Global Constraints

- Do not change the base URL, endpoint paths, device-token security, or required technology stack.
- Do not hard-code video login, password, balance, positions, history, broker credentials, or secrets.
- Do not present YODO as Exness.
- Never publish account B data under account A identity.
- Never log password, device token, Authorization, reconnectGrant, or full request bodies.
- Preserve unrelated dirty worktree files.

---

### Task 1: Lock active-account presentation with RED tests

**Files:**
- Modify: `mobile/test/account_presentation_mapper_test.dart`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`

**Interfaces:**
- Consumes: `demoAccountsProvider`, `ExV2AccountProfileMapper.map`, linked account list and active bootstrap.
- Produces: regression expectations for exact-ID metadata joining and missing inactive balance presentation.

- [ ] Add a provider test where bootstrap account `account-a` has no presentation metadata but `GET /mobile/accounts` returns broker/server metadata for `account-a` and `account-b`.
- [ ] Assert active profile uses only matching `account-a` broker/server data and does not contain `Unavailable`.
- [ ] Add a same-login/different-ID case proving account B metadata cannot replace account A metadata.
- [ ] Add a widget assertion that an inactive account without balance renders `USD, Hedge`, not a fabricated `0.00` or em dash.
- [ ] Run focused tests and confirm failures originate from current fallback/join behavior.

### Task 2: Join linked presentation by exact account ID

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_view_state.dart`
- Modify: `mobile/lib/features/profile/application/ex_v2_account_profile_mapper.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Test: `mobile/test/account_presentation_mapper_test.dart`
- Test: `mobile/test/ex_v2_account_provider_test.dart`

**Interfaces:**
- Consumes: `LinkedTradingAccount.id`, `brokerId`, `brokerName`, `serverName`.
- Produces: `ExV2AccountPresentation` with optional `accessPoint` and a `DemoAccountProfile` without visible `Unavailable`.

- [ ] Extend `ExV2AccountPresentation` with optional `accessPoint` and preserve it in `copyWith` paths.
- [ ] In `demoAccountsProvider`, find the linked row whose public ID exactly equals `bootstrap.account.id`.
- [ ] Map the active bootstrap with presentation from that matching row; keep bootstrap balance/history authoritative.
- [ ] Use `Access Point #1` only as a non-financial presentation fallback when neither settings nor activation presentation contains one.
- [ ] Run focused mapper/provider tests and confirm GREEN.
- [ ] Commit only Task 1-2 files.

### Task 3: Match the account-list broker mark and text hierarchy

**Files:**
- Modify: `mobile/lib/features/profile/domain/account_presentation_profile.dart`
- Modify: `mobile/lib/features/profile/application/ex_v2_account_profile_mapper.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/lib/features/profile/presentation/widgets/account_visuals.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/test/account_visuals_test.dart`
- Modify: `mobile/test/multi_account_switch_test.dart`

**Interfaces:**
- Consumes: broker ID/name and nullable inactive balance.
- Produces: `DemoBrokerBrand.yodo`, yellow 31 x 31 YODO mark and honest missing-balance copy.

- [ ] Add RED widget tests for a 31 x 31 yellow YODO mark whose text is `yodo`, and for absence of `exness` on YODO rows.
- [ ] Add `DemoBrokerBrand.yodo` and detect it from broker identity before generic unknown handling.
- [ ] Render YODO with the same square geometry as the reference yellow broker mark.
- [ ] Change the inactive missing-balance line from `— USD, Hedge` to `USD, Hedge` without inventing a number.
- [ ] Assert active row still owns selected surface, blue name and chevron; inactive row remains unselected and has no chevron.
- [ ] Run focused visual/widget tests and confirm GREEN.
- [ ] Commit only Task 3 files.

### Task 4: Document the production activate blocker

**Files:**
- Create: `docs/ex-v2-account-activation-concurrency-fix.md`

**Interfaces:**
- Consumes: public error code `concurrency_conflict` and the existing activate contract.
- Produces: one server-side implementation checklist that can be executed against `/opt/ex-v2-api-src`.

- [ ] Document the reproducible `PUT /mobile/accounts/{accountId}/activate` HTTP 409 without including account IDs, device tokens or credentials.
- [ ] Require a server test with two linked accounts proving one activate returns HTTP 200 canonical bootstrap and makes subsequent bootstrap/list reads agree.
- [ ] Require transaction serialization, idempotency replay, concurrent-different-key behavior and rollback tests.
- [ ] State that Flutter must not work around the failure with optimistic or fabricated account state.
- [ ] Scan the document for secrets and commit it.

### Task 5: Full verification and LDPlayer comparison

**Files:**
- Verify: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Capture: `.codex_tmp/account-video-parity/`

**Interfaces:**
- Consumes: all implementation tasks.
- Produces: analyzer/test/build evidence and screenshots against video frames 4, 72 and 76 seconds.

- [ ] Run focused account/profile/settings suites.
- [ ] Run `flutter analyze` and full `flutter test`.
- [ ] Run `flutter build apk --debug`.
- [ ] Run `dotnet build Trading.sln` and `dotnet test Trading.sln --no-build`.
- [ ] Install the APK on LDPlayer, cold start, open Settings and account list, and capture both screens.
- [ ] Confirm no visible `Unavailable`, account rows use the yellow YODO mark and IDs remain API-owned.
- [ ] Attempt one switch and record the actual HTTP-safe result; do not claim success unless the returned bootstrap belongs to the selected account.
- [ ] Scan changed source/tests for real credentials and forbidden logging.

