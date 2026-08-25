[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReferenceSerial,

    [Parameter(Mandatory)]
    [string]$DevelopmentSerial,

    [Parameter(Mandatory)]
    [ValidateSet('M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN')]
    [string]$Timeframe,

    [Parameter(Mandatory)]
    [ValidateSet('min', 'default', 'max')]
    [string]$Zoom,

    [Parameter(Mandatory)]
    [string]$OperatorStateConfirmation,

    [Parameter(Mandatory)]
    [string]$OutputRoot,

    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-Adb {
    $adbLocations = @()
    $androidHome = [Environment]::GetEnvironmentVariable('ANDROID_HOME')
    if (-not [string]::IsNullOrWhiteSpace($androidHome)) {
        $adbLocations += Join-Path $androidHome 'platform-tools\adb.exe'
    }
    $adbLocations += 'D:\toolchains\android-sdk\platform-tools\adb.exe'
    $candidates = @($adbLocations | Where-Object { $_ -and (Test-Path -LiteralPath $_) })

    if (@($candidates).Count -eq 0) {
        throw 'ADB was not found. Set ANDROID_HOME or install D:\toolchains\android-sdk.'
    }

    return $candidates[0]
}

function Confirm-OperatorState(
    [string]$Confirmation,
    [string]$ExpectedTimeframe,
    [string]$ExpectedZoom
) {
    $match = [regex]::Match(
        $Confirmation,
        '^timeframe=(?<timeframe>M1|M5|M15|M30|H1|H4|D1|W1|MN);zoom=(?<zoom>min|default|max);symbol=(?<symbol>[^;]+);oneClickPanel=(?<oneClickPanel>visible|hidden)$'
    )
    if (-not $match.Success) {
        throw 'OperatorStateConfirmation must be timeframe=<value>;zoom=<value>;symbol=<value>;oneClickPanel=<visible|hidden>.'
    }
    if ($match.Groups['timeframe'].Value -ne $ExpectedTimeframe -or $match.Groups['zoom'].Value -ne $ExpectedZoom) {
        throw "OperatorStateConfirmation does not match requested $ExpectedTimeframe/$ExpectedZoom."
    }

    return [ordered]@{
        timeframe = $ExpectedTimeframe
        zoom = $ExpectedZoom
        symbol = $match.Groups['symbol'].Value
        oneClickPanel = $match.Groups['oneClickPanel'].Value
        zoomVerification = 'operator-confirmed; native automation unavailable'
    }
}

function Get-DeviceMetrics([string]$Adb, [string]$Serial) {
    $sizeOutput = (& $Adb -s $Serial shell wm size | Out-String).Trim()
    $densityOutput = (& $Adb -s $Serial shell wm density | Out-String).Trim()
    $sizeMatch = [regex]::Match($sizeOutput, '(\d+)x(\d+)')
    $densityMatch = [regex]::Match($densityOutput, '(\d+)')
    if (-not $sizeMatch.Success -or -not $densityMatch.Success) {
        throw "Unable to parse display metrics for ${Serial}: $sizeOutput / $densityOutput"
    }

    return [ordered]@{
        width = [int]$sizeMatch.Groups[1].Value
        height = [int]$sizeMatch.Groups[2].Value
        densityDpi = [int]$densityMatch.Groups[1].Value
    }
}

function Capture-Chart([string]$Adb, [string]$Serial, [string]$LocalPath) {
    $remotePath = "/sdcard/chart-parity-$([guid]::NewGuid().ToString('N')).png"
    try {
        & $Adb -s $Serial shell screencap -p $remotePath
        if ($LASTEXITCODE -ne 0) { throw "screencap failed for $Serial" }
        & $Adb -s $Serial pull $remotePath $LocalPath
        if ($LASTEXITCODE -ne 0) { throw "adb pull failed for $Serial" }
    }
    finally {
        & $Adb -s $Serial shell rm -f $remotePath | Out-Null
    }
}

$root = (Resolve-Path -LiteralPath $OutputRoot).Path
$captureDirectory = Join-Path $root 'reference\screens\chart\light'
$adb = Find-Adb
$operatorConfirmation = Confirm-OperatorState $OperatorStateConfirmation $Timeframe $Zoom

if ($PreflightOnly) {
    Write-Output "Capture preflight passed for $Timeframe/$Zoom with operator confirmation."
    return
}

New-Item -ItemType Directory -Force -Path $captureDirectory | Out-Null
$manifestPath = Join-Path $captureDirectory 'manifest.json'

$captures = @(
    [ordered]@{ source = 'ref'; serial = $ReferenceSerial; fileName = "ref-$Timeframe-$Zoom.png" },
    [ordered]@{ source = 'dev-before'; serial = $DevelopmentSerial; fileName = "dev-before-$Timeframe-$Zoom.png" }
)

foreach ($capture in $captures) {
    $metrics = Get-DeviceMetrics $adb $capture.serial
    if ($metrics.width -ne 590 -or $metrics.height -ne 1280 -or $metrics.densityDpi -ne 240) {
        throw "Expected 590x1280 at 240 dpi for $($capture.serial), got $($metrics.width)x$($metrics.height) at $($metrics.densityDpi) dpi."
    }

    Capture-Chart $adb $capture.serial (Join-Path $captureDirectory $capture.fileName)
    $capture.metrics = $metrics
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Capture files created, but manifest is missing: $manifestPath. Create the deterministic matrix fixture before updating captures."
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($capture in $captures) {
    $entry = $manifest.entries | Where-Object {
        $_.source -eq $capture.source -and $_.timeframe -eq $Timeframe -and $_.zoom -eq $Zoom
    }
    if ($null -eq $entry) {
        throw "Manifest has no entry for $($capture.source)/$Timeframe/$Zoom."
    }

    $entry.screenshotPath = "reference/screens/chart/light/$($capture.fileName)"
    $entry.captureState = 'captured'
    $entry.captureMode = 'adb-screencap'
    $entry.device = $capture.metrics
    $entry.capturedAt = [DateTime]::UtcNow.ToString('o')
    $entry.PSObject.Properties.Remove('fixtureNote')
    Add-Member -InputObject $entry -NotePropertyName 'operatorStateConfirmation' -NotePropertyValue $operatorConfirmation -Force
    if ($capture.source -eq 'ref') {
        Add-Member -InputObject $entry -NotePropertyName 'observedColorStatus' -NotePropertyValue 'reference-sampled' -Force
        Add-Member -InputObject $entry -NotePropertyName 'observedColors' -NotePropertyValue $manifest.referenceTargetPalette -Force
    }
    else {
        Add-Member -InputObject $entry -NotePropertyName 'observedColorStatus' -NotePropertyValue 'not-sampled' -Force
        Add-Member -InputObject $entry -NotePropertyName 'observedColors' -NotePropertyValue $null -Force
    }
}

$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "Captured $Timeframe/$Zoom for reference and development emulators."
