# EX V2 Automatic Stop Out and Negative Balance Protection Design

## Status

Approved in chat on 2026-09-01. This document records the design; no source,
database, service, deployment, or TestFlight change has occurred from writing
it.

## Goal

Keep the virtual-money account from finishing below zero when market losses
consume all account equity. EX V2 must automatically execute a server-side Stop
Out when authoritative equity reaches zero, preserve a complete trading
history, and apply an auditable Negative Balance Protection adjustment when the
realized balance is negative.

The required terminal state of a completed Stop Out is:

- every open position is closed;
- every pending order is canceled;
- no opposite open position is created while closing;
- the final stored Balance and Equity are exactly `0.00` at the account
  currency scale;
- a negative realized balance is offset by one immutable
  `NegativeBalanceProtection` adjustment displayed as `D-null`; and
- the original orders, closing orders, entry/exit deals, closed positions,
  cancellations, and adjustment remain visible in History.

## Scope and Non-Goals

This is an architectural change spanning the production EX V2 service under
`/opt/ex-v2-api-src` and the Flutter client in this repository.

The product remains a virtual-money trading app:

- execution uses the app's authoritative Bid/Ask quotes from the existing
  market bridge;
- no order is sent to a real broker or an MT5 terminal;
- no broker ticket, live fill, or real-money accounting is introduced;
- Flutter never decides whether Stop Out has occurred and cannot trigger it
  through a public endpoint;
- the local `backend/` market-data service is not converted into an execution
  engine; and
- unrelated visual work, account identity work, and TestFlight delivery are
  outside this design.

## Confirmed Production Baseline

The design is based on the production-source audit performed against commit
`a9dc3f75c78a43f24f48dd2dcccfbd1876849bd1` in
`/opt/ex-v2-api-src`.

The current EX V2 service:

- executes virtual trades by updating SQL state;
- obtains current prices from the market service but does not subscribe to
  market ticks for account-risk evaluation;
- calculates floating equity only when account summary is read;
- has no Stop Out, Negative Balance Protection, trading-balance adjustment
  ledger, or account-wide trading outbox;
- closes a BUY by writing a SELL exit deal and closes a SELL by writing a BUY
  exit deal, without creating an opposite open position;
- publishes trading SignalR messages directly after commit;
- uses idempotency records and rowversion on orders/positions, but has no
  shared account-level lock for all trading mutations; and
- has a dirty source tree containing unrelated pre-existing work, including
  migration `005`, while another worktree has already occupied migration
  number `006`.

The audited build passes with no warnings or errors. Unit and compatibility
tests pass, while 75 integration cases are blocked because the isolated test
connection variable `EXV2_TEST_SQL_CONNECTION` is missing. A production
database connection must never be substituted for that test dependency.

Flutter already maps close/out deal types to History entry `out`. An exit deal
whose side is SELL is therefore a record of closing a BUY, not evidence of an
open SELL position. Open positions remain authoritative only from the server
position collection.

## Chosen Approach

Use a hybrid, server-authoritative risk worker in EX V2:

1. subscribe to market `QuoteUpdated` events for immediate evaluation;
2. retain the newest quote per symbol in an in-process quote cache;
3. coalesce duplicate tick work per account;
4. perform a periodic safety reconciliation and a full reconciliation after
   startup or SignalR reconnect; and
5. execute Stop Out transactionally under the same account lock used by every
   manual trading mutation.

A poll-only worker was rejected because it adds latency and database load. A
Flutter-driven implementation was rejected because it fails whenever the app
is closed, suspended, disconnected, or stale.

## Required Invariants

The implementation must enforce all of these invariants:

1. The trigger is authoritative rounded `Equity <= 0`, including exactly zero.
2. Only fresh, complete Bid/Ask data may trigger or price a Stop Out.
3. One immutable quote snapshot prices every position in a Stop Out run.
4. The trigger calculation and closing calculation use the same money and
   rounding rules.
