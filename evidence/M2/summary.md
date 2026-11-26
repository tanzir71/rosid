# Verification summary: M2

- **Date**: 2026-11-27 01:45:47 +06:00
- **Commit**: `948ee8c`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 2 |
| Code generation (build_runner) | pass | 60.99 |
| Generate OCR fixture bundle | pass | 7.56 |
| Format check | pass | 2.06 |
| Static analysis | pass | 7.36 |
| Unit and widget tests | pass | 25.39 |
| Offline audit (source) | pass | 0.34 |
| Build debug APK | pass | 99.23 |
| Start emulator and install debug APK | pass | 13.57 |
| Cold start launch and screenshot | pass | 15.78 |
| Integration tests (2 flow file(s)) | pass | 113.43 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:15 +217: All tests passed! |
| Cold start (ms) | 5580 |
| Integration flows | 2 file(s) passed |
| Host synthetic corner accuracy (n=24) | 23/24 (95.8%) within 2% of frame diagonal (target >= 90%) |
| Frame analysis median on `rosid_test` (`FrameAnalyzerIsolate`, 320x240 luma) | 3 ms (target <= 40 ms) |
| Frame analysis median on `rosid_test` (`FrameAnalyzerIsolate`, encoded JPEG) | 21 ms (target <= 40 ms) |
| Visual comparisons | `evidence/M2/compare/` (scan-camera, scan-id-card-back, scan-adjust-page, scan-reading, id-card-composed-a4) |

