# BTCUSDT Display Scope Design

## Goal

Display `BTCUSDT` everywhere outside the Price (`Gia`) experience while preserving `BTCUSD` as the backend symbol and as the visible symbol inside Price.

## Approved display rules

- Price (`Gia`), symbol search, and symbol editing keep the visible text `BTCUSD`.
- Chart, Trade, History, order tickets, position details, dialogs, notifications, and profile surfaces display `BTCUSDT`.
- BTC order and position headers display `Bitcoin vs US Dollar Tether` on the second line.
- Embedded user-facing strings replace only the complete token `BTCUSD`; already-rendered `BTCUSDT` must not become `BTCUSDTT`.

## Data safety rules

- Models, provider keys, route query parameters, quote subscriptions, price precision checks, and API payloads keep `BTCUSD`.
- No server or realtime contract changes are part of this work.

## Acceptance criteria

- Automated tests prove the global trading display mapping and the Price-specific exception.
- The BTC close-ticket header shows `BTCUSDT` and `Bitcoin vs US Dollar Tether`.
- Existing order, close, chart, and navigation behavior continues to pass regression tests.
