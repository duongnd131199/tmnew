# Demo wallet sheet

## Reference

- The Profile rows appear in `exness/docs/reference-frames/31s.png`, `34s.png`,
  and `35s.png`. The video does not open the wallet details or a money form.

## Layout and states

- The Profile row uses `bootstrap.wallet.totalBalance` and its currency.
- The detail sheet shows the server's total, available, and locked balances,
  followed by `GET /wallet/transactions`.
- Loading, empty, and retryable error states are separate. Transaction amount
  and status come from the server; an unknown type has a neutral amount with no
  inferred inflow/outflow sign. Missing amounts remain unknown.

## Assumptions

- The EX V2 wallet is displayed as a **demo wallet** under Deposit wallet. It
  is not the distinct electronic wallet in the reference video.
- Deposit, withdrawal, and transfer forms are outside the captured video. The
  existing account shortcut placeholders are unchanged in this phase.
