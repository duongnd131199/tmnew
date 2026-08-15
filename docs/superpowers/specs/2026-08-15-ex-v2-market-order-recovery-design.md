# EX V2 Market Order Recovery Design

## Goal

Restore successful market-order execution through EX V2 while preserving the current mobile failure copy `Không thể đặt lệnh`.

## Confirmed evidence

- `NewOrderScreen` awaits `ExV2AccountController.createOrder`, but catches every failure and displays the same generic snackbar.
- The mobile repository sends `POST /orders` with a UUID `clientOrderId`, `type=market`, `side=buy|sell`, volume, optional SL/TP, `Idempotency-Key`, and `X-Correlation-Id`.
- The production OpenAPI document is reachable and defines `CreateOrderRequest` at `/api/v2/orders`.
- The repository incident report records two authenticated `XAUUSD+` market requests returning an empty HTTP 500 while pending-order create/cancel continued to work. Neither failed request committed an order, position, or deal.
- The local `backend/` package is only the market-data/read-only MT5 bridge. The failing order implementation belongs to the separately deployed EX V2 source under `/opt/ex-v2-api-src`.

The exact exception inside the current EX V2 market branch must be reconfirmed from current service logs before changing production code. The historical HTTP 500 narrows the failure boundary but is not a substitute for a fresh stack trace.

## Chosen approach

Fix the EX V2 market-order boundary rather than adding a mobile retry, local fake execution, or alternate API fallback.

The server must accept the existing mobile contract and execute a market order atomically:

1. Authenticate and resolve the active demo account from `X-Device-Token`.
2. Validate symbol, side, volume, account state, market-feed freshness, and available margin.
3. Resolve the execution price from the authoritative server market feed; the client does not send an executed price.
4. In one database transaction, create one filled order, one open position, one entry deal, update account/margin state, and increment the sync version once.
5. Commit before publishing order/position/deal and snapshot-invalidated events.
6. Replay of the same idempotency key and identical body returns the original result without duplicate rows.

No change is made to the legacy `/ex/api/api/*` service or the local read-only market backend.

## Mobile behavior

- Keep the existing order form, loading state, navigation, and generic failure message `Không thể đặt lệnh`.
- Keep awaiting the server response before showing success.
- Keep server state authoritative; do not create a local filled position as a fallback.
- Do not automatically retry a mutation with a new idempotency key.
- Diagnostic detail belongs in secure application/server logs using correlation IDs. Device tokens must never be logged.

## Server failures

Expected business failures return a non-500 response with a stable error code and correlation ID for logs, even though the current app continues to show the generic failure message:

- Invalid symbol, side, or volume: HTTP 400.
- Invalid/expired device token: HTTP 401.
- Stale quote, market unavailable, or insufficient margin: HTTP 422.
- Idempotency body conflict: HTTP 409.
- Unexpected exception: structured HTTP 500 with correlation ID, with the stack trace retained only in server logs.

No failure path may leave partial order, position, deal, balance, margin, or sync-version changes.

## Test strategy

### EX V2 integration tests

- A deterministic fresh quote plus an active funded account produces exactly one filled order, one position, and one entry deal.
- Buy uses the authoritative ask and sell uses the authoritative bid.
- Replaying the same idempotency key produces no duplicates.
- Invalid symbol/volume, stale quote, insufficient margin, and forced database failure commit no rows.
- Events are emitted only after commit.

### Mobile tests

- Success remains pending until the server returns and then displays the confirmed server order.
- A server failure preserves the form and shows exactly `Không thể đặt lệnh`.
- Repeated taps while submitting send only one mutation.
- Request JSON and authentication/idempotency/correlation headers remain unchanged.

## Deployment and acceptance

1. Capture a fresh failing correlation ID from logs without placing a new production order.
2. Reproduce the exception in an EX V2 integration test.
3. Apply the smallest server fix and run EX V2 build/tests.
4. Deploy only EX V2 with a recorded rollback artifact; do not restart or modify the legacy API.
5. Verify health, bootstrap, market feed, pending orders, and legacy checksums.
6. With explicit approval for a demo mutation, place one minimum-volume market order and verify the response, bootstrap position, deal/history, and database rows share the same lifecycle.
7. Replay the same captured request metadata in a controlled test to prove idempotency, then close the demo position and verify one realized result.

## Access requirement

Implementation and deployment require shell/source access to the EX V2 host containing `/opt/ex-v2-api-src` and `ex-v2-api.service`. The current Windows workspace does not contain that order service and has no configured SSH target. If access is unavailable, mobile-only changes cannot make market orders succeed.

## Out of scope

- Changing the visible error message.
- Client-side simulated fills or financial mutations.
- Automatic mutation retry.
- Changes to chart/order visual design.
- Changes to real-money broker execution.
- Restarting or modifying legacy `/ex/api/api/*`.
