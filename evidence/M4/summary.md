# Verification summary: M4

- **Date**: 2026-11-27 02:54:24 +06:00
- **Commit**: `96ead99`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 1.92 |
| Code generation (build_runner) | pass | 5.54 |
| Generate OCR fixture bundle | pass | 4.69 |
| Format check | pass | 2.13 |
| Static analysis | pass | 7.04 |
| Unit and widget tests | pass | 23.43 |
| Offline audit (source) | pass | 0.24 |
| Build debug APK | pass | 42.2 |
| Start emulator and install debug APK | pass | 44.78 |
| Cold start launch and screenshot | pass | 21.07 |
| Integration tests (2 flow file(s)) | pass | 114.68 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:16 +232: All tests passed! |
| Cold start (ms) | 10671 |
| Integration flows | 2 file(s) passed (Flow 1 + full Flow 2 land record read/check/fix + Flow 3 ID card) |
| Land record key details accuracy (36 synthetic land fixtures) | 36/36 (100%) on khatian no., plot no., and area (target >= 90%) |
| Land unit conversions | 12.50 decimals -> 5,445 sq ft, 0.125 acre, about 7.56 katha + 12 cases passed |
| Visual comparisons | `evidence/M4/compare/` (read-text, read-text-dark, read-check-words, read-scan-tap-line) |

