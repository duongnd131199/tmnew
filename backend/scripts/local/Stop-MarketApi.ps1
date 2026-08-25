[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$backendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runtimeDirectory = Join-Path $backendRoot ".local-market-api"
$processPath = Join-Path $runtimeDirectory "market-api.json"

if (-not (Test-Path -LiteralPath $processPath)) {
    Write-Host "No local market API runtime record was found."
    exit 0
}

$runtime = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
$process = Get-Process -Id $runtime.pid -ErrorAction SilentlyContinue
if ($null -eq $process) {
    Remove-Item -LiteralPath $processPath
    Write-Host "The recorded process is no longer running."
    exit 0
}

$processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$($runtime.pid)"
$expectedDll = [IO.Path]::GetFullPath([string]$runtime.apiDll)
if (
    $null -eq $processInfo -or
    [string]::IsNullOrWhiteSpace($processInfo.CommandLine) -or
    -not $processInfo.CommandLine.Contains($expectedDll)
) {
    throw "PID $($runtime.pid) does not match the recorded Trading.Api process. It was not stopped."
}

Stop-Process -Id $runtime.pid
Wait-Process -Id $runtime.pid -Timeout 10 -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $processPath

Write-Host "Local market API stopped."
