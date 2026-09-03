# Codex Instructions

Before any implementation, read:

- META_TRADER_CLONE_GUIDE.md
- README.md
- docs/architecture.md
- docs/design-system.md

Do not change the required technology stack without approval.
After every task, run build, analyze and relevant tests.

## TestFlight internal releases

Use the established internal-update flow for every iOS beta release:

1. Check the highest build number currently visible in App Store Connect.
2. Run `scripts/build-testflight-internal.sh --last-build <highest-build>`.
3. In Xcode Organizer, choose **Distribute App → TestFlight Internal Only**.
4. Wait until the new build appears under **Internal Testers** with status
   **Testing** before reporting completion.
5. Existing internal testers then refresh TestFlight and tap **Update**. Do not
   reinvite their email addresses unless they are not already accepted internal
   testers.

The TestFlight build number is a 12-digit `YYYYMMDDHHmm` value and must be
strictly greater than the previous uploaded build. Pass it to Flutter as an
iOS-only `--build-number` override. Never save this 12-digit value in
`mobile/pubspec.yaml`: Android version codes must remain at or below
`2100000000`. The release script preserves the Android-compatible pubspec
version, verifies both the archive and IPA build numbers, registers the archive
with Xcode Organizer, and records the latest prepared build in
`scripts/testflight-internal-last-build.txt`.
