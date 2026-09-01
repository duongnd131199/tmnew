# Flutter Stop Out History and Versioned Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flutter converge on the authoritative EX V2 Stop Out state, reject mixed-version snapshots, deduplicate realtime events, and display complete exit/D-null history without ever creating an opposite open position locally.

**Architecture:** The HTTP client captures `X-Server-Data-Version`, the repository exposes versioned bootstrap/history reads, and a focused snapshot loader accepts trading state only when all server versions match. Realtime events carry `EventId`/`DataVersion`; Flutter deduplicates them and performs GET-only canonical reconciliation, while existing History Balance rows render typed `D-null` adjustments.

**Tech Stack:** Flutter 3.44+, Dart, Riverpod, Dio, `signalr_hub`, Flutter test, iOS release build.

**Spec:** `docs/superpowers/specs/2026-09-01-ex-v2-stop-out-negative-balance-protection-design.md`

**Server prerequisite:** `docs/superpowers/plans/2026-09-01-ex-v2-server-stop-out-negative-balance-protection.md` is implemented through Task 11 and its handoff confirms stable public OpenAPI, version headers, realtime envelopes, complete History, and enabled virtual Stop Out.

## Global Constraints

- Before implementation, read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and `docs/design-system.md` fully.
- Preserve the current Flutter/Dart/Riverpod/Dio/SignalR stack and the existing visual design.
- The server remains authoritative for Balance, Equity, positions, orders, deals, adjustments, and History totals.
- Flutter must never calculate a Stop Out, clamp a negative server balance, create `D-null`, or call a public Stop Out mutation.
- Open positions come only from `bootstrap.positions`; `SELL/out` and `BUY/out` are History deals and never become open positions.
- Reconciliation retries GET requests only. A committed mutation is never resent.
- Keep the current exact-volume close payload; the server remains compatible with nullable full-close requests from older clients.
- Treat `X-Server-Data-Version` as optional only for backward-compatible rollout. When any required trading response has it, every required trading response must have the same value as Bootstrap.
- Preserve existing optimistic create/close/cancel behavior and active-account scoping.
- Preserve History layout, font sizes, font weights, colors, navigation, date filter state, and details behavior.
- Use the existing Balance History row to display `D-null`; do not add a new visual row type.
- Do not log device tokens, credentials, response financial payloads, or raw SignalR envelopes.
- Before every Task 1-5 commit, run `flutter analyze --no-pub`, that task's relevant tests, and `flutter build ios --release --no-codesign --no-pub`.
- Do not upload TestFlight until the user explicitly requests it after verification.

---

### Task 1: Capture Server Data Version in the Dio Transport

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_api_client.dart`
- Modify: `mobile/test/ex_v2_api_client_test.dart`

**Interfaces:**
- Consumes: normal Dio JSON responses and optional `X-Server-Data-Version` header.
- Produces: `ExV2Versioned<T>`, `getVersionedJson`, `getVersionedList`, and strict header parsing while preserving existing `getJson`/`getList` callers.

- [ ] **Step 1: Write failing response-version tests**

Add cases proving:

```dart
final response = await client.getVersionedJson('/mobile/bootstrap');
expect(response.dataVersion, 41);
expect(response.value['version'], 41);
```

Also assert:

- missing header yields `dataVersion == null`;
- whitespace around a valid integer is accepted;
- negative, non-integer, duplicate-conflicting, or overflow header values throw
  `FormatException`;
- existing `getJson`/`getList` still return their original value types; and
- no diagnostic output contains the device token or response body.

Update `_RecordingAdapter` to accept response headers:

```dart
_RecordingAdapter(
  body: const {'version': 41},
  responseHeaders: const {'X-Server-Data-Version': ['41']},
);
```

- [ ] **Step 2: Run transport tests and verify RED**

Run:

```bash
cd mobile
flutter test --no-pub test/ex_v2_api_client_test.dart
```

Expected: compile failure because versioned response methods/types do not
exist.

- [ ] **Step 3: Add the immutable versioned response type**

```dart
final class ExV2Versioned<T> {
  const ExV2Versioned({required this.value, required this.dataVersion});