5. One account can have only one owner of a trading mutation at a time.
6. One risk version can create at most one Stop Out run.
7. One Stop Out run can close a position, cancel an order, create an
   adjustment, and enqueue a logical event at most once each.
8. Closing volume is never greater than the current remaining position volume.
9. A closing deal with the opposite side never creates an open opposite
   position.
10. Stop Out either commits the complete state or commits nothing.
11. No history row is deleted or rewritten to conceal the Stop Out.
12. Realtime publication occurs only from committed outbox records.
13. Flutter renders canonical server state and does not clamp, fabricate, or
    recompute financial totals.

## Architecture

### Market tick intake

`SignalRMarketTickSource` connects EX V2 to the existing market SignalR hub and
maintains a latest-quote cache. A quote record contains symbol, Bid, Ask,
source timestamp, receive timestamp, and a monotonically comparable source or
local sequence.

`MarketRiskWorker` receives symbol updates and finds accounts with open
positions in that symbol. It submits account IDs to a bounded single-flight
queue. If several ticks arrive while an account is queued or running, the
worker retains only the fact that another evaluation is required and uses the
newest quote snapshot on the next pass.

On startup and after SignalR reconnect, the worker obtains a fresh market
snapshot and enumerates all accounts with open positions. It also runs a
safety reconciliation every five seconds. This sweep is a recovery mechanism;
normal Stop Out latency comes from the SignalR subscription.

The worker must not perform network I/O while holding a SQL transaction or
account application lock. It captures quotes from the local cache, then opens
the transaction. If the locked account contains a symbol missing from the
captured snapshot, or any quote is stale, the transaction rolls back and the
account is requeued after the quote cache is refreshed.

### Component boundaries

The implementation introduces focused components instead of adding the whole
workflow to `SqlTradingService`:

- `AccountRiskRules`: pure decimal calculations, trigger decision,
  deterministic execution ordering, and currency rounding.
- `IAccountRiskService`: evaluates an account against an immutable quote
  snapshot.
- `ITradingAccountLock`: acquires the transaction-owned SQL application lock
  `trading-account:{accountId}`.
- `IPositionExecutionService`: performs a common close execution for manual
  close and Stop Out without creating an opposite position.
- `SqlStopOutService`: owns the locked transactional Stop Out state machine.
- `SignalRMarketTickSource`: receives and caches market quotes.
- `MarketRiskWorker`: queues tick-driven and recovery evaluations.
- `TradingOutboxDispatcher`: publishes committed account-scoped events and
  retries failures.

Manual create, close, partial close, bulk-close iterations, cancel, Stop Out,
and balance protection must acquire the same account lock. Refactoring is
limited to the shared execution and lock boundaries needed by this feature.

## Risk and Money Calculations

All financial calculations use .NET `decimal` and compatible SQL `decimal`
columns. Floating-point `double` is prohibited for persisted or authoritative
money calculations.

The account currency determines the scale through an explicit server mapping;
USD uses two fractional digits. An unknown currency or missing scale is a
configuration error that blocks execution and raises a health alert rather
than guessing a precision.

For each open position:

- BUY floating P/L uses `(Bid - entryPrice) * contractSize * remainingVolume`;
- SELL floating P/L uses `(entryPrice - Ask) * contractSize * remainingVolume`;
- accrued commission and swap are included in the position's net floating
  result when those fields exist; and
- the result applied to account equity uses the account currency scale.

Account values are:

- `Equity = Balance + sum(net floating P/L)`;
- `Margin = sum(remainingVolume * contractSize * marginPrice / leverage)`,
  using Ask as the BUY margin price and Bid as the SELL margin price, matching
  the side-aware quote used by the existing create-order calculation;
- `FreeMargin = Equity - Margin`; and
- `MarginLevel = Equity / Margin * 100` when Margin is greater than zero,
  otherwise the existing API-compatible zero/null representation.

Stop Out depends only on `Equity <= 0`; Margin Level is calculated for a
complete authoritative account summary but is not an additional trigger.

