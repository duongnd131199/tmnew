# Chart Order and Live Account Sync Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make chart/new-order actions report the real EX V2 result, show the resulting order or position on Trade, and update floating profit/equity from live quotes without changing the existing UI layout.

**Architecture:** EX V2 remains the authoritative order/account store. Production UI commands become awaited async operations owned by `ExV2AccountController`; the compatibility `Demo*` providers remain read-only adapters. A successful command refreshes bootstrap before the UI reports success. Live quotes may derive display-only current price, floating profit, equity, and free margin, while balance changes only when the server commits a closing deal.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, Flutter Secure Storage, SignalR, ASP.NET Core EX V2, SQL Server.

## Global Constraints

- Do not change the existing chart, order sheet, Trade screen geometry, colors, spacing, or navigation.
- Do not send `accountId`, `executedPrice`, `profit`, balance, or status from Flutter.
- Do not optimistically create a financial order/position in local state.
- Every mutation must use one stable `Idempotency-Key` and `X-Correlation-Id` per user submit.
- Never swallow API failures or show success before server confirmation.
- Production device/account scope remains resolved solely from `X-Device-Token`.
- Do not place diagnostic writes against production. Exercise order mutations in automated server tests or an explicitly approved demo account.
- Do not clean drive D.

## Root-cause evidence

- `DemoTradingController._submitServer` catches and discards every exception.
- `placeOrder`/`placePendingOrder` return an idempotency UUID immediately, not the server order ID.
- `ChartScreen._placeChartOrder` immediately displays “đã khớp” without awaiting REST.
- Production `updateMarketPrice` updates `ExV2AccountViewState.positions`, but `demoAccountProvider` still exposes the unchanged bootstrap `summary.profit/equity/freeMargin`.
- Read-only production probes at 2026-08-13 13:50 UTC show account `109740422` has zero positions, zero pending orders, zero deals, balance/equity `6102678.33`; therefore the reported chart action did not result in a committed server position.
- Market feed and `XAUUSD+` quote are healthy, so the failure is not caused by a stale quote feed.

---

### Task 1: Make production trading commands observable and awaited

**Files:**
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Test: `mobile/test/ex_v2_trading_command_test.dart`

**Interfaces:**
- Produces: `Future<ExV2Order> ExV2AccountController.createOrder(...)`
- Produces: `Future<void> ExV2AccountController.cancelOrder(...)`
- Produces: `Future<void> ExV2AccountController.closePosition(...)`
- Consumes: existing `ExV2Repository` and `ExV2CommandMetadata`.

- [ ] **Step 1: Write a failing controller test**

Create a fake repository/client response where `POST /orders` returns a filled order and the next bootstrap contains its position. Assert the returned value uses the server order ID and controller state is refreshed before the future completes.

```dart
final order = await container.read(exV2AccountProvider.notifier).createOrder(
  symbol: 'XAUUSD+',
  side: 'buy',
  volume: 0.01,
);
expect(order.id, 'server-order-1');
expect(container.read(exV2AccountProvider).value!.positions.single.id,
    'server-position-1');
```

- [ ] **Step 2: Write a failing rejection test**

Return HTTP 422 with `{ "code": "ORDER_REJECTED", "message": "..." }`. Assert the future throws `ExV2RequestFailure`, state is not mutated, and correlation ID is retained for user support.

- [ ] **Step 3: Run the focused test and confirm RED**

Run:

```powershell
cd mobile
flutter test test/ex_v2_trading_command_test.dart
```

Expected: failure because the async controller command does not exist and legacy production command errors are swallowed.

- [ ] **Step 4: Implement controller-owned async commands**

Each method creates metadata once, awaits repository mutation, awaits `refresh()`, and returns only after refreshed state is published. Preserve the original `ExV2RequestFailure`; do not catch and discard it.

```dart
Future<ExV2Order> createOrder({
  required String symbol,
  required String side,
  required double volume,
  String type = 'market',
  double? requestedPrice,
  double? stopLoss,
  double? takeProfit,
}) async {
  final metadata = ExV2CommandMetadata.create();
  final result = await ref.read(exV2RepositoryProvider).createOrder(
    clientOrderId: metadata.idempotencyKey,
    symbol: symbol,
    type: type,
    side: side.toLowerCase(),
    volume: volume,
    requestedPrice: requestedPrice,
    stopLoss: stopLoss,
    takeProfit: takeProfit,
    metadata: metadata,
  );
  await refresh();
  return result;
}
```

