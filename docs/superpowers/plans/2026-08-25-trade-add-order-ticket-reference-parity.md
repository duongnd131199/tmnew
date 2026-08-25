# Trade Add Order Ticket Reference Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the order ticket opened by the Trade-tab `+` button match `iconMau/photo_2026-08-25_08-08-23.jpg` at the canonical 590 x 1280 LDPlayer viewport while retaining live symbol and quote data.

**Architecture:** Keep the existing `/order` route and `NewOrderScreen` trading behavior, but tag the Trade `+` navigation with `source=trade-add`. The route converts that tag into an entry-specific full-screen presentation flag; only that presentation removes the drawer inset and bottom navigation and applies the reference geometry, controls, typography, and semantic colors. Market, Chart, pending-order, and position-close entry paths retain their current presentation and behavior.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, GoRouter, Flutter widget tests, Android/LDPlayer.

**Spec:** User-approved in-chat design; visual source `iconMau/photo_2026-08-25_08-08-23.jpg`; shared light-theme constraints `docs/screens/white-theme.md`.

## Global Constraints

- Required technology remains Flutter, Dart, Riverpod, and GoRouter.
- Reference viewport is 590 x 1280 physical pixels at 1.5 DPR; Android system status-bar chrome remains platform-owned.
- Dynamic symbol, name, Bid, Ask, and order submission state may differ from the reference image.
- The Trade `+` entry uses default volume `1.00` and controls `-5`, `-1`, `+1`, and `+5`.
- The app-owned ticket must be full width, must hide `MtBottomNavigationBar`, and must return to Trade through Back.
- Other `/order` entry points and all order/repository/API semantics remain unchanged.
- Existing owner changes in the dirty worktree must not be reset, reformatted wholesale, or included in unrelated edits.
- No source commit is created unless the user explicitly requests one.

---

### Task 1: Lock Trade `+` entry semantics and reference geometry

**Files:**
- Create: `mobile/test/trade_add_order_ticket_reference_test.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/app/router.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`

**Interfaces:**
- Consumes: existing `/order?symbol=<symbol>` route and `NewOrderScreen(symbol: ...)` constructor.
- Produces: `/order?symbol=<symbol>&source=trade-add` and `NewOrderScreen.tradeAddReferenceLayout` with a default value of `false`.

- [ ] **Step 1: Write the failing route and shell tests**

Add tests that pump `TradeScreen` behind a small `GoRouter`, tap `Key('trade-add-button')`, and assert that the destination receives `source=trade-add`. Pump `NewOrderScreen(symbol: 'XAUUSD+', tradeAddReferenceLayout: true)` at 590 x 1280 / 1.5 DPR and assert:

```dart
expect(find.byKey(const Key('trade-add-order-ticket')), findsOneWidget);
expect(tester.getTopLeft(find.byKey(const Key('trade-add-order-ticket'))).dx, 0);
expect(
  tester.getSize(find.byKey(const Key('trade-add-order-ticket'))).width,
  closeTo(590 / 1.5, 0.01),
);
expect(find.byType(MtBottomNavigationBar), findsNothing);
expect(find.text('1.00'), findsOneWidget);
expect(find.text('-5'), findsOneWidget);
expect(find.text('-1'), findsOneWidget);
expect(find.text('+1'), findsOneWidget);
expect(find.text('+5'), findsOneWidget);
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test\trade_add_order_ticket_reference_test.dart
```

Expected: FAIL because `source=trade-add`, `tradeAddReferenceLayout`, and `trade-add-order-ticket` do not exist and the current screen is inset with a bottom navigation bar.

- [ ] **Step 3: Implement the entry-specific route contract**

Change the Trade header callback to push:

```dart
'/order?symbol=${Uri.encodeQueryComponent(defaultSymbol)}&source=trade-add'
```

Map the query parameter in `router.dart`:

```dart
tradeAddReferenceLayout:
    state.uri.queryParameters['source'] == 'trade-add',
```

Add the constructor flag with `false` as the compatibility default. In `initState`, set `volume = 1` only for a Trade-add ticket without `closePositionId`.

- [ ] **Step 4: Implement the full-width reference shell**

For `tradeAddReferenceLayout == true`, render `orderContent` inside a full-width `Scaffold`/`SafeArea` keyed `trade-add-order-ticket`, use the order-ticket surface token, and omit `MtBottomNavigationBar`. Keep the current inset, rounded shell, and bottom navigation for every other entry path.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the Task 1 command. Expected: PASS with the route tag, full-width shell, no bottom navigation, and reference volume controls present.

---

### Task 2: Match reference ticket styling without changing data flow

