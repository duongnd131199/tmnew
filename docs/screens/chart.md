# Chart

## Reference

- Video: `giaoDienMau/giao diện chuẩn 2.MP4`
- Canonical segment: approximately `02:12–04:14`
- Source-video encoded viewport: `576 × 1280`
- Canonical validation device: LDPlayer at `590 × 1280`, `240 dpi`
- System status chrome and AssistiveTouch shown in the recording are not app
  widgets and are excluded from parity checks.

## Layout

- Top safe area followed by an 80 logical-pixel chart toolbar.
- Normal toolbar: timeframe, crosshair, indicators, objects, one-click
  trading, and chart windows.
- Expanded toolbar: favorite timeframes `M1 M5 M15 M30 H1 H4 D1 W1 MN`
  and the full timeframe dialog.
- Plot uses the MT5 light-chart appearance: a white canvas, a light dashed
  grid, a black right price axis, and a black bottom time axis.
- Floating capsule bottom navigation remains above the chart.
- One-click trading inserts the `SELL / volume / Buy` strip above the plot.
- Pending-order editing replaces the bottom navigation with the order editor.

## Components

- Candlestick renderer with live current-candle updates.
- Symbol, timeframe, and instrument-name header inside the plot. OHLC appears
  only while the crosshair is active, matching the compact native default.
- Current-price dotted line and a single-line price badge.
- Position and pending-order levels.
- Crosshair and two-pointer measurement.
- Indicator and chart-object routes.
- Chart-window selector.
- Numeric volume keypad.

## States

- Loading: BTCUSD H1 holds the reference loading view before live candles.
- Success: candles, quote, current price, and position P/L update
  from the same quote stream.
- Empty: fallback history keeps the chart usable when no candle history exists.
- Error/reconnecting: market-history failures fall back to the local demo
  series while live quote state continues to update.

## Interactions

- Tap timeframe to expand favorites; tap `…` for all timeframes.
- Tap crosshair to enter or leave cursor mode.
- Tap indicator, object, and window icons to open their respective controls.
- Tap the red/blue circular icon to toggle one-click trading.
- Pinch to zoom and drag the plot to pan horizontally. Drag the right price
  axis to scale vertically; double tap the plot or price axis to reset its
  corresponding viewport.
- Long press the plot to create a pending level.
- Drag a pending level, edit SL/TP, expand or collapse its editor, or confirm it.
- Tap one-click volume to open the numeric keypad.

## Assumptions

- The reference video demonstrates Japanese candlesticks only; it does not
  demonstrate switching to line, bar, or Heikin-Ashi rendering.
- Exact market ticks vary at runtime. Geometry, contour seed, axis density,
  colors, and synchronized tick behavior are the parity targets.

## Light-chart parity contract (2026-08-23)

- Scope is limited to Chart-tab content: toolbar, optional one-click strip,
  plot, candles, axes, labels, price/position lines, timeframe changes, zoom,
  and pan. Shared bottom navigation and the other tabs are not redesigned.
- Canonical device is LDPlayer at `590 × 1280`, `240 dpi`; responsive support
  remains required for `360–430` Flutter logical-pixel widths.
- The live MT5 reference target palette is canvas `#FFFFFF`, grid `#E8E8E8`,
  bullish candle `#26A69A`, bearish candle `#EF5350`, trading/position blue
  `#3183FF`, and primary text/axes `#000000`.
- The supported matrix is `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`, `W1`,
  and `MN`, each at minimum, default, and maximum zoom.
- Changing timeframe must retire the old realtime subscription, retain the last
  valid frame until new history is ready, atomically replace the candle series,
  align the newest bar to the right, and never flash an empty or dark chart.
- Pinch zoom must keep the candle under the focal point stable. Dragging must
  pan with bounded inertia, and double tap must restore the reference default
  viewport.
- Pixel comparison excludes changing prices, timestamps, candle-data contour,
  Android status/navigation chrome, and shared bottom navigation. Static Chart
  UI must stay within `1 px` geometry tolerance and `1.5%` differing pixels in
  the chart-region comparison mask.

## Capture baseline (2026-08-23)