The calculation helper rounds monetary components with the account currency
scale and `MidpointRounding.AwayFromZero`, matching SQL Server `ROUND`. The
same rounded per-position net result is used both in the trigger equity and in
the virtual close execution. This prevents the trigger and final balance from
diverging because of different rounding paths.

If a completed close set produces a negative balance, the adjustment amount is
exactly `-postCloseBalance`. If the balance is already exactly zero, no
adjustment is created. A positive post-close balance after an `Equity <= 0`
decision violates the frozen-snapshot invariant; the transaction must roll
back and be retried rather than deducting a positive balance.

## Stop Out Transaction

For one queued account, `SqlStopOutService` performs this sequence:

1. Begin a SQL transaction at `Serializable` isolation.
2. Acquire transaction-owned `sp_getapplock` for the account, using the
   existing bounded retry/deadlock pattern.
3. Re-read the trading account, open positions, pending orders, relevant symbol
   rules, sync version, and any existing run for the candidate risk version.
4. Validate that the immutable quote snapshot covers every open symbol and
   that every quote is within the existing 30-second freshness limit.
5. Calculate and persist `V2AccountRiskState` with a new `RiskVersion`.
6. If Equity is greater than zero, commit only the risk-state update and stop.
7. If Equity is zero or negative, insert or replay the unique
   `V2StopOutRun` for that account and risk version.
8. Sort positions by floating P/L ascending, then open time, then position ID,
   so history and events are deterministic.
9. Close every current remaining volume through
   `IPositionExecutionService` using the frozen Bid/Ask snapshot.
10. Cancel every pending order and preserve it with cancellation reason
    `stop-out`.
11. Recalculate the realized account balance from the persisted executions.
12. If the balance is negative, insert the unique
    `NegativeBalanceProtection` adjustment and apply it.
13. Assert that final stored Balance and Equity equal zero at the account
    currency scale, and that no open position or pending order remains.
14. Increment the account-scoped data version once for the complete Stop Out.
15. Write audit rows and typed outbox messages with that data version.
16. Mark the run completed and commit.

No SignalR call or other external I/O occurs inside this transaction.

### Position execution semantics

Each Stop Out close creates:

- one server-generated `V2Order` with role `exit`, reason `stop-out`, the exact
  locked remaining volume, and a link to the position and run;
- one `V2Deal` linked to the closing order, opening order, position, and run;
- an opposite-side exit deal (`SELL/out` for a BUY position and `BUY/out` for
  a SELL position);
- the realized profit, commission, swap, and net result; and
- a closed position state with remaining volume zero and its original identity
  preserved.

The execution service never routes an exit deal through the create-position
path. A deal side alone is never used to decide that an open position exists.

For manual closes, omitted/null volume continues to mean the full current
remaining volume, calculated after the account lock is held. Numeric volume
must be greater than zero, obey symbol lot-step rules, and be less than or
equal to locked remaining volume. The server rejects excess numeric volume; it
does not clamp it.

## Concurrency and Idempotency

Every trading mutation uses the same account lock. When a manual close races a
Stop Out, the first lock owner commits first and the second command re-reads
canonical state. The second command may close only what remains; it cannot
over-close or create a reverse position.

Required uniqueness constraints are:

- Stop Out trigger: `(TradingAccountId, RiskVersion)`;
- position execution: `(StopOutRunId, PositionId)`;
- pending-order cancellation: `(StopOutRunId, OrderId)`;
- NBP adjustment: `(StopOutRunId, AdjustmentType)`;
- closing command: unique server command key; and
- outbox event: unique logical event key plus globally unique `EventId`.

A rollback leaves no partial run. A retry after commit reads the completed run
and returns its canonical result without creating another order, deal,
cancellation, adjustment, audit entry, or logical event.

## Persistence Design

### New tables

`V2AccountRiskStates` stores one current row per account:

- account ID;
- Balance, Equity, Margin, Free Margin, and Margin Level;
- immutable quote-snapshot identifier and evaluated timestamp;
- `RiskVersion`; and
- rowversion.

`V2StopOutRuns` stores:

