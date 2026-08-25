# MT5 iOS Position Actions Parity Design

## Scope

Match the MetaTrader 5 iPhone position interactions in the Trade tab without
changing unrelated screens. The official iPhone behavior is the source of
truth for swipe commands, Close Position, Close By, Modify, Trade, Chart,
Depth of Market, and Bulk Operations.

## Interaction design

- Swiping a position from right to left reveals Context, Modify, and Close.
- Context Close Position and the swipe Close action open the existing close
  ticket. They do not submit the mutation from the context menu.
- The close ticket initializes volume to the selected position's full volume,
  allows a smaller valid volume, and passes that volume to EX V2. Full close
  removes the row optimistically; partial close reduces the visible volume.
- Close By is available only when an opposite position of the same symbol
  exists. Selecting it opens an opposite-position chooser. The user selects
  the ticket and explicitly taps Close.
- Close By reconciliation uses raw server state so unequal volumes preserve
  the remaining position. Deal types containing `out` or `close` map to an
  exit deal for History.
- Modify opens the position SL/TP editor; Trade opens a new-order ticket for
  the symbol; Chart and Depth of Market retain their existing routes.
- Bulk Operations remains in the positions section header.

## Error behavior

- Mutations use the existing optimistic state and idempotency headers.
- A genuine server rejection restores affected positions and displays the
  server error.
- A committed mutation is never reversed merely because history is delayed.
- The app never invents server close prices or realized profit.

## Compatibility

EX V2 already exposes close, partial volume through the close request, and
close-by endpoints. The active-account contract does not expose an accounting
mode; for this demo, Close By eligibility is derived from the existence of an
opposite same-symbol position and remains subject to server authorization.
