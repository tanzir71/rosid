param(
    [switch]$Emulator,
    [switch]$Release,
    [string]$Evidence = '',
    [string]$AvdName = 'rosid_test'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Release.IsPresent) {
    $Emulator = $true
}

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutterBin = if ([string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) { 'flutter' } else { $env:FLUTTER_BIN }
$dartBin = $env:DART_BIN
if ([string]::IsNullOrWhiteSpace($dartBin)) {
    $flutterCommand = Get-Command $flutterBin -ErrorAction Stop
    $dartCandidate = Join-Path (Split-Path -Parent $flutterCommand.Source) 'dart.bat'
    $dartBin = if (Test-Path -LiteralPath $dartCandidate -PathType Leaf) { $dartCandidate } else { 'dart' }
}

$sdkRoot = if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
    $env:ANDROID_SDK_ROOT
} elseif (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    $env:ANDROID_HOME
} else {
    Join-Path $env:LOCALAPPDATA 'Android\sdk'
}

$adbBin = Join-Path $sdkRoot 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbBin -PathType Leaf)) {
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCmd) { $adbBin = $adbCmd.Source }
}
$emulatorBin = Join-Path $sdkRoot 'emulator\emulator.exe'

$stepResults = [System.Collections.Generic.List[hashtable]]::new()
$metrics = [ordered]@{}
$startedEmulatorSerial = $null
$startedEmulatorProcess = $null
$logLines = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format 'HH:mm:ss'
    $line = "[$stamp] $Message"
    Write-Output $line
    $logLines.Add($line)
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    Write-Log "=== STEP: $Name ==="
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
        $sw.Stop()
        $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $stepResults.Add(@{ Name = $Name; Status = 'pass'; Seconds = $secs })
        Write-Log "PASS: $Name (${secs}s)"
    } catch {
        $sw.Stop()
        $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $stepResults.Add(@{ Name = $Name; Status = 'fail'; Seconds = $secs; Error = $_.Exception.Message })
        Write-Log "FAIL: $Name (${secs}s): $($_.Exception.Message)"
        throw
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command @ArgumentList 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevPref
    }
    foreach ($line in $output) {
        $text = "$line"
        Write-Output $text
        $logLines.Add($text)
    }
    if ($code -ne 0) {
        throw "Command failed with exit code $code`: $Command $($ArgumentList -join ' ')"
    }
    return $output
}

function Get-RunningEmulatorSerial {
    if (-not (Test-Path -LiteralPath $adbBin -PathType Leaf)) { return $null }
    $out = & $adbBin devices 2>$null
    foreach ($line in $out) {
        if ($line -match '^(emulator-\d+)\s+device$') {
            return $Matches[1]
        }
    }
    return $null
}

function Ensure-EmulatorRunning {
    param([string]$Name)
    $serial = Get-RunningEmulatorSerial
    if ($null -ne $serial) {
        Write-Log "Using already running emulator: $serial"
        return $serial
    }
    if (-not (Test-Path -LiteralPath $emulatorBin -PathType Leaf)) {
        throw "Android emulator binary not found at $emulatorBin"
    }
    $avds = @(& $emulatorBin -list-avds 2>$null)
    if ($avds -notcontains $Name) {
        throw "AVD '$Name' not found. Available: $($avds -join ', ')"
    }
    Write-Log "Starting headless emulator '$Name'..."
    $proc = Start-Process -FilePath $emulatorBin -ArgumentList @(
        '-avd', $Name,
        '-no-window',
        '-no-audio',
        '-no-boot-anim',
        '-camera-back', 'none',
        '-camera-front', 'none',
        '-gpu', 'swiftshader_indirect'
    ) -PassThru -WindowStyle Hidden
    $script:startedEmulatorProcess = $proc

    $deadline = (Get-Date).AddMinutes(4)
    while ((Get-Date) -lt $deadline) {
        if ($proc.HasExited) {
            throw "Emulator process exited prematurely with code $($proc.ExitCode)"
        }
        $serial = Get-RunningEmulatorSerial
        if ($null -ne $serial) {
            $boot = (& $adbBin -s $serial shell getprop sys.boot_completed 2>$null) -join ''
            if ($boot.Trim() -eq '1') {
                Start-Sleep -Seconds 3
                $script:startedEmulatorSerial = $serial
                Write-Log "Emulator '$Name' booted at $serial"
                return $serial
            }
        }
        Start-Sleep -Seconds 3
    }
    throw "Timed out waiting for emulator '$Name' to boot."
}

