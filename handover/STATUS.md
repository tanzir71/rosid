# Status

The implementing agent keeps this file true. Update it in the same push as the work.

Last updated: 2026-11-27 (Rosid 2.0.0 complete — M0 through M9 done, verified to Release level, published on GitHub Releases and live on GitHub Pages)

## Summary

- **Release**: [Rosid 2.0.0 (`v2.0.0`)](https://github.com/tanzir71/rosid/releases/tag/v2.0.0) — signed split Android APKs (`rosid-arm64-v8a.apk`, 99.75 MB; `rosid-armeabi-v7a.apk`, 88.53 MB), `SHA256SUMS.txt`, `symbols-2.0.0.zip`, and bilingual release notes.
- **Landing page**: Live at <https://tanzir71.github.io/rosid/> (বাংলা) and <https://tanzir71.github.io/rosid/en/> (English), served from `main /docs` with zero GitHub Actions and zero external requests.
- **Privacy**: Zero `INTERNET` or `ACCESS_NETWORK_STATE` permission in source or merged release manifests; zero Firebase, Play Services, analytics, or ad SDK classes in DEX. Every OCR model, translation model, and font ships inside the APK.

## Milestones

| | Milestone | State | Verified to | Evidence |
|---|---|---|---|---|
| M0 | Ground rules and baseline | done | B | `evidence/M0/summary.md` |
| M1 | Design system and app shell | done | B | `evidence/M1/summary.md` |
| M2 | Capture and image | done | B | `evidence/M2/summary.md` |
| M3 | Reading text | done | B | `evidence/M3/summary.md` |
| M4 | Read and fix | done | B | `evidence/M4/summary.md` |
| M5 | English draft | done | B | `evidence/M5/summary.md` |
| M6 | Export | done | B | `evidence/M6/summary.md` |
| M7 | Library and bundles | done | B | `evidence/M7/summary.md` |
| M8 | Expenses, settings, safety | done | B | `evidence/M8/summary.md` |
| M9 | Landing page and release | done | Release | `evidence/M9/summary.md` |

State is one of: not started, in progress, done, done with gaps.
"Verified to" is A, B or Release, as defined in `03-verification.md`.

## In progress

None. All milestones M0–M9 are complete and pushed to `main`.

## Measured numbers

All values below were measured on this machine (`rosid_test` / `rosid_low` / host). Nothing was estimated.

| What | Target | Measured | Where |
|---|---|---|---|
| Printed English character error, synthetic set | 5% or less | 0.09% (baseline 0.18%, n=54) | `evidence/M3/final.json` |
| Printed Bangla character error, synthetic set | 30% lower than M3 baseline | 2.22% vs 4.75% baseline (-53.3%, n=62) | `evidence/M3/final.json` |
| Receipt total read exactly, synthetic set | 85% or more | 35/36 (97.2%) | `evidence/M3/final.json` |
| Time for one page, emulator | 4 s or less | 3.60 s median (`rosid_test`, debug JIT) | `evidence/M3/summary.md` |
| Cold start, emulator (release build) | 3 s or less | 0.70 s (`703 ms`, `rosid_test` release AOT) | `evidence/M9/summary.md` |
| Peak memory while reading, 2 GB emulator | 600 MB or less | 248.7 MB RSS (`rosid_low`) | `evidence/M3/summary.md` |
| arm64 APK size | 90 MB target, 110 MB limit | 99.75 MB (`rosid-arm64-v8a.apk`); 88.53 MB (`rosid-armeabi-v7a.apk`) | `evidence/M9/summary.md` |
| 16 KB page alignment | All `.so` aligned | Pass (`zipalign -c -P 16 -v 4` + `llvm-readelf` across all 13 `arm64-v8a` `.so` libs) | `evidence/M9/summary.md` |
| Network permissions & DEX libraries | None | 0 network permissions (`CAMERA`, `USE_BIOMETRIC`, `USE_FINGERPRINT` only); 0 Firebase/Play Services/analytics/ads DEX classes | `evidence/M9/summary.md` |
| M5 English draft gate (40 lines) | 100% preservation, <= 8 s/page | 51/51 (100%) preserved, 64–65 ms median/page (`rosid_test`), chrF 81.32 | `evidence/M5/summary.md` |
| 500-paper search, emulator | 150 ms or less | 3–4 ms Bangla, 1–2 ms English via Name Book (`rosid_test`) | `evidence/M7/summary.md` |
| Random-input test, 5,000 events (release) | no crash | Pass (5,000 events, seed `20261126`, 0 crashes, 0 ANRs) | `evidence/M9/summary.md` |
| Unit, widget & golden tests | All pass | 281/281 passed + all 6 E2E flow files (Flows 1–11) passed | `evidence/M9/summary.md` |
| Landing page weight & external requests | < 600 KB, 0 external | bn 353.3 KB, en 349.4 KB (excl. lazy screens); 0 external requests in headless Chrome | `evidence/M9/summary.md` |
| Lighthouse accessibility score | 95 or more (if available) | Not run (Lighthouse CLI not installed on host) | `evidence/M9/summary.md` |
| LibreOffice headless `.docx -> PDF` | Visual check (if available) | Not run (`soffice` not installed on host); `.docx` zip/XML verified programmatically | `evidence/M6/summary.md` |

## Decisions taken

| Date | Decision | Why |
|---|---|---|
| 2026-11-26 | Upgraded Flutter to 3.50.1 (Dart 3.14.0), `material_ui: ^1.11.1`, `cupertino_ui: ^1.11.7`, Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, OpenJDK 21, and `tesseract_ocr: ^0.6.0` | Matches `02-architecture.md`; `flutter_tesseract_ocr` depended on removed `jcenter()`. |
| 2026-11-26 | Made `tanzir71/rosid` public, switched GitHub Pages to `main /docs` (`build_type: legacy` + `.nojekyll`), removed `.github/workflows/*`, and disabled GitHub Actions (`enabled: false`) | Verified `gitleaks 8.30.1` clean across all commits and confirmed all fixtures are synthetic. Pages deploys directly from `main /docs` without Actions. |
| 2026-11-27 | Bundled subsetted Anek Bangla (400/500/600/700) and Tiro Bangla (400) + `flutter_svg: ^2.5.1` (56 icons); added Drift Schema v3 migration preserving v1/v2 rows | Matches Mohor design system (`design/tokens.json`) and keeps bundled fonts compact (~1.1 MB). Built empty/loading/error/lock states from the same tokens. |
| 2026-11-27 | M2 fallback: replaced `opencv_dart` with pure-Dart `FrameAnalyzerIsolate` (320 px) and `ImageCleaner` (<= 2,000 px) | `dartcv4`'s native CMake OpenCV 4.13 build hit Windows paging-file exhaustion. Pure Dart met every M2 gate (95.8% corner accuracy, 3 ms median luma on `rosid_test`, 0 native bloat). |
| 2026-11-27 | M3 OCR engine: bundled Apache-2.0 PP-OCRv5 mobile det + English rec via `flutter_onnxruntime: 1.9.1` + per-line Tesseract `psm 7` (`ben.traineddata` from `tessdata_best`, `eng.traineddata` from `tessdata_fast`); retired ML Kit; skipped EasyOCR 54 MB model | Achieved 0.09% EN CER, 2.22% BN CER (-53.3% vs baseline), 97.2% exact receipt totals, 3.60 s/page, 248.7 MB RSS on `rosid_low`, and kept `rosid-arm64-v8a.apk` at 99.75 MB (<= 110 MB) with 0 Play Services classes. |
| 2026-11-27 | M4 Listen & Check Words: zero-permission Android `TextToSpeech` channel (`app.rosid.rosid/tts`) hiding Listen when no `bn-BD` voice is installed; alternatives from remembered corrections + Name Book + edit-distance <= 2 vocabulary | Zero external packages or permissions; follows M4 fallback specification. |
| 2026-11-27 | M5 Translation: shipped Integration A — hidden Android `WebView` + Mozilla Firefox Translations `bn-en` v1.0 + Bergamot WASM v3.0 (MPL-2.0, deterministically gzipped, 16.28 MB) via `OfflineBergamotTranslator.kt` | Strict offline `shouldInterceptRequest` (`https://rosid.local/translation/*` only; HTTP 403 for all other origins), zero `INTERNET` permission, 100% entity preservation, 64–65 ms/page median, chrF 81.32. |
| 2026-11-27 | M6 Export: native Kotlin `PlatformFileBridge.kt` (Android SAF + `PrintManager`), pure-Dart `archive: ^4.0.9` `.docx` writer, PDF password option hidden | Avoided `printing` package because it depends on `http`. Hid PDF password per M6 step 12 because `pdf: ^3.13.0` lacks encryption. |
| 2026-11-27 | M8 Safety: added pure-Dart `cryptography: ^2.9.0` (Argon2id + AES-256-GCM) and `local_auth: ^3.0.2` (`USE_BIOMETRIC` / `USE_FINGERPRINT` hardware-only permissions), switched `MainActivity` to `FlutterFragmentActivity`, added `FLAG_SECURE` channel enabled only while locked | Zero network permissions; atomic `VACUUM INTO` + encrypted ZIP backup/restore verified by host SHA-256 round-trip, wrong-password, and truncated-file tests. |
| 2026-11-27 | M9 Release: swapped `eng.traineddata` to `tessdata_fast` (3.92 MB) to keep `rosid-arm64-v8a.apk` well under 110 MB (99.75 MB); removed legacy `site/` and stale golden failure diffs; published `v2.0.0` and updated `docs/` | Initial M9 arm64 APK was 110.09 MB; swapping secondary `eng.traineddata` freed 11.48 MB with zero loss on PP-OCRv5 English (0.09% CER) or `tessdata_best` Bangla (2.22% CER). |

## Not done, needs a person

| What | Why a person is needed | What was shipped instead |
|---|---|---|
| Licence for the repository | A legal choice only the owner can make | No licence file; third-party notices in `NOTICE.md` only |
| Version 1 signing key | Neither `android/key.properties` nor `%LOCALAPPDATA%\Rosid\ReleaseKey\rosid-release.jks` existed on this machine | Version 2.0.0 is signed with a new key at `%USERPROFILE%\.rosid\rosid-release.jks` (SHA-256 `1B:83:A5:29:55:86:4B:A1:C9:8D:1B:52:36:C2:96:72:57:B3:63:41:3F:40:74:BA:C7:35:68:95:FB:9D:FE:47`). Version 1 users must uninstall before installing. Back up `%USERPROFILE%\.rosid`; losing it means future updates cannot install over this one. Documented in release notes and landing page install steps. |
| iPhone build | Needs a Mac with Xcode (no GitHub Actions) | Android-only release for 2.0.0; `ios/` left in place |

## Not verified by machine

| What | Why it could not be checked |
|---|---|
| Physical Android device installation from a browser download | Headless emulator only; no physical phone available |
| Real camera lens, autofocus, YUV HAL stride, and real paper under real lighting | Tested with `FakeCaptureSource` fixture stream and synthetic photo-like datasets |
| Real physical fingerprint/biometric sensor hardware | Headless emulator has no physical fingerprint sensor; PIN path verified end to end (Flow 9) and biometric path verified via a fake authenticator in widget tests |
| System file picker (SAF), third-party share targets, and physical printing | Integration tests verify the exported temp file written by Rosid up to the system handoff; external Android DocumentsUI picker, third-party share apps, and real printer hardware were not exercised |
| Real Bangla TTS voice for Listen (read aloud) | Headless emulator ships without an offline `bn-BD` voice pack; Listen hides automatically when unavailable |
| LibreOffice headless `.docx -> PDF` visual render | `soffice` is not installed on this machine; `.docx` zip structure, XML, Bangla `w:cs="Nirmala UI"` / `w:bidi="bn-BD"`, and DRAFT header verified programmatically |
| Lighthouse accessibility audit | Lighthouse CLI is not installed on this machine; contrast, focus states, lang attributes, reduced motion, and 0 external requests verified directly |
