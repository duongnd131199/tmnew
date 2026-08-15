# Add Trading Account Video-Parity Design

## Goal

Implement the complete add-existing-account flow shown in `giaoDienMau/themmoitk.MP4`: discover a broker, choose a trading server, authenticate an existing account, persist it, activate it, and switch all account-owned app data to it while matching the reference UI and transitions.

The implementation remains a virtual-money EX V2 product. It does not log in to or trade against a real Exness account.

## Reference flow

The 77.23-second, 576 x 1280 reference records this sequence:

1. Open Settings, then open `Tài khoản`.
2. Tap the circular add button on the account list.
3. Show the `Brokers` screen with Exness and MetaQuotes rows, row information buttons, a QR action, and the bottom company-search field.
4. Select `Exness Technologies Ltd`.
5. Show the Exness account screen with the broker header, new real/demo account choices, and the `Sử dụng tài khoản hiện có` form.
6. Open `Máy chủ`, display and scroll the Exness server list, and choose `Exness-MT5Real15` in the recorded path.
7. Enter a numeric login with the numeric keyboard, enter the password, keep `Lưu mật khẩu` enabled, and submit.
8. On success, activate the new account and open Trade with that account's server-owned empty snapshot.
9. Continue using Market Watch, symbol search, Trade, and History under the new active account.
10. Return to `Tài khoản`; the new account appears first and selected, while the previous account remains listed.
11. Return to Settings; the account summary shows the newly active account.

The recorded login, account number, server, name, balance, symbols, positions, and history are reference data only. They must not be hard-coded into production.

## Current gaps

- `/register` currently opens a generic demo-registration form unrelated to MT5 account linking.
- The Settings new-account row and account-list add button are disabled when EX V2 state is present.
- Production exposes only the server-selected active account; it has no mobile linked-account list or mobile activation endpoint.
- The production OpenAPI document has admin trading-account reads and one active-account snapshot, but no broker discovery, server discovery, account authentication/linking, or mobile account switching endpoints.
- The local `backend/` project is a market-data/read-only bridge. The EX V2 order/account service is separately deployed from `/opt/ex-v2-api-src` and is not present in this Windows workspace.

## Chosen architecture

### Mobile account-linking feature

Replace the generic `/register` destination with a focused account-linking route stack owned by a new profile/account-linking feature:

- `BrokerListScreen`: broker discovery, broker rows, info actions, QR action, and company search.
- `ExistingAccountLoginScreen`: selected-broker header, real/demo registration rows, server/login/password/save-password form, forgot-password action, and submit state.
- `TradingServerScreen`: searchable/selectable server list scoped to the selected broker.
- `AccountLinkController`: loads brokers/servers, validates form state, submits credentials once, stores only an opaque reconnect grant when requested, activates the linked account, and refreshes bootstrap.

Existing `ProfileScreen`, Settings, Trade, Market Watch, Chart, and History keep their visual responsibilities. They consume the active account selected by EX V2.

### EX V2 multi-account boundary

Extend EX V2 with device-scoped linked accounts. A device token may see and activate only accounts linked to that device.

Required endpoints:

- `GET /mobile/brokers?query=` returns broker identity and display metadata.
- `GET /mobile/brokers/{brokerId}/servers?query=` returns valid real/demo server names.
- `GET /mobile/accounts` returns linked account summaries and the active marker; it never returns credentials.
- `POST /mobile/accounts/link` accepts broker ID, server ID/name, numeric login, password, save-password preference, and idempotency metadata. It validates the pre-provisioned EX V2 demo trading account and returns the linked account plus an optional opaque reconnect grant.
- `PUT /mobile/accounts/{accountId}/activate` atomically changes the device's active account and returns the new bootstrap snapshot.

The existing bootstrap/account/trading/history/wallet/settings endpoints continue resolving account scope from the device token and the active linked-account ID. `ActiveAccountChanged` invalidates the mobile snapshot after a successful activation.

### Credential handling

- Credentials travel only over HTTPS.
- Flutter never logs or stores the password.
- EX V2 verifies the password against a salted password hash for the pre-provisioned virtual trading account; plaintext passwords are never persisted.
- When `Lưu mật khẩu` is enabled, EX V2 may issue a revocable opaque reconnect grant. Flutter stores that grant in secure storage. When disabled, the grant remains memory-only and a later cold reconnect may require the password again.
- Device tokens, passwords, password hashes, and reconnect grants never appear in analytics, screenshots, exception messages, fixtures, source, or documentation.

## State and data flow

