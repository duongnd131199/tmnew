# EX V2 market-order production incident

Verified: 2026-08-13 UTC

## Scope

- Affected: `POST https://trochoi.top/ex/v2/api/orders` with `type=market`.
- Not affected: device authentication, bootstrap, market quote feed, pending-order create/cancel, or legacy web routes.
- Legacy `/ex/api/api/*` must not be changed or restarted while fixing this incident.

## Reproduction evidence

Account is active, device token is accepted, market feed is connected, and `XAUUSD+` has fresh bid/ask data.

Both market requests return HTTP 500 with an empty body:

1. `type=market`, `side=sell`, `volume=0.01`, `requestedPrice=null`
   - Correlation: `f7b2107a-e17c-4658-81c7-63d65d47199c`
2. `type=market`, `side=sell`, `volume=0.01`, `requestedPrice` set to the fresh server-feed bid
   - Correlation: `f3e99740-8e1f-459b-9e7c-096026365673`

No order, position, or deal is committed by either request.

Control probe:

- `type=limit` returns HTTP 400.
- `type=pending` with a distant requested price creates successfully and can be canceled successfully.
- Therefore the deployed contract uses `pending`, not `limit`/`stop`, and the shared route/auth/idempotency/database connection are working.

## Required server investigation

Run on the server:

```bash
journalctl -u ex-v2-api.service --since "2026-08-13 14:20:00 UTC" --until "2026-08-13 14:35:00 UTC" --no-pager
rg -n "f7b2107a-e17c-4658-81c7-63d65d47199c|f3e99740-8e1f-459b-9e7c-096026365673" /var/log /opt/ex-v2-api-src 2>/dev/null
rg -n "CreateOrderRequest|type.*market|V2Positions|V2Deals|executedPrice" /opt/ex-v2-api-src
```

Add an integration test with a deterministic fresh quote. One market request must atomically create one filled order, one open position, one deal, increment sync version once, and emit post-commit events. A retry with the same idempotency key must return the same order without duplicate rows.

The API must return structured failures (`code`, `message`, `correlationId`) instead of an empty HTTP 500. Do not deploy until build/tests pass and the legacy service/static checksum remain unchanged.

## Flutter changes already applied

- Trading commands await the server response and bootstrap refresh.
- Chart/New Order no longer report a match before server confirmation.
- Production errors are shown to the user; an empty 500 is shortened to `Lỗi máy chủ (HTTP 500)`.
- UI limit/stop selections are mapped to the deployed server value `type=pending`.
- Live position ticks update display profit, equity, free margin, and margin level while balance stays server-owned.
