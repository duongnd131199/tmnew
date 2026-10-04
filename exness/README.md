# Exness demo app

This is a separate Flutter Android app. It has its own Android application ID,
`com.tradingdemo.exness`, so it can be installed beside the existing `mobile`
app without replacing it.

The app opens in a **video preview** by default. All five tabs, the account
detail sheet, settings, and the chart use fixed local fixture values from the
supplied recording. These values are visual samples only; they are not live
prices, balances, transactions, or tradable quotes. Local controls allow the
recorded screen states to be inspected without an API session.

The existing live API paths remain in the app for later integration. To run
those paths instead of the visual preview:

```powershell
flutter run --dart-define=VIDEO_DEMO_MODE=false
```

In live API mode, market quotes load from REST, then receive `QuoteUpdated` ticks from the
SignalR market hub. The app keeps the last valid quote while reconnecting and
resubscribes and reloads a REST snapshot after a connection is restored. A
quote older than five seconds is labelled stale and its old price is hidden.
The visible `XAU/USD` label maps
to the API symbol `XAUUSD+`. Override the public market origin if needed:

```powershell
flutter run --dart-define=MARKET_API_BASE_URL=https://example.com
```

The chart uses a local copy of TradingView Lightweight Charts 5.2.1 in a
Flutter WebView. It loads candle history once per symbol/timeframe and updates
the latest candle and Bid/Ask lines from the quote feed without page reloads.
The default video preview supplies a deterministic local candle series and
Bid/Ask labels instead.
The chart's TradingView attribution logo links to TradingView. The library's
Apache 2.0 license is included under `assets/chart/`. The market API does not
currently provide older-candle pagination or the next market opening time.

In live API mode, Performance shows 7, 30, or 90 days of exit-deal `profit`, including partial
closes, for the active account. “Toàn bộ thời gian” reads the server's
`bootstrap.performance` aggregate. The account chip can activate another linked
account; the API does not currently provide an aggregate across every account.
The app reports a history loading error if its pagination safety limit is
reached, so a truncated total is not displayed.

## Run

```powershell
cd exness
flutter pub get
flutter run
```

## Verify

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

See [Phase 3 validation](docs/phase3-validation.md),
[Phase 4 validation](docs/phase4-validation.md), and
[Phase 5 chart validation](docs/phase5-validation.md) for the earlier live API screens,
LDPlayer captures, and current API limits.

## Manual check

1. Log in with an authorized demo account and open **Giao dịch**. Confirm live
   prices update, search filters symbols, editing changes favorites, and tapping
   a symbol opens its matching chart route.
2. Disconnect and reconnect the emulator's network. Confirm the status message
   appears and prices resume without returning to the tab.
3. Open **Hiệu suất**. Check 7/30/90-day results against exit deals, including
   partial closes, and the all-time total against `bootstrap.performance`.
   Switch between linked accounts and check the empty and retry states.
4. Open **Hồ sơ**. Check that the demo wallet balance matches
   `bootstrap.wallet`, the wallet sheet shows server transactions, and separate
   electronic-wallet/referral/loyalty values are not invented.
5. Open the Account bell. Check unread notifications, mark one read, mark all
   read, and retry after a network failure.
6. Open **Hồ sơ → Thiết lập → Thông báo**. Change the trade-notification
   preference, reopen the sheet, and confirm the server value persists. Check
   logout clears the account and wallet data from the UI.
