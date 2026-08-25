# Order success must survive refresh failure

## Evidence and root cause

- The production device token, active account, market feed, and `POST /orders` contract are valid.
- A production probe for `XAUUSD+`, BUY, volume `0.25` returned HTTP 201 and a filled order.
- Taps made through the installed app also appeared in the next server bootstrap.
- The app currently treats `POST /orders` and the following bootstrap refresh as one fallible operation. A refresh failure therefore throws from `createOrder`, removes the optimistic row, and shows “Không thể đặt lệnh” even when the order was accepted.

## Chosen design

HTTP order acceptance is the command boundary. After a successful POST, replace only that command's `sending` row with the confirmed server order, clear only its pending-operation marker, and return success. Refresh account/position state in the background through a refresh path that preserves the last valid state when the follow-up read fails.

This keeps the server authoritative: the app does not invent an execution price or position. It uses the confirmed order response immediately and obtains positions, balance, equity, and history from bootstrap/SignalR afterward.

## Alternatives rejected

- Keep awaiting bootstrap but suppress its exception: avoids the false error but still makes command completion depend on a slow secondary read.
- Retry the POST: unsafe and unnecessary because the server already accepted it; idempotency protects retries but does not justify extra network traffic.
- Remove all error messages: hides genuine POST rejection and authentication/network failures.

## Acceptance criteria

1. A successful POST returns a confirmed order even if the next bootstrap fails.
2. The confirmed order remains in state and its `sending` marker is cleared.
3. A genuine POST rejection still rolls back only that command and throws the server failure.
4. Background refresh failure keeps the last valid account state.
5. Rapid commands remain independent and keep unique idempotency keys.

