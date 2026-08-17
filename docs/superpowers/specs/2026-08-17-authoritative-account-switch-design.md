# Authoritative Account Switch Design

## Goal

After a successful account login or linked-account activation, publish and display only the bootstrap data belonging to that account, even when its account-scoped bootstrap version is lower than the previously active account's version.

## Root cause

`publishBootstrap` compared bootstrap versions before considering account identity. A newly linked account can start at version 1 while the old active account is at a higher version, so the valid activation response was rejected as stale and the UI retained the old account.

## Design

- Add an explicit `authoritativeAccountSwitch` publication intent.
- Account activation and direct account/password login use this intent.
- For a different account, an authoritative publication ignores cross-account version ordering and atomically replaces the entire account view state.
- Concurrent linked-account activations remain ordered by `operationAuthority`; an older response cannot replace a newer accepted activation.
- For the same account and for ordinary refresh/reconciliation, existing version checks remain unchanged.
- Bootstrap account ID and summary account ID validation remains mandatory.

## Verification

- RED/GREEN tests cover switching from a high-version old account to a low-version new account.
- Tests assert account, summary, wallet, positions, orders, deals, and presentation all belong to the new account.
- Existing out-of-order activation tests continue to reject late responses.
- Full Flutter and backend verification plus an LDPlayer smoke test complete the change.