- run ID and account ID;
- trigger risk version and quote-snapshot identifier;
- trigger Balance and Equity;
- status (`started` while inside the transaction and `completed` before the
  transaction commits);
- final Balance and Equity;
- correlation ID and timestamps; and
- rowversion.

A failed pre-commit attempt rolls back the run row with the rest of the
transaction. Failure telemetry belongs in structured logs/health metrics and
must not leave a durable run that could block a valid retry.

`V2AccountAdjustments` is an immutable trading-account ledger containing:

- account and Stop Out run IDs;
- type `NegativeBalanceProtection`;
- display code `D-null`;
- currency, amount, before Balance, and after Balance;
- correlation ID and created timestamp; and
- the uniqueness constraint for one NBP adjustment per run.

`V2TradingOutboxMessages` contains:

- `EventId`, account ID, data version, event type, and serialized payload;
- logical event key;
- created/published timestamps;
- bounded attempt count, next-attempt timestamp, and sanitized last error; and
- indexes for unpublished dispatch order.

### Existing table changes

`V2Orders` gains nullable links and metadata for position ID, Stop Out run ID,
legacy trade-order ID, role (`entry` or `exit`), execution reason, and server
command key. Existing orders are backfilled as role `entry` without changing
their trading data. Existing legacy links are populated only where the source
relationship is deterministic.

`V2Deals` gains opening-order ID, commission, swap, net profit, Stop Out run ID,
and unique execution key. Existing `OrderId` values are copied to
`OpeningOrderId` where deterministic. Historical rows are not assigned
fabricated closing orders. For new exits, `OrderId` identifies the actual
closing order and `OpeningOrderId` identifies the entry order.

The trading account gains a rowversion as defense in depth against balance
lost updates. Open-position and pending-order lookup indexes must support
symbol-to-account risk fan-out without scanning all history.

The existing `MobileSyncVersion` remains the account-scoped public data
version. `RiskVersion` changes with risk evaluations; public `DataVersion`
changes only when canonical user-visible account/trade/history state changes.
Normal quote evaluation therefore does not create a realtime/history version
storm.

The migration is additive. Its numeric prefix is the first free number after
the existing `005` and other-worktree `006` changes are reconciled; based on
the audited state, the expected prefix is `007`. Migration, verification, and
guarded rollback files use the same resolved prefix.

## History Contract

History remains append-only from the user's perspective.

- Orders show the original entry order and the server-generated Stop Out exit
  order.
- Deals show entry and exit executions. `sell, out` means a SELL execution that
  closed a BUY; it is not an open SELL position.
- Positions show the original position as closed with its open-to-close prices
  and total realized result.
- Pending orders remain stored with canceled status and reason `stop-out`.
- Transactions include the NBP adjustment with code `D-null`, description
  `Negative Balance Protection`, its positive offset amount, and resulting
  balance zero.

The existing mobile order history keeps legacy original orders and adds V2
orders whose role is `exit`. Any broader legacy/V2 merge uses the explicit
legacy trade-order ID; it must not de-duplicate using symbol, price, or
timestamp heuristics. Existing history is neither deleted nor backfilled with
invented executions.

Summary totals include realized profit, commission, swap, and NBP adjustment
without counting the adjustment as trading profit. Net change reconciles to
the authoritative balance movement.

## HTTP and OpenAPI Contract

No public Stop Out mutation endpoint is added.

Existing close paths remain compatible. Their OpenAPI description explicitly
states:

- null/omitted volume means full locked remaining volume;
- numeric volume must be positive, lot-step valid, and no greater than locked
  remaining volume;
- server numeric volume is never clamped;
- HTTP 200 has an explicit response schema; and
- mutation headers and stable 400/401/404/409/503 errors are documented.

Bootstrap, Trade, and all History reads expose
`X-Server-Data-Version`. Existing JSON response envelopes remain unchanged;
new DTO members are optional additive fields. Each reader obtains its data and
version from one consistent read;
multi-query bootstrap uses a snapshot transaction or version-before/version-
after retry.

