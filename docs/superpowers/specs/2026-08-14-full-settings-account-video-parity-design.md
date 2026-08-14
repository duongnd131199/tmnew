# Full Settings Account Video Parity Design

## Goal

Make the complete Settings account flow match `giaoDienMau/IMG_5526.MP4`
as closely as Flutter/Android permits while keeping live account identity and
financial values authoritative from EX V2.

The covered flow is:

1. Settings root account card.
2. Account list.
3. Active-account detail, including its full vertical scroll range.
4. Navigation from Settings to the list and detail, plus deposit, withdrawal,
   back navigation, and the trade-notification switch.

## Reference Contract

- Source video: `giaoDienMau/IMG_5526.MP4`.
- Native recording size: 576 x 1280 pixels.
- Recording duration: approximately 26.97 seconds.
- Account-list reference: approximately 0.0-1.4 seconds.
- Account-detail reference: approximately 2.8-9.9 seconds and 22.7-26.5
  seconds.
- Settings-root reference: approximately 12.8-14.2 seconds and 21.3 seconds.
- iOS status bar, Dynamic Island, AssistiveTouch, screenshot editor, and share
  sheet are operating-system overlays and are not application UI.

Visual parity covers application-owned text, icon silhouettes, geometry,
typography, colors, dividers, badges, switches, scrolling, and transitions.
The Android status/navigation bars may remain platform-native.

## Root Cause

`demoAccountsProvider` currently adapts an EX V2 account into
`DemoAccountProfile` with semantically incorrect assignments:

- `account.status` is displayed as the broker company.
- `trochoi.top` is displayed as the MT5 server.
- `EX V2` is displayed as the connected access point.

Consequently, the same incorrect values appear in the Settings card, account
list, account-detail hero, Company row, Server row, and Connected row. The
screens also own separate broker-logo implementations, allowing their icon
geometry to drift apart.

## Data Ownership

### EX V2 remains authoritative

The following values continue to come from the authenticated EX V2 account
and view state:

- Account ID and account code.
- Account display name.
- Currency.
- Balance and other financial values.
- Account status for business logic only.
- Owner name, email, phone, and notification settings when supplied.

These values must not be replaced with the sample account code, balance,
email, or other personal data visible in the recording.

### Broker presentation metadata

Introduce one immutable presentation metadata model for the account UI with
these fields:

- `companyName`
- `tradingServer`
- `accessPoint`
- `brand`
- `accountMode`
- `isMaster`

Resolve metadata in this priority order:

1. Canonical EX V2 fields, if the backend contract is extended to provide
   them.
2. Existing server settings keys with non-empty values.
3. The configured Exness reference fallback for this product:
   `Exness Technologies Ltd`, `Exness-MT5Real20`, `Access Point #9`, Exness,
   `Hedge`, and master enabled.

`status`, API origin, and integration version are never accepted as broker
company/server/access-point fallbacks. This prevents the current mapping bug
from returning.

The mapper produces one `DemoAccountProfile` compatibility view consumed by
all three existing screens. It does not introduce a second source for balance,
account code, currency, or other financial state.

## Shared Account Visuals

Extract the broker mark and small account navigation glyphs into focused
shared widgets used by the Settings flow:

- Exness broker mark: yellow square with the reference wordmark treatment.
- Vantage fallback mark: existing code-native mark for offline fixtures.
- Circular back button.
- Circular add button.
- Reference right chevron.

The implementation may recreate simple geometry and text in code but must not
add an unlicensed proprietary bitmap. Sizes, stroke widths, colors, and
alignment are measured against normalized 576 x 1280 reference frames.

## Screen Design

### Settings root

The active-account header renders, in order:

1. Live account name.
2. `Exness Technologies Ltd` from presentation metadata.
3. `{liveAccountCode} - Exness-MT5Real20`.
4. `Access Point #9`.

The header keeps a single right chevron and a divider before `Tai khoan moi`.
All three cards are tuned against the reference for horizontal inset, radius,
vertical gap, row height, icon frame, divider inset, text baseline, subtitle
color, notification badge, and connected indicator. Existing routes and
API-owned unread/language values remain unchanged.

Every visible Settings row in the reference remains present:

