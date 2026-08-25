# EX V2 mobile integration

## Production configuration

- REST: `https://trochoi.top/ex/v2/api`
- Realtime: `https://trochoi.top/ex/v2/hubs/trading`
- Market data: `https://trochoi.top/api/market/*`
- Authentication: one opaque device token for the signed-in app session, stored in Flutter Secure Storage
- Account scope: resolved by the server from the active account associated with that device token

The production overrides are registered in `mobile/lib/app/bootstrap.dart`. Initial device activation still uses the one-time activation gate, and `POST /mobile/auth/login` establishes or replaces the global device token. The explicit existing-account form sends broker, server, login, and password to `/mobile/accounts/link` under that authenticated session, then activates the returned account with the existing global token. The link password stays in memory only for that request; neither it nor the returned reconnect grant is retained.

`GET /mobile/accounts` is the only source of truth for the switchable account catalog. The app may retain presentation-only metadata such as company and server labels for the active account, but it never restores account rows from a local session registry or cached catalog. Legacy per-account session and reconnect-grant values from older installs are ignored.

Never put a production device token in source, assets, tests, documentation, build arguments, or logs. Rotate a token from the web admin if it is disclosed.

## Server-owned data

| App area | Server source |
|---|---|
| Active account and account metrics | `GET /mobile/bootstrap` |
| Open orders and positions | Bootstrap, `GET /orders`, `GET /positions` |
| Order, deal, position and transaction history | `/history/*` |
| Wallet, deposit, withdrawal and transfer history | Bootstrap, `/wallet/transactions`, `/deposits`, `/withdrawals`, `/transfers` |
| Performance | Bootstrap/account snapshot |
| Notifications | `/notifications` |
| Settings | `/settings` |
| Quotes and candles | `/api/market/*` |

Bootstrap is rendered first. Slower history/configuration requests hydrate the same state in the background, so the account balance is not blocked by ancillary endpoints.

## Mutations

Order, position, wallet, notification, and settings writes are sent to EX V2. Every mutation includes a stable `Idempotency-Key` and `X-Correlation-Id`. A retry of the same user action must reuse both the key and body.

After a successful mutation, or after SignalR sends an invalidation/account-change event, the app reloads the server snapshot. Server state always wins over cached display state. Live quote updates may alter displayed price and floating profit but never mutate the authoritative server balance.

## Realtime and account changes

To switch accounts, the app sends the server account ID to `PUT /mobile/accounts/{accountId}/activate` using the current global device token. A successful response contains the complete bootstrap for the new active account; the app publishes it atomically, refreshes the server catalog, and keeps using the same global token. The switch never opens the existing-account login form and never asks for the trading password again.

HTTP 404 means the selected server row is stale, so the app refreshes `GET /mobile/accounts` and stays on the current account. HTTP 401 or 403 invalidates the global authenticated state; it does not create a per-account reauthentication flow. Network, server, malformed-response, and rejected-publication failures leave the current bootstrap visible.

The app connects to the trading hub with the current account token and invokes `Subscribe`. After an accepted account switch, the previous realtime subscription is disposed and restarted so it reads the new token. `AccountSnapshotInvalidated` and `ActiveAccountChanged` continue to refresh the active bootstrap.

## Legacy UI adapters

The existing `Demo*` model/provider names remain as compatibility adapters so the visual layout and widget tree do not need to be rewritten. With `exV2EnabledProvider == true`, their account, trading, and history values come from EX V2. Static mock records remain available only when production overrides are disabled, which is used by widget tests and local UI development.

Do not add new production financial values to the legacy constants. New server fields should be added to the EX V2 domain model, mapped into `ExV2AccountViewState`, and then exposed through the existing UI adapter.

## Verification

From `mobile/`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

From `backend/`:

```powershell
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

On a configured device, sign in once, open **Settings -> Accounts**, and verify that the rows exactly match `GET /mobile/accounts`. Switch A -> B -> A without entering a password and confirm positions, orders, wallet, history, and settings follow the selected account. Remove an account on the server and confirm its stale row disappears after refresh instead of opening a password form.
