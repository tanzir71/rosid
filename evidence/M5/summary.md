# Verification summary: M5

- **Date**: 2026-11-27 03:46:50 +06:00
- **Commit**: `4bd5893`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 1.88 |
| Code generation (build_runner) | pass | 21.96 |
| Generate OCR fixture bundle | pass | 4.49 |
| Format check | pass | 2.2 |
| Static analysis | pass | 6.84 |
| Unit and widget tests | pass | 23.85 |
| Offline audit (source) | pass | 0.26 |
| Build debug APK | pass | 71.35 |
| Start emulator and install debug APK | pass | 15.03 |
| Cold start launch and screenshot | pass | 14.68 |
| Integration tests (3 flow file(s)) | pass | 179.21 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:16 +248: All tests passed! |
| Cold start (ms) | 4664 |
| Integration flows | 3 file(s) passed |


## M5 Translation Gate & Release APK Audit

- **Integration shipped**: Integration A — Hidden Android `WebView` (`OfflineBergamotTranslator.kt`) serving bundled Mozilla Firefox Translations `bn-en` v1.0 + Bergamot WASM v3.0 (MPL-2.0) strictly from local Flutter assets via `shouldInterceptRequest` (`https://rosid.local/translation/*`, 403 for all other origins).
- **40-line synthetic land-record & certificate gate (`rosid_test`)**:
  - Lines tested: 40 (5 pages x 8 lines; 8 free-text prose lines routed to Bergamot WASM)
  - Number, date & name placeholder preservation: **51 / 51 (100.0%)** (gate: 100%)
  - Median page time: **65 ms** (0.065 s; gate: <= 8.0 s; one-time cold WebView+WASM warmup: 16.3 s)
  - Reference English chrF score: **81.32** (informational)
- **Split release APK audit**:
  - `app-arm64-v8a-release.apk`: **108.5 MB** (limit <= 110 MB)
  - `app-armeabi-v7a-release.apk`: **97.1 MB**
  - `aapt2 dump permissions`: `android.permission.CAMERA` only (**0 network permissions**)
  - `zipalign -c -P 16 4`: exit 0 (16 KB aligned)
- **Design comparisons**: `evidence/M5/compare/{translate-english-draft,translate-english-draft-dark,translate-term-help,translate-name-book}.png`
