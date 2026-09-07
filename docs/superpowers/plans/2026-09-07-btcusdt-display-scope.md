# BTCUSDT Display Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display `BTCUSDT` throughout the app except in Price, while all internal trading contracts continue using `BTCUSD`.

**Architecture:** Centralize non-Price symbol presentation in `displayTradingSymbol` and add a dedicated `displayMarketWatchSymbol` for the Price exception. Presentation widgets consume the appropriate helper; order headers add the approved BTC description without mutating domain data.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, flutter_test

**Spec:** `docs/superpowers/specs/2026-09-07-btcusdt-display-scope-design.md`

## Global Constraints

- Keep `BTCUSD` in models, provider keys, routes, subscriptions, precision logic, and API payloads.
- Keep visible `BTCUSD` in Price, symbol search, and symbol editing.
- Display `BTCUSDT` on every other user-facing surface.
- Do not change the required Flutter/Riverpod/GoRouter stack.

---

### Task 1: Central display mappings

**Files:**
- Modify: `mobile/lib/core/utils/trading_symbol_display.dart`
- Create: `mobile/test/trading_symbol_display_test.dart`

**Interfaces:**
- Produces: `displayTradingSymbol(String) -> String`, `displayTradingSymbolText(String) -> String`, and `displayMarketWatchSymbol(String) -> String`.

- [ ] **Step 1: Write the failing mapping test**

```dart
expect(displayTradingSymbol('BTCUSD'), 'BTCUSDT');
expect(displayTradingSymbolText('BTCUSD buy'), 'BTCUSDT buy');
expect(displayMarketWatchSymbol('BTCUSD'), 'BTCUSD');
```

- [ ] **Step 2: Run the test and verify it fails because the new mapping and Price helper are missing**

Run: `flutter test test/trading_symbol_display_test.dart`

- [ ] **Step 3: Implement exact-token trading mapping and the Price-specific mapping**

```dart
String displayTradingSymbol(String symbol) => switch (symbol) {
  'XAUUSD+' => 'XAUUSD',
  'BTCUSD' => 'BTCUSDT',
  _ => symbol,
};

String displayMarketWatchSymbol(String symbol) =>
    symbol == 'XAUUSD+' ? 'XAUUSD' : symbol;
```

- [ ] **Step 4: Run the mapping test and verify it passes**

Run: `flutter test test/trading_symbol_display_test.dart`

### Task 2: Preserve the Price exception

**Files:**
- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Modify: `mobile/lib/features/market_watch/presentation/screens/symbol_search_screen.dart`
- Modify: `mobile/lib/features/market_watch/presentation/screens/symbol_edit_screen.dart`
- Test: `mobile/test/market_watch_parity_test.dart`

**Interfaces:**
- Consumes: `displayMarketWatchSymbol(String)` from Task 1.
- Produces: Price-family screens that continue showing `BTCUSD`.

- [ ] **Step 1: Keep the existing Price assertion `BTCUSD` and add coverage for the Price helper**

```dart
expect(displayMarketWatchSymbol('BTCUSD'), 'BTCUSD');
expect(find.text('BTCUSD'), findsOneWidget);
```

- [ ] **Step 2: Run `flutter test test/market_watch_parity_test.dart` and observe failure after the central mapping changes**
- [ ] **Step 3: Replace Price-family calls to `displayTradingSymbol` with `displayMarketWatchSymbol`**

```dart
Text(displayMarketWatchSymbol(quote.symbol));
```

- [ ] **Step 4: Run `flutter test test/market_watch_parity_test.dart` and verify it passes**

### Task 3: Synchronize non-Price surfaces and BTC headers

**Files:**
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Test: `mobile/test/trade_add_order_ticket_reference_test.dart`
- Test: `mobile/test/position_detail_functionality_test.dart`
- Test: `mobile/test/trade_position_bulk_actions_dialog_test.dart`
- Test: `mobile/test/order_failure_silent_feedback_test.dart`
- Test: `mobile/test/chart_controls_test.dart`

**Interfaces:**
- Consumes: `displayTradingSymbol(String)` from Task 1.
- Produces: `BTCUSDT` on order, trade, chart, history, and dialog surfaces; order headers also show `Bitcoin vs US Dollar Tether`.

- [ ] **Step 1: Update or add UI expectations for `BTCUSDT` and the full BTC subtitle**

```dart
expect(find.text('BTCUSDT'), findsOneWidget);
expect(find.text('Bitcoin vs US Dollar Tether'), findsOneWidget);
```

- [ ] **Step 2: Run focused UI tests and verify failures are limited to old `BTCUSD`/`Bitcoin` presentation**
- [ ] **Step 3: Use the centralized mapping and add the BTC order-header description mapping**

```dart
String orderHeaderDescription(String symbol, String fallback) =>
    symbol == 'BTCUSD' ? 'Bitcoin vs US Dollar Tether' : fallback;
```

- [ ] **Step 4: Run the focused UI tests and verify they pass**

### Task 4: Regression and visual verification

**Files:**
- Verify all files changed in Tasks 1-3.

**Interfaces:**
- Consumes: completed presentation mappings and UI tests.
- Produces: verified iOS Simulator build and visual evidence.

- [ ] **Step 1: Run `flutter analyze`**
- [ ] **Step 2: Run all relevant market, chart, trade, order, history, and interaction tests**
- [ ] **Step 3: Run `flutter build ios --simulator --debug`**
- [ ] **Step 4: Open Price and confirm `BTCUSD`, then open a non-Price BTC screen and confirm `BTCUSDT`**
- [ ] **Step 5: Run `git diff --check`**
