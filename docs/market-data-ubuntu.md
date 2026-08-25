# Realtime MT5 Market Data on Ubuntu

This deployment keeps broker credentials inside the MetaTrader 5 terminal.
The Flutter APK receives only read-only quotes and candles from the ASP.NET API.
Order placement in the clone remains demo-only.

## Runtime flow

```text
Broker MT5 server
  -> MetaTrader 5 terminal under Wine
  -> TradingDemoMarketBridge Expert Advisor
  -> POST /api/market/feed/ticks/batch
  -> ASP.NET in-memory quote/candle store
  -> REST snapshot + SignalR /hubs/market
  -> Flutter Market, Chart, Order and Trade screens
```

## 1. Prepare Ubuntu

Use a non-root service user and a supported Ubuntu release. Install Docker,
Docker Compose, Nginx and Certbot. Point the API DNS record to the server before
requesting a TLS certificate.

MetaQuotes publishes an Ubuntu-compatible Wine installer:

```bash
wget https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh
chmod +x mt5linux.sh
./mt5linux.sh
```

The first login and broker selection are interactive. Use a demo or
investor/read-only account for market-data collection. Do not place a live
trading password in source code, Docker environment variables or the mobile
application.

## 2. Start the API

```bash
cd /opt/mt5New/backend
cp .env.example .env
openssl rand -hex 32
```

Put the generated value in `MARKET_FEED_INGEST_KEY`, configure the SQL/Redis
development passwords, then run:

```bash
docker compose up -d --build market-api
docker compose ps
curl http://127.0.0.1:5150/health
```

Copy `backend/deploy/nginx/trading-api.conf` into the Nginx sites directory,
replace `api.example.com`, obtain a TLS certificate, validate Nginx, and reload
it. SignalR requires the included WebSocket upgrade headers.

## 3. Install the read-only EA

Copy `mt5/Experts/TradingDemoMarketBridge.mq5` into the terminal's `MQL5/Experts`
directory and compile it in MetaEditor. In MT5:

1. Log in to the chosen broker demo or investor account.
2. Open Tools > Options > Expert Advisors.
3. Enable WebRequest and add `https://api.example.com`.
4. Attach `TradingDemoMarketBridge` to one chart.
5. Set `ApiBaseUrl`, the same `FeedKey`, and symbol mappings.

Example mapping:

```text
XAUUSD+=XAUUSDm;BTCUSD=BTCUSDm;EURUSD=EURUSDm
```

The left side is the app symbol. The right side must be the exact broker symbol
shown in MT5 Market Watch. The EA seeds M1 through MN history, then captures at
a 50 ms timer interval by default. `CopyTicksRange` recovers every available
broker tick since the last acknowledged source millisecond, including ticks
that arrived while an HTTP request was in progress. It sends at most 256 ticks
per request to `/api/market/feed/ticks/batch`.

The cursor advances only after a 2xx response. A failed request therefore
retries the unacknowledged source range; the API suppresses exact duplicate
retries while preserving different prices that share the same millisecond.
The EA never sends the MT5 login or password to the API.

Changing the source cadence in production requires compiling this `.mq5` file
in MetaEditor and replacing/restarting the attached EA after the matching API
version has been deployed. Merely rebuilding the Flutter APK cannot increase
the broker tick rate.

## 4. Verify the feed

```bash
curl https://api.example.com/api/market/status
curl https://api.example.com/api/market/quotes/XAUUSD+
curl "https://api.example.com/api/market/candles?symbol=XAUUSD%2B&timeframe=H4&limit=10"
```

`connected` becomes false when the last broker tick exceeds the configured
stale interval. This is expected while a market is closed.

## 5. Build the Flutter app

Pass the public HTTPS API origin at build time:

```bash
flutter build apk --release \
  --dart-define=MARKET_API_BASE_URL=https://api.example.com
```

Never pass `MARKET_FEED_INGEST_KEY` to Flutter. It is accepted only by the two
feed ingestion endpoints and belongs on the server/EA.