  final T value;
  final int? dataVersion;
}
```

Add strict parser:

```dart
int? _serverDataVersion(Headers headers) {
  final values = headers['X-Server-Data-Version'];
  if (values == null || values.isEmpty) return null;
  final normalized = values.map((value) => value.trim()).toSet();
  if (normalized.length != 1) {
    throw const FormatException('Conflicting EX V2 data versions');
  }
  final version = int.tryParse(normalized.single);
  if (version == null || version < 0) {
    throw const FormatException('Invalid EX V2 data version');
  }
  return version;
}
```

- [ ] **Step 4: Implement versioned GET methods and compatibility delegates**

`getVersionedJson` and `getVersionedList` call `_request`, validate the body
with the same rules as current methods, and return header metadata. Existing
methods become:

```dart
Future<Map<String, dynamic>> getJson(String path) async =>
    (await getVersionedJson(path)).value;

Future<List<dynamic>> getList(
  String path, {
  Map<String, dynamic>? queryParameters,
}) async =>
    (await getVersionedList(path, queryParameters: queryParameters)).value;
```

- [ ] **Step 5: Run tests and analyze**

```bash
flutter test --no-pub test/ex_v2_api_client_test.dart
flutter analyze --no-pub
```

Expected: transport tests pass and analyze reports no issues.

- [ ] **Step 6: Commit transport metadata support**

```bash
git add mobile/lib/features/account_sync/data/ex_v2_api_client.dart mobile/test/ex_v2_api_client_test.dart
git commit -m "feat: capture EX V2 server data versions"
```

---

### Task 2: Parse Complete Exit and Negative Balance Protection Contracts

**Files:**
- Modify: `mobile/lib/features/account_sync/domain/ex_v2_models.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_demo_mapper.dart`
- Modify: `mobile/lib/features/account_sync/data/ex_v2_wallet_history_mapper.dart`
- Modify: `mobile/test/ex_v2_models_test.dart`
- Modify: `mobile/test/ex_v2_demo_mapper_test.dart`
- Modify: `mobile/test/ex_v2_wallet_history_mapper_test.dart`

**Interfaces:**
- Consumes: optional server deal/order/adjustment fields from the stable EX V2 contract.
- Produces: additive `ExV2Deal` metadata, optional History adjustment total, and a `DemoHistoryPosition` Balance row whose subtitle remains exactly `D-null`.

- [ ] **Step 1: Write failing deal and summary parsing tests**

Use this server deal fixture:

```dart
final deal = ExV2Deal.fromJson({
  'id': 'deal-exit-1',
  'orderId': 'order-exit-1',
  'openingOrderId': 'order-entry-1',
  'positionId': 'position-1',
  'type': 'out',
  'symbol': 'XAUUSD+',
  'side': 'SELL',
  'volume': 1.0,
  'price': 4600.0,
  'profit': -103100.0,
  'commission': -10.0,
  'swap': -5.0,
  'netProfit': -103115.0,
  'executionReason': 'stop-out',
  'stopOutRunId': 'run-1',
  'createdAtUtc': '2026-09-01T00:00:00Z',
});