- `reference/screens/chart/light/manifest.json` reserves all 54 source,
  timeframe, and zoom combinations at `590 × 1280`, `240 dpi`.
- `ref-M5-default.png` and `dev-before-M5-default.png` are the only verified
  ADB screenshots. They are the real BTCUSD/M5 default viewport with the
  one-click strip visible on the reference and development emulators.
- The other 52 rows are `fixture-pending-native-pinch`, have no
  `screenshotPath`, and must not be treated as image evidence. Native pinch
  automation was not relied on because it cannot safely produce repeatable,
  truthful reference screenshots.
- Re-capture an observed row with `scripts/capture-chart-parity.ps1`. It
  requires `-OperatorStateConfirmation` in the form
  `timeframe=<value>;zoom=<value>;symbol=<value>;oneClickPanel=<visible|hidden>`.
  The confirmation must match the requested timeframe and zoom. Zoom is
  operator-confirmed because the script cannot verify native pinch state.
- The script uses `adb shell screencap -p` followed by `adb pull` and records
  device metrics in the manifest. A recaptured fixture becomes `captured`, gains
  an image path and operator confirmation, and loses its `fixtureNote`.
- The six target colors are separate from `observedColors`. `dev-before` is a
  dark pre-parity capture and has no inferred light-palette observation.
- No Task 1 commit is required. The shared checkout is dirty and mostly
  untracked, so an isolated baseline commit is unsafe.

## Native geometry and price-axis calibration (2026-08-23)

- Measurements use the live official MT5 and development LDPlayers at
  `590 × 1280`, `240 dpi` with BTCUSD/M5 selected. The final ADB aliases were
  `emulator-5558` (`MT5-Real`) and `emulator-5560` (`MT5-App-Code`).
- The plot/right-axis boundary is physical `x = 476`; the price axis is `114`
  physical pixels wide. The responsive logical contract uses a canonical
  `76`-pixel price axis and preserves the earlier 576-pixel capture width.
- Default candle-center and grid cadence is `42` physical pixels (`28`
  logical pixels). Candle bodies occupy `64%` of a slot (`≈27` physical
  pixels), with `12` physical pixels of newest-candle right padding.
- The internal chart header is `64/3` logical pixels high and the bottom time
  axis is `22` logical pixels high. Price labels share the exact y-coordinate
  of their horizontal grid row; time labels use compact alternating date/time
  text to avoid collisions.
- Right-axis scaling is multiplicative and anchored under the pointer. A
  controlled upward drag from physical y `760` to `440` reduced the visible
  price range to `80.1%` in the development app versus `80.7%` in official
  MT5. Upward drags zoom in, downward drags zoom out, and horizontal candle
  position is unchanged.
- Price-axis drag owns its gesture exclusively, so it cannot pan candles or
  create/move pending orders. Timeframe changes return vertical scaling to
  automatic mode; price-axis double tap provides the same explicit reset.
- The automatic viewport starts from a nice price step. During a manual drag,
  row prices scale continuously with the viewport instead of snapping to a new
  nice step; official MT5 produced the same non-round increments (for example
  `21.00` becoming approximately `16.95`) during the controlled drag.
- Market prices, order levels, and candle contours remain live-data
  exclusions. Geometry and gesture response are the stable parity contract.
- Final device evidence includes static M5, 160-pixel up/down axis drags, and a
  320-pixel up drag for both apps. Both emulators were returned to BTCUSD/M5.
  The retained host captures are
  `C:\Users\Admin\AppData\Local\Temp\official_final_m5.png`,
  `C:\Users\Admin\AppData\Local\Temp\dev_final_m5.png`,
  `C:\Users\Admin\AppData\Local\Temp\emulator-5558_axis_up160.png`,
  `C:\Users\Admin\AppData\Local\Temp\emulator-5558_axis_down160.png`,
  `C:\Users\Admin\AppData\Local\Temp\emulator-5560_axis_up160.png`, and
  `C:\Users\Admin\AppData\Local\Temp\emulator-5560_axis_down160.png`.
- Completion verification ran the focused Chart suite, full `flutter test`,
  `flutter analyze`, `flutter build apk --debug`, `dotnet build Trading.sln`,
  and `dotnet test Trading.sln --no-build` from the appropriate project roots.
