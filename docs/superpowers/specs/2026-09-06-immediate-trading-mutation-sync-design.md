# Immediate Trading Mutation Sync Design

## Scope

Fix only the EX V2 mobile state reconciliation that follows a successful order
create or position close. Do not change REST contracts, financial formulas,
navigation, visual styling, feature flags, or any unrelated workflow.

## Confirmed failure modes

- `POST /api/v2/orders` returns an order but not the created position. The app
  currently performs one bootstrap read before returning. If that read observes
  the pre-commit/cache snapshot, the accepted market order is not shown in
  Trade until a later refresh or app restart.
- Account Summary realtime can advance the local bootstrap version while a
  close request is in flight. The close response contains authoritative
  `affectedPositions`, `closedPositions`, `deals`, and history data, but the app
  currently rejects the entire close sync when its version is lower than the
  latest Summary version. History then depends on slower GET reconciliation.

## Design

For a reconciled market create, issue the mutation exactly once, then perform a
bounded sequence of GET bootstrap reads. Completion is confirmed by the exact
server relationship `recentDeals.orderId == createdOrder.id`, a non-null
`positionId`, and the corresponding open position being present. Pending orders
are confirmed by their returned order ID. A stale or temporarily unavailable
read never resends the mutation; the confirmed order remains in local state and
normal realtime/background reconciliation continues after the bounded window.

For a close response, treat the close operation payload separately from the
quote-sensitive account summary watermark. A valid response matching the exact
idempotency key, correlation ID, account, mode, and affected position IDs always
applies its position topology and canonical History rows once. When a newer
Account Summary is already present, preserve that newer summary, server time,
bootstrap version, and summary watermark while applying the close transaction.
This prevents data regression and makes Trade/History update in one state write.

## Safety and verification

- Never retry POST/PUT/DELETE mutations.
- Never infer a position by symbol, side, volume, or timestamp.
- Never downgrade a newer Account Summary or switch account scope.
- Keep existing fallback GET reconciliation for absent/malformed/mismatched
  close sync.
- Add regression tests for a lagging first bootstrap after create and a close
  response overtaken by a newer Account Summary event.
- Run focused tests, the relevant regression suite, `flutter analyze`, and an
  iOS Simulator debug build.
