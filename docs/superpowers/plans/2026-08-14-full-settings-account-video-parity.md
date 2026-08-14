# Full Settings Account Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the complete Settings → account list → account detail flow match `giaoDienMau/IMG_5526.MP4`, with correct Exness metadata and shared reference-matched visuals while preserving live EX V2 identity and financial values.

**Architecture:** Add a focused account-presentation mapper between `ExV2AccountViewState` and the existing UI-facing `DemoAccountProfile`, so transport/status fields can no longer leak into company, trading-server, or access-point labels. Extract broker/navigation visuals shared by the account list and detail screen, then tune each screen against fixed reference-frame contracts without changing routes, account authorization, or financial state ownership.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter widget tests, ASP.NET Core 8 verification only.

## Global Constraints

- Keep Flutter, Dart, Riverpod, GoRouter, Dio, and the existing EX V2 integration.
- Do not add packages or change the required technology stack.
- Live account code, account name, currency, balance, email, phone, and settings remain EX V2-owned.
- Never display `account.status`, `trochoi.top`, or `EX V2` as broker company, MT5 server, or access point.
- Reference broker metadata is `Exness Technologies Ltd`, `Exness-MT5Real20`, and `Access Point #9` when canonical server/settings fields are absent for this configured Exness product.
- Production mode shows only the account authorized by the device token; do not fabricate the reference Vantage accounts.
- Do not copy personal or financial values from the video.
- Do not add an unlicensed broker bitmap; render the simple broker mark with code-native widgets.
- Use semantic design-system colors, typography, spacing, radius, and icon-size tokens. Add a named feature token when the reference needs a size not represented by a global token.
- Preserve existing Settings routes, account-scope restrictions, optimistic `PUT /settings`, and iOS-style push/pop transitions.
- Run build, analyze, relevant tests, full tests, and emulator screenshot comparison before completion.

---

## File Structure

- Create `mobile/lib/features/profile/domain/account_presentation_profile.dart`: immutable UI-facing account profile, broker enum, and metadata value object currently embedded in the shared provider.
- Create `mobile/lib/features/profile/application/ex_v2_account_profile_mapper.dart`: the only adapter from EX V2 account/settings state to the UI-facing profile.
- Create `mobile/lib/features/profile/presentation/widgets/account_visuals.dart`: shared broker mark, back/add buttons, and chevron used throughout the account flow.
- Modify `mobile/lib/shared/providers/demo_data_provider.dart`: retain offline fixtures but delegate live profile construction to the mapper and re-export the moved profile types for compatibility.
- Modify `mobile/lib/features/profile/presentation/screens/settings_screen.dart`: consume canonical metadata and tune the root header/cards.
- Modify `mobile/lib/features/profile/presentation/screens/profile_screen.dart`: consume shared account visuals and tune list geometry.
- Modify `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart`: consume the same metadata/visuals and tune all detail groups.
- Modify `mobile/lib/core/theme/app_icons.dart`, `app_typography.dart`, or `app_spacing.dart` only when a reusable semantic token is genuinely missing; do not add screen-coordinate constants globally.
- Create `mobile/test/account_presentation_mapper_test.dart`: data-ownership and fallback priority tests.
- Create `mobile/test/account_visuals_test.dart`: shared visual size/semantics contracts.
- Modify `mobile/test/settings_navigation_video_test.dart`: Settings-root text, geometry, icon, and metadata contracts.
- Modify `mobile/test/video2_functional_regression_test.dart`: complete route stack and tab-reset contracts.
- Modify `mobile/test/account_detail_screen_test.dart`: hero, rows, scroll, actions, and server-settings behavior.
- Modify `mobile/test/ex_v2_account_provider_test.dart`: live provider integration contract.
- Modify `docs/screens/settings.md`: record the complete three-screen reference and final emulator measurements.

---

### Task 1: Introduce the account presentation profile and fix the EX V2 mapping

