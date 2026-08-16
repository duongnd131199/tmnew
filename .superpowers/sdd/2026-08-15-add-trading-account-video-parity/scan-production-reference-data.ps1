param(
  [string]$ApkPath,
  [string]$RipgrepPath = 'rg.exe'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..\..\..')).Path
$mobileRoot = Join-Path $repoRoot 'mobile'
$libRoot = Join-Path $mobileRoot 'lib'
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
  $ApkPath = Join-Path $mobileRoot 'build\app\outputs\flutter-apk\app-debug.apk'
}
$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path

$prohibited = @(
  '28210230',
  '463696038',
  '425302695',
  '425297911',
  'Exness-MT5Trial17',
  'Exness-MT5Real15',
  'Exness-MT5Real20',
  '2292.60',
  '318441.72',
  '-325690.38',
  '21081.96',
  '-11531.70',
  '2301.60',
  '27297978.10',
  '12000119',
  '15297859.10',
  '1231.48',
  '1470684.33',
  '179.00',
  '57360797890',
  '57360798130',
  '57016800413',
  '4078.77',
  '4039.03',
  '4104.09',
  '4104.22',
  '4108.117',
  '4102.396',
  '65175.98',
  '65193.10',
  '2026.07.',
  '2026.07.24 18:04:32',
  '2026.07.27 04:00:49',
  'Cash Adjustment-Debt W/O',
  'Transfer In from 32401745',
  '-41.36',
  '24.24',
  '50.00',
  '100.00%',
  '4063.33',
  '4115.79',
  '3959.93',
  '6 336',
  '6336'
)

$sourceHits = [System.Collections.Generic.List[string]]::new()
foreach ($file in Get-ChildItem -LiteralPath $libRoot -Recurse -File -Filter '*.dart') {
  $contents = [System.IO.File]::ReadAllText($file.FullName)
  foreach ($literal in $prohibited) {
    if ($contents.Contains($literal)) {
      $sourceHits.Add("$literal :: $($file.FullName)")
    }
  }
  if ($contents.Contains("'Vantage'") -or $contents.Contains('"Vantage"')) {
    $sourceHits.Add("Vantage string literal :: $($file.FullName)")
  }
}

$scanParent = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Force -Path $scanParent | Out-Null
$resolvedScanParent = (Resolve-Path -LiteralPath $scanParent).Path
$scanRoot = Join-Path $resolvedScanParent (
  'production-reference-scan-' + [System.Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $scanRoot | Out-Null

$apkHits = [System.Collections.Generic.List[string]]::new()
$scannerExitCode = 0
$scannerStderr = ''
try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedApk, $scanRoot)

  $kernelBlob = Join-Path $scanRoot 'assets\flutter_assets\kernel_blob.bin'
  if (-not (Test-Path -LiteralPath $kernelBlob -PathType Leaf)) {
    $scannerExitCode = 2
    $scannerStderr = @(
      'DEBUG_APK_REQUIRED: the APK must contain ',
      'assets/flutter_assets/kernel_blob.bin so Dart string literals ',
      'can be checked without confusing broker-name identifiers.'
    ) -join ''
  } else {
    $apkPatterns = foreach ($literal in $prohibited) {
      if ($literal -eq '2026.07.') {
        [regex]::Escape($literal)
      } elseif ($literal -match '^-') {
        '(?<![0-9.])' + [regex]::Escape($literal) + '(?![0-9.])'
      } elseif ($literal -match '^[0-9]') {
        '(?<![-+0-9.])' + [regex]::Escape($literal) + '(?![0-9.])'
      } else {
        [regex]::Escape($literal)
      }
    }
    # Debug kernel blobs preserve Dart source spelling, so quotes distinguish
    # the prohibited UI value from legitimate names such as brokerVantage.
    $apkPatterns += [regex]::Escape("'Vantage'")
    # Hex escapes preserve literal double quotes through Windows native-argv
    # serialization; raw quotes would be stripped before ripgrep receives them.
    $apkPatterns += '\x22Vantage\x22'
    $combinedPattern = '(?:' + ($apkPatterns -join '|') + ')'
    $rgStdoutPath = Join-Path $scanRoot '.rg-stdout.txt'
    $rgStderrPath = Join-Path $scanRoot '.rg-stderr.txt'
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & $RipgrepPath `
        -a `
        -l `
        -P `
        --hidden `
        --no-ignore `
        -- `
        $combinedPattern `
        $scanRoot `
        1> $rgStdoutPath `
        2> $rgStderrPath
      $scannerExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorAction
    }
    $scannerStderr = [System.IO.File]::ReadAllText($rgStderrPath)
    if ($scannerExitCode -eq 0) {
      foreach ($match in [System.IO.File]::ReadAllLines($rgStdoutPath)) {
        if (-not [string]::IsNullOrWhiteSpace($match)) {
          $apkHits.Add($match)
        }
      }
    } elseif ($scannerExitCode -ne 1) {
      if ([string]::IsNullOrWhiteSpace($scannerStderr)) {
        $scannerStderr = "ripgrep failed with exit code $scannerExitCode."
      }
    }
  }
} finally {
  $resolvedScanRoot = [System.IO.Path]::GetFullPath($scanRoot)
  $expectedPrefix = $resolvedScanParent.TrimEnd('\') + '\'
  if (-not $resolvedScanRoot.StartsWith(
      $expectedPrefix,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to clean scan directory outside $resolvedScanParent"
  }
  Remove-Item -LiteralPath $resolvedScanRoot -Recurse -Force
}

if ($scannerExitCode -gt 1) {
  [Console]::Error.WriteLine($scannerStderr.TrimEnd())
  exit $scannerExitCode
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedApk
Write-Output "LITERAL_COUNT=$($prohibited.Count + 1)"
Write-Output 'APK_MODE=debug-kernel'
Write-Output "SOURCE_HIT_COUNT=$($sourceHits.Count)"
$sourceHits
Write-Output "APK_HIT_COUNT=$($apkHits.Count)"
$apkHits
Write-Output "APK_SIZE=$((Get-Item -LiteralPath $resolvedApk).Length)"
Write-Output "APK_SHA256=$($hash.Hash)"

if ($sourceHits.Count -ne 0 -or $apkHits.Count -ne 0) {
  exit 1
}
