# Close Position Stale-State Design

## Problem

The close command can commit on EX V2 before the closing deal is visible in
history. The app currently treats any later reconciliation failure as a failed
close, restores the old position, and lets the user submit the same close
again. The second request then receives `POSITION_NOT_FOUND` because the server
already closed the position.

## Design

- Keep the existing immediate optimistic removal.
- Treat the close POST as the mutation boundary. Roll back only when that POST
  fails and the server still reports the position as open.
- Treat bootstrap/history reads as reconciliation. A reconciliation failure
  must not restore a position after the close POST committed.
- Return an optional closing deal. If the authoritative deal is not available
  yet, the ticket returns to Trade and reports that history is synchronizing;
  it must not invent a close price or profit.
- On `POSITION_NOT_FOUND`, reload bootstrap. If the position is absent, accept
  the server state as an already-completed close and remove the stale UI row.
  If it remains open, restore the row and surface the original error.
- Preserve the current layout and production API contract.

## Verification

- Regression tests cover committed close with delayed history, stale 404,
  genuine close rejection, and the normal authoritative-deal path.
- Run Flutter analyze/tests, backend build/tests, build the debug APK, install
  it on LDPlayer, and verify the app launches without a fatal exception.