**Files:**
- Create: `mobile/lib/features/profile/domain/account_presentation_profile.dart`
- Create: `mobile/lib/features/profile/application/ex_v2_account_profile_mapper.dart`
- Create: `mobile/test/account_presentation_mapper_test.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart:516-668`
- Modify: `mobile/test/ex_v2_account_provider_test.dart:70-95`

**Interfaces:**
- Consumes: `ExV2AccountViewState`, `ExV2Account`, `ExV2AccountSummary`, and `JsonMap settings`.
- Produces: `AccountPresentationMetadata ExV2AccountProfileMapper.metadata(JsonMap settings)`.
- Produces: `DemoAccountProfile ExV2AccountProfileMapper.map(ExV2AccountViewState state)`.
- Preserves: `demoAccountsProvider` and `activeDemoAccountProvider` public provider names.

- [ ] **Step 1: Write failing mapper tests for source ownership and exact fallback metadata**

Create `mobile/test/account_presentation_mapper_test.dart` with tests that build an `ExV2AccountViewState` from a complete bootstrap fixture and then attach settings with `copyWith`:

```dart
test('maps live identity and finance but never maps transport fields as broker metadata', () {
  final state = accountState(
    accountCode: '109740422',
    name: 'Mỗi Ngày Một Tỷ 🍀',
    status: 'active',
    balance: 154763.90,
  );

  final profile = ExV2AccountProfileMapper.map(state);

  expect(profile.id, '109740422');
  expect(profile.name, 'Mỗi Ngày Một Tỷ 🍀');
  expect(profile.balance, 154763.90);
  expect(profile.currency, 'USD');
  expect(profile.company, 'Exness Technologies Ltd');
  expect(profile.server, 'Exness-MT5Real20');
  expect(profile.accessPoint, 'Access Point #9');
  expect(profile.company, isNot('active'));
  expect(profile.server, isNot('trochoi.top'));
  expect(profile.accessPoint, isNot('EX V2'));
});

test('canonical settings metadata wins over configured Exness fallback', () {
  final state = accountState(
    accountCode: 'LIVE-7',
    name: 'Live account',
    status: 'active',
    balance: 25,
  ).copyWith(settings: const {
    'brokerCompany': 'Canonical Broker Ltd',
    'tradingServer': 'Canonical-MT5Live01',
    'accessPoint': 'Access Point #4',
    'accountMode': 'Netting',
    'isMaster': false,
  });

  final profile = ExV2AccountProfileMapper.map(state);

  expect(profile.company, 'Canonical Broker Ltd');
  expect(profile.server, 'Canonical-MT5Live01');
  expect(profile.accessPoint, 'Access Point #4');
  expect(profile.mode, 'Netting');
  expect(profile.isMaster, isFalse);
});
```

The `accountState` helper must provide every field required by `ExV2Bootstrap.fromJson`, using the same empty-list/wallet/performance/connection structure already present in `mobile/test/ex_v2_account_view_state_test.dart`; only the four named account/summary inputs vary.

- [ ] **Step 2: Run the mapper test and verify it fails because the mapper/types do not exist**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_presentation_mapper_test.dart
```

Expected: FAIL on missing `ExV2AccountProfileMapper` and `AccountPresentationMetadata`.

- [ ] **Step 3: Move the UI profile types and implement deterministic metadata resolution**

Create the domain file with these exact public shapes:

```dart
enum DemoBrokerBrand { vantage, exness, unknown }

final class AccountPresentationMetadata {
  const AccountPresentationMetadata({
    required this.companyName,
    required this.tradingServer,
    required this.accessPoint,
    required this.brand,
    required this.accountMode,
    required this.isMaster,
  });

  final String companyName;
  final String tradingServer;
  final String accessPoint;
  final DemoBrokerBrand brand;
  final String accountMode;
  final bool isMaster;
}

