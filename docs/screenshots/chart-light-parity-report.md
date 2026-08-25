# Chart light parity and performance report

Date: 2026-08-23  
Device profile: LDPlayer, 590 x 1280, 240 dpi

## Device mapping

| Role | LDPlayer | ADB device | Package |
| --- | --- | --- | --- |
| Development profile harness | index 0, `LDPlayer` | `emulator-5554` | `com.tradingdemo.trading_mobile` |
| MT5 reference | index 3, `MT5-Fresh` | `emulator-5560` | `net.metaquotes.metatrader5` |

Both instances were left running on BTCUSD M5. The development instance uses
the deterministic profile benchmark entry point routed through the production
`TradingApp`, `appRouter`, and `AppShell`, including the unchanged five-item
bottom navigation. Installing the benchmark removed the previous secure-storage
session; the production APK therefore requires the operator to sign in again.

## Final device evidence

- Development: [chart-light-dev-final.png](chart-light-dev-final.png)
- MT5 reference: [chart-light-ref-final.png](chart-light-ref-final.png)
- Frozen reference contract: `reference/screens/chart/light/manifest.json`

Live prices, candle timestamps, trade volume, and account overlays are genuine
source-dependent differences. They are not treated as geometry or palette
regressions.

## Static matrix

The test surface is 394 x 854 logical pixels, derived from the 590 x 1280,
240-dpi device. All 27 committed implementation goldens matched their freshly
rendered result with zero changed pixels:

| Timeframe | Min zoom | Default zoom | Max zoom |
| --- | ---: | ---: | ---: |
| M1 | 0.00% | 0.00% | 0.00% |
| M5 | 0.00% | 0.00% | 0.00% |
| M15 | 0.00% | 0.00% | 0.00% |
| M30 | 0.00% | 0.00% | 0.00% |
| H1 | 0.00% | 0.00% | 0.00% |
| H4 | 0.00% | 0.00% | 0.00% |
| D1 | 0.00% | 0.00% | 0.00% |
| W1 | 0.00% | 0.00% | 0.00% |
| MN | 0.00% | 0.00% | 0.00% |

These percentages are implementation-regression diffs against the committed
goldens, not fabricated MT5-source diffs. The manifest intentionally contains
only one captured native reference state (`M5/default`); the other native
pinch states remain image-free fixtures, so a truthful native pixel percentage
cannot be calculated for those 26 states.

## Profile benchmark

Command:

```powershell
D:\toolchains\flutter\bin\flutter.bat drive `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/chart_performance_test.dart `
  -d emulator-5554 --profile --no-dds --keep-app-running --timeout=360
```

The measured 10-second sequence included four zoom-in/out cycles, double-tap
reset, one continuous pan, and
`M1 -> M5 -> M15 -> M30 -> H1 -> H4 -> D1 -> W1 -> MN -> M5`.

| Metric | Result | Gate |
| --- | ---: | ---: |
| Frames | 359 | > 30 |
| Build p50 | 0.201 ms | — |
| Build p95 | 3.693 ms | <= 16.7 ms |
| Build p99 | 5.438 ms | — |
| Raster p50 | 3.269 ms | — |
| Raster p95 | 5.737 ms | <= 16.7 ms |
| Raster p99 | 10.562 ms | — |
| Missed frames | 1 / 359 | < 2% |
| Missed-frame ratio | 0.279% | < 2% |

The renderer now batches dashed segments into stroke paths and reuses a bounded
32-entry picture cache for static background/grid configurations. All dynamic
candles, prices, positions, pending orders, crosshair, and chart objects remain
outside that cache.

Before frame collection, the device test also requires all five bottom-tab
labels, verifies Chart is selected, switches to Prices, and returns to Chart.

## Verification evidence

Focused Chart gate:

```powershell
D:\toolchains\flutter\bin\flutter.bat test test/chart_reference_manifest_test.dart test/chart_light_theme_test.dart test/chart_viewport_test.dart test/chart_timeframe_transition_test.dart test/chart_repaint_performance_test.dart test/chart_light_parity_golden_test.dart test/chart_controls_test.dart test/live_market_candles_test.dart test/market_data_service_test.dart test/realtime_market_service_test.dart test/market_chart_route_test.dart test/chart_market_order_dispatch_regression_test.dart
```

Result: 148/148 passed. This includes rapid timeframe replacement, last-valid
frame retention, realtime active-candle updates, repaint isolation, pan/zoom,
double-tap reset, order overlays, and subscription retirement/replacement.

Project gates:

| Command | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 448/448 passed |
| `flutter build apk --debug` | Succeeded |
| `flutter build apk --profile` | Succeeded |
| `dotnet build Trading.sln` | Succeeded, 0 warnings, 0 errors |
| `dotnet test Trading.sln --no-build` | 17/17 passed |

The final source verification is rerun after this report and the static-picture
cache change; the handoff summary records that freshest result.

## APK outputs

- Debug: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
  - 224,827,118 bytes
  - SHA-256 `E517AFA478FC517724E20415036F9912DD5FA6D8893701578F65012C19C5ECC0`
- Profile: `mobile/build/app/outputs/flutter-apk/app-profile.apk`
  - 82,136,177 bytes
  - SHA-256 `BB134453CF401761FF8C44B8370242148B315B82A7A39155D1A6433B18BD04D2`

## Remaining limitations

- Native MT5 has only the canonical M5/default screenshot in the frozen
  evidence set. Automated native pinch capture for the remaining 26 states was
  deliberately not invented.
- Real MT5 and the deterministic benchmark do not share market/account data, so
  price text, OHLC, timestamps, candle contour, and position values differ.
- The Android emulator logs an optional `androidx.window.sidecar` class lookup
  warning; it does not crash the app or affect the passing frame-timing run.
- No commit was created because the shared checkout already contains extensive
  uncommitted work that must not be bundled without owner review.