**Files:**
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Modify: `mobile/test/trade_add_order_ticket_reference_test.dart`

**Interfaces:**
- Consumes: `NewOrderScreen.tradeAddReferenceLayout` from Task 1 and live `DemoQuote` values.
- Produces: semantic `AppColors.orderTicketSurface`, `orderTicketControlSurface`, `orderTicketQuote`, `orderTicketSell`, and `orderTicketBuy` roles; keyed reference regions for geometry/color assertions.

- [ ] **Step 1: Extend the focused test with failing visual-role assertions**

Assert that the reference ticket contains full-width keyed regions for header, order type, quote strip, market buttons, and notice; assert that Bid and Ask text use `AppColors.orderTicketQuote`; assert the Sell and Buy `Material` fills use `AppColors.orderTicketSell` and `AppColors.orderTicketBuy`; and assert body labels use the non-condensed system font while the symbol and prices retain tabular/condensed treatment.

- [ ] **Step 2: Run the focused test and verify RED**

Run the Task 1 command. Expected: FAIL because the semantic ticket colors, keys, and reference typography are absent.

- [ ] **Step 3: Add semantic reference tokens**

Add only the sampled roles needed by this ticket:

```dart
static const orderTicketSurface = Color(0xFFF1F1F1);
static const orderTicketControlSurface = Color(0xFFFFFFFF);
static const orderTicketQuote = Color(0xFF007FFF);
static const orderTicketSell = Color(0xFFDD5E4F);
static const orderTicketBuy = Color(0xFF4A92F4);
```

- [ ] **Step 4: Apply the reference geometry and typography conditionally**

In reference mode:

- move the 40 logical-pixel Back circle to the full-width reference position instead of relying on the old 34-pixel drawer inset;
- center the symbol over the 590-pixel viewport;
- keep rows edge-to-edge with white control rows and the sampled `#F1F1F1` header/quote/notice surface;
- use volume deltas 5 and 1 with labels matching the reference;
- render both live prices in the sampled blue role;
- render the 40-logical-pixel market strip with sampled Sell/Buy fills and reference-sized white labels;
- keep all taps, sheets, SL/TP changes, fill-policy selection, submission guards, and live providers unchanged.

- [ ] **Step 5: Run focused behavior and parity tests**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat test test\trade_add_order_ticket_reference_test.dart test\video_interactions_test.dart
```

Expected: PASS. Existing Market/Chart order tests continue to see the compatibility presentation because their constructor flag remains false.

---

### Task 3: Repository verification and LDPlayer comparison

**Files:**
- Verify: `mobile/`
- Verify: `backend/`
- Produce: `.codex_tmp/trade-add-order-reference-final.png`

**Interfaces:**
- Consumes: final debug APK and the running `MT5-App-Code` LDPlayer (`emulator-5560`).
- Produces: analyzer/test/build results and a fresh 590 x 1280 screenshot proving the Trade `+` route opens the reference ticket.

- [ ] **Step 1: Format only touched Dart files**

Run `dart format` against the exact changed Dart files; do not format unrelated dirty files.

- [ ] **Step 2: Run Flutter analysis and tests**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat analyze
D:\toolchains\flutter\bin\flutter.bat test
```

Expected: analyzer exit 0. Record any pre-existing full-suite failures separately; the focused order-ticket tests must pass.

- [ ] **Step 3: Build the Flutter APK and backend**

Run:

```powershell
cd mobile
D:\toolchains\flutter\bin\flutter.bat build apk --debug
cd ..\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Expected: both builds exit 0 and backend tests pass.

- [ ] **Step 4: Install without clearing app data and open the Trade `+` ticket**

Run:

```powershell
D:\LDPlayer\LDPlayer9\adb.exe -s emulator-5560 install -r D:\mt5New\mobile\build\app\outputs\flutter-apk\app-debug.apk
```

Launch `com.tradingdemo.trading_mobile`, open Trade, tap the `+` control, and verify the full-width ticket is foreground with no bottom navigation or visible Trade underlay.

- [ ] **Step 5: Capture and compare the final frame**

Capture `.codex_tmp/trade-add-order-reference-final.png` from LDPlayer. Compare it with `iconMau/photo_2026-08-25_08-08-23.jpg` at 590 x 1280, excluding the platform-owned status bar and dynamic symbol/name/Bid/Ask values. Check left/right bounds, row boundaries, Back-circle position, typography, quote strip, button strip, warning block, and empty lower surface.

- [ ] **Step 6: Report exact verification status**

Report changed files, focused tests, full-suite pass/fail counts, analyzer/build/backend results, APK path, screenshot path, and any residual platform-rendering difference. Do not claim 100% parity for Android system status-bar glyphs.
