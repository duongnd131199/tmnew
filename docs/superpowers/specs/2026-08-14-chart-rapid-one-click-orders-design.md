# Chart rapid one-click orders design

## Goal

Make every BUY or SELL tap in the chart one-click panel respond immediately and submit exactly one independent market-order command. A slow response for one command must not block or discard later taps.

## Current failure

`ChartScreen._placeChartOrder` uses the same `_tradingCommandPending` boolean for the full duration of the HTTP request and account refresh. While it is true, every later BUY/SELL tap returns `false`, so rapid taps are silently lost.

## Design

- Remove the shared pending lock from chart market orders only.
- Start each EX V2 market-order command independently. `ExV2AccountController.createOrder` already creates a unique command metadata/idempotency key before its first await and inserts a `sending` row optimistically.
- Keep the official position, execution price, balance, and history server-authoritative. Do not invent a filled position locally.
- Preserve the lock for pending-order confirmation dialogs, where duplicate confirmation is still undesirable.
- Preserve per-command failure rollback and error handling; one failed request must not cancel other in-flight commands.
- Do not change the API contract, UI geometry, colors, or chart layout.

## Acceptance criteria

1. Three rapid taps while the server response is blocked create three in-flight commands.
2. Each command has a distinct client/idempotency identity.
3. The UI exposes three optimistic `sending` rows before the server replies.
4. Server confirmations reconcile into authoritative state without duplicate requests.
5. Pending-order confirmation remains guarded against duplicate submission.

