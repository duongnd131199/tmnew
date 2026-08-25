# Tab Typography and Spacing Parity Design

**Date:** 2026-08-25

**References:**

- `iconMau/anhmau/photo_2026-08-25_22-30-10.jpg` — Prices.
- `iconMau/anhmau/photo_2026-08-25_22-30-17.jpg` — Chart.
- `iconMau/anhmau/photo_2026-08-25_22-30-20.jpg` — Trade.
- `iconMau/anhmau/photo_2026-08-25_22-30-23.jpg` — History positions.
- `iconMau/anhmau/photo_2026-08-25_22-30-26.jpg` — History orders.
- `iconMau/anhmau/photo_2026-08-25_22-30-29.jpg` — History orders summary.
- `iconMau/anhmau/photo_2026-08-25_22-30-34.jpg` — History deals.

**Canonical reference:** 590 x 1280 physical pixels, interpreted as a
393.333 x 853.333 logical-pixel Flutter viewport at device pixel ratio 1.5.

## Goal

Match the text size, weight, family, color, letter spacing, line height, text
baseline, and text-to-text spacing of every application state visibly covered
by the seven supplied screenshots. Preserve the current white theme, trading
behavior, data flow, navigation, gestures, and chart interaction.

"100%" in this task means that static text and its surrounding geometry in a
fresh application capture match the corresponding reference after both images
are aligned to the canonical 590 x 1280 canvas. Dynamic prices, timestamps,
profit values, candle contours, Android status content, and JPEG compression
noise may differ in value or raster detail, but their font roles, bounds,
alignment, and colors must match.

## Approved Scope

The task calibrates these reference-visible areas:

- Prices header, quote daily change, symbol, tick time, spread, bid, ask,
  low, and high labels.
- Chart toolbar timeframe label, one-click Buy/Sell strip, lot control, plot
  title/subtitle, position annotations, price-axis labels, time-axis labels,
  and chart overflow label.
- Trade header profit, account metrics, open-position section header, position
  symbol/side/volume, open-to-current price range, and floating profit.
- History shared header, segmented labels, positions, orders, deals, dates,
  statuses, profit values, and summary rows.
- Shared five-item bottom navigation labels and text placement in the selected
  and unselected states used by Prices, Chart, Trade, and History.

Settings is not calibrated because none of the seven screenshots shows its
content. Its bottom-navigation item participates in the shared navigation
contract, but its screen body is unchanged. Routes and overlays absent from
the supplied screenshots are also unchanged except where they consume a
corrected shared typography token; they are reported as unverified rather
than reference-perfect.

## Non-Goals

- No provider, repository, REST, SignalR, authentication, account, order,
  position, history, or wallet behavior changes.
- No fixture or live-value changes made only to resemble a screenshot.
- No route, navigation, gesture, animation, scroll, or business-copy changes.
- No chart candle, viewport, price-scale, or interaction redesign.
- No technology-stack replacement or new runtime font-downloading dependency.
- No modification, reset, stash, or broad formatting of the owner's existing
  account-sync and iOS work.
- No parity claim for Settings content or any route not visible in the seven
  references.

## Reference Measurement Contract

All measurements use the original JPEG files without rescaling. A reference
manifest records, for each screenshot, the route/state, selected bottom tab,
scroll position, expected static labels, and masks for dynamic regions.

Text geometry is measured from glyph bounding boxes and repeated baselines,
not from container guesses. Each role records:

- font family and asset;
- font weight;
- logical font size;
- letter spacing;
- line-height multiplier;
- foreground semantic color;
- horizontal and vertical alignment;
- baseline or top offset relative to its row;
- gap to the next text role.

JPEG colors are sampled only from the interior of repeated thick glyphs.
Edge pixels and isolated compression artifacts are excluded. When several
samples differ by one or two RGB values, the most frequent interior cluster
is used. Financial colors remain semantic: buy/positive blue, sell/negative
red, primary ink, secondary ink, tertiary ink, and chart-specific teal/red.

## Typography Architecture

Production typography becomes deterministic rather than relying on a device's
interpretation of generic Android family aliases.

- `Roboto` is used for ordinary toolbar, navigation, summary, and non-condensed
  reference roles.
- `Roboto Condensed` is used for dense quote, trade, history, and chart roles.
- Regular 400, medium 500, and bold 700 weights are declared as local Flutter
  font assets in `mobile/pubspec.yaml`; no font is downloaded at runtime.
- Tabular figures are enabled only for changing prices, balances, timestamps,
  profit values, and axis labels.
- `AppTypography` owns reusable semantic styles. Feature-specific style files
  may define roles unique to a dense screen, but production widgets do not
  repeat anonymous font-family/size/spacing combinations.

The semantic roles are:

- `toolbarTitle` and `toolbarControl`;
- `navigationLabel` and `navigationLabelSelected`;
- `quoteChange`, `quoteSymbol`, `quoteMeta`, and `quotePrice`;
- `chartToolbar`, `chartTicketLabel`, `chartTicketPrice`, `chartAnnotation`,
  `chartAxis`, and `chartTimeAxis`;
- `tradeHeaderProfit`, `tradeMetric`, `tradeSection`, `tradePositionPrimary`,
  `tradePositionSecondary`, and `tradePositionProfit`;
- `historySegment`, `historyPrimary`, `historySecondary`, and
  `historySummary`.

Each role includes its final color, font metrics, and letter spacing. Widgets
may override only semantic financial color or dynamic weight explicitly
required by the reference.

## Geometry Architecture

Typography and geometry are calibrated together because changing font metrics
without row baselines creates apparent spacing errors.

- Shared canonical metrics live beside the typography tokens and describe
  bottom-navigation label position and toolbar text alignment.
