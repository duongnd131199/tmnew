# Modern Market Watch Reference Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development or superpowers:executing-plans and
> follow strict RED/GREEN TDD for implementation.

**Goal:** Make the live Quotes screen match the 2026-08-31 modern reference
while replacing fabricated session metadata with values derived from live
ticks and D1 candles.

**Architecture:** Keep realtime quote ownership unchanged. Add a pure Market
Watch display-model builder at the feature boundary, feed it D1 history through
the existing Riverpod candle provider, then render a single shared row layout
with reference-calibrated theme tokens.

**Tech Stack:** Flutter, Dart, Riverpod, existing ASP.NET Core API.

**Spec:**
`docs/superpowers/specs/2026-08-31-modern-market-watch-reference-parity-design.md`

## Global constraints

- Preserve all unrelated dirty-worktree changes and the required stack.
- Do not hard-code bid/ask or statistics from the screenshot.
- Do not change global Trade/History colors to calibrate the Quotes screen.
- Use `apply_patch` for source edits.
- Reload the same iPhone 17 Simulator app and compare after material UI steps.

---

### Task 1: Lock the real quote display semantics

**Files:**
- Create: `mobile/lib/features/market_watch/domain/market_quote_display.dart`
- Create: `mobile/test/market_quote_display_test.dart`
- Reference: `mobile/lib/shared/models/demo_models.dart`
- Reference: `mobile/lib/shared/models/market_candle.dart`

- [x] Add literal D1 fixtures and failing unit tests for current-day and stale
  D1 series, hand-derived point/percent changes, live extrema, UTC time, XAU
  two-decimal precision, BTC two-decimal precision, and explicit-stat fallback.
- [x] Run the focused test and verify RED because the domain builder does not
  exist yet.
- [x] Implement the smallest immutable display model and pure builder needed by
  the tests.
- [x] Run the focused test and verify GREEN.

### Task 2: Lock modern row content and geometry

**Files:**
- Modify: `mobile/test/market_watch_parity_test.dart`
- Modify: `mobile/test/test_support/video_reference_fixtures.dart`
- Modify: `mobile/test/tab_typography_tokens_test.dart`

- [x] Give fixtures literal source timestamps and D1 candles through provider
  overrides; do not mock the display model itself.
- [x] Replace legacy expectations with behavior assertions for `BTCUSD`, no BTC
  clock, no XAU corner, UTC time, shared 72-point row pitch, symbol-aware price
  runs, toolbar positions/sizes, bid/ask alignment, and modern semantic colors.
- [x] Run the focused widget/token tests and verify RED against current code.

### Task 3: Connect D1 statistics to each live quote row

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Use: `mobile/lib/features/chart/data/market_data_provider.dart`

- [x] Watch the existing `marketCandlesProvider` with a D1 request for each
  visible quote and build the pure display model from current quote + history.
- [x] Preserve the last valid/live display during asynchronous refresh and use
  explicit values only as the safe fallback defined by the spec.
- [x] Replace local fake time and `_QuoteMeta` calculations with display-model
  values.
- [x] Run unit and widget tests to GREEN.

### Task 4: Implement the modern reference visuals

**Files:**
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/core/theme/app_typography.dart`
- Modify: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`

- [x] Add Prices-specific secondary, spread, and negative colors.
- [x] Calibrate header height, 72-point row pitch, toolbar/title positions,
  visual discs, and glyph sizes from the measured reference.
- [x] Unify symbol row geometry, render `BTCUSD`, remove obsolete decorations,
  move the bid column left, and preserve the ask edge.
- [x] Render XAU and BTC with two decimal digits in the emphasized run, while
  retaining an optional pipette only for higher-precision instruments such as FX.
- [x] Remove old BTC-only and compression transforms, then run focused tests.

### Task 5: Device comparison and measured refinement

**Files:**
- Update only the four production files above plus scoped tests as needed.
- Capture: `artifacts/qa/market-watch-modern-parity-*.png`

- [x] Format changed Dart files and run focused Market Watch tests.
- [x] Build iOS Simulator debug, install, terminate/relaunch on iPhone 17, open
  the Quotes tab, and capture a screenshot.
- [x] Create an app/reference comparison at the same 1206-pixel scale; refine
  measured offsets, sizes, colors, and typography until no material app-owned
  mismatch remains.
- [x] Repeat focused tests after each refinement.

### Task 6: Full verification and review

- [x] Run `flutter analyze` and the full relevant/full Flutter test suites,
  distinguishing any pre-existing baseline failures with controlled evidence.
- [x] Run `flutter build ios --simulator --debug`.
- [x] Run repository-required backend `dotnet build` and `dotnet test`; report
  an SDK/environment blocker exactly if one persists.
- [x] Request independent spec and code-quality reviews; fix all valid findings.
- [x] Inspect the scoped diff to confirm no unrelated user changes were lost.
- [x] Perform one final install/relaunch/screenshot check on iPhone 17.

Verification note: the scoped 60-test suite passes and `flutter analyze` is
clean. The repository-wide legacy suite was also run and exposed existing
golden/reference-baseline failures before hanging in its tooling tests; those
unrelated baselines were not rewritten. Backend verification remains blocked
because `global.json` requires .NET SDK 8.0.421 while this machine only has
10.0.203 installed.