Deal/history DTOs add optional commission, swap, net profit, execution reason,
opening-order link, closing-order link, and Stop Out run link. Transaction DTOs
add optional typed adjustment fields and display code. Optional fields preserve
compatibility with older clients and historical rows.

The runtime Swagger and checked-in `docs/openapi-v2.json` must be regenerated
from the same build and tested for parity. The existing runtime/static OpenAPI
drift is removed as part of this change.

## Realtime Contract

The transaction enqueues these logical events as applicable:

- `StopOutTriggered`;
- `PositionClosed`;
- `OrderCanceled`;
- `DealCreated`;
- `AccountAdjustmentCreated`;
- `AccountSummaryUpdated`;
- `HistoryUpdated`;
- `StopOutCompleted`; and
- `AccountSnapshotInvalidated`.

Every event contains `EventId`, account ID, account-scoped `DataVersion`, Stop
Out run/correlation ID, event type, and the minimum typed payload needed by the
consumer. Publication is at least once. `TradingOutboxDispatcher` marks a row
published only after successful SignalR delivery and retries with bounded
backoff. It publishes only to the authenticated account group already resolved
by the linked-account authorization layer, never to a global group. Consumers
deduplicate by `EventId`.

## Flutter Behavior

Flutter continues to treat the server as the financial authority.

When it receives a newer Stop Out or snapshot-invalidated event, it performs a
canonical Bootstrap/Trade/History refresh. It accepts the composed snapshot
only when response data versions match; a mismatch triggers bounded GET-only
reconciliation. It never resends a committed mutation while reconciling.

The visible result is:

- Trade contains no position or pending order from the completed run;
- Balance and Equity show `0.00`;
- History shows closing orders, exit deals, closed positions, canceled pending
  orders, and `D-null` when an NBP adjustment was required; and
- `SELL/out` remains in Deals/History and is never inserted into the open
  position list.

Older optional fields remain safe during server/mobile rollout. The existing
exact-volume Flutter close payload remains unchanged; the server's null/full
semantics continue to support older clients.

## Failure Handling and Observability

- Missing, incomplete, stale, or out-of-order quotes cannot execute Stop Out.
  The account is requeued and a health signal is emitted.
- SQL deadlock or application-lock contention uses bounded retry. Exhaustion
  rolls back and requeues the account without partial financial state.
- A crash before commit rolls back the complete run.
- A crash after commit but before publish leaves durable outbox messages for
  dispatcher recovery.
- A malformed outbox payload is quarantined after bounded attempts and raises
  a health alert without undoing committed financial history.
- A frozen-snapshot invariant failure rolls back, requeues with a new snapshot,
  and raises a health alert after bounded consecutive failures.
- SignalR reconnect triggers quote snapshot recovery and full account-risk
  reconciliation.
- Structured logs include correlation ID, Stop Out run ID, anonymized account
  identifier, risk/data versions, result code, and duration. They exclude
  credentials, tokens, connection strings, complete financial payloads, and
  customer-identifying data.

Two independent feature switches control rollout:

- `RiskWorkerEnabled` starts quote intake and risk evaluation;
- `StopOutExecutionEnabled` permits the worker to execute the locked Stop Out
  transaction.

Observation mode enables the first switch and disables the second. It may
persist risk state and health metrics but cannot close/cancel/adjust accounts.

## Testing Strategy

### Domain and unit tests

- BUY/SELL floating P/L uses the correct Bid/Ask.
- Equity greater than zero does not trigger.
- Equity exactly zero and below zero trigger.
- Decimal currency rounding is identical across evaluation and execution.
- Position ordering is deterministic.
- Invalid/stale/incomplete quote snapshots are rejected.
- NBP amount is exactly the negative post-close balance and produces zero.
- A zero balance creates no adjustment.
- Numeric manual close rejects zero, negative, invalid-step, and
  over-remaining volume.

### SQL integration tests

- Stop Out closes all positions and cancels all pending orders atomically.
- A closing BUY creates a SELL/out exit deal but no open SELL position.
- Original and closing history links are correct and original rows remain.
- Commission and swap are included before NBP.
- Concurrent ticks create one run.
- Retry creates no duplicate order, deal, cancellation, adjustment, audit, or
  outbox record.