- `Tai khoan moi`
- `Hop thu`
- `Tin tuc`
- `Tradays`
- `Trao doi va tin nhan`
- `Cong dong trader`
- `MQL5 Algo Trading`
- `OTP`
- `Giao dien`
- `Nhung bieu do`
- `Nhat ky`
- `Cai dat`

### Account list

The account list retains its toolbar, back button, title, add button, and
account rows. The active production account is rendered with the Exness mark,
blue selected name, live account code, canonical trading server, live balance,
currency, mode, and right chevron.

Production mode continues to show only the account authorized by the device
token. The two Vantage accounts visible in the reference are not fabricated.
Offline demo mode may continue to show its existing fixture accounts, but each
row must use the same shared broker/logo/chevron primitives and reference
geometry.

Tapping the active account pushes `/account-detail`. Back returns to Settings.
The add button preserves its existing authorized behavior: it opens register
only in offline/demo mode and is inert when the server owns account scope.

### Account detail

The detail screen follows the reference grouping and order:

1. Circular back button.
2. Broker hero with Exness mark, live name, live account code plus canonical
   trading server, live balance/currency, `Master`, and account-mode badges.
3. Company row.
4. Deposit and withdrawal action rows.
5. Name, email, phone, login, server, and connected rows.
6. Trade-notification switch with info glyph.
7. Connect another device, change password, and delete-account rows.

The Company, Server, and Connected values consume the same presentation
metadata as the Settings card. Missing owner/contact fields render an em dash;
they are never copied from the video. Long values remain single-line,
right-aligned, and ellipsized like the reference.

Deposit and withdrawal continue to push `/deposit` and `/withdraw`. The trade
notification switch updates immediately and persists through the existing
`PUT /settings` flow. A failed mutation rolls back to the confirmed server
value. Device connection, password change, and delete remain non-destructive
until corresponding authorized backend flows exist.

## Navigation and State

- `/settings` pushes `/profile` from the account header.
- `/profile` pushes `/account-detail` for the active account.
- Back from detail returns to the account list.
- Back from the list returns to Settings.
- Leaving and re-entering the Settings bottom tab returns to its root screen.
- Existing iOS-style push/pop transitions remain in place.
- Loading or refreshing EX V2 state must not briefly replace canonical broker
  metadata with `active`, `trochoi.top`, or `EX V2`.

## Error and Empty Handling

- If EX V2 is unavailable, existing offline fixtures continue to render.
- Empty optional contact values render an em dash.
- Unknown broker metadata falls back to a neutral broker presentation; it must
  not be mislabeled as Exness unless the product configuration identifies it
  as Exness.
- A failed notification-setting update restores the last confirmed value.
- No account deletion or account-switch request is introduced by this work.

## Testing and Acceptance

### Mapper tests

- Verify live account code, name, currency, and balance remain server-owned.
- Verify `status` cannot become `companyName`.
- Verify API origin cannot become `tradingServer`.
- Verify integration version cannot become `accessPoint`.
- Verify canonical server/settings metadata wins over the Exness fallback.
- Verify the configured Exness fallback produces the reference metadata.

### Widget and navigation tests

- Settings header renders the live account name/code and canonical metadata.
- Settings rows retain exact copy, icon sizes, badge behavior, and routes.
- Account list renders the shared Exness mark, selected state, server, balance,
  mode, and active-account navigation.
- Account detail renders every reference group and uses consistent metadata.
- Detail scrolling exposes the bottom security rows.
- Deposit/withdraw routes and notification optimistic update/rollback work.
- Back navigation and Settings-root reset remain correct.

### Visual acceptance

Capture LDPlayer screenshots at the Settings root, account list, account-detail
top, account-detail middle, and account-detail bottom. Normalize the reference
and implementation screenshots to the same application viewport. Mask only
API-owned personal/financial text and platform-owned system overlays. Compare
all remaining application pixels and iterate on measurable differences in
position, size, color, and shape.

The work is accepted when:

- `active`, `trochoi.top`, and `EX V2` no longer appear in broker metadata
  positions.
- The three screens agree on company, trading server, access point, brand, and
  account mode.
- All focused and full validation commands pass.
- No unapproved technology or dependency is added.
- Emulator screenshots match the application-owned reference UI within the
  limits of Android platform text rasterization.

## Required Validation

Run after implementation:

```powershell
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug

cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Review `git diff` before completion and attach the five final emulator
screenshots to the change report.