final class DemoAccountProfile {
  const DemoAccountProfile({
    required this.id,
    required this.name,
    required this.company,
    required this.server,
    required this.accessPoint,
    required this.balance,
    required this.brand,
    required this.historyDeposit,
    required this.historyWithdrawal,
    required this.historyProfit,
    required this.historySwap,
    required this.historyCommission,
    required this.historyBalance,
    this.currency = 'USD',
    this.mode = 'Hedge',
    this.isMaster = true,
    this.isDemo = false,
  });

  final String id;
  final String name;
  final String company;
  final String server;
  final String accessPoint;
  final double balance;
  final DemoBrokerBrand brand;
  final String currency;
  final String mode;
  final bool isMaster;
  final bool isDemo;
  final double historyDeposit;
  final double historyWithdrawal;
  final double historyProfit;
  final double historySwap;
  final double historyCommission;
  final double historyBalance;
}
```

Implement `ExV2AccountProfileMapper.metadata` with small `_text` and `_bool` helpers, and make `map` consume that returned value. Read canonical settings aliases in this order:

```dart
companyName: _text(settings, const ['brokerCompany', 'companyName', 'company'])
    ?? 'Exness Technologies Ltd',
tradingServer: _text(settings, const ['tradingServer', 'mt5Server', 'server'])
    ?? 'Exness-MT5Real20',
accessPoint: _text(settings, const ['accessPoint', 'mt5AccessPoint'])
    ?? 'Access Point #9',
accountMode: _text(settings, const ['accountMode', 'positionMode'])
    ?? 'Hedge',
isMaster: _bool(settings, 'isMaster') ?? true,
brand: DemoBrokerBrand.exness,
```

Build `DemoAccountProfile` from `state.bootstrap.account`, `state.balance`, and `state.historySummary`. Map the history fields exactly as follows:

```dart
historyDeposit: state.historySummary.deposit,
historyWithdrawal: state.historySummary.withdrawal,
historyProfit: state.historySummary.realizedProfit,
historySwap: state.historySummary.swap,
historyCommission: state.historySummary.commission,
historyBalance: state.balance,
```

Do not read `account.status` for display metadata. Do not add API-origin or integration-version constants to the mapper.

- [ ] **Step 4: Replace the live branch in `demoAccountsProvider` with the mapper**

Remove the inline live `DemoAccountProfile` construction and use:

```dart
final demoAccountsProvider = Provider<List<DemoAccountProfile>>((ref) {
  final server = ref.watch(exV2AccountProvider).value;
  if (server == null) return demoAccountProfiles;
  return [ExV2AccountProfileMapper.map(server)];
});
```

Import and export `account_presentation_profile.dart` from `demo_data_provider.dart` so existing consumers of `DemoAccountProfile` and `DemoBrokerBrand` remain source-compatible. Update offline fixtures with explicit `isMaster` only where the reference differs from the default.

- [ ] **Step 5: Strengthen the provider integration assertion**

In `mobile/test/ex_v2_account_provider_test.dart`, after reading the server-backed `demoAccountsProvider.single`, assert:

```dart
expect(profile.id, serverState.accountCode);
expect(profile.balance, serverState.balance);
expect(profile.company, 'Exness Technologies Ltd');
expect(profile.server, 'Exness-MT5Real20');
expect(profile.accessPoint, 'Access Point #9');
expect(profile.company, isNot(serverState.bootstrap.account.status));
```

- [ ] **Step 6: Run focused mapper/provider tests and confirm they pass**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_presentation_mapper_test.dart test/ex_v2_account_provider_test.dart test/reference_fixture_test.dart
```

Expected: all focused tests PASS; offline fixture ordering remains unchanged.

- [ ] **Step 7: Commit the data-boundary fix**

```powershell
git add mobile/lib/features/profile/domain/account_presentation_profile.dart mobile/lib/features/profile/application/ex_v2_account_profile_mapper.dart mobile/lib/shared/providers/demo_data_provider.dart mobile/test/account_presentation_mapper_test.dart mobile/test/ex_v2_account_provider_test.dart
git commit -m "fix: map canonical broker metadata for account UI"
```

