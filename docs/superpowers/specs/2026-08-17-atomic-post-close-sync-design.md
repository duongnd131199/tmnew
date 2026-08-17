# Atomic Post-Close Synchronization Design

## Goal

After a successful EX V2 position close, Flutter must expose the authoritative
balance, open positions, closed-position history, exit deals, and history
summary as one coherent post-close state before the close operation completes.

## Evidence and Root Cause

Production OpenAPI has no composite close/snapshot endpoint. The supported
contract is `POST /api/v2/positions/{positionId}/close` followed by reads from
`GET /api/v2/mobile/bootstrap`, `GET /api/v2/history/deals`,
`GET /api/v2/history/positions`, and `GET /api/v2/history/summary`.

Flutter already performs the close and reads bootstrap plus history, but a
delayed-history retry is launched with `unawaited`. Consequently,
`closePosition()` can finish after publishing the new bootstrap balance while
the closed position is still absent from History. The post-close snapshot also
omits `history/summary`, leaving History totals stale until a later general
refresh.

## Chosen Design

Keep the production API paths unchanged. Treat the close POST as the only
mutation and never repeat it after it commits. For a full close, load bootstrap,
deals, closed positions, and history summary, reconcile the close price from
the linked exit deals, and require the target position to be absent from Trade
and present in resolved History. If history is briefly delayed, await the
existing bounded read-only retry sequence before completing the close.

Publish each fetched post-close snapshot in one Riverpod state assignment so
balance, positions, deals, closed history, and History totals come from the
same reconciliation attempt. All awaits remain scoped to the active account;
a response from an older account is discarded. Partial close keeps the
authoritative remaining position and refreshes the same financial collections
without requiring a closed-position row.

If history remains unavailable after the bounded retries, retain the latest
authoritative bootstrap and the last confirmed history instead of fabricating
prices or profits. Realtime or manual refresh can continue reconciliation.

## Safety and Compatibility

- Do not add or guess an unsupported server route.
- Generate exactly one idempotency key for the close mutation.
- Retries issue GET requests only; they never resend the close POST.
- Server values remain canonical; Flutter does not calculate balance, equity,
  realized profit, or History totals.
- Do not log request bodies, device tokens, credentials, or financial payloads.
- Preserve optimistic removal and genuine-failure rollback behavior.

## Tests

- A delayed history response is resolved before `closePosition()` returns.
- The committed snapshot updates balance and History summary together with the
  closed row and its exit deals.
- A delayed reconciliation performs one close POST and only repeats GET reads.
- A stale response cannot update a different active account.
- Existing full close, partial close, close-by, rejection, history mapping, and
  pagination tests remain green.

