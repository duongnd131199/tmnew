# Gold price display reference

## Reference set

The authoritative gold-number references are the six 590 x 1280 images in
`iconMau/anhmau/SoVang/`, captured on 2026-09-09:

- `photo_2026-09-09_08-43-40.jpg`: New Order
- `photo_2026-09-09_08-44-07.jpg`: Position Modify
- `photo_2026-09-09_08-44-11.jpg`: History
- `photo_2026-09-09_08-44-14.jpg`: Market Watch
- `photo_2026-09-09_08-44-17.jpg`: Chart
- `photo_2026-09-09_08-44-21.jpg`: Trade

This reference supersedes older two-decimal XAU notes. It changes only gold
number precision and presentation; existing colors, sizes, weights, layout,
and behavior remain authoritative everywhere else.

## Shared precision

- XAU currency pairs and their broker-suffixed forms use exactly three
  fractional digits, including `XAU`, `XAUUSD`, `XAUEUR`, and `XAUUSD+`.
- Non-gold tickers that merely share the prefix, such as the `XAUG` ETF, keep
  their legacy precision rules.
- Price ranges, History rows/details, Trade rows, Chart axis/tags, pending-order
  labels, Low/High statistics, and order inputs show the full three digits.
- Market Watch Point and Spread calculations use the same `10^3` scale.
- BTC and non-gold instruments retain their existing precision rules.

Examples:

- `4375.463` is split visually as `4375.` + `46` + raised `3` in large quote
  controls.
- A range remains plain inline text: `4373.328 -> 4377.441`.
- Market Watch statistics remain plain inline text: `L: 4340.955` and
  `H: 4378.050`.

## Large quote typography

Market Watch retains the existing XAU styles:

- leading part: 16 pt, weight 400;
- final two normal pip digits: 27 pt, weight 700;
- new third digit: 14.5 pt, weight 700, raised 11 logical pixels so its
  top remains inside the price line and cannot be clipped;
- colors continue to come from the current live tick direction.

New Order and Position Modify retain their existing quote styles:

- leading part: 20.5 pt, weight 600;
- final two normal pip digits: 26.5 pt, weight 700;
- new third digit: 14.5 pt, weight 700, raised 8 logical pixels;
- the new digit inherits the exact current quote color.

Chart one-click tickets retain their existing quote styles:

- leading part: 16 pt, weight 700;
- final two normal pip digits: 24 pt, weight 700;
- new third digit: 14.5 pt, weight 700, raised 11.5 logical pixels so its
  top sits about 2.5 logical pixels above the adjacent pip digits while
  remaining inside the visible price strip;
- the new digit inherits the ticket's existing foreground color.

All number runs use tabular figures. The first two runs are deliberately
unchanged; only the third fractional digit is added and positioned as a
pipette.