1. The account list loads `GET /mobile/accounts` and the active bootstrap together.
2. Add opens broker discovery regardless of whether an EX V2 account is active.
3. Broker and server selection are represented by stable server IDs; displayed names come from the API.
4. Submit is enabled only when server, numeric login, and non-empty password are valid.
5. One tap creates one idempotent link request. Repeated taps while submitting do not create duplicate links.
6. Successful linking immediately activates the account, refreshes bootstrap, resets account-scoped feature navigation/state, and opens Trade as in the video.
7. Account-list selection calls the activate endpoint, waits for the returned bootstrap, then returns to the previous root screen.
8. Market Watch selection, positions/orders, history, wallet, notifications, settings, and profile data must come from the newly active account. No row from the previous account may remain visible during or after the switch.
9. Restarting the app restores linked-account metadata and the server-authoritative active account.

## Visual behavior

- Match the reference at a normalized 576 x 1280 portrait capture.
- Preserve the existing black/dark MT5 surface, circular toolbar buttons, iOS-style push transitions, bounce scrolling, divider weight, typography hierarchy, blue active values, green switch, and disabled/enabled login-button states.
- Implement the exact visible reference copy, including `Brokers`, `Tài khoản`, `Máy chủ`, `Đăng ký tài khoản mới`, `Tài khoản thật`, `Tài khoản dùng thử`, `Sử dụng tài khoản hiện có`, `Đăng nhập`, `Mật khẩu`, `Lưu mật khẩu`, `Quên mật khẩu`, and `Đăng nhập`.
- Broker and server rows use API data, but their geometry, icons, selection feedback, search field, keyboard configuration, and scroll behavior match the reference.
- The account list places the active account first with a blue name, full-color broker mark, white metadata, selected surface, and chevron. Inactive accounts remain below with muted metadata.
- AssistiveTouch, Dynamic Island, status bars, and keyboard pixels are platform/reference overlays, not app-owned artwork.

## Error and recovery behavior

- Broker/server load failure keeps the screen open with retry and no fixture fallback.
- Invalid login/password shows a concise authentication failure and preserves server/login/save-password fields while clearing only the password.
- Duplicate account linking activates the existing link instead of creating a duplicate.
- Account activation failure retains the previous active account across every tab.
- A refresh or SignalR event during linking cannot publish a mixed snapshot.
- Offline mode may display cached linked-account metadata but disables link and activate mutations until connected.
- Back navigation never changes the active account unless linking or activation has completed successfully.

## Testing

### EX V2

- Broker/server filtering and stable ordering.
- Correct credential, wrong credential, disabled account, server mismatch, and unknown login.
- Idempotent duplicate submission and duplicate existing link.
- Device isolation: one device cannot list or activate another device's account.
- Atomic activation and bootstrap response.
- No secret fields in response models or logs.

### Flutter

- Route sequence and back behavior for every reference screen.
- Exact static copy, key geometry, keyboard type, switch state, button enablement, list scrolling, and transitions.
- One request for repeated submit taps.
- Successful link/activate switches Settings, Trade, History, Wallet, and profile selectors atomically.
- Invalid credentials preserve the form correctly.
- Cold restart restores the linked list and active account.
- Golden/crop comparison at reference checkpoints around 9.5, 12, 16, 20, 24, 28, 32, 56, 64, 72, and 76 seconds.

## Acceptance criteria

- The complete recorded path is reproducible without hard-coded account data.
- The new account is authenticated, linked, persisted, selected, and displayed first.
- All account-owned tabs agree on the active account immediately after switching and after restart.
- No password or reusable secret leaks into logs, source, tests, screenshots, or API responses.
- Mobile analyze/tests/build and EX V2 build/tests pass.
- Portrait device captures match the video after masking only system overlays, keyboard differences, and API-owned values.

## Delivery dependency

The Flutter UI can be implemented in `D:/mt5New`, but the real link/activate behavior requires source and deployment access to `/opt/ex-v2-api-src`. This workspace currently has neither that source nor a configured SSH target. The server portion cannot be implemented or verified by changing the local read-only `backend/` project.

## Out of scope

- Connecting to or trading through real Exness/MetaQuotes broker accounts.
- Hard-coded video credentials, balances, symbols, positions, or history.
- Creating a new real or demo account from the two registration rows; those rows retain reference navigation/feedback until separately specified.
- QR account import beyond the visible action and a safe unsupported-state response.
- Deleting linked accounts.
- Changing the required Flutter, Riverpod, GoRouter, Dio, SignalR, ASP.NET Core, or SQL Server stack.
