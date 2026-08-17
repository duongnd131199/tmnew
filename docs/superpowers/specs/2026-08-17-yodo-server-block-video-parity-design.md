# YODO Server Block Video Parity Design

## Goal

Make the YODO account-link server presentation match `giaoDienMau/themmoitk.MP4`: the form header presents `Exness Technologies Ltd` with the square yellow Exness mark, and the server value/list use the full-width reference server typography and names.

## Scope and data contract

- Apply the reference presentation only when the real broker ID is `yodo-demo`.
- Keep the real broker ID `yodo-demo` and real server ID `yodo-demo-01` unchanged for selection and API submission.
- Present `Exness Technologies Ltd`, the yellow `exness` mark, and the fixed reference server names only in the UI.
- Keep loading, empty, retry, and error states backed by the real API. Do not fabricate availability.
- Do not change login, password, device-token, or account-link request behavior.

## Components

- `reference_server_catalog.dart` owns the scoped reference display profile and the mapping from display aliases to live server identities.
- `AccountLinkBrokerMark` accepts a presentation-only Exness override while retaining the original broker key and object.
- `ExistingAccountLoginScreen` applies the profile to the header and selected server row.
- `TradingServerScreen` uses the same reference server typography so the selected value and catalog rows remain visually consistent.
- `AppTypography.referenceServerName` is a semantic regular-width sans-serif token; the rest of the app typography is unchanged.

## Verification

- Widget tests first fail against the current YODO title, round mark, condensed type, and then pass after implementation.
- Tests assert the reference name/logo/block geometry and verify selecting an alias still returns `serverId == yodo-demo-01`.
- Run focused tests, full `flutter test`, `flutter analyze`, debug APK build, install on LDPlayer, and compare fresh screenshots with the video frame.

