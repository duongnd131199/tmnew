# Order Rejection Diagnostics Design

## Evidence collected on 2026-08-20

- The installed debug app is `com.tradingdemo.trading_mobile`, updated at
  2026-08-20 17:11 local time on the running LDPlayer instance.
- The active account shown by Settings is account `3428`.
- The Trade screen reports balance `0.00`, equity `0.00`, and free margin
  `0.00`.
- The History screen reports deposit `0.00`, profit `0.00`, commission `0.00`,
  and balance `0.00`, with no committed trade row.
- The Quotes screen continues to receive XAUUSD+ and BTCUSD prices, so the
  visible failure is not explained by a disconnected quote feed.
- `ExV2AccountController.createOrder` already treats a successful POST as the
  command boundary and performs the follow-up bootstrap in
  `_refreshAfterMutation()`. A failed refresh cannot produce the current
  generic order error after the POST has succeeded.
- Both New Order and Chart catch every exception and replace it with the fixed
  text `Không thể đặt lệnh`. The typed `ExV2RequestFailure` already retains the
  HTTP status, server code, readable message, and correlation ID, but neither
  order UI exposes them.

## Diagnosis

The active account has no funds or free margin. That is the immediate reason a
normal market order cannot be accepted. The exact server rejection code cannot
be recovered from the installed app because the UI discards the exception and
the app does not log it. No extra order was submitted during diagnosis.

This is two separate concerns:

1. Account readiness: account `3428` needs a legitimate demo deposit/balance
   before an order requiring margin can succeed.
2. Client diagnostics: genuine server rejections must remain visible instead
   of being flattened into one generic message.

## Chosen design

- Keep the server authoritative for balance, free margin, order validation,
  and rejection messages.
- Do not invent or hard-code money in Flutter.
- Restore demo funds through the existing server/admin wallet workflow.
- Add one shared presentation helper that exposes safe EX V2 errors and falls
  back to the current short copy for unknown exceptions.
- Use the helper from New Order and Chart for market and pending commands.
- Preserve the current optimistic rollback, idempotency, POST-success boundary,
  and background refresh behavior.

## Acceptance criteria

1. Account `3428` has positive server-owned balance/equity/free margin before
   the success probe.
2. A structured HTTP 422 rejection displays the server message, safe code, and
   safe correlation ID.
3. A missing token or network failure displays its typed safe message.
4. An unknown exception still displays `Không thể đặt lệnh` (or the pending
   equivalent) and never leaks stack traces or secrets.
5. A successful POST still produces exactly one server order and never retries
   the mutation automatically.
6. A follow-up bootstrap failure still cannot turn an accepted order into a UI
   failure.
7. The same behavior is covered on New Order and Chart.

