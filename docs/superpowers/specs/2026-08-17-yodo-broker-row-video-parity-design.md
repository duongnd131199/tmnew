# YODO Broker Row Video Parity Design

## Goal

Remove the remaining visible `YODO Demo Markets` text from the broker picker and render the live YODO broker as the reference-video row `Exness Technologies Ltd` / `Exness` with the yellow Exness mark.

## Root cause

The previous reference presentation was applied only to the account form header and server list. `BrokerListScreen` still rendered `MobileBroker.name`, `companyName`, and mark identity directly from the live API, so the preceding picker continued to show YODO.

## Design

- Add a presentation-only broker projection beside the existing reference-server catalog.
- Only broker ID `yodo-demo` receives the reference labels and Exness mark.
- Search, tap, info, selection, navigation, and API state retain the original `MobileBroker` with ID `yodo-demo`.
- Other brokers remain unchanged and live loading/empty/error behavior is preserved.
- Do not change backend data or the account-link request contract.

## Verification

- RED widget test proves the live broker picker currently exposes YODO.
- GREEN tests assert the two reference labels, yellow mark, and navigation to `/accounts/add/yodo-demo`.
- Full analyze, tests, builds, LDPlayer install, screenshot comparison, and forbidden-log scan complete the task.

