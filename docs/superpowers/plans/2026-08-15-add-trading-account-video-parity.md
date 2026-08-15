# Add Trading Account Video Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add, authenticate, persist, and activate multiple EX V2 virtual trading accounts while matching the complete `themmoitk.MP4` flow.

**Architecture:** EX V2 owns broker/server discovery, credential verification, device-account links, and the active account. Flutter adds a focused account-linking feature and treats the activate response as an atomic bootstrap replacement so every account-scoped tab changes together. The existing local market-data backend remains read-only and unchanged.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, SignalR, ASP.NET Core, Entity Framework Core, SQL Server, xUnit.

## Global Constraints

- Keep the required technology stack unchanged.
- Do not connect to or trade through real Exness/MetaQuotes accounts.
- Do not hard-code account `425297911`, server `Exness-MT5Real15`, password, balance, symbols, positions, or history.
- Never log or persist plaintext passwords.
- Do not add account mutations to the local read-only `backend/` market service.
- Device tokens and linked-account grants must remain device-scoped and revocable.
- Account activation must publish one complete bootstrap; mixed old/new account state is forbidden.
- Run build, analyze, and relevant tests after every implementation task.

---

### Task 1: Establish the EX V2 source and contract gate

**Files:**
- Verify external source root: `/opt/ex-v2-api-src`
- Create local working copy when access exists: `D:/mt5New/ex-v2-api-src`
- Verify: `D:/mt5New/ex-v2-api-src/docs/openapi-v2.json`

**Interfaces:**
- Consumes: deployed EX V2 source and its existing device-token account resolver.
- Produces: a buildable local EX V2 source tree and exact project/test paths used by Tasks 2-3.