expect(deal.side, 'SELL');
expect(deal.type, 'out');
expect(deal.openingOrderId, 'order-entry-1');
expect(deal.orderId, 'order-exit-1');
expect(deal.netProfit, -103115.0);
expect(deal.executionReason, 'stop-out');
```

Assert old fixtures without new fields still parse with null/default values.
Add an `adjustment` summary value and assert a missing value defaults to zero.

- [ ] **Step 2: Write failing D-null History mapping tests**

Pass this transaction to `ExV2WalletHistoryMapper.entries`:

```dart
{
  'id': 'adjustment-1',
  'type': 'NegativeBalanceProtection',
  'displayCode': 'D-null',
  'description': 'Negative Balance Protection',
  'amount': 31.15,
  'currency': 'USD',
  'balanceBefore': -31.15,
  'balanceAfter': 0.0,
  'createdAtUtc': '2026-09-01T00:00:01Z',
}
```

Expected mapped row:

```dart
expect(row.title, 'Balance');
expect(row.profit, 31.15);
expect(row.subtitle, 'D-null');
expect(row.isBalance, isTrue);
```

Assert `normalizeReferences` does not rewrite `D-null` into a generated
`D-ALLINT-...` deposit reference and does not match it to a deposit request.

- [ ] **Step 3: Run model/mapper tests and verify RED**

```bash
flutter test --no-pub test/ex_v2_models_test.dart test/ex_v2_demo_mapper_test.dart test/ex_v2_wallet_history_mapper_test.dart
```

Expected: missing fields and D-null mapping assertions fail.

- [ ] **Step 4: Extend models with optional additive fields**

Add to `ExV2Deal`:

```dart
final String? openingOrderId;
final double commission;
final double swap;
final double? netProfit;
final String? executionReason;
final String? stopOutRunId;
```

Parse commission/swap as optional numeric values defaulting to zero. Parse
links/reason as nullable strings. Add `adjustment` to `ExV2HistorySummary`,
defaulting to zero when absent so older servers remain compatible.

- [ ] **Step 5: Map NBP as a protected Balance reference**

Extend `_transactionType` to return `negativeBalanceProtection` when type,
kind, adjustment type, or description equals/contains
`negativebalanceprotection`, `negative balance protection`, or `d-null`.
For this type:

- amount is always positive `amount.abs()`;
- `_displayReference` returns explicit `displayCode`/`code`, normalized to
  exactly `D-null`;
- request matching is skipped; and
- `normalizeReferences` immediately preserves a Balance entry whose subtitle
  equals `D-null` case-insensitively.

Do not treat the adjustment as a deposit or realized trading profit.

- [ ] **Step 6: Keep exit deals in History only**

`ExV2DemoMapper.deal` and `historyDeal` continue mapping close/out types to
`entry = out`. Do not add any path from deals to `DemoPosition`; the only open
position mapping remains `ExV2AccountViewState.fromBootstrap` over
`bootstrap.positions`.

- [ ] **Step 7: Run mapper/model tests and analyze**

```bash
flutter test --no-pub test/ex_v2_models_test.dart test/ex_v2_demo_mapper_test.dart test/ex_v2_wallet_history_mapper_test.dart
flutter analyze --no-pub
```

Expected: new/legacy contract and D-null cases pass with no analyze issues.

- [ ] **Step 8: Commit contract/history mapping**

```bash
git add mobile/lib/features/account_sync/domain/ex_v2_models.dart mobile/lib/features/account_sync/data/ex_v2_demo_mapper.dart mobile/lib/features/account_sync/data/ex_v2_wallet_history_mapper.dart mobile/test/ex_v2_models_test.dart mobile/test/ex_v2_demo_mapper_test.dart mobile/test/ex_v2_wallet_history_mapper_test.dart
git commit -m "feat: map stop out and D-null history"
```

---

### Task 3: Load One Coherent Versioned Bootstrap and Trading History Snapshot

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_repository.dart`
- Create: `mobile/lib/features/account_sync/data/ex_v2_versioned_snapshot_loader.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/test/ex_v2_repository_test.dart`
- Create: `mobile/test/ex_v2_versioned_snapshot_loader_test.dart`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`

**Interfaces:**
- Consumes: versioned Bootstrap, orders, deals, positions, transactions, and summary reads.
- Produces: `ExV2SnapshotSource`, `ExV2CanonicalTradingSnapshot`, and bounded GET-only retry that accepts only one data version.

- [ ] **Step 1: Write failing repository paging/version tests**

Assert:

- `bootstrapVersioned()` returns parsed Bootstrap plus header version;
- every versioned History method returns its items plus header version;
- all pages of one endpoint must have the same version;
- a missing header on every page is legacy-compatible;
- a mixture of present/missing page headers throws
  `ExV2DataVersionMismatch`; and
- two different page versions throw before rows are published.

- [ ] **Step 2: Write failing coherent-loader tests**

Create a fake `ExV2SnapshotSource` with scripted versions. Test:

1. all values `9` return one snapshot;
2. first attempt `bootstrap=9`, `deals=10` retries GETs and accepts second
   attempt all `10`;
3. six mismatched attempts throw `ExV2DataVersionMismatch`;
4. all headers missing accept legacy mode using `bootstrap.version`;
5. any required response header present while another is missing retries and
   never publishes a partial snapshot; and
6. no mutation method exists on or is called by the loader.

- [ ] **Step 3: Run repository/loader tests and verify RED**

```bash
flutter test --no-pub test/ex_v2_repository_test.dart test/ex_v2_versioned_snapshot_loader_test.dart
```

Expected: versioned repository/loader symbols are missing.

- [ ] **Step 4: Add versioned repository methods without breaking old callers**

Define:

```dart
abstract interface class ExV2SnapshotSource {
  Future<ExV2Versioned<ExV2Bootstrap>> bootstrapVersioned();
  Future<ExV2Versioned<List<JsonMap>>> historyOrdersVersioned();
  Future<ExV2Versioned<List<JsonMap>>> historyDealsVersioned();
  Future<ExV2Versioned<List<JsonMap>>> historyPositionsVersioned();
  Future<ExV2Versioned<List<JsonMap>>> historyTransactionsVersioned();
  Future<ExV2Versioned<ExV2HistorySummary>> historySummaryVersioned();
}
```

Make `ExV2Repository` implement it. Existing `bootstrap()`/History methods
delegate to `.value`. `_readAllVersionedMaps` rejects mixed/mismatched page
versions before returning accumulated rows.

Define the shared typed failure in `ex_v2_repository.dart`:

```dart
final class ExV2DataVersionMismatch implements Exception {
  const ExV2DataVersionMismatch({
    required this.expected,
    required this.actual,
  });