- Concurrent manual closes cannot lose a Balance update or over-close.
- Manual close racing Stop Out resolves under the account lock.
- Rollback injection leaves no partial Stop Out.
- Post-commit publish failure is recovered from outbox without duplicates.
- Stale/out-of-order ticks cannot overwrite a newer risk state.
- Multi-symbol evaluation uses one immutable complete quote snapshot.
- Startup/reconnect reconciliation catches an account already at or below
  zero.
- Migration verification covers columns, precision, defaults, indexes,
  rowversions, foreign keys, and uniqueness constraints.

These tests must execute against an isolated database configured by
`EXV2_TEST_SQL_CONNECTION`. A test that returns early when the variable is
missing is not accepted as evidence.

### Contract and Flutter tests

- Runtime and checked-in OpenAPI document the same paths and schemas.
- Mutation headers, close volume semantics, response, and stable errors are
  documented.
- Bootstrap, Trade, History, and realtime carry consistent data versions.
- Flutter deduplicates repeated event IDs and ignores older versions.
- A completed Stop Out renders zero Balance/Equity and complete History.
- `D-null` maps to a balance transaction, not trading profit.
- Exit deals never enter Flutter's open-position collection.
- Existing full/partial/bulk close reconciliation remains green.

### Required verification before deployment

- EX V2 build passes with zero errors and zero warnings.
- Unit, compatibility, and true SQL integration suites pass.
- Flutter analyze passes.
- Relevant Flutter trading/history/realtime tests pass.
- Flutter release build succeeds.
- Migration and verification SQL pass on an isolated restored schema.
- A dedicated virtual staging account passes Equity greater than zero, equal
  to zero, below zero, concurrency, retry, reconnect, and history smoke cases.

No test may issue a real financial mutation or use the production database as
its integration-test database.

## Deployment and Rollback

Implementation begins in an isolated branch/worktree based on the exact
deployed source commit. Existing dirty production-source changes are preserved
and not staged, overwritten, or silently incorporated. Migration numbering is
resolved before any schema file is created.

Deployment order is:

1. back up the production database and current release;
2. apply and verify the guarded additive migration;
3. deploy the tested EX V2 binary with both feature switches disabled;
4. verify health, schema, OpenAPI, outbox dispatcher, and market connectivity;
5. enable `RiskWorkerEnabled` only and validate observation results with a
   dedicated virtual test account;
6. enable `StopOutExecutionEnabled` and run the approved zero/negative-equity
   virtual smoke cases; and
7. monitor Stop Out, outbox, quote freshness, lock contention, and error
   metrics.

If a problem appears, disable `StopOutExecutionEnabled` immediately and roll
the application binary back to the previous release. The additive schema and
committed history remain. Destructive SQL rollback is prohibited once any
Stop Out or NBP production row exists unless data has been exported, a verified
backup is available, and explicit approval is given.

Flutter is built and tested only after the server contract is stable. A
TestFlight upload remains a separate explicit user action.

## Acceptance Criteria

The feature is complete only when all of these are demonstrated against the
virtual system:

1. A fresh quote snapshot with Equity greater than zero leaves the account
   untouched.
2. Equity exactly zero or below zero automatically closes every position and
   cancels every pending order without Flutter being open.
3. No Stop Out close creates an opposite open position.
4. A negative realized balance creates exactly one `D-null` adjustment and the
   final Balance and Equity are exactly zero.
5. History retains and correctly links the original order, closing order,
   entry/exit deals, closed position, canceled pending orders, commission,
   swap, profit, and adjustment.
6. Concurrent ticks, retries, restarts, and SignalR failures do not duplicate
   financial or history records.
7. Flutter converges to one authoritative data version and shows the same
   state after realtime update, manual refresh, and cold restart.
8. All required build, analysis, test, migration verification, staging,
   deployment, and rollback gates pass without using production financial data
   for tests.
