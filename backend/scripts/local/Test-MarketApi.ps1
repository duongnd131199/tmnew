[CmdletBinding()]
param(
    [string]$BaseUrl = "http://127.0.0.1:5150",

    [string]$Symbol = "XAUUSD+",

    [string]$Timeframe = "H4",

    [string]$FeedKeyPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($FeedKeyPath)) {
    $FeedKeyPath = Join-Path $backendRoot ".local-market-api\market-feed-key.txt"
}

if (-not (Test-Path -LiteralPath $FeedKeyPath)) {
    throw "Feed key file not found at $FeedKeyPath. Run Start-MarketApi.ps1 first."
}

$feedKey = [IO.File]::ReadAllText($FeedKeyPath).Trim()
if ($feedKey.Length -lt 16) {
    throw "The local feed key is invalid."
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$headers = @{
    "X-Market-Feed-Key" = $feedKey
}

$health = Invoke-WebRequest `
    -UseBasicParsing `
    -Uri "$BaseUrl/health" `
    -TimeoutSec 5
if ($health.StatusCode -ne 200) {
    throw "Health endpoint returned HTTP $($health.StatusCode)."
}

$historyStart = [DateTimeOffset]::UtcNow.AddHours(-4 * 119)
$candles = @(
    for ($index = 0; $index -lt 120; $index++) {
        $open = 4100.0 +
            [Math]::Sin($index / 8.0) * 13.0 +
            [Math]::Cos($index / 3.2) * 4.0
        $close = $open + [Math]::Sin($index / 2.7) * 2.2
        @{
            time = $historyStart.AddHours($index * 4).ToUnixTimeSeconds()
            open = [Math]::Round($open, 2)
            high = [Math]::Round([Math]::Max($open, $close) + 1.8, 2)
            low = [Math]::Round([Math]::Min($open, $close) - 1.6, 2)
            close = [Math]::Round($close, 2)
            volume = 1000 + $index
        }
    }
)

$seedBody = @{
    symbol = $Symbol
    timeframe = $Timeframe
    candles = $candles
} | ConvertTo-Json -Depth 5 -Compress

$seedResult = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/api/market/feed/candles/seed" `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $seedBody `
    -TimeoutSec 10

if ($seedResult.count -ne $candles.Count) {
    throw "The API accepted $($seedResult.count) candles instead of $($candles.Count)."
}

$batchStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$batchTicks = @(
    for ($index = 0; $index -lt 20; $index++) {
        $bid = [Math]::Round(4104.00 + $index * 0.01, 2)
        @{
            symbol = $Symbol
            bid = $bid
            ask = [Math]::Round($bid + 0.13, 2)
            timeMsc = $batchStart + $index * 50
            source = "Local 20 ticks per second verification feed"
        }
    }
)
$lastExpectedBid = $batchTicks[-1].bid
$tickBatchBody = @{
    ticks = $batchTicks
} | ConvertTo-Json -Depth 5 -Compress

Invoke-WebRequest `
    -UseBasicParsing `
    -Method Post `
    -Uri "$BaseUrl/api/market/feed/ticks/batch" `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $tickBatchBody `
    -TimeoutSec 5 |
    Out-Null

$escapedSymbol = [Uri]::EscapeDataString($Symbol)
$status = Invoke-RestMethod `
    -Uri "$BaseUrl/api/market/status" `
    -TimeoutSec 5
$quote = $null
for ($attempt = 0; $attempt -lt 60; $attempt++) {
    $quote = Invoke-RestMethod `
        -Uri "$BaseUrl/api/market/quotes/$escapedSymbol" `
        -TimeoutSec 5
    if ([decimal]$quote.bid -eq [decimal]$lastExpectedBid) {
        break
    }

    Start-Sleep -Milliseconds 50
}
$receivedCandles = Invoke-RestMethod `
    -Uri "$BaseUrl/api/market/candles?symbol=$escapedSymbol&timeframe=$Timeframe&limit=200" `
    -TimeoutSec 5
$receivedCandleCount = if ($receivedCandles -is [Array]) {
    $receivedCandles.Count
} elseif ($null -eq $receivedCandles) {
    0
} else {
    1
}
$negotiate = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/hubs/market/negotiate?negotiateVersion=1" `
    -ContentType "application/json" `
    -Body "{}" `
    -TimeoutSec 5

if (-not $status.connected) {
    throw "Market status is not connected after sending local ticks."
}
if ($quote.symbol -ne $Symbol) {
    throw "Quote endpoint returned symbol '$($quote.symbol)' instead of '$Symbol'."
}
if ([decimal]$quote.bid -ne [decimal]$lastExpectedBid) {
    throw "Quote endpoint ended at bid '$($quote.bid)' instead of '$lastExpectedBid'."
}
if ($receivedCandleCount -lt 100) {
    throw "Candle endpoint returned only $receivedCandleCount candles."
}
$lastCandle = @($receivedCandles)[-1]
if ([decimal]$lastCandle.close -ne [decimal]$lastExpectedBid) {
    throw "The active $Timeframe candle closed at '$($lastCandle.close)' instead of '$lastExpectedBid'."
}
if ([string]::IsNullOrWhiteSpace($negotiate.connectionToken)) {
    throw "SignalR negotiate did not return a connection token."
}

[pscustomobject]@{
    health = "OK"
    connected = $status.connected
    symbol = $quote.symbol
    bid = $quote.bid
    ask = $quote.ask
    acceptedTicks = $batchTicks.Count
    expectedFinalBid = $lastExpectedBid
    finalCandleClose = $lastCandle.close
    candleCount = $receivedCandleCount
    timeframe = $Timeframe
    signalRNegotiate = "OK"
    source = $quote.source
} | Format-List

Write-Host "Local market API verification passed."
