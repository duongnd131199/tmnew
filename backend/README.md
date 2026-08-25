# Realtime MT5 Chart API

This package contains only the ASP.NET market-data API and the read-only MT5
bridge needed to supply quotes and candles to the Flutter application. It does
not contain the Flutter client and it does not place broker orders.

## Local Windows verification

Requirements:

- .NET SDK 8
- PowerShell 5.1 or newer

From the `backend` directory:

```powershell
.\scripts\local\Start-MarketApi.ps1
.\scripts\local\Test-MarketApi.ps1
.\scripts\local\Stop-MarketApi.ps1
```

`Start-MarketApi.ps1` builds the solution, generates a local feed key and
starts the API at `http://127.0.0.1:5150`. The key, PID and logs are written
under the ignored `.local-market-api` directory. The key is never printed.

`Test-MarketApi.ps1` seeds deterministic H4 history, sends a short sequence of
synthetic XAUUSD+ ticks, then verifies:

- `GET /health`
- authenticated tick and candle ingestion
- public quote and candle reads
- market connection status
- SignalR negotiation

The local verification feed is synthetic and is labelled as such. Broker data
starts only after the EA is installed and logged in to the chosen MT5 server.

## Public application endpoints

```text
GET  /health
GET  /api/market/status
GET  /api/market/quotes
GET  /api/market/quotes/{symbol}
GET  /api/market/candles?symbol=XAUUSD%2B&timeframe=H4&limit=500
POST /hubs/market/negotiate?negotiateVersion=1
```

The two `/api/market/feed/*` ingestion routes require
`X-Market-Feed-Key`. Never put this key in the Flutter application.

## Ubuntu deployment

Copy the package to the server, create `backend/.env` from `.env.example`, and
replace every example value. Then:

```bash
cd backend
docker compose config
docker compose build market-api
docker compose up -d market-api
curl http://127.0.0.1:5150/health
```

Use `deploy/nginx/trading-api.conf` for HTTPS and WebSocket proxying. Replace
`api.example.com` with the real API domain.

Install `mt5/Experts/TradingDemoMarketBridge.mq5` in the terminal, allow
WebRequest for the public HTTPS API origin, enter the server feed key in the EA
inputs and map app symbols to the broker's exact symbol names.

The Flutter release must be built with:

```bash
flutter build apk --release \
  --dart-define=MARKET_API_BASE_URL=https://api.example.com
```
