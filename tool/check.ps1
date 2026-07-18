param(
    [switch]$RunBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutterBin = if ([string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) {
    'flutter'
} else {
    $env:FLUTTER_BIN
}
$pythonBin = if ([string]::IsNullOrWhiteSpace($env:PYTHON_BIN)) {
    'python'
} else {
    $env:PYTHON_BIN
}

$dartBin = $env:DART_BIN
if ([string]::IsNullOrWhiteSpace($dartBin)) {
    $flutterCommand = Get-Command $flutterBin -ErrorAction Stop
    $dartCandidate = Join-Path (Split-Path -Parent $flutterCommand.Source) 'dart.bat'
    $dartBin = if (Test-Path -LiteralPath $dartCandidate -PathType Leaf) {
        $dartCandidate
    } else {
        'dart'
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    & $Command @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $Command $($ArgumentList -join ' ')"
    }
}

Push-Location $projectDir
try {
    Invoke-CheckedCommand $flutterBin @('--no-version-check', 'gen-l10n')
    Invoke-CheckedCommand $dartBin @('run', 'build_runner', 'build')
    Invoke-CheckedCommand $dartBin @('run', 'tool/generate_ocr_fixture_bundle.dart')
    Invoke-CheckedCommand $dartBin @('run', 'tool/generate_v2_preprocess_goldens.dart', '--check')
    Invoke-CheckedCommand $dartBin @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'integration_test', 'tool')
    Invoke-CheckedCommand $flutterBin @('--no-version-check', 'analyze')
    Invoke-CheckedCommand $flutterBin @('--no-version-check', 'test')
    Invoke-CheckedCommand $pythonBin @('-m', 'unittest', 'tool.test_audit_v2_model')
    Invoke-CheckedCommand $pythonBin @('-m', 'unittest', 'discover', '-s', 'ml/tests', '-v')
    & (Join-Path $PSScriptRoot 'audit_offline.ps1')

    if ($RunBuild.IsPresent -or $env:ROSID_RUN_BUILD -eq '1') {
        Invoke-CheckedCommand $flutterBin @('--no-version-check', 'build', 'apk', '--debug')
        & (Join-Path $PSScriptRoot 'audit_offline.ps1')
    } else {
        Write-Output 'Skipping APK build (pass -RunBuild or set ROSID_RUN_BUILD=1 on a provisioned machine).'
    }
} finally {
    Pop-Location
}
