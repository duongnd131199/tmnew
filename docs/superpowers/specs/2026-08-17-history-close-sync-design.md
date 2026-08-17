# History Close Synchronization Design

## Goal

Make every closed EX V2 position shown in Flutter History agree with the
server's closing deals, including full close, partial close followed by final
close, and close-by. A closed row must show the correct effective close price
whenever the server supplies sufficient linked deal data.

## Current Failure

The client currently enriches a history position with a deal price only when
the linked exit deals contain exactly one distinct price. A position closed in
multiple parts naturally has multiple exit prices, so its History row keeps a
null `closePrice` and renders an em dash. Matching also reads only the history
position's `id`, although the mapper accepts both `id` and `positionId`.

After a close command, Trade is reconciled immediately from bootstrap, but
History is refreshed asynchronously. If the history endpoints lag the close
transaction, the closed position and its exit deals can temporarily disagree
without a guaranteed follow-up reconciliation.

## Chosen Design

Introduce a focused history reconciliation component in the account-sync data
layer. It will:

1. Prefer a server-provided `closePrice` or `exitPrice` on the position.
2. Normalize position identifiers from `id` or `positionId` and compare UUIDs
   case-insensitively.
3. Select only exit deals (`out`, `out_by`, `close`, or `exit`) linked to that
   position.
4. For one exit deal, use its execution price.
5. For multiple exit deals, calculate the volume-weighted average:
   `sum(price * volume) / sum(volume)`.
6. Refuse symbol/time guessing when identifiers are present but do not match.
   A legacy fallback may match symbol and close timestamp only when it resolves
   to one unambiguous exit group.
7. Return null instead of inventing a financial value when price or positive
   volume is insufficient.

The provider will use the same reconciler for ordinary hydration and
post-close reconciliation. After a committed close, it will fetch both history
positions and deals, publish a coherent pair, and perform bounded delayed
retries when the server has not exposed the closed position or linked exit deal
yet. Retries remain read-only and account-generation scoped, so a late response
cannot update a different active account.

## Data Rules

- A fully closed position appears in History and not in Trade.
- A partially closed position remains in Trade with the server's remaining
  volume; its exit deal appears in Deals, but the position enters closed
  position history only after final close.
- A position closed in parts displays the volume-weighted effective close
  price across all linked exit deals.
- Close-by deal types are treated as exits.
- Open positions returned accidentally by the history endpoint are excluded.
- Server values remain canonical; the client does not calculate realized
  profit, balance, or equity.
- A transient failure of one history endpoint must not erase the last confirmed
  history from the UI.

## Error and Race Handling

- A rejected close restores the optimistic Trade position as today.
- A committed close is never rolled back merely because History is delayed.
- Post-close retries stop when a closed row with a resolved close price is
  available, the active account changes, or the bounded retry count is
  exhausted.
- If the backend never supplies enough linked data, the UI continues showing
  an em dash rather than a fabricated price.

## Tests

Tests must be written and observed failing before production changes:

- Multiple partial-close deals produce a volume-weighted close price.
- `positionId` aliases and differently cased UUIDs still link correctly.
- Close-by exit deals contribute to the close price.
- Unrelated same-symbol deals do not contaminate the result.
- A committed close publishes matching history position and deal data.
- Delayed history becomes visible after bounded reconciliation.
- A history endpoint failure preserves the last confirmed history.
- Existing full close, partial close, rollback, account-switch, mapper, and
  History widget tests remain green.

## Scope

This change modifies only Flutter account-history reconciliation and its tests.
It does not change backend behavior, public URLs, authentication, trading
calculations, or the required technology stack.
