$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scanner = Join-Path $scriptRoot 'scan-production-reference-data.ps1'
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..')).Path
$tempParent = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Force -Path $tempParent | Out-Null
$resolvedTempParent = (Resolve-Path -LiteralPath $tempParent).Path
$testRoot = Join-Path $resolvedTempParent (
  'production-reference-scan-tests-' + [System.Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $testRoot | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:testFailures = [System.Collections.Generic.List[string]]::new()

function New-DebugApkFixture {
  param(
    [string]$Name,
    [string]$KernelContents,
    [hashtable]$AdditionalEntries = @{}
  )

  $payloadRoot = Join-Path $testRoot "$Name-payload"
  $kernelPath = Join-Path $payloadRoot 'assets\flutter_assets\kernel_blob.bin'
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $kernelPath) |
    Out-Null
  [System.IO.File]::WriteAllText($kernelPath, $KernelContents)
  foreach ($entry in $AdditionalEntries.GetEnumerator()) {
    $entryPath = Join-Path $payloadRoot $entry.Key
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $entryPath) |
      Out-Null
    [System.IO.File]::WriteAllText($entryPath, [string]$entry.Value)
  }

  $apkPath = Join-Path $testRoot "$Name-debug.apk"
  [System.IO.Compression.ZipFile]::CreateFromDirectory($payloadRoot, $apkPath)
  return $apkPath
}

function Invoke-ReferenceScanner {
  param(
    [string]$ApkPath,
    [string]$RipgrepPath
  )

  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $scanner,
    '-ApkPath',
    $ApkPath
  )
  if (-not [string]::IsNullOrWhiteSpace($RipgrepPath)) {
    $arguments += @('-RipgrepPath', $RipgrepPath)
  }
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = @(& (Join-Path $PSHOME 'powershell.exe') @arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorAction
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = $output -join [Environment]::NewLine
  }
}

function Assert-Equal {
  param($Expected, $Actual, [string]$Message)
  if ($Expected -ne $Actual) {
    $script:testFailures.Add(
      "$Message Expected <$Expected>, actual <$Actual>."
    )
  }
}

function Assert-Contains {
  param([string]$Expected, [string]$Actual, [string]$Message)
  if (-not $Actual.Contains($Expected)) {
    $script:testFailures.Add("$Message Missing <$Expected> in: $Actual")
  }
}

try {
  $cleanApk = New-DebugApkFixture `
    -Name 'clean' `
    -KernelContents "const broker = 'Generic Broker';"
  $clean = Invoke-ReferenceScanner -ApkPath $cleanApk
  Assert-Equal 0 $clean.ExitCode 'clean APK must pass.'
  Assert-Contains 'APK_HIT_COUNT=0' $clean.Output 'clean result must be explicit.'
  Write-Output 'CHECKED clean APK exits 0'

  $hiddenHitApk = New-DebugApkFixture `
    -Name 'hidden-hit' `
    -KernelContents "const broker = 'Generic Broker';" `
    -AdditionalEntries @{ '.hidden\recorded.bin' = '4063.33' }
  $hiddenHit = Invoke-ReferenceScanner -ApkPath $hiddenHitApk
  Assert-Equal 1 $hiddenHit.ExitCode 'hidden prohibited data must fail.'
  Assert-Contains 'APK_HIT_COUNT=1' $hiddenHit.Output 'hit count must be reported.'
  Write-Output 'CHECKED hidden APK hit exits 1'

  $brokerHitApk = New-DebugApkFixture `
    -Name 'broker-hit' `
    -KernelContents "const broker = 'Vantage';"
  $brokerHit = Invoke-ReferenceScanner -ApkPath $brokerHitApk
  Assert-Equal 1 $brokerHit.ExitCode 'debug kernel broker literal must fail.'
  Assert-Contains 'APK_HIT_COUNT=1' $brokerHit.Output 'broker hit must be reported.'
  Write-Output 'CHECKED single-quoted debug broker literal exits 1'

  $doubleQuotedBrokerApk = New-DebugApkFixture `
    -Name 'double-quoted-broker-hit' `
    -KernelContents 'const broker = "Vantage";'
  $doubleQuotedBrokerHit = Invoke-ReferenceScanner `
    -ApkPath $doubleQuotedBrokerApk
  Assert-Equal `
    1 `
    $doubleQuotedBrokerHit.ExitCode `
    'double-quoted debug kernel broker literal must fail.'
  Assert-Contains `
    'APK_HIT_COUNT=1' `
    $doubleQuotedBrokerHit.Output `
    'double-quoted broker hit must be reported.'
  Write-Output 'CHECKED double-quoted debug broker literal exits 1'

  $releasePayload = Join-Path $testRoot 'release-payload'
  New-Item -ItemType Directory -Force -Path $releasePayload | Out-Null
  [System.IO.File]::WriteAllText(
    (Join-Path $releasePayload 'compiled.bin'),
    'neutral compiled artifact'
  )
  $releaseApk = Join-Path $testRoot 'release.apk'
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    $releasePayload,
    $releaseApk
  )
  $release = Invoke-ReferenceScanner -ApkPath $releaseApk
  Assert-Equal 2 $release.ExitCode 'non-debug APK must be rejected.'
  Assert-Contains `
    'DEBUG_APK_REQUIRED' `
    $release.Output `
    'debug-only constraint must be explicit.'
  Write-Output 'CHECKED non-debug APK is rejected explicitly'

  $fakeRipgrep = Join-Path $env:SystemRoot 'System32\findstr.exe'
  $scannerError = Invoke-ReferenceScanner `
    -ApkPath $cleanApk `
    -RipgrepPath $fakeRipgrep
  Assert-Equal 2 $scannerError.ExitCode 'ripgrep exit 2 must be retained.'
  Assert-Contains `
    'FINDSTR' `
    $scannerError.Output `
    'ripgrep stderr must be retained.'
  Write-Output 'CHECKED scanner error retains stderr and exits 2'

  $missingRipgrep = Join-Path $testRoot 'missing-rg.exe'
  $launchFailure = Invoke-ReferenceScanner `
    -ApkPath $cleanApk `
    -RipgrepPath $missingRipgrep
  Assert-Equal 2 $launchFailure.ExitCode 'missing ripgrep must fail closed.'
  Assert-Contains `
    'RIPGREP_LAUNCH_FAILED' `
    $launchFailure.Output `
    'launch failure diagnostic must be retained.'
  Write-Output 'CHECKED missing scanner exits 2 with diagnostic'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $expectedPrefix = $resolvedTempParent.TrimEnd('\') + '\'
  if (-not $resolvedTestRoot.StartsWith(
      $expectedPrefix,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to clean test directory outside $resolvedTempParent"
  }
  Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}

if ($script:testFailures.Count -ne 0) {
  throw ($script:testFailures -join [Environment]::NewLine)
}
Write-Output 'PASS all scanner behavior checks'
$global:LASTEXITCODE = 0
