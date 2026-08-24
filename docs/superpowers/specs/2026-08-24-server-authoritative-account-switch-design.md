# Server-Authoritative Account Switching Design

## Goal

Use the authenticated EX V2 server session as the only production authority for the account list and account switching. A user signs in once, then switches between server-returned accounts with one tap and without per-account passwords, reconnect grants, or local session selection.

## Root Cause

The production account catalog currently merges `GET /mobile/accounts` with locally stored account sessions and a cached linked-account catalog. That allows an account absent from the server response to remain visible. Selecting that stale row calls the activation endpoint, receives `404 account_not_found`, and redirects into the broker/password relink flow.

## Approved Architecture

1. `POST /mobile/auth/login` establishes one app session and returns the single device token stored by the client.
2. `GET /mobile/accounts` is the only authority for inactive account rows. The server bootstrap remains authoritative for the active account.
3. Selecting a server-returned inactive account calls `PUT /mobile/accounts/{id}/activate` exactly once.
4. A successful activation atomically publishes the returned bootstrap and restarts account-scoped realtime through the existing account activation coordinator.
5. Switching never routes to the existing-account password screen.
6. `404 account_not_found` refreshes the server catalog and reports that the row is no longer available. `401` or `403` invalidates the global authenticated bootstrap. Network and conflict failures preserve the current account.
7. Legacy local account-session and linked-account catalog storage are not read as production authorities. Existing storage keys may remain harmlessly unread until a focused cleanup removes them; they must never recreate account rows.

## Add-Account Boundary

Adding a genuinely new broker account remains a separate explicit action. Its password may be sent to `/mobile/accounts/link`, but it is not used during switching. The client must not persist reconnect grants or a per-account device-token registry for the switching flow.

## UI Behavior

- The active row stays first.
- A tap on an inactive row starts one activation operation and ignores repeat taps until it settles.
- Success closes the account list only after the new bootstrap is accepted.
- Failure leaves the current account selected and shows a safe message.
- No activation failure opens a password form.

## Verification

- A local-only account never appears in production.
- A server-returned account switches through `/activate` without `/login` or `/link`.
- A `404` refreshes the catalog and does not navigate.
- A `401`/`403` invalidates the global account state.
- A failed activation never publishes mixed account data.
- Flutter analyze, relevant tests, full test suite, backend build/tests, APK build, emulator install, and A/B/A smoke test are run before completion.

