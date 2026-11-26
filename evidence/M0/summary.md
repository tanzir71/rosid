# Verification summary: M0

- **Date**: 2026-11-27 00:36 +06:00
- **Commit**: `4c7cb1f` (plus M0 evidence & STATUS commit)
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable (Dart 3.14.0)
- **Android toolchain**: Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, OpenJDK 21.0.8 (JBR), AVD `rosid_test` (`android-35;google_apis;x86_64`, WHPX + RTX 3060 host GPU)

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (`gen-l10n`) | pass | 13.72 |
| Code generation (`build_runner`) | pass | 32.97 |
| Generate OCR fixture bundle | pass | 12.56 |
| Format check (`dart format`) | pass | 3.76 |
| Static analysis (`flutter analyze`) | pass | 145.06 |
| Unit and widget tests (`flutter test`) | pass | 45.12 |
| Offline audit (source + merged release manifests) | pass | 1.43 |
| Universal release APK baseline build | pass | 367.80 |
| Debug APK build (`ROSID_FAKE_CAMERA=true`) | pass | 177.78 |
| Emulator boot (`rosid_test`) & APK install | pass | 55.60 |
| Cold start launch & home screenshot | pass | 24.80 |

## Baseline measured numbers

| Metric | Value |
|---|---|
| Unit and widget tests | 188 passed (185 v1 + 3 `FakeCaptureSource`) |
| Universal release APK size (v1 baseline on Flutter 3.50.1) | 143,191,426 bytes (136.56 MB) |
| `FakeCaptureSource` hits in release symbols (`build/symbols-m0`) | 0 |
| Offline audit | Passed across 4 merged release manifests |
| Cold start on `rosid_test` (AOT release APK, `-gpu host`) | 2,656 ms (`TotalTime`, `LaunchState: COLD`) |
| Cold start on `rosid_test` (first launch right after install) | 10,800 ms (`TotalTime`) |
| GitHub Pages (`https://tanzir71.github.io/rosid/`) | HTTP 200 (`build_type: legacy`, `main /docs`, Actions disabled) |
| Secret scan (`gitleaks 8.30.1 --log-opts="--all"`) | 34 commits scanned, 0 leaks |

## Evidence files

- `evidence/M0/pages.txt` — GitHub Pages build status, HTTP 200 headers, and Actions disabled proof
- `evidence/M0/secret-scan.txt` — `gitleaks` and key-file scan summary
- `evidence/M0/baseline-release.txt` — Universal release APK size, symbol audit, offline audit
- `evidence/M0/screens/launch-home.png` — Rendered home screen captured from `rosid_test`
- `evidence/M0/verify.log` — Full `tool/verify.ps1` log