- [ ] **Step 5: Remove production fire-and-forget mutation paths**

Keep legacy synchronous mutation methods only behind `exV2EnabledProvider == false`. Production callers must use the new async controller commands. Remove `_submitServer` after all production call sites in Tasks 2 and 3 have migrated.

- [ ] **Step 6: Run the focused test and confirm GREEN**

Run `flutter test test/ex_v2_trading_command_test.dart` and expect all command success/rejection/idempotency cases to pass.

### Task 2: Wire the chart order flow to the actual server result

**Files:**
- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Test: `mobile/test/chart_server_order_test.dart`

**Interfaces:**
- Consumes: `ExV2AccountController.createOrder(...)` from Task 1.
- Produces: one submitting state per chart order interaction and server-backed success/rejection feedback.

- [ ] **Step 1: Write failing chart widget tests**

Cover both outcomes:

```dart
expect(find.textContaining('đã khớp'), findsNothing); // while request pending
completeOrderWithServerId('server-order-1');
await tester.pumpAndSettle();
expect(find.textContaining('đã khớp'), findsOneWidget);
```

For HTTP 422, assert the pending/chart panel remains open and the error text is shown; no success snackbar appears.

- [ ] **Step 2: Run tests and confirm RED**

Run `flutter test test/chart_server_order_test.dart`. Expected: current chart reports success synchronously.

- [ ] **Step 3: Convert `_placeChartOrder` and pending confirmation to async**

Disable repeat taps while submitting. Await the controller. Close transient overlays and show “đã khớp” only after the server returns a filled order and refreshed bootstrap contains the position. If the server returns pending, show “đã đặt lệnh chờ” and verify it appears in `pendingOrders`; do not call it matched.

- [ ] **Step 4: Render structured failures without altering layout**

Map 401 to device-token invalid, 409 to concurrency conflict/reload, 422 to server rejection text, and network timeout to retry text. Include a short correlation ID in diagnostic details, never the device token.

- [ ] **Step 5: Run chart tests and confirm GREEN**

Run `flutter test test/chart_server_order_test.dart test/chart_controls_test.dart test/video_interactions_test.dart`.

### Task 3: Apply the same awaited contract to New Order and position actions

**Files:**
- Modify: `mobile/lib/features/order/presentation/screens/new_order_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/features/trade/presentation/screens/position_detail_screen.dart`
- Test: `mobile/test/new_order_server_sync_test.dart`
- Test: `mobile/test/position_server_sync_test.dart`

**Interfaces:**
- Consumes: async create/cancel/modify/close commands from Task 1.
- Produces: consistent submitting, confirmed, rejected, and retry behavior for all trading entry points.

- [ ] **Step 1: Add failing tests for false success and double tap**

Assert the artificial 700 ms timer is not considered success, two taps issue one HTTP mutation, and a rejection leaves Trade unchanged.

- [ ] **Step 2: Remove the artificial delay and await EX V2**

Use the exact server order ID in the confirmation state. Do not use the idempotency key as the displayed ticket. Await cancel/modify/close before dismissing sheets.

- [ ] **Step 3: Refresh on 409 and preserve the user's form values**

