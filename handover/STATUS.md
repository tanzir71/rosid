# Status

The implementing agent keeps this file true. Update it in the same push as the work.

Last updated: 2026-11-27 (M5 completed and verified to Level B)

## Milestones

| | Milestone | State | Verified to | Evidence |
|---|---|---|---|---|
| M0 | Ground rules and baseline | done | B | `evidence/M0/summary.md` |
| M1 | Design system and app shell | done | B | `evidence/M1/summary.md` |
| M2 | Capture and image | done | B | `evidence/M2/summary.md` |
| M3 | Reading text | done | B | `evidence/M3/summary.md` |
| M4 | Read and fix | done | B | `evidence/M4/summary.md` |
| M5 | English draft | done | B | `evidence/M5/summary.md` |
| M6 | Export | in progress | | |
| M7 | Library and bundles | not started | | |
| M8 | Expenses, settings, safety | not started | | |
| M9 | Landing page and release | not started | | |

State is one of: not started, in progress, done, done with gaps.
"Verified to" is A, B or Release, as defined in `03-verification.md`.

## In progress

Starting M6: Export.

## Measured numbers

Fill in as they are measured. Never write a number you did not measure.

| What | Target | Measured | Where |
|---|---|---|---|
| Printed English character error, synthetic set | 5% or less | 0.09% (baseline 0.18%, n=54) | `evidence/M3/final.json` |
| Printed Bangla character error, synthetic set | 30% lower than the M3 baseline | 2.22% vs 4.75% baseline (-53.3%, n=62) | `evidence/M3/final.json` |
| Receipt total read exactly, synthetic set | 85% or more | 35/36 (97.2%) | `evidence/M3/final.json` |
| Time for one page, emulator | 4 s or less | 3.60 s median (`rosid_test`, debug JIT) | `evidence/M3/summary.md` |
| Cold start, emulator | 3 s or less | 2.66 s (M0 v1 release baseline on `rosid_test`) | `evidence/M0/summary.md` |
| Peak memory while reading, 2 GB emulator | 600 MB or less | 248.7 MB RSS (`rosid_low`) | `evidence/M3/summary.md` |
| arm64 APK size | 90 MB target, 110 MB limit | 108.5 MB split arm64-v8a release APK (M5, incl. Mozilla `bn-en` model + Bergamot WASM) | `evidence/M5/summary.md` |
| M5 English draft gate (40 lines) | 100% preservation, <= 8 s/page | 51/51 (100%) preserved, 65 ms median/page (`rosid_test`), chrF 81.32 | `evidence/M5/summary.md` |
| Random-input test, 5,000 events | no crash | | |

## Decisions taken

Record every choice the handover left to you: which Bangla recogniser won, which translation integration shipped, package versions actually used, any threshold you could not meet.

| Date | Decision | Why |
|---|---|---|
| 2026-11-26 | Upgraded Flutter from 3.44.6 to 3.50.1 (Dart 3.14.0) and migrated imports to `material_ui: ^1.11.1` and `cupertino_ui: ^1.1.7` | `02-architecture.md` specifies Flutter 3.50.1; Flutter 3.50.1 deprecated `package:flutter/material.dart` in favour of `material_ui`. Excluded generated `lib/core/l10n/app_localizations*.dart` in `analysis_options.yaml` because `flutter gen-l10n` emits two deprecated localization references. |
| 2026-11-26 | Upgraded Android build to Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, OpenJDK 21 (Android Studio JBR), and replaced discontinued `flutter_tesseract_ocr` 0.4.31 with `tesseract_ocr` 0.6.0 | Flutter 3.50.1 requires Gradle 9.3.1+ and AGP 9.x; `flutter_tesseract_ocr` used `jcenter()` which fails on Gradle 9. `tesseract_ocr` 0.6.0 drops `jcenter()` and bundles `tesseract4android:4.8.0`. Set `kotlin.incremental=false` in `android/gradle.properties` to avoid Windows cross-drive incremental cache close failures. |
| 2026-11-26 | Made `tanzir71/rosid` public, switched GitHub Pages to `main /docs` (`build_type: legacy` + `.nojekyll`), removed `.github/workflows/*`, and disabled GitHub Actions (`enabled: false`) | Verified `gitleaks 8.30.1` clean across all 34 commits, verified all fixtures are synthetic, confirmed `https://tanzir71.github.io/rosid/` returns HTTP 200 without Actions. `gh` CLI is signed in as `tanzir71` with admin access; direct push to `main` works with no blocking rulesets. |
| 2026-11-26 | Configured `rosid_test` (4 GB RAM, `android-35;google_apis;x86_64`, WHPX + host GPU) and `rosid_low` (2 GB RAM) | Hardware GPU acceleration (`-gpu host`) enabled reliable, fast headless emulator verification (2.66 s AOT cold start vs 24 s with software rendering). |
| 2026-11-27 | Bundled subsetted Anek Bangla (instantiated at weights 400/500/600/700 from Google Fonts variable TTF) and Tiro Bangla (400), plus `flutter_svg: ^2.5.1` for the 56 stroke icons | Keeps total bundled fonts to ~1.1 MB while matching Mohor typography and line heights (`tokens.g.dart` generated from `design/tokens.json`). `flutter_svg` adds zero Android permissions. |
| 2026-11-27 | Added Schema v3 migration (`scans` additions, `scan_pages` additions, 8 new tables) and built empty states for Library, Bundles, Expenses, and shell routes | Preserves all v1/v2 rows (verified by v2→v3 SQLite migration test). Empty states use Mohor cards and primary actions as specified in `design/screens.md` "States not drawn". |
| 2026-11-27 | M2 fallback: removed `opencv_dart: 2.3.3` and implemented pure-Dart 320 px live edge/quality analyzer (`FrameAnalyzerIsolate`) plus <= 2,000 px `ImageCleaner` (perspective warp, 1/8-scale bright-dilation lighting division, 8x8 CLAHE clip 2.0, edge-preserving denoise, deskew) | `dartcv4`'s native build hook failed during `flutter build apk` while compiling OpenCV 4.13 from source via CMake/Ninja (`The paging file is too small for this operation to complete`). Per `M2-capture-and-image.md` Fallbacks, pure Dart met every M2 gate: 23/24 (95.8%) corners within 2% of frame diagonal on synthetic photo-like set, 3 ms median luma frame time (21 ms encoded JPEG) in `FrameAnalyzerIsolate` on `rosid_test`, and zero native size/alignment bloat. |
| 2026-11-27 | M3 OCR engine choice: bundled official Apache-2.0 PP-OCRv5 mobile det (4.60 MB) + PP-OCRv5 English mobile rec (7.48 MB) via `flutter_onnxruntime: 1.9.1` (ONNX Runtime 1.28.0) + per-line Tesseract `psm 7` with `tessdata_best` for Bangla; retired ML Kit (`com.google.mlkit:text-recognition`) and `tflite_bn_stub.dart`; skipped EasyOCR 54 MB Bengali ONNX | Benchmark on 168 synthetic fixtures (`evidence/M3/baseline.json` vs `final.json`): Baseline v1 whole-page Tesseract got 0.18% EN CER, 4.75% BN CER, 3.94% mixed CER. Per-line `tessdata_fast` got 17.58% BN CER (rejected). Per-line `tessdata_best` + PP-OCRv5 ONNX achieved **0.09% EN CER**, **2.22% BN CER (-53.3% vs baseline)**, **2.30% mixed CER**, **97.2% exact receipt totals**, **3.60 s/page** on `rosid_test`, **248.7 MB RSS** on `rosid_low`, and **91.92 MB** arm64 APK with zero Play Services classes. EasyOCR 54 MB ONNX would break the 110 MB arm64 APK limit (91.9 + 54 > 110 MB) and is slower. Handwriting detection tested using synthetic OFL `Galada` calligraphy fixtures (flagged `is_synthetic_handwriting: true`). |

