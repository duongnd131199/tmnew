# Video White Theme Parity Design

**Date:** 2026-08-24

**Reference:** `giaoDienMau/giaodientrang.MP4`

**Reference properties:** 79.6 seconds, 384 x 848 pixels, 30 fps

## Goal

Convert the current Flutter application from its dark presentation to the
white presentation demonstrated in the supplied video while preserving all
existing behavior, navigation, data flow, layout geometry, copy, controls,
gestures, and trading semantics.

"100%" in this task means theme parity for screens and states visibly
demonstrated by the reference video. Screens absent from the video receive the
shared light-theme baseline, but they are reported as unverified rather than
claimed as reference-perfect.

## Approved Scope

The following reference-visible areas are calibrated in this task:

- Prices/Market Watch, including the symbol action sheet.
- Chart, including the one-click strip and bottom navigation integration.
- Trade, account summary, open positions, the position action sheet, and the
  bulk-position action sheet.
- History list, tab/filter chrome, totals, and navigation state.
- Settings, grouped cards, account header, rows, icons, and bottom navigation.
- Linked-account list, account selection state, add-account form, and server
  picker.
- Shared app shell, Android status/navigation bars, overlays, dialogs, sheets,
  dividers, selected states, and disabled states that appear in those flows.

The following existing routes have no complete visual evidence in the video:

- Splash, primary credential login, register, and device-gate failures.
- Symbol search, symbol edit, and market-column selection.
- New Order and standalone position detail.
- History detail.
- Wallet, deposit, and withdrawal.
- Notifications and messages.
- Chart indicator and chart-object management screens.
- Account detail and generic Settings section screens.

They inherit the shared light tokens so the app does not retain a black shell,
but only obvious dark-theme leakage is corrected. Their reference parity is
deferred until the user supplies additional video or screenshots. The final
report must enumerate this exact unverified set and any newly discovered route.

## Non-Goals

- No controller, provider, repository, API client, backend, authentication,
  realtime, account, order, position, history, or wallet behavior changes.
- No route additions, removals, redirects, or navigation changes.
- No changes to text, localization, numbers, market values, symbols, account
  identity, or test fixtures merely to resemble the video.
- No changes to size, spacing, alignment, safe-area behavior, typography,
  widget hierarchy, icon geometry, animation timing, scrolling, or gestures.
- No runtime theme switch and no retained user-facing dark-mode option.
- No replacement of Flutter, Riverpod, GoRouter, Dio, SignalR, secure storage,
  or the native CustomPainter chart.
- No unrelated refactor and no reset/revert of owner changes already present in
  the dirty checkout.

## Reference Evidence

The video is sampled at scene boundaries and interaction states, not only at
uniform intervals. Each accepted screenshot must record its video timestamp
and corresponding application route/state. Dynamic prices, timestamps,
floating P/L, candle contours, and account data are excluded from pixel parity.

Observed scene groups are:

| Approximate time | Reference state |
| --- | --- |
| 00.0-08.4 s | Prices and symbol action sheet |
| 12.6-16.8 s | Chart with one-click trading strip |
| 20.9-33.5 s | Trade, position sheet, and bulk-position sheet |
| 37.7 s | History |
| 41.9 s | Settings |
| 46.1-50.3 s and 62.8 s | Account list |
| 54.4 s | Existing-account form |
| 58.6 s | Server picker |
| 67.0-75.4 s | History and Chart return states |
| 79.6 s | Prices return state |

JPEG/video compression means sampled pixels are evidence, not blindly copied
constants. Dominant observed surfaces are near `#FDFDFD`, grouped-page chrome
near `#EEEDF5`, form rows near `#F5F5F5`, and sheets near `#ECECEC`. Dominant
accents are near blue `#0868F0`, bearish red `#D83048`, and bullish teal in the
`#28A888`-`#40A890` range. Final constants are selected through masked visual
comparison against decoded source frames and documented with their roles.

## Theme Architecture

### Semantic token migration

`AppColors` remains the single semantic palette used by ordinary screens. Its
dark surface/text/divider roles are replaced with light roles, and missing
roles are added only when the video distinguishes them, such as grouped page
background, sheet surface, disabled fill, dim barrier, selected navigation
pill, and dark glyph on light surface.

The migration must not use screen-specific literals for general surfaces.
Existing brand colors and financial semantics remain separate from neutral
theme colors. Positive/buy/up and negative/sell/down retain their meaning; they
are calibrated only where the video supplies evidence.

`AppTheme.light` becomes the production Material theme. It defines
`Brightness.light`, scaffold, Material color scheme, text, app bar, cards,
inputs, dividers, navigation bar, sheets, dialogs, switches, disabled states,
selection, splash, and highlight behavior. Nested `MaterialApp` instances in
the device gate use the same light theme.

The Android status bar and navigation bar use light surfaces with dark system
icons. Route transitions and safe areas remain unchanged.

### Hard-coded color remediation

