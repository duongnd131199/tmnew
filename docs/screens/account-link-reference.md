# Account link reference

## Reference

- `iconMau/anhmau/broker-list-exness.png`
- `iconMau/anhmau/exness-account-login.png`
- `iconMau/anhmau/exness-client-id-login.png`
- `iconMau/anhmau/exness-server-list-top.png`
- `iconMau/anhmau/exness-server-list-bottom.png`
- All five supplied images are 590 × 1280 pixels. The operating-system status
  area is reference context and is supplied by the device, not drawn by Flutter.

## Broker list

- The safe-area toolbar is 70 logical pixels high. Circular back and QR
  controls begin 21 logical pixels below the app safe-area origin.
- MetaQuotes is shown above Exness. Both rows are 62 logical pixels high and
  retain their information actions.
- The bottom search field remains functional and keeps the existing debounced
  repository query behavior.
- The search pill is 43 logical pixels high with the supplied Vietnamese hint,
  a white surface, and a soft shadow.

## Existing-account form

- The broker header is 84 logical pixels high. The registration and existing-
  account section bands remain 42 logical pixels high.
- Each registration row is fixed at 88 logical pixels and presents its existing
  full source string in at most two visible lines.
- The account type control switches between `Tài khoản giao dịch` and
  `Mã máy khách`. The latter changes only the identity label, keyboard type,
  and `cl1234` placeholder; the same controller and submission flow remain in
  use.
- Server, identity, password, and save-password rows are 49 logical pixels
  high. The save-password switch defaults to the enabled visual state.
- For security, the switch is presentation-only in this task: passwords are not
  persisted and the existing request behavior is unchanged.

## Server list

- The selected default display server is `Exness-MT5Trial5`.
- Reference rows follow the supplied image order through
  `Exness-MT5Real34`; each row is 49 logical pixels high.
- The scrollable content begins with 103 logical pixels of top content inset
  and moves behind the translucent 70-pixel toolbar while scrolling, matching
  the two supplied scroll states.
- `Exness-MT5Real20` and `Exness-MT5Real26` are retained after the supplied
  reference sequence. The live server ID and broker ID still back every
  presentation option.

## States and interactions

- Loading, empty, error, retry, broker selection, server selection, login,
  activation, registration feedback, forgot-password feedback, and search
  behavior remain wired to the existing application/repository flow.
- MetaQuotes remains a presentation-only fallback row.
- Selecting a server returns its original live identity even when a reference
  display name is shown.

## Verification artifacts

- Golden states:
  `mobile/test/goldens/account-link-reference/brokers.png`,
  `trading-account.png`, `client-id.png`, `server-top.png`, and
  `server-bottom.png`.
- iPhone 17 simulator captures:
  `docs/screenshots/account-link-reference/iphone17-brokers.png`,
  `iphone17-trading-account.png`, `iphone17-client-id.png`, and
  `iphone17-server-top.png`, and `iphone17-server-bottom.png`.

## Assumptions

- Clock, Dynamic Island, signal, battery, simulator chrome, and pointer overlays
  are operating-system evidence and are excluded from application parity.
- Existing hardcoded and repository-owned values are preserved. The supplied
  images determine presentation order and styling only.