| 2026-11-27 | M4 Listen (read aloud) & Check Words alternatives | Implemented Listen via a zero-dependency, zero-permission Android `TextToSpeech` MethodChannel (`app.rosid.rosid/tts`) that checks `isLanguageAvailable(Locale("bn", "BD"))` and hides Listen automatically when no offline Bangla voice is installed. Built Check Words alternatives from remembered `corrections` (first priority), `names`, and a curated Bangla/English document vocabulary with edit-distance <= 2 (per M4 fallback). |
| 2026-11-27 | M5 translation engine: shipped Integration A (hidden Android `WebView` + Mozilla Firefox Translations `bn-en` v1.0 + Bergamot WASM v3.0, MPL-2.0) | Stored the 4 Mozilla binary files deterministically gzipped (`mtime=0`, level 9, 16.28 MB total) in `assets/models/translation/` and served them strictly offline via `OfflineBergamotTranslator.kt` `shouldInterceptRequest` (`https://rosid.local/translation/*` with on-the-fly `GZIPInputStream`, HTTP 403 for all other origins, zero extra pub packages, zero `INTERNET` permission). Passed M5 40-line gate on `rosid_test` (51/51 = 100% preservation of numbers/dates/names, 65 ms median page time, chrF 81.32), Flow 4 E2E passed up to export, and split arm64 release APK is 108.5 MB (<= 110 MB) with `CAMERA` permission only. |

## Not done, needs a person

Things you could not do alone. One line each: what, why, and what you shipped instead.

| What | Why a person is needed | What was shipped instead |
|---|---|---|
| Licence for the repository | A legal choice only the owner can make | No licence file; third-party notices only |
| Version 1 signing key | Neither `android/key.properties` nor `%LOCALAPPDATA%\Rosid\ReleaseKey\rosid-release.jks` exists on this machine | Version 2 is signed with a new key at `%USERPROFILE%\.rosid\rosid-release.jks` (SHA-256 `1B:83:A5:29:55:86:4B:A1:C9:8D:1B:52:36:C2:96:72:57:B3:63:41:3F:40:74:BA:C7:35:68:95:FB:9D:FE:47`). Version 1 users must uninstall before installing. Back up `%USERPROFILE%\.rosid`; losing it means future updates cannot install over this one. |
| iPhone build | Needs a Mac with Xcode (no GitHub Actions) | Android-only release for 2.0; `ios/` left in place |

## Not verified by machine

Things that exist and may work but that you could not check on your machine (for example a real camera lens, a real share target, a real printer).

| What | Why it could not be checked |
|---|---|
| Physical Android device installation and camera lens/autofocus | Headless emulator only; no physical phone available |
| Live hardware camera YUV image stream format on physical phones | Headless emulator camera tested via `FakeCaptureSource` fixture stream; live hardware Y-plane stride behaviour depends on device HAL |
| Real Bangla TTS voice for Listen (read aloud) | Headless emulator ships without an offline `bn-BD` voice pack; Listen hides automatically when unavailable |
