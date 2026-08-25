# XAUUSD display audit

Verified on 2026-08-24 with the freshly built debug APK on `emulator-5560`.

## Result

- User-facing text displays `XAUUSD` without the broker suffix.
- Internal routing, market-data subscriptions, cache keys, and trading payloads keep the canonical `XAUUSD+` symbol.
- The display conversion is centralized in `mobile/lib/core/utils/trading_symbol_display.dart`.

## Runtime evidence

- `market.png`: Market Watch row.
- `symbol-menu.png`: symbol action menu.
- `chart.png`: chart header.
- `order.png`: new-order header.
- `history.png`: history rows.

## Automated evidence

- Flutter analyze: no issues.
- XAUUSD-focused Flutter regression suite: 97/97 passed.
- Flutter debug APK: built successfully.
- Backend solution build: 0 warnings, 0 errors.
- Backend tests: 17/17 passed.

The default-concurrency full Flutter run completed 575/576 tests; its only failure was the unrelated pixel-density test `realtime price and countdown use the thin price-axis stroke density`, which passed immediately when rerun alone.
