# Residual fix report

## Outcome

Both final re-review blockers are closed.

1. `_mergeCoreWithHydrated` now carries the hydrated `ExV2AccountPresentation` into every same-account core reconciliation that uses the helper. The regression activates the second linked-broker fixture, keeps `/settings` empty, performs `updatePositionProtection`, and verifies both state and mapped profile still expose `Second Broker Ltd` / `Second-Live-02`.
2. Recorded playback account, balance, margin, position, order, deal, history, timestamp, and quote data no longer live in production Dart. Production demo mode retains generic accounts, neutral quotes, and one small EURUSD seed without EX-branded success. The recorded corpus is now under `mobile/test/test_support/video_reference_fixtures.dart` and affected playback tests inject it through Riverpod overrides.

No backend or prompt files changed.

## TDD evidence

- Presentation regression RED: `flutter test --no-pub test/account_activation_coordinator_test.dart` failed because `state.presentation.companyName` was null after protection reconciliation.
- Presentation regression GREEN: the same file passed 3/3 after preserving `hydrated.presentation` in `_mergeCoreWithHydrated`.
- Production-data scan RED: `flutter test --no-pub test/production_reference_identifier_test.dart` reported 17 recorded financial/trade literals in `demo_data_provider.dart`, then four recorded quote literals in `section_screen.dart` after the first removal.
- Production-data scan GREEN: the broadened source gate passed after removing all detected production literals.

## Final verification

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --concurrency=1`: 264 tests passed.
- `flutter build apk --debug --no-pub`: built `build/app/outputs/flutter-apk/app-debug.apk` successfully.
- Debug APK size: 159,925,059 bytes.
- Debug APK SHA-256: `85D806F27FE3B0B8E3ADBFF71B55ADE0A4413D41F908AB1D2E07E76A30F85D9D`.
- Expanded literal scan: 35 prohibited recorded account/server/financial/trade literals checked across `mobile/lib` and every extracted APK entry; source hits 0, APK hits 0.

## Residual concerns

- None in the requested mobile scope. The separately deployed EX V2 endpoints remain externally unverified, unchanged from the re-review assessment.

## Final residual re-review closure

The remaining `section_screen.dart` production-reference finding is closed.

- Symbol properties now obtain the price source from the active account catalog. Hydrated server accounts therefore expose their real company name; an unavailable account produces the neutral `—` state. No EX V2 success state is synthesized.
- Swap long/short, blocked margin, and margin rate no longer contain recorded values and render `—` because no authoritative symbol-specification provider exists.
- Market bid and ask still use the existing quote provider. Unsupported last/open/high/low/volume/tick fields now render `—` instead of recorded or calculated fixture values.
- The production source gate now includes every cited value: `-41.36`, `24.24`, `50.00`, `100.00%`, `Vantage`, `4063.33`, `4115.79`, `3959.93`, `6 336`, and `6336`.

### TDD evidence

- RED: the expanded source gate reported the nine actual `section_screen.dart` occurrences, and the widget tests could not find account-derived/unavailable values.
- GREEN: the source gate plus new section behavior tests passed 3/3; the focused section suites passed 6/6.

### Final verification

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --concurrency=1`: 266 tests passed.
- `flutter build apk --debug --no-pub`: built `build/app/outputs/flutter-apk/app-debug.apk` successfully.
- Debug APK size: 159,925,059 bytes.
- Debug APK SHA-256: `876789D89359A68A45B768BB372E731163D8CED557BABF997E8C6D0D85F194A9`.
- Expanded exact-literal scan: 45 prohibited recorded account/server/financial/trade entries checked across `mobile/lib` and every extracted APK entry; source hits 0, APK hits 0. Numeric artifact checks use digit/decimal boundaries to avoid false matches inside unrelated compiled coordinates and native constants.
- Repeatable gate: `scan-production-reference-data.ps1 -ApkPath mobile/build/app/outputs/flutter-apk/app-debug.apk` exits nonzero on either source or APK hits; the final run reported `LITERAL_COUNT=45`, `SOURCE_HIT_COUNT=0`, and `APK_HIT_COUNT=0`.

No backend or prompt files changed. No additional mobile concerns remain for this residual finding.
