# Trade Wallet Icon Video-Parity Design

## Goal

Match the wallet/balance button in the Trade tab to `giaoDienMau/IMG_5526.MP4`, including the populated trading state shown at approximately 17.2 seconds.

## Evidence and root cause

- The reference shows a 42–43 logical pixel circular wallet button at the left of the Trade header while multiple XAUUSD positions are visible.
- The app already has a custom credit-card painter and a 42.666 logical pixel hit target in the correct header location.
- `_TradeHeader` currently wraps the entire left button in `if (empty)`, so it disappears whenever a position or pending order exists.
- The mismatch is therefore a visibility-state bug, not an API or wallet-data bug.

## Design

Render `trade-balance-button` unconditionally in `_TradeHeader`. Keep its existing position, hit target, semantic label, custom-painted card glyph, and balance-dialog callback. Preserve the existing centered profit/`USD` label and right-side add button.

Do not introduce an image asset, icon package, API call, or new state. The custom painter already matches the reference icon family more closely than a generic Material/Cupertino glyph.

## Behavior

- Empty account: wallet button remains visible and opens the balance dialog.
- Open positions: wallet button is visible and opens the same balance dialog.
- Pending orders only: wallet button is visible and opens the same balance dialog.
- Profit text, account values, list layout, order actions, and server synchronization remain unchanged.

## Verification

- Add a widget regression test for a populated account.
- Retain the existing empty-account button test.
- Run Trade/video regression tests, analyzer, complete mobile tests, and Android debug build.
- Install on LDPlayer and capture the populated Trade header for comparison with the 17.2-second reference frame.

## Scope

Only the Trade header wallet icon visibility and any evidence-backed subpixel painter adjustment are in scope. No wallet business logic or API contract changes are allowed.
