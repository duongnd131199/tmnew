# White Theme Video Parity

## Reference

- Source: `giaoDienMau/giaodientrang.MP4`
- Reference canvas: 384 x 848 at 30 fps, duration 79.6 seconds
- Emulator smoke canvas: 590 x 1280 on `emulator-5560`
- Manifest: `reference/screens/theme-light/manifest.json`
- Captures: `.codex_tmp/white_theme_final/`

The comparison covers the static theme shown in the video. Status-clock text,
live prices, timestamps, account values, profit/loss, and candle
contours are dynamic and are excluded from theme parity.

## Semantic palette

| Role | Value |
| --- | --- |
| Page/background | `#FDFDFD` |
| Grouped page background | `#EEEDF5` |
| Card/surface | `#FDFDFD` |
| Elevated surface | `#F5F5F5` |
| Selected surface | `#E4E4E4` |
| Sheet/dialog surface | `#F1F1F1` |
| Sheet action surface | `#EAEAEA` |
| Selected navigation pill | `#E6F2FC` |
| Primary/positive | `#0A6CF1` |
| Negative/destructive | `#D83048` |
| Primary text | `#111111` |
| Secondary text | `#66666B` |
| Tertiary text | `#9A9A9F` |
| Divider | `#D9D9DE` |
| Modal barrier | `#39000000` |

## Video-visible verification

| Scene | Timestamp | Result | Capture |
| --- | ---: | --- | --- |
| Prices | 0.00 s | Theme matched | `prices.png` |
| Symbol action sheet | 8.37 s | Theme matched | `symbol-sheet.png` |
| Chart | 12.57 s | Existing light Chart preserved; shell matched | `chart.png` |
| Trade | 20.93 s | Theme matched | `trade.png` |
| Position action sheet | 25.13 s | Theme matched | `position-sheet.png` |
| Bulk position actions | 29.30 s | Theme matched | `bulk-position-sheet.png` |
| History | 37.70 s | Theme matched | `history.png` |
| Settings | 41.87 s | Grouped background/cards matched | `settings.png` |
| Account list | 46.07 s | Grouped background/rows matched | `accounts.png` |
| Existing-account form | 54.43 s | Theme matched | `existing-account.png` |
| Server picker | 58.63 s | Theme matched | `server-picker.png` |

The Android status and navigation chrome use a light surface with dark system
icons after Flutter startup. The native splash transition can briefly retain
the emulator's platform launch color before the app overlay style is applied.

## History typography supplement

- Reference: `iconMau/photo_2026-08-24_14-45-49.jpg`
- Reference and emulator capture size: 590 x 1280 physical pixels
- History row pitch: 78 physical pixels / 52 logical pixels
- Primary row text: 16 logical pixels
- Secondary price/time text: 14 logical pixels
- Primary-to-secondary vertical offset: 22 logical pixels
- Summary row pitch: 32 physical pixels / 21.333 logical pixels
- Summary text: 15 logical pixels at medium weight
- Verification capture: `docs/screenshots/history-typography-after.png`

These measurements apply consistently to Positions, Orders, and Deals. The
header, navigation, filters, data order, detail actions, and API behavior are
unchanged.

## Wallet history reference supplement

Deposit and withdrawal rows keep the server amount, status, and timestamp, but
present their reference identifiers with the fixed MT5-style shapes measured
from `giaoDienMau/photo_2026-08-18_09-14-45.jpg` and
`giaoDienMau/photo_2026-08-18_09-14-36.jpg`:

- Deposit: `D-ALLINT-USD-INT-` followed by exactly 12 digits.
- Withdrawal: `W-BANKVNGT-USD-` followed by exactly 13 digits.
- A valid numeric suffix supplied by the server is preserved. Legacy or short
  references receive a stable time-derived suffix, so refreshing does not
  change the displayed identifier.
- Within each transaction type, later history rows always receive a greater
  numeric suffix than earlier rows.

## Trade position price color supplement

The `open price → current price` line in every open-position row uses the
primary text role (`#111111`) on the white surface. This applies only to the
two-price range shown for positions; Buy/Sell, profit/loss, pending-order
prices, row geometry, and trading behavior are unchanged.

## Screens without complete reference evidence

These routes inherit the same light baseline and were checked for unexplained
dark neutral literals, but cannot be called reference-perfect until the user
provides a matching video or screenshot:

- Splash, primary credential login, register, and device-gate failure states.
- Symbol search, symbol edit, and market-column selection.
- New Order and standalone position detail.
- History detail.
- Wallet, deposit, and withdrawal.
- Notifications and messages.
- Chart indicator and chart-object management screens.
- Account detail and generic Settings section screens.

For a later reference pass, record each missing screen at 384 x 848, including
its default, selected, disabled, error, and modal states where applicable. Avoid
including real passwords or other secrets in the recording.

## Functional preservation

No provider, controller, repository, API request, route, trading command, market
data flow, Chart viewport calculation, widget geometry, spacing, or gesture was
changed for the theme migration. Regression coverage includes cross-tab state,
Market Watch actions, Chart controls/goldens, Trade actions and commands,
History filters/details, Settings navigation, linked-account activation, login,
server selection, and device-gate behavior.
