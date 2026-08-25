# Immediate Post-Close Balance Design

## Goal

After EX V2 commits a full or partial position close, publish the first
authoritative post-close bootstrap balance to Flutter state immediately. Do not
hold the Trade balance behind slower deals, closed-position history, or History
summary reconciliation.

## Evidence and root cause

- `TradeScreen` watches `demoAccountProvider`, which reads
  `ExV2AccountViewState.balance`; the screen has no independent balance cache.
- `ExV2AccountViewState.balance` reads `bootstrap.summary.balance`, so the UI
  will rebuild as soon as a new bootstrap is published.
- A close optimistically removes/reduces the position immediately, but keeps
  the old bootstrap and therefore the old balance.
- After the close POST, `_retryCommittedCloseHistory()` fetches a bootstrap on
  each retry. When `_isCoreCloseVisible()` succeeds, it only assigns that
  bootstrap to `latestAuthoritativeCore`; it does not publish it.
- Publication currently waits until deals, closed history, and History summary
  all satisfy `_isCommittedCloseVisible()`, or until every retry is exhausted.
- Retry delays are 0, 150, 300, 600, and 1200 milliseconds, excluding HTTP
  latency. Consequently an already-returned server balance can remain hidden
  for more than 2.25 seconds.
- The existing tests assert the final balance after `closePosition()` returns,
  but do not assert the intermediate state while history is delayed. They
  therefore pass while the visible latency remains.
- The unrelated uncommitted wallet-history changes do not touch the close loop
  or the Trade balance provider.

## Required behavior

Use two authoritative publication phases:

1. **Core close publication:** after the close POST commits, poll bootstrap as
   today. As soon as a current, same-account bootstrap proves the full/partial
   close, publish its balance, equity, margin, free margin, positions, wallet,
   and version while retaining the last confirmed History collections.
2. **History completion:** continue the existing bounded GET-only
   reconciliation. When deals, closed history, and History summary become
   coherent, publish them without replacing a newer core snapshot or
   concurrent optimistic command.

The balance is "immediate" at the earliest safe point: the first authoritative
bootstrap returned after the server commits. Flutter must not predict realized
profit or calculate a new balance before that response.

## Safety constraints

- Send `POST /positions/{id}/close` exactly once.
- Never derive balance from displayed floating profit, close price, or a deal.
- Never retry the close mutation; retry only GET reads.
- Reject stale bootstrap versions and snapshots for another active account.
- Preserve concurrent order, protection, and account-switch operations.
- Preserve genuine close rejection rollback.
- A history outage must not roll back or hide an already-published canonical
  balance.
- Full and partial closes must follow the same publication rule.

## Acceptance criteria

1. While the post-close history request is deliberately blocked, Trade already
   exposes the updated bootstrap balance.
2. The close Future may still be waiting for History, but the balance provider
   has already notified listeners.
3. Full close removes the position and publishes the new balance together.
4. Partial close publishes server remaining volume and server balance together.
5. A stale first bootstrap cannot update the balance.
6. A history endpoint failure preserves the new balance.
7. Exactly one close POST is sent.
8. Final deals, closed history, and History summary still reconcile as before.

