# MT5 iOS Silent Trading Feedback Design

Date: 2026-08-14

## Goal

Remove application-specific technical and success notifications that are not
part of the target MT5 iOS trading interaction. Trading actions must feel
immediate while server synchronization, idempotency, reconciliation, and
rollback continue to run underneath the UI.

## Scope

The change covers user-facing feedback produced by trading actions in:

- Trade positions and pending orders.
- New Order and Close Position tickets.
- Chart trading actions.
- Position modification.
- Wallet request success feedback where it exposes asynchronous processing.

Device activation and genuine failures remain visible, but their wording must
be short and user-facing. They must not expose server terminology, URLs,
correlation IDs, stack traces, synchronization state, or implementation detail.

## Interaction Rules

1. A valid tap immediately updates the optimistic account state and dismisses
   the relevant menu or sheet.
2. Do not show success SnackBars or transient messages for close, close-by,
   bulk close, pending-order cancel, or modification.
3. Do not render text such as "please wait", "sent to server", "synchronizing",
   "request sent", or "pending server processing".
4. Prevent duplicate submission while a command is in flight without adding a
   technical status message.
5. Keep the canonical order result UI when it represents a trading outcome:
   filled, pending, canceled, or rejected.
6. Keep actionable validation and failure feedback, including invalid volume,
   invalid price, insufficient margin, unavailable connection, and rejected
   order. Present it as a concise trading result, not infrastructure output.
7. If a mutation fails after an optimistic update, restore the prior state and
   show only the concise trading failure.
8. Background refresh and SignalR reconciliation remain silent.

## Message Policy

Remove:

- "Vui lòng chờ... Lệnh đã được gửi đến server".
- "Vị thế đã đóng, lịch sử đang đồng bộ".
- "Đã gửi yêu cầu đóng bởi".
- Success messages after bulk close, cancel, modify, order placement, or wallet
  request submission.
- Reconnect/synchronization progress presented as a popup or SnackBar.

Keep and normalize:

- Invalid input messages before submission.
- Trading rejection or unavailable-connection results.
- Device activation failure when the app cannot be entered.
- Destructive confirmation dialogs that exist in the target interaction.

Error text must describe the user-visible result and omit exception strings.

## Data Flow

```text
Tap
 -> validate locally
 -> apply optimistic state
 -> close action UI
 -> send idempotent command silently
 -> commit server snapshot
    or rollback optimistic state and show concise rejection
```

No API contract, token handling, idempotency key, database behavior, or server
deployment changes are required.

## Test Strategy

- Widget tests assert forbidden technical/success messages are absent during
  slow commands and after successful commands.
- Widget tests assert duplicate taps remain blocked.
- Widget tests assert concise validation/rejection feedback remains visible.
- Provider tests continue to verify optimistic updates and rollback.
- Run Flutter analyze, all Flutter tests, backend build/tests, debug APK build,
  installation, launch, and emulator log inspection.

## Acceptance Criteria

- No trading UI contains `server`, `máy chủ`, `đồng bộ`, `vui lòng chờ`,
  `đã gửi yêu cầu`, or equivalent infrastructure progress wording.
- Successful trading actions produce state changes rather than SnackBars.
- A slow network does not introduce a technical waiting message.
- A failed command restores state and gives a concise actionable result.
- Existing layout, navigation, and backend contracts remain unchanged.

## Non-goals

- Recreating proprietary MT5 assets or source code.
- Removing loading placeholders needed for initial screen rendering.
- Hiding genuine validation, rejection, authentication, or connectivity errors.
- Changing financial calculations or server execution behavior.