- [ ] Confirm the source is accessible without changing production:

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=8 root@trochoi.top "test -d /opt/ex-v2-api-src && find /opt/ex-v2-api-src -maxdepth 2 -name '*.sln' -o -name '*.csproj'"
```

- [ ] Copy or clone that source into `D:/mt5New/ex-v2-api-src` using the repository's existing deployment mechanism; do not manufacture EX V2 endpoints inside `backend/`.
- [ ] Locate the current controller, DbContext, migrations, device resolver, password hashing, event publisher, and integration-test project:

```powershell
rg -n "mobile/bootstrap|WebActiveAccount|X-Device-Token|DbContext|PasswordHasher|ActiveAccountChanged" D:/mt5New/ex-v2-api-src
```

- [ ] Run the unmodified server build and tests and record the baseline:

```powershell
dotnet build D:/mt5New/ex-v2-api-src/*.sln
dotnet test D:/mt5New/ex-v2-api-src/*.sln --no-build
```

- [ ] Stop this task if the source or baseline is unavailable. Do not route the app to a fake local substitute.

### Task 2: Add EX V2 linked-account persistence and credential verification

**Files:**
- Create in the EX V2 domain project: `Domain/MobileAccounts/MobileBroker.cs`
- Create in the EX V2 domain project: `Domain/MobileAccounts/MobileTradingServer.cs`
- Create in the EX V2 domain project: `Domain/MobileAccounts/MobileAccountCredential.cs`
- Create in the EX V2 domain project: `Domain/MobileAccounts/MobileDeviceAccountLink.cs`
- Modify the discovered EX V2 `DbContext` from Task 1.
- Create one EF Core migration named `AddMobileLinkedAccounts`.
- Test in the discovered integration-test project: `MobileAccountLinkPersistenceTests.cs`

**Interfaces:**
- Produces: broker/server catalog rows, salted credential hashes, unique device/account links, active-link state, and revocable reconnect-grant hashes.
- Consumes: existing trading-account IDs and mobile-device IDs.

- [ ] Write a failing persistence test proving one device may link two accounts, another device cannot see those links, and `(DeviceId, TradingAccountId)` is unique.
- [ ] Run the focused server test and confirm RED because the entities and tables do not exist.
- [ ] Implement the four entities with database uniqueness on broker code, `(BrokerId, ServerName)`, `(TradingAccountId, ServerId, Login)`, and `(DeviceId, TradingAccountId)`.
- [ ] Hash demo trading passwords with the server's existing password hasher. Store only the hash and its normal framework metadata.
- [ ] Hash reconnect grants before storage; return the plaintext grant only once at successful link time.
- [ ] Add the migration and inspect it to ensure no plaintext password/grant columns exist.
- [ ] Run the focused test and complete server build/tests.
- [ ] Commit only the server persistence slice:

```powershell
git add Domain Infrastructure tests
git commit -m "feat: persist device linked trading accounts"
```

### Task 3: Add EX V2 broker, server, link, list, and activate APIs

**Files:**
- Create in the discovered EX V2 API project: `Controllers/MobileAccountsController.cs`
- Create in the discovered EX V2 application project: `MobileAccounts/MobileAccountContracts.cs`
- Create in the discovered EX V2 application project: `MobileAccounts/MobileAccountService.cs`
- Modify: `D:/mt5New/ex-v2-api-src/docs/openapi-v2.json`
- Test in the discovered integration-test project: `MobileAccountsApiTests.cs`

**Interfaces:**
- Produces:
  - `GET /api/v2/mobile/brokers?query=`
  - `GET /api/v2/mobile/brokers/{brokerId}/servers?query=`
  - `GET /api/v2/mobile/accounts`
  - `POST /api/v2/mobile/accounts/link`
  - `PUT /api/v2/mobile/accounts/{accountId}/activate`
- Consumes: Task 2 persistence and the existing device-token resolver/bootstrap builder.

- [ ] Write failing integration tests for catalog filtering, correct credentials, wrong credentials, server mismatch, disabled account, duplicate idempotency replay, device isolation, and activate returning the new bootstrap.
- [ ] Define request/response contracts without secret fields:

```csharp
public sealed record LinkMobileAccountRequest(
    Guid BrokerId,
    Guid ServerId,
    string Login,
    string Password,
    bool SavePassword);

public sealed record ActivateMobileAccountResponse(
    MobileAccountSummary Account,
    MobileBootstrapDto Bootstrap);
```

- [ ] Implement case-insensitive broker/server search with stable display ordering.
- [ ] Implement idempotent credential validation and link creation in one transaction.
- [ ] For an existing link, validate credentials and return that link rather than inserting a duplicate.
- [ ] Implement activation as one transaction that updates the device active account/version, builds bootstrap after commit, and publishes `ActiveAccountChanged` after commit.
- [ ] Verify response serialization and structured 400/401/409/422 errors contain correlation IDs but no credentials.
- [ ] Update OpenAPI and compare the generated request fields with the committed document.
- [ ] Run focused tests, complete server build/tests, and commit:

```powershell
git add Controllers MobileAccounts tests docs/openapi-v2.json
git commit -m "feat: expose mobile linked account APIs"
```

### Task 4: Add Flutter account-link domain, repository, and controller

**Files:**
- Create: `mobile/lib/features/account_link/domain/account_link_models.dart`
- Create: `mobile/lib/features/account_link/data/account_link_repository.dart`
- Create: `mobile/lib/features/account_link/application/account_link_controller.dart`
- Create: `mobile/lib/features/account_link/data/account_reconnect_grant_store.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Test: `mobile/test/account_link_repository_test.dart`
- Test: `mobile/test/account_link_controller_test.dart`

**Interfaces:**
- Produces `MobileBroker`, `MobileTradingServer`, `LinkedTradingAccount`, `LinkAccountRequest`, and `ActivateLinkedAccountResult`.
- Produces `AsyncNotifierProvider<AccountLinkController, AccountLinkState>`.
- Consumes the existing `ExV2ApiClient`, device token, secure storage, and `ExV2Bootstrap` parser.

- [ ] Write failing repository tests asserting exact paths, query parameters, JSON fields, device/idempotency/correlation headers, and absence of password in returned models.
- [ ] Write failing controller tests for one-submit locking, invalid credentials clearing only password, duplicate-link activation, grant persistence when enabled, memory-only grant when disabled, and atomic bootstrap replacement.
- [ ] Run both files and confirm RED because the feature does not exist.
- [ ] Implement immutable JSON models with strict required IDs/names and tolerant optional display metadata.
- [ ] Implement repository methods:

```dart
Future<List<MobileBroker>> brokers({String query = ''});
Future<List<MobileTradingServer>> servers(String brokerId, {String query = ''});
Future<List<LinkedTradingAccount>> accounts();
Future<LinkAccountResult> link(LinkAccountRequest request,
    {required ExV2CommandMetadata metadata});
Future<ActivateLinkedAccountResult> activate(String accountId,
    {required ExV2CommandMetadata metadata});
```

- [ ] Implement the controller state machine `idle/loadingCatalog/editing/submitting/activating/succeeded/failed` and reject repeat submits while `submitting` or `activating`.
- [ ] On activate success, publish the returned bootstrap through the existing account controller before navigation.
- [ ] Store only the opaque reconnect grant in Flutter Secure Storage.
- [ ] Run focused tests, analyze, complete mobile tests/build, and commit:

```powershell
git add mobile/lib/features/account_link mobile/lib/features/account_sync mobile/test/account_link_*.dart
git commit -m "feat: add server backed account linking client"
```

### Task 5: Build the Brokers and trading-server reference screens

**Files:**
- Create: `mobile/lib/features/account_link/presentation/screens/broker_list_screen.dart`
- Create: `mobile/lib/features/account_link/presentation/screens/trading_server_screen.dart`
- Create: `mobile/lib/features/account_link/presentation/widgets/account_link_visuals.dart`
- Modify: `mobile/lib/app/router.dart`
- Test: `mobile/test/account_link_catalog_video_test.dart`

**Interfaces:**
- Produces routes `/accounts/add`, `/accounts/add/:brokerId`, and `/accounts/add/:brokerId/servers`.
- Consumes broker/server providers from Task 4.

- [ ] Write failing widget tests for the 9.5-second Brokers frame: title, back/add/QR controls, Exness and MetaQuotes rows, info actions, bottom search, keyboard input, filtering, and broker navigation.
- [ ] Write failing widget tests for the 16-second server frame: `Máy chủ` title, back control, divider pitch, scrolling, selected callback, and server name returned to the login form.
- [ ] Run focused tests and confirm RED.
- [ ] Implement code-native broker marks and toolbar controls using existing account visual metrics and theme tokens.
- [ ] Implement debounced local presentation over server-filtered catalog results; stale responses must not replace a newer query.
- [ ] Configure the bottom broker search for text input and the login field for numeric input.
- [ ] Run focused tests, analyze, complete mobile tests/build, and commit:

```powershell
git add mobile/lib/features/account_link/presentation mobile/lib/app/router.dart mobile/test/account_link_catalog_video_test.dart
git commit -m "feat: match broker and server selection video"
```

### Task 6: Build the existing-account login reference screen

**Files:**
- Replace: `mobile/lib/features/authentication/presentation/screens/register_screen.dart`
- Prefer new implementation at: `mobile/lib/features/account_link/presentation/screens/existing_account_login_screen.dart`
- Modify: `mobile/lib/app/router.dart`
- Test: `mobile/test/account_link_login_video_test.dart`

**Interfaces:**
- Consumes `AccountLinkController`, selected broker, and selected server.
- Produces validated server/login/password/save-password input and a single link/activate action.

- [ ] Write failing widget tests for reference frames 12, 20, 24, and 28 seconds, including exact copy, row order, disabled/enabled login button, numeric login keyboard, obscured password, green save switch, and preserved form after server navigation.
- [ ] Write failure tests proving invalid credentials clear only password and show retry feedback without navigating.
- [ ] Write success tests proving link then activate completes before `context.go('/trade')`.
- [ ] Run focused tests and confirm RED.
- [ ] Implement the selected-broker header, reference sections, server row, login/password fields, save switch, forgot-password action, and anchored pill login button.
- [ ] Keep real/demo registration rows and QR action non-mutating with safe reference feedback because the video does not execute them.
- [ ] Remove the generic demo-registration UI after `rg` confirms no consumer expects it.
- [ ] Run focused tests, analyze, complete mobile tests/build, and commit:

```powershell
git add mobile/lib/features/account_link mobile/lib/features/authentication/presentation/screens/register_screen.dart mobile/lib/app/router.dart mobile/test/account_link_login_video_test.dart
git commit -m "feat: match existing account login video"
```

### Task 7: Enable add and atomic account switching across the app

**Files:**
- Modify: `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Test: `mobile/test/multi_account_switch_test.dart`
- Test: `mobile/test/account_link_cross_tab_video_test.dart`

**Interfaces:**
- Consumes `GET /mobile/accounts`, activate endpoint, and returned bootstrap.
- Produces active-first linked account list and one account generation shared by Settings, Market, Chart, Trade, History, Wallet, and notifications.

- [ ] Write failing tests proving add controls navigate in production and the linked account list contains both active and inactive server accounts.
- [ ] Write a cross-tab failure test that starts on account A, activates account B, and asserts no account-A positions/history/settings remain in any tab.
- [ ] Write a failure test proving activate error leaves account A active everywhere.
- [ ] Run focused tests and confirm RED.
- [ ] Remove the production no-op callbacks from Settings and Profile add buttons.
- [ ] Replace the single-account projection with the linked-account list while preserving active-first ordering and reference active/inactive styling.
- [ ] Add an account generation key to reset account-scoped branch/navigation state after activation without resetting global theme/device state.
- [ ] Publish the activate bootstrap atomically, then return to the reference destination.
- [ ] Run focused tests, analyze, complete mobile tests/build, and commit:

```powershell
git add mobile/lib/features/profile mobile/lib/features/account_sync mobile/lib/shared mobile/test/multi_account_switch_test.dart mobile/test/account_link_cross_tab_video_test.dart
git commit -m "feat: switch linked accounts across all tabs"
```

### Task 8: Pixel parity, deployment, and end-to-end acceptance

**Files:**
- Update: `docs/screens/settings.md`
- Update: `docs/ex-v2-mobile-integration.md`
- Add screenshots under: `docs/screenshots/add-account/`
- Verify all files from Tasks 2-7.

**Interfaces:**
- Consumes the completed EX V2 and Flutter slices.
- Produces deployed video-parity evidence and a rollback-ready release.

- [ ] Run EX V2 build/tests and Flutter analyze/tests/debug APK build.
- [ ] Deploy only EX V2 using its existing rollback process; do not restart or alter legacy `/ex/api/api/*`.
- [ ] Verify broker/server/list endpoints and wrong-password rejection with a provisioned virtual test account.
- [ ] Install the APK with `adb install -r` so device data is preserved.
- [ ] Execute the reference path with a dedicated virtual account and capture frames matching 9.5, 12, 16, 20, 24, 28, 32, 56, 64, 72, and 76 seconds.
- [ ] Normalize to 576 x 1280 and mask only system overlays, keyboard differences, and API-owned values. Tune unmasked geometry/colors until no material mismatch remains.
- [ ] Restart the app, verify linked accounts and active selection persist, switch back, and confirm every tab changes atomically.
- [ ] Confirm logs, screenshots, source, fixtures, and API payloads contain no password, hash, device token, or reconnect grant.
- [ ] Commit documentation and evidence:

```powershell
git add docs/screens/settings.md docs/ex-v2-mobile-integration.md docs/screenshots/add-account
git commit -m "docs: verify add account video parity"
```

## Plan self-review

- Tasks 2-3 cover all EX V2 persistence, security, discovery, link, list, activate, idempotency, isolation, and bootstrap requirements.
- Tasks 4-7 cover the complete Flutter route, UI, credential, persistence, activation, and cross-tab behavior.
- Task 8 covers build, deploy, device capture, parity, secret audit, restart, and rollback evidence.
- Task 1 intentionally blocks server implementation when the separately deployed source cannot be accessed; replacing it with the local market backend is prohibited.