function Stop-StartedEmulator {
    if ($null -ne $script:startedEmulatorSerial) {
        Write-Log "Shutting down emulator $script:startedEmulatorSerial..."
        try { & $adbBin -s $script:startedEmulatorSerial emu kill 2>$null | Out-Null } catch {}
        Start-Sleep -Seconds 2
    }
    if ($null -ne $script:startedEmulatorProcess -and -not $script:startedEmulatorProcess.HasExited) {
        try { $script:startedEmulatorProcess.Kill() } catch {}
    }
}

function Find-LatestBuildTool {
    param([string]$ToolName)
    $btDir = Join-Path $sdkRoot 'build-tools'
    if (-not (Test-Path -LiteralPath $btDir -PathType Container)) { return $null }
    $versions = Get-ChildItem -LiteralPath $btDir -Directory | Sort-Object Name -Descending
    foreach ($v in $versions) {
        foreach ($ext in @('.exe', '.bat', '')) {
            $candidate = Join-Path $v.FullName "$ToolName$ext"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    return $null
}

Push-Location $projectDir
$overallExit = 0
try {
    # Level A
    Invoke-Step 'Generate localizations (gen-l10n)' {
        Invoke-Checked $flutterBin @('--no-version-check', 'gen-l10n') | Out-Null
    }
    Invoke-Step 'Code generation (build_runner)' {
        Invoke-Checked $dartBin @('run', 'build_runner', 'build', '--delete-conflicting-outputs') | Out-Null
        Invoke-Checked $dartBin @('format', 'lib/data/database/app_database.g.dart') | Out-Null
    }
    Invoke-Step 'Generate OCR fixture bundle' {
        Invoke-Checked $dartBin @('run', 'tool/generate_ocr_fixture_bundle.dart') | Out-Null
    }
    Invoke-Step 'Format check' {
        Invoke-Checked $dartBin @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'integration_test', 'tool') | Out-Null
    }
    Invoke-Step 'Static analysis' {
        Invoke-Checked $flutterBin @('--no-version-check', 'analyze') | Out-Null
    }
    Invoke-Step 'Unit and widget tests' {
        $testOut = Invoke-Checked $flutterBin @('--no-version-check', 'test')
        $summaryLine = ($testOut | Select-String -Pattern '\+\d+.*All tests passed!' | Select-Object -Last 1)
        if ($null -ne $summaryLine) {
            $metrics['Tests'] = $summaryLine.Line.Trim()
        }
    }
    Invoke-Step 'Offline audit (source)' {
        & (Join-Path $PSScriptRoot 'audit_offline.ps1')
        if ($LASTEXITCODE -ne 0) { throw "audit_offline.ps1 failed" }
    }

    # Level B (Emulator)
    if ($Emulator.IsPresent) {
        $serial = $null
        Invoke-Step 'Build debug APK' {
            Invoke-Checked $flutterBin @('--no-version-check', 'build', 'apk', '--debug', '--dart-define=ROSID_FAKE_CAMERA=true') | Out-Null
        }
        Invoke-Step 'Start emulator and install debug APK' {
            $script:emuSerial = Ensure-EmulatorRunning -Name $AvdName
            $apk = Join-Path $projectDir 'build\app\outputs\flutter-apk\app-debug.apk'
            Invoke-Checked $adbBin @('-s', $script:emuSerial, 'install', '-r', '-g', $apk) | Out-Null
        }
        Invoke-Step 'Cold start launch and screenshot' {
            $serial = $script:emuSerial
            & $adbBin -s $serial shell am force-stop app.rosid.rosid 2>$null | Out-Null
            Start-Sleep -Seconds 1
            $launchOut = Invoke-Checked $adbBin @('-s', $serial, 'shell', 'am', 'start', '-W', '-n', 'app.rosid.rosid/.MainActivity')
            $totalTimeLine = $launchOut | Select-String -Pattern 'TotalTime:\s*(\d+)' | Select-Object -First 1
            if ($null -ne $totalTimeLine) {
                $ms = [int]$totalTimeLine.Matches[0].Groups[1].Value
                $metrics['Cold start (ms)'] = $ms
            }
            Start-Sleep -Seconds 3
            if (-not [string]::IsNullOrWhiteSpace($Evidence)) {
                $screenDir = Join-Path $projectDir "evidence\$Evidence\screens"
                New-Item -ItemType Directory -Force -Path $screenDir | Out-Null
                $shotPath = Join-Path $screenDir 'launch-home.png'
                $tmpRemote = '/sdcard/rosid_launch.png'
                & $adbBin -s $serial shell screencap -p $tmpRemote
                & $adbBin -s $serial pull $tmpRemote $shotPath | Out-Null
                & $adbBin -s $serial shell rm -f $tmpRemote
                Write-Log "Saved screenshot: $shotPath"
            }
        }
    }

    # Release level
    if ($Release.IsPresent) {
        Invoke-Step 'Verify signing files are not tracked by git' {
            $tracked = & git ls-files android/key.properties "*.jks" "*.keystore" 2>$null
            if (-not [string]::IsNullOrWhiteSpace(($tracked -join ''))) {
                throw "Signing material is tracked by git: $($tracked -join ', ')"
            }
        }
        Invoke-Step 'Build split release APKs' {
            Invoke-Checked $flutterBin @(
                '--no-version-check', 'build', 'apk', '--release',
                '--split-per-abi',
                '--target-platform', 'android-arm,android-arm64',
                '--obfuscate',
                '--split-debug-info=build/symbols',
                '--tree-shake-icons'
            ) | Out-Null
        }
        Invoke-Step 'Offline audit (merged release manifest)' {
            & (Join-Path $PSScriptRoot 'audit_offline.ps1') -RequireMerged
            if ($LASTEXITCODE -ne 0) { throw "audit_offline.ps1 -RequireMerged failed" }
        }
        Invoke-Step 'Release APK checks (size, permissions, 16KB alignment, signing)' {
            $arm64Apk = Join-Path $projectDir 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
            if (-not (Test-Path -LiteralPath $arm64Apk -PathType Leaf)) {
                throw "Missing $arm64Apk"
            }
            $sizeMb = [math]::Round((Get-Item $arm64Apk).Length / 1MB, 2)
            $metrics['arm64 APK size (MB)'] = $sizeMb
            if ($sizeMb -gt 110) {
                throw "arm64 APK exceeds 110 MB limit: $sizeMb MB"
            }
            $aapt2 = Find-LatestBuildTool 'aapt2'
            if ($null -ne $aapt2) {
                $perms = & $aapt2 dump permissions $arm64Apk 2>&1
                if ($perms -match 'INTERNET|ACCESS_NETWORK_STATE') {
                    throw "Network permission found in release APK: $($perms -join '; ')"
                }
            }
            $zipalign = Find-LatestBuildTool 'zipalign'
            if ($null -ne $zipalign) {
                Invoke-Checked $zipalign @('-c', '-P', '16', '-v', '4', $arm64Apk) | Out-Null
            }
            $apksigner = Find-LatestBuildTool 'apksigner'
            if ($null -ne $apksigner) {
                $sigOut = Invoke-Checked $apksigner @('verify', '--print-certs', $arm64Apk)
                $shaLine = $sigOut | Select-String -Pattern 'SHA-256 digest:\s*([0-9a-fA-F]+)' | Select-Object -First 1
                if ($null -ne $shaLine) {
                    $metrics['Signing cert SHA-256'] = $shaLine.Matches[0].Groups[1].Value
                }
            }
        }
        Invoke-Step 'Random-input monkey test (5000 events)' {
            $serial = $script:emuSerial
            # Install arm64 or x86_64/universal debug-free release? Emulator is x86_64, so build x86_64 release for monkey if needed.
            $x86Apk = Join-Path $projectDir 'build\app\outputs\flutter-apk\app-x86_64-release.apk'
            Invoke-Checked $flutterBin @('--no-version-check', 'build', 'apk', '--release', '--target-platform', 'android-x64', '--obfuscate', '--split-debug-info=build/symbols-x64', '--tree-shake-icons') | Out-Null
            $releaseApk = Join-Path $projectDir 'build\app\outputs\flutter-apk\app-release.apk'
            if (Test-Path -LiteralPath $x86Apk) { $releaseApk = $x86Apk }
            Invoke-Checked $adbBin @('-s', $serial, 'install', '-r', '-g', $releaseApk) | Out-Null
            $monkeyOut = Invoke-Checked $adbBin @('-s', $serial, 'shell', 'monkey', '-p', 'app.rosid.rosid', '-s', '20261126', '--throttle', '10', '--pct-syskeys', '0', '5000')
            if (($monkeyOut -join "`n") -match 'CRASH|ANR|Monkey aborted') {
                throw 'Monkey test detected crash or ANR'
            }
            $metrics['Monkey 5000 events'] = 'pass (0 crashes)'
        }
    }
} catch {
    $overallExit = 1
    Write-Log "VERIFY FAILED: $($_.Exception.Message)"
} finally {
    Stop-StartedEmulator
    if (-not [string]::IsNullOrWhiteSpace($Evidence)) {
        $evDir = Join-Path $projectDir "evidence\$Evidence"
        New-Item -ItemType Directory -Force -Path $evDir | Out-Null
        $logPath = Join-Path $evDir 'verify.log'
        Set-Content -Path $logPath -Value ($logLines -join "`n") -Encoding UTF8

        $commit = (& git rev-parse --short HEAD 2>$null) -join ''
        $flutterVer = ((& $flutterBin --version 2>$null) | Select-Object -First 1) -join ''
        $level = if ($Release.IsPresent) { 'Release' } elseif ($Emulator.IsPresent) { 'B' } else { 'A' }

        $md = [System.Text.StringBuilder]::new()
        [void]$md.AppendLine("# Verification summary: $Evidence")
        [void]$md.AppendLine()
        [void]$md.AppendLine("- **Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
        [void]$md.AppendLine("- **Commit**: ``$commit``")
        [void]$md.AppendLine("- **Level**: $level")
        [void]$md.AppendLine("- **Flutter**: $flutterVer")
        [void]$md.AppendLine()
        [void]$md.AppendLine("## Steps")
        [void]$md.AppendLine()
        [void]$md.AppendLine("| Step | Status | Duration (s) |")
        [void]$md.AppendLine("|---|---|---|")
        foreach ($s in $stepResults) {
            [void]$md.AppendLine("| $($s.Name) | $($s.Status) | $($s.Seconds) |")
        }
        if ($metrics.Count -gt 0) {
            [void]$md.AppendLine()
            [void]$md.AppendLine("## Measured numbers")
            [void]$md.AppendLine()
            [void]$md.AppendLine("| Metric | Value |")
            [void]$md.AppendLine("|---|---|")
            foreach ($k in $metrics.Keys) {
                [void]$md.AppendLine("| $k | $($metrics[$k]) |")
            }
        }
        $summaryPath = Join-Path $evDir 'summary.md'
        Set-Content -Path $summaryPath -Value $md.ToString() -Encoding UTF8
        Write-Output "Wrote evidence summary to $summaryPath"
    }
    Pop-Location
}

exit $overallExit
