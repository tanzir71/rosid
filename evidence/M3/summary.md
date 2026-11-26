# Verification summary: M3

- **Date**: 2026-11-27 02:18:35 +06:00
- **Commit**: `2c273eb`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 2.01 |
| Code generation (build_runner) | pass | 59.28 |
| Generate OCR fixture bundle | pass | 5.24 |
| Format check | pass | 2.01 |
| Static analysis | pass | 6.98 |
| Unit and widget tests | pass | 25.04 |
| Offline audit (source) | pass | 0.23 |
| Build debug APK | pass | 92.51 |
| Start emulator and install debug APK | pass | 11.33 |
| Cold start launch and screenshot | pass | 14.89 |
| Integration tests (2 flow file(s)) | pass | 96.88 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:15 +223: All tests passed! |
| Cold start (ms) | 4877 |
| Integration flows | 2 file(s) passed (+ `m3_reading_bench_test.dart` & `ocr_fixtures_test.dart` passed on `rosid_test`) |
| Printed English CER (168 synthetic fixtures) | 0.09% (baseline 0.18%, target <= 5.0%) |
| Printed Bangla CER (168 synthetic fixtures) | 2.22% (baseline 4.75%, -53.3%, target >= 30% lower) |
| Mixed Bangla+English CER (168 synthetic fixtures) | 2.30% (baseline 3.94%, -41.6%) |
| Receipt total exact (36 synthetic receipts) | 35/36 (97.2%, target >= 85%) |
| Median page time on `rosid_test` | 3.60 s (3,603 ms debug JIT, target <= 4.0 s) |
| Peak memory while reading on `rosid_low` (2 GB) | 248.7 MB RSS (target <= 600 MB) |
| arm64 release APK size | 91.92 MB (target 90 MB, limit 110 MB) |
| Release permissions (`aapt2`) | CAMERA only (0 network permissions) |
| 16 KB alignment (`zipalign -c -P 16 4`) | pass (exit 0) |

