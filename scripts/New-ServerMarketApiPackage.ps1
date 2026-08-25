[CmdletBinding()]
param(
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$distDirectory = Join-Path $repositoryRoot "dist"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $distDirectory "server-market-api.zip"
}

$resolvedOutputDirectory = [IO.Path]::GetFullPath(
    (Split-Path -Parent $OutputPath)
)
$resolvedDistDirectory = [IO.Path]::GetFullPath($distDirectory)
if ($resolvedOutputDirectory -ne $resolvedDistDirectory) {
    throw "OutputPath must stay directly inside $resolvedDistDirectory."
}

New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
$stagingRoot = Join-Path $env:TEMP (
    "server-market-api-" + [Guid]::NewGuid().ToString("N")
)
$packageRoot = Join-Path $stagingRoot "server-market-api"

try {
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

    $backendSource = Join-Path $repositoryRoot "backend"
    $backendTarget = Join-Path $packageRoot "backend"
    New-Item -ItemType Directory -Path $backendTarget -Force | Out-Null

    Get-ChildItem -LiteralPath $backendSource -Force |
        Where-Object {
            $_.Name -notin @(
                ".env",
                ".local-market-api",
                "bin",
                "obj",
                "TestResults"
            )
        } |
        ForEach-Object {
            Copy-Item `
                -LiteralPath $_.FullName `
                -Destination $backendTarget `
                -Recurse `
                -Force
        }

    Get-ChildItem -LiteralPath $backendTarget -Directory -Recurse |
        Where-Object { $_.Name -in @("bin", "obj", "TestResults") } |
        Sort-Object { $_.FullName.Length } -Descending |
        Remove-Item -Recurse -Force

    $eaTargetDirectory = Join-Path $packageRoot "mt5\Experts"
    New-Item -ItemType Directory -Path $eaTargetDirectory -Force | Out-Null
    Copy-Item `
        -LiteralPath (Join-Path $repositoryRoot "mt5\Experts\TradingDemoMarketBridge.mq5") `
        -Destination $eaTargetDirectory

    $docsTargetDirectory = Join-Path $packageRoot "docs"
    New-Item -ItemType Directory -Path $docsTargetDirectory -Force | Out-Null
    Copy-Item `
        -LiteralPath (Join-Path $repositoryRoot "docs\market-data-ubuntu.md") `
        -Destination $docsTargetDirectory
    Copy-Item `
        -LiteralPath (Join-Path $backendSource "README.md") `
        -Destination (Join-Path $packageRoot "README.md")

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath
    }
    Compress-Archive `
        -LiteralPath $packageRoot `
        -DestinationPath $OutputPath `
        -CompressionLevel Optimal
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

$archive = Get-Item -LiteralPath $OutputPath
Write-Host "Created package: $($archive.FullName)"
Write-Host "Size: $($archive.Length) bytes"
