# Phase 3 validation — 2026-09-19

The Trading tab loads the public quote snapshot, subscribes to SignalR
`QuoteUpdated`, keeps the newest timestamp per symbol, and resubscribes and
reloads the snapshot after reconnect. Quotes older than the backend's default
five-second freshness limit are labelled stale and no longer shown as live.
Quote rows and the top cards in Insights watch only their own symbol;
mini charts load M1 candles. Search, favorites, manual ordering, and symbol to
chart routing remain in the tab.

Insights shows explicit empty states for signals, events, and news because no
source for these feeds has been confirmed. Performance uses exit-deal `profit`,
including partial closes, for its 7/30/90-day filters and the server's
`bootstrap.performance.netProfit` for all time. Its account chip activates a
linked account and refreshes the result. The current contract does not provide
a combined result for every linked account. A page-limit error prevents a
truncated history total from appearing as complete.

The 360 logical-pixel widget test covers all three Phase 3 tabs without layout
overflows. `flutter analyze` reported no issues, `flutter test` passed 23 tests,
and `flutter build apk --debug` produced the APK. The backend
`dotnet build Trading.sln` succeeded with no warnings or errors, and
`dotnet test Trading.sln --no-build` passed 17 tests.

LDPlayer screenshots of the installed debug APK:

- [Trading](screenshots/phase3-trading-ldplayer.png)
- [Insights](screenshots/phase3-insights-ldplayer.png)
- [Performance](screenshots/phase3-performance-ldplayer.png)

The screenshots are raw emulator window captures at 488 × 1010. Frames from
the source video were decoded sequentially at 24, 26, and 28 seconds, then
compared side by side with the cropped app at 384 × 848:

- [Trading comparison](screenshots/phase3-compare-trading.png)
- [Insights comparison](screenshots/phase3-compare-insights.png)
- [Performance comparison](screenshots/phase3-compare-performance.png)

Trading's main structure and Performance's empty state are close to the video,
though the Trading rows are more compact and the logged-out header differs.
The final live screenshot also shows XAU/USD and ETH as stale while BTC updates,
confirming that freshness is tracked per symbol.
Insights differs materially in content: the reference shows news and economic
events, but the current API has no confirmed feeds for those sections, so the
app uses explicit empty states. Price values and symbols also change with live
data. No authorized logged-in demo account was available for an emulator check
of nonempty Performance or account switching; those paths were tested with
fixtures. The emulator's ADB connection was unavailable, so window capture and
input were used for visual checks.
