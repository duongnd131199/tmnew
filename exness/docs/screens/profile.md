# Profile, wallet, notifications, and settings

## Reference

- Video: `exness/IMG_1265.MP4`, 30–42 seconds.
- Decoded frames: `exness/docs/reference-frames/30s.png` through `42s.png`.
- App viewport: 384 × 848 pixels in the source video. The operating system
  status bar and bottom gesture area are outside the app's control on Android.

## Layout and interaction

- The Profile tab has a large left-aligned title at the top. Scrolling pins a
  smaller centered title and the settings button.
- The first card is a dark benefits banner. Account, Benefits, Deposit wallet,
  Electronic wallet, Referral, and Support sections follow in that order.
- “Hiển thị thêm” expands the benefits section. The list remains scrollable.
- The settings button opens a dismissible sheet with Options, Security, and
  Security actions. The Notifications row opens notification preferences.
- The wallet balance opens a sheet with the server wallet total, available and
  locked balances, and transaction history. A notification sheet lists server
  notifications and supports mark-read actions.
- Logout clears the app's secure device token and returns to the signed-out
  presentation.

## States

- Loading: a progress indicator appears while the session or sheet data loads.
- Empty: wallet transactions and notifications show a specific empty message.
- Error: failed wallet, notification, or settings reads show a retry action;
  failed settings writes retain the confirmed value and report the error.
- Success: server balances, settings, notifications, and transactions replace
  placeholders without inventing values from the video.

## API mapping and assumptions

- `bootstrap.wallet` is the only wallet aggregate exposed by EX V2. It appears
  under Deposit wallet as the **demo wallet**. The reference video's separate
  electronic wallet cannot be calculated from that aggregate.
- `GET /wallet/transactions` supplies wallet history. The list may contain
  different transaction types; the UI uses the type and amount reported by the
  server and does not synthesize financial references.
- `GET /notifications`, `PUT /notifications/{id}/read`, and
  `PUT /notifications/read-all` supply notification state.
- `GET /settings` supplies the account email/language and
  `tradeNotificationsEnabled` when present. Only that confirmed preference is
  editable through `PUT /settings` in this phase.
- EX V2 has no confirmed source for Bronze/EXD, eligibility, verification,
  referral totals, support articles, a distinct electronic wallet, PIN policy,
  biometric unlock, or balance hiding. These controls stay informational or
  disabled. Android does not reproduce the iPhone Face ID behavior.
