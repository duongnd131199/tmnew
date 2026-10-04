# Video preview validation

The default Flutter launch uses local fixture data to reproduce the supplied
`IMG_1265.MP4` recording. The app remains a separate demo application; no
preview balance, quote, article, event, or history item comes from a live
account or can be submitted as a trade. Run with
`--dart-define=VIDEO_DEMO_MODE=false` to inspect the retained API screens.

The reference recording is 384 × 848. LDPlayer was temporarily set to that
size at 160 dpi to capture the images below at the same pixel dimensions.

| Recording frame | Preview capture | Reviewed content |
| --- | --- | --- |
| 13s | [Account](screenshots/video-final-account.png) | Promotion, account card, tabs, recommendations |
| 06s | [Account detail](screenshots/video-final-account-sheet.png) | Account settings sheet |
| 08s | [Account funds](screenshots/video-final-account-equity.png) | Balance rows and quick actions |
| 15s | [Closed history](screenshots/video-final-account-closed.png) | Date group and XAU/USD deals |
| 22s | [Trading](screenshots/video-final-trading.png) | Favorites, prices, sparklines |
| 26s | [Insights](screenshots/video-final-insights.png) | Quote cards, signals, events |
| 28s | [Performance](screenshots/video-final-performance.png) | Filters and empty state |
| 30s | [Profile](screenshots/video-final-profile.png) | Bronze card, verification, benefits |
| 37s | [Settings](screenshots/video-final-settings.png) | Preference and security controls |
| 48s | [Chart](screenshots/video-final-chart.png) | Candles, Bid/Ask, toolbar |
| 58s | [Chart settings](screenshots/video-final-chart-settings.png) | Chart options, provider and shortcuts |

The chart is rendered by TradingView Lightweight Charts. Its initial XAU/USD
one-minute view uses 60 local OHLC candles measured from the 48s video frame;
the grid and time labels reproduce that frame and return to normal chart axes
when the user drags or zooms. Article thumbnails and the promotion artwork are
drawn in Flutter and remain approximations. Android font rasterization and
platform status icons can also differ from the recorded iOS interface. The
interactive preview is ready for a separate API integration pass.
