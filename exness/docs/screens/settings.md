# Settings sheet

## Reference

- `exness/docs/reference-frames/37s.png` to `40s.png`, 384 × 848.
- The sheet starts near y=55 in the source frame and covers the tab bar.

## Layout and states

- A close control sits at the left of a centered title. The content scrolls
  through Options, Security, and Security actions.
- `GET /settings` supplies the language label and notification preference.
  A long language value truncates inside its row on narrow screens.
- Loading shows progress. A read failure shows retry. The Notifications row
  opens a second sheet; `tradeNotificationsEnabled` is the only editable
  preference and is reread after a successful `PUT /settings`.
- A failed write keeps the last server-confirmed switch value and shows an
  error. The switch is disabled while the write is in progress.

## Assumptions

- PIN, Face ID, balance hiding, password changes, remote device security,
  and personal-area closure are disabled because this app has no corresponding
  platform or confirmed API implementation. The iPhone Face ID state shown in
  the reference cannot be reproduced on LDPlayer.
- Language and interface rows display server/device state. Changing them is
  unavailable until their contracts are confirmed.