  final int? expected;
  final int? actual;
}
```

- [ ] **Step 5: Implement the focused snapshot loader**

```dart
final class ExV2CanonicalTradingSnapshot {
  const ExV2CanonicalTradingSnapshot({
    required this.bootstrap,
    required this.orders,
    required this.deals,
    required this.positions,
    required this.transactions,
    required this.summary,
    required this.dataVersion,
  });

  final ExV2Bootstrap bootstrap;
  final List<JsonMap> orders;
  final List<JsonMap> deals;
  final List<JsonMap> positions;
  final List<JsonMap> transactions;
  final ExV2HistorySummary summary;
  final int dataVersion;
}

final class ExV2VersionedSnapshotLoader {
  const ExV2VersionedSnapshotLoader(
    this.source, {
    this.delays = const [
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1600),
    ],
  });

  final ExV2SnapshotSource source;
  final List<Duration> delays;

  Future<ExV2CanonicalTradingSnapshot> load() async {
    ExV2DataVersionMismatch? lastMismatch;
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      final bootstrap = await source.bootstrapVersioned();
      final reads = await Future.wait<Object>([
        source.historyOrdersVersioned(),
        source.historyDealsVersioned(),
        source.historyPositionsVersioned(),
        source.historyTransactionsVersioned(),
        source.historySummaryVersioned(),
      ]);
      final orders = reads[0]
          as ExV2Versioned<List<JsonMap>>;
      final deals = reads[1]
          as ExV2Versioned<List<JsonMap>>;
      final positions = reads[2]
          as ExV2Versioned<List<JsonMap>>;
      final transactions = reads[3]
          as ExV2Versioned<List<JsonMap>>;
      final summary = reads[4]
          as ExV2Versioned<ExV2HistorySummary>;
      final versions = <int?>[
        bootstrap.dataVersion,
        orders.dataVersion,
        deals.dataVersion,
        positions.dataVersion,
        transactions.dataVersion,
        summary.dataVersion,
      ];
      final hasVersionHeader = versions.any((value) => value != null);
      final dataVersion = hasVersionHeader
          ? bootstrap.dataVersion
          : bootstrap.value.version;
      if (dataVersion == null ||
          (hasVersionHeader && versions.any((value) => value != dataVersion)) ||
          bootstrap.value.version != dataVersion) {
        lastMismatch = ExV2DataVersionMismatch(
          expected: dataVersion ?? bootstrap.value.version,
          actual: versions.whereType<int>().firstOrNull,
        );
        continue;
      }
      return ExV2CanonicalTradingSnapshot(
        bootstrap: bootstrap.value,
        orders: orders.value,
        deals: deals.value,
        positions: positions.value,
        transactions: transactions.value,
        summary: summary.value,
        dataVersion: dataVersion,
      );
    }
    throw lastMismatch ?? const ExV2DataVersionMismatch(
      expected: null,
      actual: null,
    );
  }
}
```

Each attempt waits its corresponding delay, fetches Bootstrap first, then the five required History
reads in parallel. If every header is absent, require no header and use
`bootstrap.version`. Otherwise require every header and
`bootstrap.version` to equal the same value. After six mismatches throw the
typed exception and retain prior confirmed state at the provider layer.

- [ ] **Step 6: Integrate without delaying initial Bootstrap visibility**

Keep `_loadCore` as the initial authoritative Bootstrap load. Replace the
trading portion of `_hydrate` with the snapshot loader in the existing
background hydration path. Only one Riverpod state assignment publishes
the loader's Bootstrap, orders, deals, closed positions, transactions, and
summary from the accepted snapshot. Wallet/deposit/withdrawal/settings reads remain independent and
cannot overwrite a newer trading version.

Scope every attempt to `_AccountMutationScope`/`_loadGeneration`; discard a
response for an old active account or an older Bootstrap version.

- [ ] **Step 7: Run repository/loader/provider tests**

```bash
flutter test --no-pub test/ex_v2_repository_test.dart test/ex_v2_versioned_snapshot_loader_test.dart test/ex_v2_account_provider_test.dart
```

Expected: version paging, retry, legacy compatibility, initial Bootstrap
visibility, stale account scoping, and atomic publication tests pass.

- [ ] **Step 8: Commit coherent snapshot loading**

```bash
git add mobile/lib/features/account_sync/data/ex_v2_repository.dart mobile/lib/features/account_sync/data/ex_v2_versioned_snapshot_loader.dart mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_repository_test.dart mobile/test/ex_v2_versioned_snapshot_loader_test.dart mobile/test/ex_v2_account_provider_test.dart
git commit -m "feat: reconcile versioned EX V2 snapshots"
```

---

### Task 4: Deduplicate Typed Stop Out Realtime Events

**Files:**
- Modify: `mobile/lib/features/account_sync/data/ex_v2_realtime_service.dart`
- Modify: `mobile/lib/features/account_sync/application/ex_v2_account_provider.dart`
- Modify: `mobile/test/ex_v2_realtime_service_test.dart`
- Modify: `mobile/test/ex_v2_account_provider_test.dart`

**Interfaces:**
- Consumes: server envelopes with `eventId`, `dataVersion`, `accountId`, correlation/run IDs, and typed Stop Out event names.
- Produces: bounded EventId dedupe, account/version filtering, and one debounced canonical GET refresh.

- [ ] **Step 1: Write failing envelope/dedupe tests**

Emit:

```dart
{
  'eventId': 'event-1',
  'dataVersion': 12,
  'accountId': 'account-1',
  'correlationId': 'correlation-1',
  'stopOutRunId': 'run-1',
}
```

Assert `ExV2RealtimeEvent` exposes every field. Emit the same `eventId` twice
and assert one event/refresh. Emit versions 12 then 11 and assert the older
event cannot refresh. Emit `HistoryUpdated` at the already-loaded version 12
and assert it can finish History hydration once. Emit a different account ID
and assert it cannot affect the current account. Emit 300 unique IDs and assert
the bounded cache evicts old entries without unbounded growth.

- [ ] **Step 2: Assert every new event name is registered**

Test registration/handling for:

```dart
const stopOutEvents = [
  'StopOutTriggered',
  'OrderCanceled',
  'PositionClosed',
  'DealCreated',
  'AccountAdjustmentCreated',
  'AccountSummaryUpdated',
  'HistoryUpdated',
  'StopOutCompleted',
  'AccountSnapshotInvalidated',
];
```

- [ ] **Step 3: Run realtime/provider tests and verify RED**

```bash
flutter test --no-pub test/ex_v2_realtime_service_test.dart test/ex_v2_account_provider_test.dart
```

Expected: missing event metadata/dedupe assertions fail.

- [ ] **Step 4: Extend event parsing and add bounded dedupe**

Add nullable `eventId`, `correlationId`, and `stopOutRunId`. Parse version from
`dataVersion`, falling back to legacy `version`. Maintain a `LinkedHashSet` of
the newest 256 nonempty EventIds; suppress a duplicate before adding it to the
stream. Clear the cache when the service is disposed/recreated for a new token.

- [ ] **Step 5: Harden provider filtering and refresh behavior**

Before scheduling refresh:

1. discard a non-null event account ID different from active account;
2. discard `dataVersion < current.bootstrap.version`, except
   `ActiveAccountChanged`;
3. when versions are equal, allow `StopOutCompleted`, `HistoryUpdated`,
   `AccountAdjustmentCreated`, and `AccountSnapshotInvalidated` to complete
   History hydration; ignore other equal-version events;
4. keep the existing 250ms coalescing window; and
5. call only canonical refresh GETs.

`StopOutCompleted` and `AccountSnapshotInvalidated` must be allowed during a
grouped close so server Stop Out can clear stale optimistic rows.

- [ ] **Step 6: Run realtime/provider tests and analyze**

```bash
flutter test --no-pub test/ex_v2_realtime_service_test.dart test/ex_v2_account_provider_test.dart
flutter analyze --no-pub
```

Expected: typed event, dedupe, account isolation, version ordering, reconnect,
and refresh coalescing cases pass.

- [ ] **Step 7: Commit realtime reconciliation**

```bash
git add mobile/lib/features/account_sync/data/ex_v2_realtime_service.dart mobile/lib/features/account_sync/application/ex_v2_account_provider.dart mobile/test/ex_v2_realtime_service_test.dart mobile/test/ex_v2_account_provider_test.dart
git commit -m "feat: reconcile typed stop out events"
```

---

### Task 5: Verify Complete Stop Out State in Trade and History UI

**Files:**
- Modify only for semantic mapping, not geometry: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify: `mobile/test/ex_v2_account_view_state_test.dart`
- Modify: `mobile/test/ex_v2_history_reconciler_test.dart`
- Modify: `mobile/test/ex_v2_trading_command_test.dart`
- Modify: `mobile/test/trade_position_bulk_actions_flow_test.dart`
- Create: `mobile/test/ex_v2_stop_out_flow_test.dart`

**Interfaces:**
- Consumes: one canonical versioned snapshot after `StopOutCompleted`.
- Produces: zero Balance/Equity, empty open positions/pending orders, complete closing History, a non-tappable `D-null` Balance row, and preserved manual close behavior.

- [ ] **Step 1: Write the end-to-end provider Stop Out fixture**

The fake server sequence is:

1. Bootstrap version 20 has one BUY position, one pending order, positive
   Balance, and negative floating Equity near zero.
2. Realtime emits `StopOutCompleted`, `eventId=event-stop-1`,
   `dataVersion=21`.
3. Bootstrap version 21 has Balance/Equity `0.00`, no positions, and no pending
   orders.
4. History version 21 has entry order, exit SELL order, entry deal, SELL/out
   exit deal, closed BUY position, canceled pending order, summary, and one
   `D-null` transaction.

Assert one refresh sequence publishes all version-21 collections together.

- [ ] **Step 2: Write failing UI/semantic assertions**

Assert:

- Trade has no open row for the exit SELL deal;
- Balance and Equity render `0.00` from Bootstrap;
- Deals render `sell, out` with realized loss;
- positions History renders original BUY with open-to-close price;
- orders History contains the original and role-exit order;
- `D-null` appears as a Balance row with the positive protection amount;
- tapping `D-null` does not open position details;
- History summary does not add NBP to realized trading profit; and
- existing row heights, fonts, weights, colors, menu/navigation, and date
  filters remain unchanged.

- [ ] **Step 3: Run Stop Out/UI tests and verify RED**

```bash
flutter test --no-pub test/ex_v2_stop_out_flow_test.dart test/history_screen_detail_test.dart test/ex_v2_account_view_state_test.dart
```

Expected: end-to-end/version/D-null assertions fail before integration.

- [ ] **Step 4: Make the smallest semantic History adjustment**

Reuse the existing `DemoHistoryPosition.isBalance` path and Balance row widget.
If the screen currently derives tap behavior or summary type from deposit-only
references, change only that semantic predicate so subtitle `D-null` remains a
non-tappable Balance transaction. Do not change padding, size, typography,
color, scrolling, headers, tabs, or navigation.

- [ ] **Step 5: Preserve manual/bulk close behavior**

Run the existing exact-volume, partial-close, concurrent group, post-close
history, and position-not-found cases. The server-triggered refresh may clear
optimistic hidden IDs only after canonical version 21 proves the positions are
closed; it must not resend any close POST.

- [ ] **Step 6: Run all affected tests**

```bash
flutter test --no-pub test/ex_v2_stop_out_flow_test.dart test/history_screen_detail_test.dart test/ex_v2_account_view_state_test.dart test/ex_v2_trading_command_test.dart test/trade_position_bulk_actions_flow_test.dart test/ex_v2_wallet_history_mapper_test.dart
flutter test --no-pub test/ex_v2_history_reconciler_test.dart
```

Expected: Stop Out, D-null, Trade/History semantics, and every existing close
flow pass.

- [ ] **Step 7: Commit end-to-end Flutter behavior**

```bash
git add mobile/lib/features/history/presentation/screens/history_screen.dart mobile/test/history_screen_detail_test.dart mobile/test/ex_v2_account_view_state_test.dart mobile/test/ex_v2_history_reconciler_test.dart mobile/test/ex_v2_trading_command_test.dart mobile/test/trade_position_bulk_actions_flow_test.dart mobile/test/ex_v2_stop_out_flow_test.dart
git commit -m "feat: render authoritative stop out state"
```

---

### Task 6: Run the Complete Flutter Release Gate and Device Smoke

**Files:**
- Verify only: all files changed in Tasks 1-5.
- Create: `docs/ex-v2-stop-out-flutter-verification.md`
- No TestFlight upload or App Store Connect mutation is allowed in this task.

**Interfaces:**
- Consumes: stable deployed EX V2 contract/server handoff and reviewed Flutter commits.
- Produces: analyzed, tested, release-built Flutter app with device evidence that realtime, refresh, and cold restart show the same Stop Out state.

- [ ] **Step 1: Run formatting and diff checks**

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test
git diff --check -- lib test
```

