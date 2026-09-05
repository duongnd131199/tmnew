# Deposit Realtime Balance Synchronization Design

## Status

Approved in chat on 2026-09-05. Implementation requires access to the
production EX V2 source at `/opt/ex-v2-api-src`; no production deployment is
authorized by this document alone.

## Problem

Account `1234` created a USD 1,000,000 demo deposit at
`2026-09-05 09:03:00`. The History endpoints expose the transaction and report
a USD 1,000,000 deposit total, while a clean app restart still receives a USD
12,058 account balance from `GET /mobile/bootstrap`.

This proves that the server-owned financial views are inconsistent. Flutter
must not repair the mismatch by adding the request amount locally because a
replayed event, repeated REST hydration, or later canonical snapshot could
credit the same deposit twice.

## Goal

When a demo deposit is approved, update the authoritative trading-account
balance, history aggregates, account data version, and realtime clients from
one committed server operation. A connected Flutter client must show the new
Balance, Equity, Free Margin, deposit row, and History total immediately. A
disconnected client must converge to the same result through REST after
reconnect or restart.

## Non-goals

- Do not credit pending or rejected deposit requests.
- Do not calculate authoritative Balance, Equity, or Free Margin in Flutter.
- Do not change the market-data service or introduce real-money payments.
- Do not erase or rewrite trading or wallet history.
- Do not deploy or restart production without explicit authorization.

## Chosen Architecture

### Server transaction

The EX V2 deposit-approval operation must execute under the existing account
mutation lock and one SQL transaction:

1. Load and lock the deposit request and its trading account.
2. Replay the stored result when the request is already approved.
3. Reject any attempt to approve a rejected request or change its amount,
   currency, or account.
4. Insert exactly one immutable deposit ledger transaction.
5. Add the approved amount to the stored trading-account balance using
   `decimal` and the account-currency scale.
6. Rebuild the canonical account summary and History summary.
7. Increment the account-scoped data version once.
8. Persist an outbox event before committing.
9. Commit all changes or none of them.

The unique deposit-request identity must prevent double credit across retries,
concurrent approvals, process restarts, and outbox replay.

### Realtime contract

After commit, the outbox dispatcher publishes `DepositRequestUpdated` to the
active account group. Its envelope contains valid UUID `eventId` and
`correlationId`, the active `accountId`, the committed `version`, and a `data`
object with:

- `deposit`: the approved canonical deposit row;
- `transaction`: the immutable ledger/history transaction;
- `accountSummary`: canonical Balance, Equity, Profit, Margin, Free Margin,
  Margin Level, currency, account ID, and timestamp;
- `historySummary`: canonical deposit, withdrawal, realized profit, swap,
  commission, and net change totals;
- `version`: the same committed account data version.

The event is an additive fast path. `GET /mobile/bootstrap`,
`GET /history/summary`, `GET /history/transactions`, and `GET /deposits` remain
the recovery authority and must expose the same committed version and values.

### Flutter behavior

Flutter applies a valid decision snapshot immediately only when account IDs
and versions are coherent. Duplicate events are ignored by event identity. A
legacy, malformed, incomplete, foreign-account, or version-gap event queues a
canonical REST refresh instead of changing money locally.

On reconnect, app restart, or manual refresh, bootstrap is loaded before the
ancillary History endpoints. Hydration may add history rows but must never
overwrite a newer canonical account summary.

## Existing Inconsistent Deposit

Before repairing the USD 1,000,000 deposit, production must identify the
canonical deposit request, ledger row, account ID, current account balance,
and current account version without printing credentials or tokens.

The repair is idempotent:

- if the ledger exists but the account credit is absent, credit it once and
  publish the same canonical decision contract;
- if both ledger and credit exist, only rebuild stale projections/caches and
  republish the canonical snapshot;
- if ownership or amount cannot be proven, stop without changing money.

The repair preserves the original request and transaction timestamps and
writes a safe audit record.

## Error Handling

- Transaction failure leaves request, ledger, balance, version, and outbox
  unchanged.
- SignalR delivery failure does not roll back committed money; the outbox
  retries and REST remains authoritative.
- Flutter never substitutes a displayed deposit amount for a missing server
  summary.
- Logs may include masked account identity, deposit ID, status, version,
  correlation ID, and amounts, but never passwords or device tokens.

## Testing

Server tests must cover successful approval, pending/rejected behavior,
idempotent replay, concurrent approval, transaction rollback, account/history
version equality, and outbox delivery after commit. An integration test must
prove one approval changes bootstrap balance and History deposit by the same
amount exactly once.

Flutter tests must cover canonical approved events, duplicate delivery,
foreign-account events, malformed/incomplete payload fallback, version gaps,
REST recovery after reconnect, and stale hydration not erasing a newer
summary.

Completion requires server and Flutter builds/tests, an authenticated demo
smoke test using the minimum safe deposit, a clean app restart proving REST
convergence, and a Simulator screenshot. No real-money transaction is used.