---

### Task 2: Extract shared reference account visuals

**Files:**
- Create: `mobile/lib/features/profile/presentation/widgets/account_visuals.dart`
- Create: `mobile/test/account_visuals_test.dart`
- Modify only if required: `mobile/lib/core/theme/app_icons.dart`

**Interfaces:**
- Consumes: `DemoBrokerBrand`, semantic theme tokens, and callbacks.
- Produces: `AccountBrokerMark`, `AccountRoundBackButton`, `AccountRoundAddButton`, and `AccountChevronRight`.
- Produces: stable keys `account-broker-mark`, `account-back-glyph`, `account-add-glyph`, and `account-chevron-glyph`.

- [ ] **Step 1: Write failing size, brand, and hit-target tests**

Create tests that pump each public widget inside a dark `MaterialApp` and assert:

```dart
expect(tester.getSize(find.byKey(const Key('account-broker-mark'))),
    const Size.square(31));
expect(find.text('exness'), findsOneWidget);
expect(tester.getSize(find.byKey(const Key('account-round-back-button'))),
    const Size.square(43));
expect(tester.getSize(find.byKey(const Key('account-round-add-button'))),
    const Size.square(43));
expect(tester.getSize(find.byKey(const Key('account-chevron-glyph'))),
    const Size(10, 14));
```

Tap the back/add buttons and assert their callback counters each increment once. Pump `DemoBrokerBrand.unknown` and assert that no `exness` text is rendered.

- [ ] **Step 2: Run the test and verify it fails because shared widgets do not exist**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_visuals_test.dart
```

Expected: FAIL on missing public account visual widgets.

- [ ] **Step 3: Implement the shared visual primitives**

Use one named feature constant block inside `account_visuals.dart`:

```dart
abstract final class AccountVisualMetrics {
  static const brokerMark = 31.0;
  static const heroBrokerMark = 60.0;
  static const toolbarHitTarget = 43.0;
  static const chevron = Size(10, 14);
}
```

Implement the Exness mark as a yellow `SizedBox.square`/`ColoredBox` with centered lowercase `exness` text and semantic exclusion. Keep the Vantage mark code-native. Use the existing painter geometry from `ProfileScreen` for back/add/chevron, but expose it once through the public shared widgets. Use `AppColors`, `AppTypography`, and `AppIconSizes`; do not duplicate screen-specific color literals.

- [ ] **Step 4: Run the shared visual tests and confirm they pass**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_visuals_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit the reusable visual layer**

```powershell
git add mobile/lib/features/profile/presentation/widgets/account_visuals.dart mobile/test/account_visuals_test.dart mobile/lib/core/theme/app_icons.dart
git commit -m "refactor: share account flow visual primitives"
```

---

### Task 3: Match the Settings root and canonical account header

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart:9-378`
- Modify: `mobile/test/settings_navigation_video_test.dart:1-139`
- Modify: `docs/screens/settings.md`

**Interfaces:**
- Consumes: `activeDemoAccountProvider`, `exV2AccountProvider`, `MtSettingsRasterIcon`, and `AccountChevronRight`.
- Produces: unchanged `SettingsScreen` public widget and existing row keys/routes.
- Preserves: API-owned unread count and language/locale subtitle.

- [ ] **Step 1: Add failing live-metadata and geometry assertions**

Add a server-state provider override that returns an account named `Mỗi Ngày Một Tỷ 🍀` with code `109740422`, status `active`, and empty metadata settings. Assert the Settings header contains:

```dart
expect(find.text('Mỗi Ngày Một Tỷ 🍀'), findsOneWidget);
expect(find.text('Exness Technologies Ltd'), findsOneWidget);
expect(find.text('109740422 - Exness-MT5Real20\nAccess Point #9'),
    findsOneWidget);
expect(find.text('active'), findsNothing);
expect(find.textContaining('trochoi.top'), findsNothing);
expect(find.text('EX V2'), findsNothing);
```