Expected: no formatting or whitespace failures.

- [ ] **Step 2: Run analyze and the complete affected regression set**

```bash
flutter analyze --no-pub
flutter test --no-pub \
  test/ex_v2_api_client_test.dart \
  test/ex_v2_models_test.dart \
  test/ex_v2_demo_mapper_test.dart \
  test/ex_v2_wallet_history_mapper_test.dart \
  test/ex_v2_repository_test.dart \
  test/ex_v2_versioned_snapshot_loader_test.dart \
  test/ex_v2_realtime_service_test.dart \
  test/ex_v2_account_provider_test.dart \
  test/ex_v2_account_view_state_test.dart \
  test/ex_v2_history_reconciler_test.dart \
  test/ex_v2_trading_command_test.dart \
  test/trade_position_bulk_actions_flow_test.dart \
  test/history_screen_detail_test.dart \
  test/ex_v2_stop_out_flow_test.dart
```

Expected: analyze has no issues and every affected test passes.

- [ ] **Step 3: Run the full Flutter suite and classify unrelated baseline failures**

```bash
flutter test --no-pub
```

Expected release gate: zero failures. If the dirty visual-parity branch still
contains previously documented unrelated golden failures, do not modify or
regenerate them in this feature. Rebase onto their resolved commits or obtain
a clean baseline before release; a failing full suite cannot be reported as a
passing release gate.

- [ ] **Step 4: Build the iOS release app without uploading**

```bash
flutter build ios --release --no-codesign --no-pub
```

Expected: `build/ios/iphoneos/Runner.app` builds successfully.

- [ ] **Step 5: Run a dedicated virtual-account device smoke**

Using the server team's dedicated virtual account only:

1. open Trade while Equity is positive and confirm the position remains;
2. execute the approved server fixture that reaches Equity zero/below zero;
3. confirm Trade empties without a client close tap;
4. confirm Balance/Equity are `0.00`;
5. confirm entry/exit/canceled/closed/D-null History;
6. background/foreground and confirm state is unchanged;
7. cold restart and confirm the same canonical state; and
8. confirm duplicate replayed realtime event creates no duplicate History.

Do not print the device token, credentials, account code, or raw financial
payload.

- [ ] **Step 6: Record final evidence and commit the verification report**

Write `docs/ex-v2-stop-out-flutter-verification.md` with commit hashes, server data version, test counts, build result, device
steps, and redacted screenshots/log identifiers. Confirm explicitly that no
TestFlight upload occurred. Commit only that report with:

```bash
git add docs/ex-v2-stop-out-flutter-verification.md
git commit -m "docs: record Flutter stop out verification"
```
