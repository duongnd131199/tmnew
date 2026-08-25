[CmdletBinding()]
param(
    [string]$PackagePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = [IO.Path]::GetFullPath(
    (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)
if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $PackagePath = Join-Path $repositoryRoot "dist\server-market-api.zip"
}
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
if (-not (Test-Path -LiteralPath $PackagePath)) {
    throw "Package not found at $PackagePath."
}

$verifyParent = [IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot ".codex_tmp")
)
New-Item -ItemType Directory -Path $verifyParent -Force | Out-Null
$verifyRoot = Join-Path $verifyParent (
    "package-verify-" + [Guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Path $verifyRoot | Out-Null
$backendPath = $null

try {
    Expand-Archive -LiteralPath $PackagePath -DestinationPath $verifyRoot
    $packageRoot = Join-Path $verifyRoot "server-market-api"
    $files = @(
        Get-ChildItem -LiteralPath $packageRoot -File -Recurse
    )
    $relativePaths = @(
        $files | ForEach-Object {
            $_.FullName.Substring($packageRoot.Length + 1)
        }
    )
    $forbiddenPaths = @(
        $relativePaths | Where-Object {
            $_ -match "(^|[\\/])(mobile|bin|obj|TestResults|\.local-market-api)([\\/]|$)" -or
            (
                $_ -match "(^|[\\/])\.env($|\.)" -and
                $_ -notmatch "(^|[\\/])\.env\.example$"
            ) -or
            $_ -match "market-feed-key"
        }
    )
    if ($forbiddenPaths.Count -gt 0) {
        throw "Forbidden package entries: $($forbiddenPaths -join ', ')"
    }

    $localSecretPath = Join-Path $repositoryRoot (
        "backend\.local-market-api\market-feed-key.txt"
    )
    if (Test-Path -LiteralPath $localSecretPath) {
        $localSecret = [IO.File]::ReadAllText($localSecretPath).Trim()
        foreach ($file in $files) {
            $content = [IO.File]::ReadAllText($file.FullName)
            if ($content.Contains($localSecret)) {
                throw "The local feed key leaked into $($file.FullName)."
            }
        }
    }

    $expectedPaths = @(
        "backend\Trading.sln",
        "backend\docker-compose.yml",
        "backend\scripts\local\Start-MarketApi.ps1",
        "backend\scripts\local\Test-MarketApi.ps1",
        "backend\scripts\local\Stop-MarketApi.ps1",
        "mt5\Experts\TradingDemoMarketBridge.mq5",
        "README.md"
    )
    foreach ($expectedPath in $expectedPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $expectedPath))) {
            throw "Missing package entry: $expectedPath"
        }
    }

    Write-Host "Package security check passed for $($files.Count) files."

    $backendPath = Join-Path $packageRoot "backend"
    & (Join-Path $backendPath "scripts\local\Start-MarketApi.ps1")
    & (Join-Path $backendPath "scripts\local\Test-MarketApi.ps1")
    & (Join-Path $backendPath "scripts\local\Stop-MarketApi.ps1")

    Write-Host "Extracted package end-to-end verification passed."
} finally {
    if (
        $null -ne $backendPath -and
        (Test-Path -LiteralPath (
            Join-Path $backendPath ".local-market-api\market-api.json"
        ))
    ) {
        & (Join-Path $backendPath "scripts\local\Stop-MarketApi.ps1") |
            Out-Null
    }

    $resolvedVerifyRoot = [IO.Path]::GetFullPath($verifyRoot)
    $expectedPrefix = $verifyParent + [IO.Path]::DirectorySeparatorChar
    if (
        -not $resolvedVerifyRoot.StartsWith(
            $expectedPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw "Unsafe cleanup target: $resolvedVerifyRoot"
    }
    if (Test-Path -LiteralPath $resolvedVerifyRoot) {
        Remove-Item -LiteralPath $resolvedVerifyRoot -Recurse -Force
    }
}