Retain the existing exact-copy loop for all twelve Settings rows. Add keys to the header text blocks and assert their top-to-top ordering and horizontal centering within 1 logical pixel. Assert the account header height, divider thickness, card horizontal inset, 29 logical-pixel row-icon frame, and shared chevron size.

- [ ] **Step 2: Run the Settings test and verify the old implementation fails**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/settings_navigation_video_test.dart
```

Expected: FAIL on live metadata and shared chevron/header keys.

- [ ] **Step 3: Replace the private account chevron and tune the header**

Use `AccountChevronRight` from `account_visuals.dart`; remove the duplicate `_ReferenceChevronRight` implementation only after `rg` confirms it has no other consumer. Add stable keys:

```dart
const Key('settings-account-name')
const Key('settings-account-company')
const Key('settings-account-server-access')
```

Keep the four-line data order from the reference. Use `AppTypography` via `copyWith` and named local metrics for the measured account-header positions instead of anonymous transform chains. Preserve `Semantics` with the same five account fields and the account header tap to `/profile`.

- [ ] **Step 4: Audit every Settings card row against frames 12.8, 14.2, and 21.3 seconds**

At a 288 x 640 logical viewport, measure and align:

- 16 logical-pixel outer left inset and 14 logical-pixel right inset.
- 24 logical-pixel card radius.
- 19 logical-pixel inter-card gap.
- 29 x 29 logical-pixel icon frame.
- 21 x 21 logical-pixel notification badge.
- Divider color/thickness from `AppColors.divider`.
- Text/subtitle baseline and truncation shown in the recording.

Keep the existing raster Settings icons and connected glyph when their pixel silhouettes match the frame. If a silhouette differs, update only the affected `MtSettingsRasterIconKind` entry; do not replace unrelated icons or import a new package.

- [ ] **Step 5: Update the screen reference document**

Expand `docs/screens/settings.md` with separate `Settings root`, `Account list`, and `Account detail` sections. Record the source timestamps, native 576 x 1280 size, normalized 288 x 640 comparison viewport, API-owned masked fields, and platform overlays excluded from comparison.

- [ ] **Step 6: Run the focused Settings tests and commit**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/settings_navigation_video_test.dart test/video_button_coverage_test.dart
```

Expected: both test files PASS.

```powershell
git add mobile/lib/features/profile/presentation/screens/settings_screen.dart mobile/test/settings_navigation_video_test.dart docs/screens/settings.md
git commit -m "fix: match settings account header to reference"
```

---

### Task 4: Match the active-account list

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart:1-339`
- Modify: `mobile/test/video2_functional_regression_test.dart:120-190`
- Modify: `mobile/test/video2_cross_tab_test.dart`

**Interfaces:**
- Consumes: `demoAccountsProvider`, `activeDemoAccountIdProvider`, and shared account visual widgets.
- Produces: unchanged `ProfileScreen`, account row keys `account-{id}`, and active navigation to `/account-detail`.
- Preserves: production single-account scope and offline fixture switching.

- [ ] **Step 1: Write failing production and offline list contracts**

For a server-backed account, assert exactly one account row and these texts:

```dart
expect(find.byKey(const ValueKey('account-109740422')), findsOneWidget);
expect(find.text('Mỗi Ngày Một Tỷ 🍀'), findsOneWidget);
expect(find.text('109740422 - Exness-MT5Real20'), findsOneWidget);
expect(find.text('154 763.90 USD, Hedge'), findsOneWidget);
expect(find.byKey(const Key('account-broker-mark')), findsOneWidget);
expect(find.text('exness'), findsOneWidget);
```

Assert the active name is `AppColors.primary`, the row has the selected surface, and the shared chevron is present. In an offline `ProviderContainer`, retain the existing fixture account order/count and verify Vantage rows do not render `exness`.

- [ ] **Step 2: Run the focused list tests and verify they fail on old server metadata/private visuals**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/video2_functional_regression_test.dart test/video2_cross_tab_test.dart
```

