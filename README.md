# Trading Demo Monorepo

This repository contains the Android-first Flutter client and ASP.NET Core
backend for a virtual-money trading demo. The mobile chart reads public
Exness MT5 Demo market data from `https://trochoi.top`; it does not place or
process real-money trades.

## Prerequisites

- Flutter 3.44 or newer with an Android SDK
- .NET SDK 8

## Mobile

```powershell
cd mobile
flutter pub get
flutter run
```

The production bootstrap uses `https://trochoi.top` by default. Override only
the public API origin when needed:

```powershell
flutter run --dart-define=MARKET_API_BASE_URL=https://example.com
```

The client loads candle history through REST and receives quotes/candle updates
through SignalR. Never put `MARKET_FEED_INGEST_KEY` in the mobile app.

The current demo includes authentication, Market Watch, symbol search, chart,
new order, positions, history, wallet requests, notifications, settings, and
profile flows. Orders and position closing update shared in-memory demo state;
they do not place real trades.

Validation commands:

```powershell
cd mobile
flutter analyze
flutter test
flutter build apk --debug
```

## Local infrastructure

Copy `backend/.env.example` to `backend/.env`, replace the example passwords,
then start SQL Server and Redis:

```powershell
cd backend
Copy-Item .env.example .env
docker compose up -d
docker compose ps
```

Stop the services without deleting their data:

```powershell
docker compose down
```

## Backend

```powershell
cd backend
dotnet restore Trading.sln
dotnet run --project src/Trading.Api/Trading.Api.csproj
```

The API exposes a health endpoint at `GET /health`. The Worker host can be run
separately:

```powershell
cd backend
dotnet run --project src/Trading.Workers/Trading.Workers.csproj
```

Validation commands:

```powershell
cd backend
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

The design system, navigation, mock data, and business modules are introduced
by their corresponding tasks.
