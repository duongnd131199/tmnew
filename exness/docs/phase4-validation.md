# Phase 4 validation — 2026-09-20

The Profile tab now follows the order shown at 30–36 seconds: benefits banner,
account, benefits, deposit wallet, electronic wallet, referral, and support.
The header becomes compact when scrolled. “Hiển thị thêm” expands the benefits
area. The settings sheet follows the Options, Security, and Security actions
layout shown at 37–40 seconds.

The EX V2 demo wallet supplies the Profile balance and a detail sheet with
total, available, locked, and transaction history. The Account bell reads
notifications and supports marking one or all as read. Settings reads the
server language and saves `tradeNotificationsEnabled`, then reloads the
confirmed value. Logout clears the secure device token and account state.
Loading, empty, and retryable error states are present for the data sheets.
Settings are tagged with the active account ID, so a newly selected account
cannot briefly display the previous account's email or preferences. Bootstrap,
refresh, and account activation responses with HTTP 401/403 clear the rejected
token and authenticated snapshot; server failures retain the snapshot for retry.

Only server-backed values appear as financial or account facts. The current
contract has no distinct electronic wallet, loyalty tier, referral totals,
support feed, PIN policy, or biometric unlock. Those rows display an
unavailable state or a disabled control. The iPhone Face ID switch in the
reference cannot operate in LDPlayer.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: 51 tests passed, including wallet parsing, notification read
  actions, settings save and reread, account switching, 401/403 token cleanup,
  logout, sheet geometry, and narrow layouts.
- `flutter build apk --debug`: succeeded.
- `dotnet build Trading.sln`: succeeded with no warnings or errors.
- `dotnet test Trading.sln --no-build`: 17 tests passed.

The final APK was installed as `com.tradingdemo.exness` on LDPlayer. The raw
captures at 576 × 1272 physical pixels with density 240 correspond to a
384 × 848 logical-pixel viewport, matching the source video dimensions:

- [Profile](screenshots/phase4-profile-384-ldplayer.png)
- [Profile after scrolling](screenshots/phase4-profile-scrolled-384-ldplayer.png)
- [Settings](screenshots/phase4-settings-384-ldplayer.png)

The settings sheet begins near logical y=55, covers the bottom navigation, and
keeps its close control at the left. The scrolled Profile view shows the same
section order as the 31-second reference frame. The larger 440 logical-pixel
LDPlayer viewport was also captured for [Profile](screenshots/phase4-profile-ldplayer.png)
and [Settings](screenshots/phase4-settings-ldplayer.png).

No authorized logged-in demo account was available for an emulator check of
nonempty wallet, notifications, or saved preferences. Those paths were checked
with repository and widget fixtures; their live server values remain to be
verified with an authorized account. The signed-out captures show explicit
missing-data states instead of copied video balances or account details.