- Prices owns quote-row height and the three text baselines on the left plus
  price/meta baselines on the right.
- Trade owns account-metric row height, section-header height, position-row
  height, and its two baselines.
- History owns header/segment geometry, list top inset, row height, primary and
  secondary baselines, summary-row height, and list bottom inset.
- Chart retains its existing plot boundaries. Only text styles and text anchor
  offsets change unless a failing reference test proves that the anchor itself
  is wrong.

The canonical values are expressed in logical pixels. Width-sensitive
alignment is derived from available width so the app remains usable at 360,
384, 393.333, and 430 logical pixels. No whole-screen scaling transform is
introduced.

## Screen Contracts

### Prices

The title remains centered independently of the left and right controls. Each
quote row exposes three left baselines and two right columns. Symbol, bid, and
ask are the dominant roles; daily change and low/high metadata are subordinate.
Text transforms currently used to compensate for mismatched fonts are removed
when the deterministic font produces the measured bounds. A transform remains
only when a reference measurement demonstrates a genuine non-font scale.

### Chart

The Chart keeps the current toolbar, one-click strip, canvas, viewport, order
annotations, and axes. Painter text receives the same deterministic font roles
as widget text. Changes are limited to font metrics, foreground colors, and
anchor offsets proven by the screenshot. Candle OHLC, grid cadence, zoom,
pan, price scaling, and live-data propagation remain unchanged.

### Trade

Account metrics align label/value baselines and keep values right-aligned with
tabular figures. The section header uses its measured bold role. Position rows
have one primary and one secondary baseline, while profit is independently
right-aligned. The row does not use FittedBox or arbitrary scaling under the
canonical width unless a genuinely long dynamic value would overflow.

### History

All three history modes share one header and one pair of list typography
roles. Positions and orders keep two-line rows. Deals keep their two-line
description/date structure. Summary labels and values use the same family,
size, height, and baseline. The two order screenshots validate both a long
scroll state and the summary-at-bottom state rather than defining separate
styles.

### Bottom Navigation

All five items share one label family, size, weight, letter spacing, and
baseline. Selection changes foreground color and pill/icon state but does not
move or resize the label. The four reference-selected states receive golden
coverage; Settings remains covered by the shared geometry contract.

## Testing and Calibration Strategy

Implementation follows red-green-refactor per independently reviewable unit.

1. Add a font/theme contract test that fails while production still uses only
   generic platform aliases and anonymous feature styles.
2. Add a reference-manifest test that locks the seven files, their dimensions,
   route/state mapping, and canonical viewport.
3. Add failing widget geometry/style tests for shared navigation and each
   reference-visible screen before changing production code.
4. Implement deterministic fonts and semantic roles, then make focused tests
   pass one screen group at a time.
5. Add 590 x 1280 candidate goldens for Prices, Chart, Trade, History
   positions, History orders list, History orders summary, and History deals.
6. Compare candidates with the supplied references using masks only for
   dynamic values/status content. Adjust one typography or geometry variable
   per iteration and rerun the focused golden.
7. Verify responsive widths 360, 384, 393.333, and 430 logical pixels without
   overflow or clipped labels.
8. Install the final debug APK on an available emulator, navigate through the
   four covered tabs plus the shared Settings navigation item, and capture
   fresh screenshots after the final source change.

Existing full-suite failures are not silently accepted. The current baseline
has 32 Flutter test failures, including chart/navigation goldens and two data
assertions, while `flutter analyze` and the debug APK build pass. Before
implementation, focused tests distinguish owner-work baseline failures from
new parity regressions. Final reporting lists any remaining pre-existing
failure by test name and does not claim a clean suite unless a fresh full run
is green.

## Required Verification

After every independently reviewable task, run its focused Flutter tests. At
the end run fresh commands:

```text
cd mobile
flutter analyze
flutter test
flutter build apk --debug

cd ../backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

The backend remains unchanged, but repository instructions require its build
and tests. If SDK 8.0.421 is still unavailable, report that environment block
exactly; do not edit `global.json` or change the required SDK.

## Failure Handling and Safety

- If a typography change breaks a behavior test, fix the visual boundary and
  preserve the behavior rather than rewriting the test around the regression.
- If a font asset changes glyph widths, recalibrate measured row anchors; do
  not compensate with a whole-screen transform.
- If an emulator is unavailable, complete automated golden verification and
  report device capture as blocked instead of claiming manual parity.
- No secrets, access tokens, passwords, broker credentials, or financial
  payloads are logged or added.
- Scoped status and diff checks precede every task commit. Only parity files
  are staged; unrelated owner changes remain untouched.

## Deliverables

- Deterministic local Roboto and Roboto Condensed font declarations.
- Central semantic typography and geometry roles.
- Calibrated Prices, Chart, Trade, History, and shared navigation text.
- Reference manifest, focused style/geometry tests, and seven candidate
  reference goldens.
- Final debug APK, emulator screenshots when a device is available, and a
  comparison report listing masks and any remaining evidence gap.

## Completion Criteria

The work is complete only when:

- all static text roles in the seven covered states use the measured family,
  size, weight, color, letter spacing, line height, and alignment;
- all covered text baselines and text-to-text gaps match the aligned reference;
- selection does not shift bottom-navigation labels;
- no covered widget relies on an unexplained font-scale transform;
- dynamic text remains readable without overflow at all supported widths;
- trading behavior, chart interaction, navigation, and data flow are unchanged;
- focused parity tests and candidate goldens pass after the final source edit;
- analyze, full Flutter tests, debug APK build, backend build, and backend tests
  have fresh results accurately reported;
- Settings and other missing-reference screens are explicitly marked
  unverified rather than claimed as exact.
