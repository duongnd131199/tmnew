# Trading Mobile

Android-first Flutter client for the virtual-money trading demo.

```powershell
flutter pub get
flutter run
```

Normal app runs use `https://trochoi.top` for REST candle history and SignalR
realtime updates. A different public origin can be selected with
`--dart-define=MARKET_API_BASE_URL=https://example.com`. No feed ingest key is
required or permitted in the client.

TASK-001 contains only a buildable application entry point and module folders.
Navigation, design tokens, mock data, and features are implemented by later
tasks.