Expected: FAIL on the canonical trading-server and shared-visual assertions.

- [ ] **Step 3: Replace private visuals and tune reference geometry**

Replace `_BrokerLogo`, `_AccountBackIcon`, `_AccountAddIcon`, and `_AccountChevronRight` with the shared widgets. Remove their private painters after `rg` confirms no remaining references.

At the normalized reference viewport, lock:

- 81 logical-pixel toolbar region.
- 43 logical-pixel circular back/add hit targets.
- 31 logical-pixel list broker mark.
- 97 logical-pixel row height.
- Name/server/balance line order and one-line ellipsis.
- Selected background, primary name color, secondary inactive text, and right chevron alignment.

Do not add the two Vantage reference accounts to production state. Preserve the existing offline account ordering and selection behavior.

- [ ] **Step 4: Verify active navigation and inert server add action**

Extend the router test to tap the active server account and expect `/account-detail`. Tap the add button in server mode and assert the route remains `/profile`. In offline mode, tap add and expect `/register`.

- [ ] **Step 5: Run the focused tests and commit**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/video2_functional_regression_test.dart test/video2_cross_tab_test.dart test/reference_fixture_test.dart
```

Expected: all focused tests PASS.

```powershell
git add mobile/lib/features/profile/presentation/screens/profile_screen.dart mobile/test/video2_functional_regression_test.dart mobile/test/video2_cross_tab_test.dart
git commit -m "fix: match account list to video reference"
```

---

### Task 5: Match the full account-detail screen and behavior

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/account_detail_screen.dart:1-471`
- Modify: `mobile/test/account_detail_screen_test.dart`
- Modify: `mobile/test/video2_functional_regression_test.dart`

**Interfaces:**
- Consumes: `activeDemoAccountProvider`, `exV2AccountProvider`, shared visuals, `/deposit`, `/withdraw`, and `ExV2AccountController.updateSettings`.
- Produces: unchanged `AccountDetailScreen` and keys for hero/groups/rows/switch.
- Preserves: optimistic notification update with rollback.

- [ ] **Step 1: Replace default-Vantage assertions with a server-backed reference contract**

Pump `AccountDetailScreen` with the same server-state override used by Settings tests. At the top, assert:

```dart
expect(find.text('Mỗi Ngày Một Tỷ 🍀'), findsWidgets);
expect(find.text('109740422 - Exness-MT5Real20'), findsOneWidget);
expect(find.text('154 763.90 USD'), findsOneWidget);
expect(find.text('Master'), findsOneWidget);
expect(find.text('Hedge'), findsOneWidget);
expect(find.text('Exness Technologies Ltd'), findsOneWidget);
```

After dragging the keyed scroll view, assert the profile group contains live account code plus canonical server/access point and never contains `active`, `trochoi.top`, or `EX V2`. Assert absent contact fields render `—`.

- [ ] **Step 2: Add failing visual and interaction assertions**

Add keys and assert the hero, company group, money group, profile group, and security group appear in the reference order. Assert the shared hero broker mark, back hit target, row height, divider thickness, right-aligned value style, info glyph, switch, and destructive delete color. Keep existing deposit/withdraw route tests.

Add an error-path notification test by overriding the account controller/repository so `updateSettings` throws. Tap the switch, assert it changes immediately, complete the failing future, pump, and assert it returns to the confirmed server value.

- [ ] **Step 3: Run the detail tests and verify failure against current private logo/geometry and mapping**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_detail_screen_test.dart
```

Expected: FAIL on shared hero mark, canonical metadata, and rollback contract if not already covered.

- [ ] **Step 4: Implement the reference detail composition**

Use `AccountRoundBackButton` and `AccountBrokerMark` from the shared visual file. Remove `_RoundToolbarButton` and `_BrokerLogo` after confirming no references remain.

Render the hero fields from `DemoAccountProfile`:

```dart
Text(account.name)
Text('${account.id} - ${account.server}')
Text('${_formatAccountBalance(account.balance)} ${account.currency}')
if (account.isMaster)
  const _AccountBadge(label: 'Master', color: AppColors.negative)
