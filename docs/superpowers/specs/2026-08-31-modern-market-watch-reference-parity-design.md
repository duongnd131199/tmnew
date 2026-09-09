# Modern Market Watch Reference Parity Design

## Reference and scope

The target is the app-owned Quotes/`Gia` content in
`iconMau/anhmau/photo_2026-08-31_15-59-21.jpg`, rendered on the iPhone 17
Simulator. The operating-system status bar, Dynamic Island, and Live Activity
shown in the reference are outside the app and are not part of this change.

Exact live bid/ask values are also intentionally not copied from the still
image. The app must continue to display current server ticks while matching the
reference's formatting, geometry, typography, colors, and data semantics.

Superseding reference: the six 2026-09-09 `SoVang` images require XAU symbols,
including broker-suffixed forms such as `XAUUSD+`, to use three decimal digits.
Bid/Ask keeps the existing leading and two-pip typography and adds the final
digit as a raised pipette. Lower L/H statistics use all three digits at their
existing style. See `docs/screens/gold-price-reference.md`.

## Current defects

- The toolbar and first quote row sit too high, toolbar controls are too small,
  and the title is visibly smaller and lighter than the reference.
- Rows use a roughly 66.67-point pitch instead of the measured 72-point pitch.
- The bid column is about 17 points too far right while the ask column is
  already aligned.
- Several compressed transforms make metadata and prices shorter and narrower
  than the reference.
- Secondary metadata and the spread glyph are too dark. The negative accent is
  too muted.
- `BTCUSD` is shortened to `BTC`, receives a leading clock, and has BTC-only
  geometry. The new reference uses the same row structure for both symbols.
- XAU precision must be applied consistently to the upper Bid/Ask values, lower
  L/H statistics, spread, and point change rather than being patched per label.
- The UI invents quote time using `DateTime.now() - 4 hours` instead of the
  tick's source timestamp.
- The displayed change, previous close, low, and high are inherited from demo
  constants because the tick endpoint does not return session statistics.

## Data design

Introduce a small, pure Market Watch presentation model that combines a live
`DemoQuote` with sorted D1 candles.

- The quote's `sourceTimestamp`, normalized to UTC, is the displayed tick time.
  A locally received timestamp is only a fallback when the source timestamp is
  absent. No arbitrary timezone subtraction is permitted.
- The preceding D1 candle's close is the previous close.
- The current D1 candle supplies the session low and high. The live bid and ask
  are included when calculating the extrema so a new intraday extreme is shown
  immediately. Live extrema are retained for the same UTC trading date until
  refreshed D1 data catches up, so a high or low cannot move backward.
- Point change is `(bid - previousClose) * 10^digits`, rounded to the nearest
  integer. Percent change is `(bid - previousClose) / previousClose * 100`.
- XAU symbols use three decimal digits. BTC remains at two decimal digits and
  other instruments retain their existing precision policy.
- If the latest D1 candle is older than the quote's UTC trading date, treat it
  as the previous candle and seed the current range from bid/ask. If statistics
  cannot be established, do not manufacture them from the demo percentage.
- Existing explicit previous-close/low/high values remain a safe fallback for
  controlled fixtures and non-realtime sources.
- Catalog symbols whose tick is still zero/invalid render an unavailable `--`
  row; the strict display builder continues to reject invalid market data.

The existing `marketCandlesProvider` and `/api/market/candles` endpoint remain
the source of truth. No backend contract or technology-stack change is needed.

## UI design

- Increase the header extent so the toolbar and list start at the positions
  measured from the reference; increase the quote row pitch to 72 points.
- Move toolbar contents downward, use larger 43.33-point visual discs inside
  accessible hit targets, enlarge the list/edit/search glyphs, and render the
  centered title at approximately 20 points with a bold optical weight.
- Use one geometry path for XAU and BTC. Remove the XAU corner marker and BTC
  delay-clock decoration. Render the full `BTCUSD` label.
- Align left metadata about 2 points farther right. Move only the bid price and
  bid range column about 17 points left; preserve the ask right edge.
- Render XAU with two emphasized full-size decimal digits followed by one
  raised pipette. BTC keeps two decimal digits and no pipette. Other precisions
  preserve the same two terminal emphasized digits before an optional final
  pipette, so five-digit FX quotes do not compress four digits.
- Use a Prices-specific negative accent close to `#E43C2F`, secondary text
  close to `#4D4D50`, and spread ink close to `#ADAFB0`. Do not change Trade or
  History semantic colors.
- Remove compensating `scaleX`/`scaleY` transforms where the new font tokens and
  row geometry can express the reference directly.
- Preserve swipe actions, row taps, navigation, live quote animation, header
  fade behavior, and bottom navigation.

## Acceptance criteria

- Widget tests prove UTC tick time, D1-derived statistics, full symbol labels,
  per-symbol precision, XAU's three-decimal upper/lower values and raised
  pipette, shared row geometry, and absence of obsolete clock/corner
  decorations.
- Focused tests are observed failing before implementation and passing after.
- The iPhone 17 Simulator screenshot aligns with the reference throughout the
  app-owned header and both visible quote rows, allowing only live-number width
  variation and OS-owned status differences.
- Flutter analyze, relevant tests, the full Flutter build checks, backend build
  and tests required by the repository guide, and an iOS Simulator debug build
  are run before completion.
