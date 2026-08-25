# Chart rapid one-click orders implementation plan

## Task 1: Lock the regression with tests

- Add a delayed-server concurrency test for EX V2 order commands.
- Start several market orders without awaiting earlier responses.
- Assert that every tap produces an immediate optimistic row and a unique command identity.
- Run the focused test and confirm the current implementation path fails at the chart interaction boundary.

## Task 2: Make chart market taps non-blocking

- Remove the global `_tradingCommandPending` guard from `_placeChartOrder`.
- Dispatch every market tap as its own asynchronous operation.
- Retain per-command server reconciliation and failure rollback.
- Leave `_placeChartPendingOrder` locking unchanged.

## Task 3: Regression verification

- Run focused chart and EX V2 trading-command tests.
- Run `flutter analyze` and the complete Flutter test suite.
- Build the debug APK.
- Install to the existing LDPlayer emulator without deleting or freeing drive D data.