_AccountBadge(label: account.mode, color: AppColors.primary)
```

Keep group order exactly as the spec. Company, Server, and Connected rows must use `account.company`, `account.server`, and `account.accessPoint`. Owner/contact values continue to use EX V2 settings with the existing em-dash fallback. Replace anonymous spacing with existing `AppSpacing` or named detail metrics, and use semantic colors/typography.

- [ ] **Step 5: Preserve routes and optimistic settings semantics**

Keep `/deposit` and `/withdraw` pushes. Keep `_tradeNotificationsOverride` for immediate feedback. On success, clear the override so confirmed server state wins; on failure, clear it so the old confirmed value is restored. Do not add delete, password, or device-management API calls.

- [ ] **Step 6: Run detail and complete-flow tests and commit**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_detail_screen_test.dart test/video2_functional_regression_test.dart test/settings_navigation_video_test.dart
```

Expected: all focused tests PASS.

```powershell
git add mobile/lib/features/profile/presentation/screens/account_detail_screen.dart mobile/test/account_detail_screen_test.dart mobile/test/video2_functional_regression_test.dart
git commit -m "fix: match account detail to video reference"
```

---

### Task 6: Verify navigation reset, full compatibility, and emulator pixel parity

**Files:**
- Modify if an uncovered contract fails: `mobile/lib/app/router.dart`
- Modify if an uncovered contract fails: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `mobile/test/video2_functional_regression_test.dart`
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Modify: `docs/screens/settings.md`
- Create: five PNG files under `docs/screenshots/` using the naming below.

**Interfaces:**
- Consumes: completed Settings/account flow and `IMG_5526.MP4` reference frames.
- Produces: full validation evidence and emulator screenshots.
- Screenshot outputs: `settings-account-root-final.png`, `settings-account-list-final.png`, `settings-account-detail-top-final.png`, `settings-account-detail-middle-final.png`, `settings-account-detail-bottom-final.png`.

- [ ] **Step 1: Add the complete route-stack regression test**

Drive this exact sequence through `MaterialApp.router`:

```text
/settings
  -> tap settings-account
/profile
  -> tap active account row
/account-detail
  -> back
/profile
  -> back
/settings
  -> switch to another bottom tab
  -> return to Settings
/settings (root, not profile/detail)
```

Assert each URI and destination key. Do not change router code unless the test demonstrates a real mismatch.

- [ ] **Step 2: Run formatting, analyzer, focused tests, and the full Flutter suite**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\dart.bat' format lib/features/profile lib/shared/providers/demo_data_provider.dart test/account_presentation_mapper_test.dart test/account_visuals_test.dart test/account_detail_screen_test.dart test/settings_navigation_video_test.dart test/video2_functional_regression_test.dart test/video2_cross_tab_test.dart test/ex_v2_account_provider_test.dart
& 'D:\toolchains\flutter\bin\flutter.bat' analyze
& 'D:\toolchains\flutter\bin\flutter.bat' test test/account_presentation_mapper_test.dart test/account_visuals_test.dart test/settings_navigation_video_test.dart test/account_detail_screen_test.dart test/video2_functional_regression_test.dart test/video2_cross_tab_test.dart test/ex_v2_account_provider_test.dart
& 'D:\toolchains\flutter\bin\flutter.bat' test
```

Expected: formatter exits 0, analyzer reports `No issues found`, and all focused/full tests PASS.

- [ ] **Step 3: Build the APK and verify the unchanged backend**

Run:

```powershell
cd mobile
& 'D:\toolchains\flutter\bin\flutter.bat' build apk --debug

cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: debug APK created, backend build has 0 errors, and all backend tests PASS.

- [ ] **Step 4: Install on LDPlayer and capture the five acceptance screenshots**

Resolve the connected emulator first:

```powershell
adb devices
adb install -r mobile\build\app\outputs\flutter-apk\app-debug.apk
```

Open the app with the authenticated EX V2 device state. Navigate through the full flow and capture:

Use device-side capture followed by binary-safe `adb pull` for each state:

```powershell
adb shell screencap -p /sdcard/settings-account-root-final.png
adb pull /sdcard/settings-account-root-final.png docs\screenshots\settings-account-root-final.png

adb shell screencap -p /sdcard/settings-account-list-final.png
adb pull /sdcard/settings-account-list-final.png docs\screenshots\settings-account-list-final.png

adb shell screencap -p /sdcard/settings-account-detail-top-final.png
adb pull /sdcard/settings-account-detail-top-final.png docs\screenshots\settings-account-detail-top-final.png

adb shell screencap -p /sdcard/settings-account-detail-middle-final.png
adb pull /sdcard/settings-account-detail-middle-final.png docs\screenshots\settings-account-detail-middle-final.png

adb shell screencap -p /sdcard/settings-account-detail-bottom-final.png
adb pull /sdcard/settings-account-detail-bottom-final.png docs\screenshots\settings-account-detail-bottom-final.png
```

- [ ] **Step 5: Compare each screenshot against the exact video frame**

Normalize both images to the same application viewport. Mask only the Android/iOS system bars, Dynamic Island/AssistiveTouch, and API-owned account code, balance, email, phone, and name when they differ from the recording. Do not mask company, trading server, access point, row text, icons, dividers, cards, badges, or switches.

For every visible mismatch, record the measured delta in `docs/screens/settings.md`, adjust the owning named metric/token, rerun its focused widget test, rebuild/install, and recapture. Stop iterating only when the remaining differences are platform font rasterization or excluded operating-system overlays.

- [ ] **Step 6: Review the final diff and commit acceptance evidence**

Run:

```powershell
git diff --check
git diff -- mobile/lib mobile/test docs/screens/settings.md
git status --short
```

Confirm no unrelated user files are staged. Then commit only this task's route/test/document/screenshot changes:

```powershell
git add mobile/lib/app/router.dart mobile/lib/shared/widgets/app_shell.dart mobile/test/video2_functional_regression_test.dart mobile/test/settings_navigation_video_test.dart docs/screens/settings.md docs/screenshots/settings-account-root-final.png docs/screenshots/settings-account-list-final.png docs/screenshots/settings-account-detail-top-final.png docs/screenshots/settings-account-detail-middle-final.png docs/screenshots/settings-account-detail-bottom-final.png
git commit -m "test: verify full settings account video parity"
```

If `router.dart` or `app_shell.dart` did not require a change, omit it from `git add` rather than touching it mechanically.

---

## Final Acceptance Checklist

- [ ] Settings root, account list, and account detail use one mapped account profile.
- [ ] `active`, `trochoi.top`, and `EX V2` never occupy broker metadata positions.
- [ ] Company is `Exness Technologies Ltd` when no canonical field is supplied.
- [ ] Trading server is `Exness-MT5Real20` when no canonical field is supplied.
- [ ] Connected access point is `Access Point #9` when no canonical field is supplied.
- [ ] Live account code, name, currency, balance, email, phone, and settings remain server-owned.
- [ ] Production shows only the server-authorized account.
- [ ] Shared logo/back/add/chevron widgets are used consistently.
- [ ] All reference rows, groups, scroll states, routes, badges, and switch behavior are covered.
- [ ] Flutter format, analyze, focused tests, full tests, and APK build pass.
- [ ] Backend build and tests pass.
- [ ] Five LDPlayer screenshots are captured and documented against the video.
- [ ] `git diff --check` is clean and no unrelated changes are included.
