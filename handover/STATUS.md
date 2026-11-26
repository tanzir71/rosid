# Status

The implementing agent keeps this file true. Update it in the same push as the work.

Last updated: 2026-11-27 (M0 completed and verified to Level B)

## Milestones

| | Milestone | State | Verified to | Evidence |
|---|---|---|---|---|
| M0 | Ground rules and baseline | done | B | `evidence/M0/summary.md` |
| M1 | Design system and app shell | not started | | |
| M2 | Capture and image | not started | | |
| M3 | Reading text | not started | | |
| M4 | Read and fix | not started | | |
| M5 | English draft | not started | | |
| M6 | Export | not started | | |
| M7 | Library and bundles | not started | | |
| M8 | Expenses, settings, safety | not started | | |
| M9 | Landing page and release | not started | | |

State is one of: not started, in progress, done, done with gaps.
"Verified to" is A, B or Release, as defined in `03-verification.md`.

## In progress

Starting M1: Design system and app shell.

## Measured numbers

Fill in as they are measured. Never write a number you did not measure.

| What | Target | Measured | Where |
|---|---|---|---|
| Printed English character error, synthetic set | 5% or less | | |
| Printed Bangla character error, synthetic set | 30% lower than the M3 baseline | | |
| Receipt total read exactly, synthetic set | 85% or more | | |
| Time for one page, emulator | 4 s or less | | |
| Cold start, emulator | 3 s or less | 2.66 s (M0 v1 release baseline on `rosid_test`) | `evidence/M0/summary.md` |
| Peak memory while reading, 2 GB emulator | 600 MB or less | | |
| arm64 APK size | 90 MB target, 110 MB limit | 136.56 MB universal baseline (M0, pre-split) | `evidence/M0/baseline-release.txt` |
| Random-input test, 5,000 events | no crash | | |

## Decisions taken

Record every choice the handover left to you: which Bangla recogniser won, which translation integration shipped, package versions actually used, any threshold you could not meet.

| Date | Decision | Why |
|---|---|---|
| 2026-11-26 | Upgraded Flutter from 3.44.6 to 3.50.1 (Dart 3.14.0) and migrated imports to `material_ui: ^1.11.1` and `cupertino_ui: ^1.1.7` | `02-architecture.md` specifies Flutter 3.50.1; Flutter 3.50.1 deprecated `package:flutter/material.dart` in favour of `material_ui`. Excluded generated `lib/core/l10n/app_localizations*.dart` in `analysis_options.yaml` because `flutter gen-l10n` emits two deprecated localization references. |
| 2026-11-26 | Upgraded Android build to Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, OpenJDK 21 (Android Studio JBR), and replaced discontinued `flutter_tesseract_ocr` 0.4.31 with `tesseract_ocr` 0.6.0 | Flutter 3.50.1 requires Gradle 9.3.1+ and AGP 9.x; `flutter_tesseract_ocr` used `jcenter()` which fails on Gradle 9. `tesseract_ocr` 0.6.0 drops `jcenter()` and bundles `tesseract4android:4.8.0`. Set `kotlin.incremental=false` in `android/gradle.properties` to avoid Windows cross-drive incremental cache close failures. |
| 2026-11-26 | Made `tanzir71/rosid` public, switched GitHub Pages to `main /docs` (`build_type: legacy` + `.nojekyll`), removed `.github/workflows/*`, and disabled GitHub Actions (`enabled: false`) | Verified `gitleaks 8.30.1` clean across all 34 commits, verified all fixtures are synthetic, confirmed `https://tanzir71.github.io/rosid/` returns HTTP 200 without Actions. `gh` CLI is signed in as `tanzir71` with admin access; direct push to `main` works with no blocking rulesets. |
| 2026-11-26 | Configured `rosid_test` (4 GB RAM, `android-35;google_apis;x86_64`, WHPX + host GPU) and `rosid_low` (2 GB RAM) | Hardware GPU acceleration (`-gpu host`) enabled reliable, fast headless emulator verification (2.66 s AOT cold start vs 24 s with software rendering). |

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