The current code contains dark literals outside `AppColors`, especially in the
app shell, Market Watch, Trade, New Order, Settings, Messages, shared icon
painters, and secondary screens. Implementation performs a repository audit
and classifies every literal as one of:

1. neutral theme color, which must become a semantic token;
2. financial/brand color, which stays semantically named and is calibrated
   only with reference evidence;
3. transparent/compositing color, which remains local when it is genuinely
   drawing-specific;
4. unverified-screen styling, which receives the light baseline but is listed
   in the final reference-gap report.

No production video-covered screen may retain an unexplained black or near-
black background, surface, divider, text field, sheet, toolbar, or navigation
container.

### Chart isolation

The Chart already owns a reference light palette and recently completed
geometry/price-axis work. Its candle painter, viewport mathematics, hit
targets, gestures, data pipeline, and geometry are frozen for this task.

Only shell integration and theme-fed overlays may change. Existing Chart
goldens and interaction tests must prove that candle geometry, axis geometry,
zoom, pan, vertical scaling, crosshair, pending-order gestures, and one-click
order behavior are unchanged.

## Screen Migration Order

1. Establish reference manifest, decoded frames, masks, semantic palette, and
   theme contract tests.
2. Convert the root theme, system chrome, app shell, bottom navigation, and
   shared sheet/dialog primitives.
3. Calibrate Prices and its action sheet.
4. Verify Chart shell integration without altering Chart geometry.
5. Calibrate Trade and both position action-sheet states.
6. Calibrate History.
7. Calibrate Settings.
8. Calibrate account list, add-account form, and server picker.
9. Apply and audit the light baseline on unverified routes without claiming
   reference parity.
10. Run cross-tab interaction regression, full repository verification, and
    produce the reference-gap report.

This order keeps each checkpoint independently reviewable and prevents a
global palette change from hiding screen-specific dark literals.

## Verification Strategy

### Automated contracts

- Palette tests lock every semantic neutral and accent role.
- Theme tests lock `Brightness.light`, Material component themes, and system
  overlay intent.
- Source-policy tests reject unexplained dark neutral literals in production
  files covered by this task.
- Existing widget tests continue to validate callbacks, navigation, account
  switching, order actions, realtime updates, and loading/error/empty states.
- Focused light-theme widget/golden tests cover each visible scene group.
- Chart regression tests prove render geometry and interactions are unchanged.
- Responsive tests cover 360, 384, 393, and 430 logical-pixel widths without
  overflow.

### Visual comparison

- Canonical reference captures are decoded from the 384 x 848 source video.
- Development captures use an emulator viewport that produces an equivalent
  384 x 848 comparison canvas, with additional 590 x 1280 smoke evidence for
  the existing LDPlayer workflow.
- Each comparison aligns the same route, scroll position, selected tab,
  expanded/collapsed state, and overlay state.
- Masks exclude status-clock content, live prices, timestamps, account values,
  candle contours, P/L, and other time-dependent pixels.
- Theme-sensitive static regions target exact geometry preservation and no
  unexplained dark-theme pixels. Color differences are iterated from decoded
  evidence; the report records any residual caused by video compression,
  platform font rasterization, or unavailable source state.

### Required commands

After every independently reviewable task, run focused Flutter tests. At final
completion run fresh commands from the appropriate roots:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
D:\toolchains\flutter\bin\flutter.bat build apk --debug

cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

The final APK is installed on the development LDPlayer, all five bottom tabs
are exercised, reference-visible overlays are opened, and screenshots are
captured after the last code change.

## Failure Handling and Safety

- A theme change that causes a widget, golden, or interaction regression is
  fixed at the semantic styling boundary; business behavior is not rewritten
  to make the test pass.
- Dynamic server failures remain represented by existing loading/error states.
  Their colors inherit the light theme without altering retry behavior.
- Existing owner changes are preserved. Scoped status/diff checks are required
  before each commit; no reset, checkout, stash, or broad formatting pass is
  allowed.
- The task must not log or introduce account credentials, device tokens, API
  secrets, or financial payloads.

## Deliverables

- A centralized production light theme and semantic palette.
- Video-covered screens and overlays calibrated to the supplied white sample.
- Focused palette/theme/source-policy/widget/golden regression tests.
- A debug APK built after final verification.
- Emulator screenshots and a concise comparison report.
- A reference-gap report listing every screen or state not present in the
  supplied video so the user can provide additional evidence later.

## Completion Criteria

The work is complete only when:

- the production app launches in the white theme with light system chrome;
- every reference-visible scene has a matched application capture;
- no reference-covered scene retains unintended dark-theme surfaces;
- layout, functionality, gestures, data, routes, and trading behavior remain
  unchanged;
- missing-reference screens are explicitly reported rather than silently
  claimed as exact;
- focused tests, full Flutter tests, analyzer, APK build, backend build, and
  backend tests all pass from the final tree;
- the final emulator smoke covers Prices, Chart, Trade, History, Settings,
  account list, add-account form, server picker, and the demonstrated sheets.
