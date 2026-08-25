[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5150,

    [string]$FeedKey = "",

    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runtimeDirectory = Join-Path $backendRoot ".local-market-api"
$secretPath = Join-Path $runtimeDirectory "market-feed-key.txt"
$processPath = Join-Path $runtimeDirectory "market-api.json"
$stdoutPath = Join-Path $runtimeDirectory "market-api.stdout.log"
$stderrPath = Join-Path $runtimeDirectory "market-api.stderr.log"
$solutionPath = Join-Path $backendRoot "Trading.sln"
$apiProjectPath = Join-Path $backendRoot "src\Trading.Api\Trading.Api.csproj"
$apiDllPath = Join-Path $backendRoot "src\Trading.Api\bin\Debug\net8.0\Trading.Api.dll"
$baseUrl = "http://127.0.0.1:$Port"

New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null

if (Test-Path -LiteralPath $processPath) {
    $existingRuntime = Get-Content -LiteralPath $processPath -Raw |
        ConvertFrom-Json
    $existingProcess = Get-Process -Id $existingRuntime.pid -ErrorAction SilentlyContinue
    if ($null -ne $existingProcess) {
        throw "Market API is already running with PID $($existingRuntime.pid). Run Stop-MarketApi.ps1 first."
    }

    Remove-Item -LiteralPath $processPath
}

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($null -ne $listener) {
    throw "Port $Port is already in use by PID $($listener.OwningProcess)."
}

if ([string]::IsNullOrWhiteSpace($FeedKey)) {
    if (Test-Path -LiteralPath $secretPath) {
        $FeedKey = [IO.File]::ReadAllText($secretPath).Trim()
    } else {
        $bytes = New-Object byte[] 32
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $generator.GetBytes($bytes)
        } finally {
            $generator.Dispose()
        }

        $FeedKey = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
    }
}

if ($FeedKey.Length -lt 16) {
    throw "FeedKey must contain at least 16 characters."
}

$utf8WithoutBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($secretPath, $FeedKey, $utf8WithoutBom)

if (-not $SkipBuild) {
    & dotnet build $solutionPath --nologo
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $apiDllPath)) {
    & dotnet build $apiProjectPath --nologo
    if ($LASTEXITCODE -ne 0) {
        throw "Trading.Api build failed with exit code $LASTEXITCODE."
    }
}

$dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
$previousFeedKey = [Environment]::GetEnvironmentVariable(
    "MarketFeed__IngestKey",
    "Process"
)

try {
    [Environment]::SetEnvironmentVariable(
        "MarketFeed__IngestKey",
        $FeedKey,
        "Process"
    )
    $process = Start-Process `
        -FilePath $dotnetPath `
        -ArgumentList @(
            "`"$apiDllPath`"",
            "--urls",
            $baseUrl
        ) `
        -WorkingDirectory $backendRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
} finally {
    [Environment]::SetEnvironmentVariable(
        "MarketFeed__IngestKey",
        $previousFeedKey,
        "Process"
    )
}

$runtime = [ordered]@{
    pid = $process.Id
    port = $Port
    baseUrl = $baseUrl
    apiDll = $apiDllPath
    startedAt = [DateTimeOffset]::Now.ToString("o")
}
[IO.File]::WriteAllText(
    $processPath,
    ($runtime | ConvertTo-Json),
    $utf8WithoutBom
)

$healthy = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 500
    $process.Refresh()
    if ($process.HasExited) {
        $errorTail = if (Test-Path -LiteralPath $stderrPath) {
            (Get-Content -LiteralPath $stderrPath -Tail 30) -join [Environment]::NewLine
        } else {
            "No stderr log was created."
        }
        throw "Market API exited before becoming healthy.$([Environment]::NewLine)$errorTail"
    }

    try {
        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri "$baseUrl/health" `
            -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        # The process can take a few seconds to bind the local port.
    }
}

if (-not $healthy) {
    throw "Market API did not become healthy at $baseUrl/health."
}

Write-Host "Market API is running."
Write-Host "Base URL: $baseUrl"
Write-Host "PID: $($process.Id)"
Write-Host "Feed key file: $secretPath"
Write-Host "Run Test-MarketApi.ps1 to seed and verify local chart data."