On `CONCURRENCY_CONFLICT`, refresh bootstrap, keep price/SL/TP/volume in the sheet, and require explicit resubmission with new metadata.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
flutter test test/new_order_server_sync_test.dart test/position_server_sync_test.dart
```

### Task 4: Make floating profit, equity, and free margin move with quotes

**Files:**
- Modify: `mobile/lib/features/account_sync/domain/ex_v2_models.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_view_state.dart`
- Modify: `mobile/lib/shared/providers/demo_data_provider.dart`
- Test: `mobile/test/ex_v2_live_account_metrics_test.dart`
- Server contract: `/opt/ex-v2-api-src/docs/openapi-v2.json`

**Interfaces:**
- Server must provide per-position `currentPrice`, `floatingProfit`, and either `contractSize` or an authoritative quote-to-profit multiplier.
- Produces display getters: `displayProfit`, `displayEquity`, `displayFreeMargin`, `displayMarginLevel`.

- [ ] **Step 1: Add a failing live-metrics test**

With balance 10,000, margin 100, and one BUY position whose quote update changes floating profit from 0 to 25, assert balance stays 10,000, profit becomes 25, equity becomes 10,025, and free margin becomes 9,925.

- [ ] **Step 2: Extend the EX V2 position contract**

On the server, include authoritative valuation metadata in bootstrap/snapshot position DTOs. Update OpenAPI and add an integration test proving values use the server market quote and decimal arithmetic. Do not hard-code `* 100` globally in Flutter because contract size differs by symbol.

- [ ] **Step 3: Derive display metrics from live positions**

`withMarketPrice` updates position display values using server-provided valuation metadata. The account adapter exposes:

```dart
displayProfit = positions.fold(0, (sum, p) => sum + p.profit);
displayEquity = balance + displayProfit;
displayFreeMargin = displayEquity - margin;
displayMarginLevel = margin == 0 ? 0 : displayEquity / margin * 100;
```

Server bootstrap overwrites these derived values on every refresh. Balance is never changed by quote ticks.

- [ ] **Step 4: Run focused tests**

Run `flutter test test/ex_v2_live_account_metrics_test.dart test/ex_v2_account_view_state_test.dart`.

### Task 5: Prove the EX V2 server creates a complete market-order lifecycle

**Files:**
- Server source root: `/opt/ex-v2-api-src`
- Update exact controller/service/test files discovered with:

```bash
rg -n "CreateOrderRequest|MapPost.*orders|HttpPost|V2Orders|V2Positions|V2Deals" /opt/ex-v2-api-src
```

- Update: `/opt/ex-v2-api-src/docs/openapi-v2.json`

**Interfaces:**
- Consumes `POST /api/v2/orders` with `type=market`, `side=buy|sell`, and no client executed price.
- Produces committed `V2Order`, `V2Position`, `V2Deal`, sync version increment, and post-commit SignalR events.

- [ ] **Step 1: Add a server integration test before production changes**

The test uses a seeded demo account and deterministic market quote. Assert one request creates exactly one order, one position, one deal; replay with the same idempotency key creates no duplicates.

- [ ] **Step 2: Add rejection-path tests**

Cover invalid symbol, invalid volume, stale market feed, insufficient margin, and malformed type. Each response must contain stable `code`, readable `message`, and correlation ID; no partial rows may remain.

- [ ] **Step 3: Fix only the failing server boundary**

Normalize documented type/side values, obtain executed price from the market service, and commit order/position/deal/version atomically. Emit `OrderCreated`, `PositionCreated`, `DealCreated`, and `AccountSnapshotInvalidated` only after commit.

- [ ] **Step 4: Run server verification**

```bash
cd /opt/ex-v2-api-src
dotnet build
dotnet test --no-build
```

Do not deploy until the integration lifecycle and idempotency tests pass.

### Task 6: End-to-end demo acceptance without web regression

**Files:**
- Update: `docs/ex-v2-mobile-integration.md`
- Add: `docs/screenshots/ex-v2-chart-order-fixed.png`
- Add: `docs/screenshots/ex-v2-trade-live-profit.png`

**Interfaces:**
- Consumes completed mobile and server tasks.
- Produces release evidence and rollback-ready acceptance report.

- [ ] **Step 1: Run all local validation**

```powershell
cd D:\mt5New\mobile
flutter analyze
flutter test
flutter build apk --debug
cd D:\mt5New\backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

- [ ] **Step 2: Deploy server v2 only with the existing rollback procedure**

Do not restart or replace legacy `ex-api.service`, and do not modify `/ex/api/api/*`. Verify v2 health, Nginx compatibility, and legacy static checksum.

- [ ] **Step 3: Perform one approved demo market order**

Record correlation ID and compare: POST response order ID, bootstrap position ID, Trade row, history order/deal, and database rows. Confirm no duplicate after retry.

- [ ] **Step 4: Verify live money behavior**

While the quote changes, capture that position profit, total profit, equity, and free margin move; balance stays fixed. Close the position and confirm the realized profit is applied once to server balance and appears identically on web and app.

- [ ] **Step 5: Verify account switching from web**

Change the active device account in web admin. Confirm SignalR triggers bootstrap reload and all Trade/history/balance data switch atomically without an app account picker.

- [ ] **Step 6: Update documentation and rotate the exposed token**

Document response codes and the async UX. Rotate the device token because it was shared in chat, activate the new token once, and verify the old token returns 401.
