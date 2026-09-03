# EX V2 Close Sync App Update Design

## Goal

Apply the canonical close snapshot returned by production EX V2 immediately
after full close, partial close, bulk close, or close-by. The normal success
path must update Trade and History atomically without waiting for History GET
polling.

## Authoritative Contract

Production runs backend commit
`26499ff898eba974054f145f29cc878145f142a1`. Full/partial close return
`ClosePositionResponseDto`; close-by returns `CloseByResultDto`; both include a
required `CloseSyncDto`. SignalR publishes the same snapshot in
`CloseExecutionCommitted.data` after commit.

`CloseSyncDto` is operation-scoped. Its positions, closed positions, orders,
and deals must be upserted by canonical ID rather than replacing complete local
collections. Account and History summaries are canonical replacements for the
same snapshot version. The app must not calculate balance, equity, realized
profit, close price, or History totals from other fields.

## Chosen Design

Keep the existing Riverpod account controller and make its close-sync reducer
the single state mutation entry point for HTTP and realtime. The reducer will:

1. Reject a snapshot for another active account or with an incoherent shape.
2. Deduplicate by `(accountId, version, idempotencyKey)` and, for realtime,
   `eventId`.
3. Ignore a version older than the current bootstrap version.
4. Atomically upsert affected entities and replace both canonical summaries.
5. Apply a version gap immediately, then queue one background reconciliation.
6. Bound and clear deduplication state when the active account changes.

HTTP validates operation mode, IDs, idempotency key, and correlation ID against
the command it sent before passing the snapshot to the reducer. A valid
snapshot completes without close-specific polling. A missing, malformed, or
mismatched snapshot keeps the existing bounded GET-only compatibility
reconciliation. Bulk close reconciles only operations that did not return a
valid sync.

Realtime parsing exposes envelope `eventId` and `correlationId`. HTTP and
realtime may arrive in either order; the canonical snapshot is published once
and entity lists remain duplicate-free. Legacy realtime events remain
invalidation signals.

## Safety and Compatibility

- A user action creates one command metadata pair; no verification POST is
  sent.
- Existing retry/reconciliation code performs GET requests only.
- `double` values are parsed for display and existing UI models only; this
  change introduces no financial calculation.
- Old server responses without `sync` remain supported.
- Account switch, stale snapshot, optimistic close rollback, automatic
  stop-out, and grouped close protections remain intact.
- Tokens, credentials, and full financial payloads are never logged.

## Verification

- Model tests cover the live full/partial/close-by response shapes.
- Realtime tests cover envelope metadata.
- Controller tests cover HTTP-first, event-first, event retry, account
  isolation, stale version, version gap, no success-path polling, and legacy
  fallback.
- Run Flutter analyzer, the EX V2 regression suite, iOS simulator build, and
  Android debug build.

