# Account Tab Video Parity Design

## Goal

Match every app-owned screen and interaction observable in `giaoDienMau/IMG_5526.MP4` for the Settings account flow while retaining the production EX V2 active-account scope.

## Scope

- Settings account card.
- Active-account list.
- Active-account detail screen and vertical scrolling.
- Navigation and iOS-style push/pop transitions.
- Deposit and withdrawal navigation.
- Immediate trade-notification toggle backed by `PUT /settings` when EX V2 state is available.
- Return to the Settings root after leaving and re-entering the tab.

The iOS screenshot/share overlay is operating-system UI and is excluded. Values visible in the reference video are not copied into production business state.

## Constraints

- Flutter, Riverpod, GoRouter, Dio, and the existing EX V2 integration remain unchanged.
- The app never sends or chooses an `accountId`; the device token resolves the active account on the server.
- Only the account selected in web administration is shown in production mode.
- API data wins over local fixtures. Missing optional profile fields use neutral unavailable presentation, never invented financial data.
- Product colors, spacing, typography, and radii use existing semantic tokens.
- No proprietary logo asset is copied from the reference video; the existing local broker mark is retained.

## Components

### Settings root

`SettingsScreen` keeps its three-card structure. The account card opens the account list. Text uses correct Vietnamese copy and live account fields already present in the provider.

### Account list

`ProfileScreen` remains the account-list route. Production mode shows exactly the active server-mapped account. Selecting it pushes the detail route instead of popping back to Settings. The add icon remains visible for visual parity but does not change server account scope.

### Account detail

`AccountDetailScreen` owns the reference layout: toolbar, broker hero, company row, deposit/withdraw actions, profile rows, notification switch, device/password/delete rows, and bounce scrolling. It consumes `activeDemoAccountProvider` only as a compatibility view over EX V2 state; financial values stay server-derived.

### Settings mutation

The trade-notification switch changes immediately. In EX V2 mode it calls `ExV2AccountController.updateSettings({'tradeNotificationsEnabled': value})`, which already implements optimistic update and rollback. Offline/demo mode keeps the state locally for the current process.

## Navigation

- `/settings` -> `/profile` -> `/account-detail`.
- Back from detail returns to profile.
- Back from profile returns to Settings.
- Deposit and withdrawal actions use `/deposit` and `/withdraw`.
- The account detail route uses the existing iOS slide transition.

## Error handling

- A failed settings mutation silently returns the switch to confirmed server state; no server-wait toast is introduced.
- Missing optional contact metadata renders an em dash.
- No destructive delete-account command is sent because account lifecycle remains web-admin controlled.

## Verification

- Widget tests cover account-list selection, detail rendering, scrolling, toggle behavior, and deposit/withdraw routes.
- Existing Settings and cross-tab regression tests remain green.
- `flutter analyze`, full `flutter test`, and `flutter build apk --debug` must pass.
- Final LDPlayer screenshots are compared against the video at the Settings root, account list, account detail top, and account detail bottom.
