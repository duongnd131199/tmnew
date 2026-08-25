# Settings Exact Copy Design

## Goal

Render every static string visible on the Settings tab exactly as it appears in `giaoDienMau/IMG_5526.MP4`, while preserving API-owned account, unread-count, and language values.

## Root cause

The recording uses unaccented Vietnamese menu copy. The app currently normalizes those strings to accented Vietnamese, so the typography and line widths differ even when the layout is otherwise aligned.

## Exact static copy

| Location | Required text |
|---|---|
| Screen title | `Cai dat` |
| New account | `Tai khoan moi` |
| Mail | `Hop thu` |
| Mail subtitle | `You have registered a new acco...` |
| News | `Tin tuc` |
| News subtitle | `Australian Dollar: RBA keeps hik...` |
| Tradays subtitle | `Lich Kinh Te` |
| Messaging | `Trao doi va tin nhan` |
| Messaging subtitle | `Dang nhap vao cong dong MQ...` |
| Trader community | `Cong dong trader` |
| OTP subtitle | `Khoi tao mat khau mot lan` |
| Interface | `Giao dien` |
| Language fallback | `Tieng Viet` |
| Charts | `Nhung bieu do` |
| Journal | `Nhat ky` |
| Settings row | `Cai dat` |
| Bottom Settings tab | `Cai dat` |

`Tradays`, `MQL5 Algo Trading`, and `OTP` already match and remain unchanged.

## Data and behavior constraints

- Account strings continue to come from `activeDemoAccountProvider`.
- An API language/locale value wins over the `Tieng Viet` fallback.
- The unread badge remains sourced from `unreadNotifications` or `unreadCount`.
- Existing routes, card geometry, icons, semantics, and interaction behavior remain unchanged except that semantics reflect the visible exact copy.

## Verification

- Widget tests assert the complete static-copy set and bottom-tab label.
- Existing navigation and geometry tests continue to pass after updating their exact-copy finders.
- Analyzer, full Flutter tests, debug APK build, `adb install -r`, and a fresh LDPlayer screenshot are required.

