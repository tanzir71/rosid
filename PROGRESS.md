# Rosid progress

## Current status

- Active milestone: V1 code complete; artifact/device/publishing gates skipped by user direction
- Flutter: 3.44.6 stable; Dart: 3.12.2
- Workspace started from only `CODEX_HANDOVER.md`; Flutter project initialized on 2026-07-17.

## User-directed validation scope

The user explicitly asked to skip signing, build validation, and other steps
that require large disk space. This machine had approximately 6.4 GB free at
start, no Android SDK, and no Java runtime. The local quality gate therefore
runs code generation, formatting, analyze, and automated tests only. APK/IPA,
Pods, emulator/device OCR, bundled model binaries, signing, and publishing are
documented but not executed in this workspace.

## Decisions

- One `AppProfile` remains the only platform branch point, with a dart-define override for tests.
- `image` is used as the V1 preprocessing implementation to keep native build weight low; native OpenCV remains behind pure data contracts if profiling later proves it necessary.
- Search uses an app-maintained FTS5 table so OCR, receipt, and document text can be indexed as one record.
- Data is app-private and every service is designed without an HTTP dependency or runtime download.

## Deviations

- Local `tool/check.sh` defaults to no APK build because of the user's disk-space instruction. `ROSID_RUN_BUILD=1` restores the handover's build gate on a provisioned machine.
- `ben.traineddata` and `eng.traineddata` are represented by release instructions/placeholders, not downloaded into this workspace.
- Signed binaries, live GitHub Pages, a GitHub Release, and TestFlight publishing require human credentials/external authority and are not performed automatically.
- Current `google_mlkit_text_recognition` requires iOS 15.5, so the deployment target is 15.5 rather than the handover's broader iOS 15.0 floor.

## Log

### 2026-07-17 — M0 started

- Installed a shallow Flutter stable SDK in Codex tooling storage.
- Initialized Android/iOS Flutter scaffolds and resolved the app's offline dependencies.
- Added this build ledger and task checklist derived from the handover.

### 2026-07-17 — M0 foundation green

- Added the single Android/iOS `AppProfile` branch point with dart-define override support.
- Added persisted Riverpod settings, EN/BN ARB localization, Material 3 theme, and a GoRouter shell.
- Added the complete Drift V1 table schema, seven default categories, and an FTS5 search index.
- Configured Android minSdk 26, camera-only manifest permission, and iOS 15 camera/photo usage strings.
- Verification: `flutter analyze` clean; 8 profile/database/widget tests pass. Artifact builds skipped by user direction.

### 2026-07-17 — M1–M3 capture, preprocessing, and OCR

- Implemented camera and gallery capture, flash, profile-gated scan modes, language hints, app-private persistence, and multi-page sessions.
- Added draggable quad crop, perspective mapping, contrast normalization, adaptive thresholding, deskew scoring, rotation, upscaling, and 3200 px memory caps in pure Dart.
- Added the shared OCR contract, ML Kit Latin and Tesseract `ben+eng` engines, script routing, block merge, tessdata installer verification, and disabled V2 TFLite handwriting seam.
- The release workflow injects pinned `tessdata_best` models so release APKs can remain offline from first launch without storing those large assets locally.

### 2026-07-17 — M4 parser gate

- Added Unicode NFC, Bangla numeral/currency/date normalization and structured fields with raw text, confidence, and source.
- Added 8 OCR-text fixtures covering English, Bangla, mixed script, discount, multiple totals, missing date, Bangla month name, and noisy handwriting-like output.
- Parser gate result: totals 8/8 (100%); dates 7/7 fixtures containing a date (100%). Required gates were ≥90% and ≥80%.
- Registered normalization/parser test count: 54 (required ≥40).

### 2026-07-17 — M5–M7 application workflows

- Added editable receipt/document review, low-confidence and handwriting warnings, transactional save, tags, and line items.
- Added combined history, FTS5 search, type/category/date filters, detail/rename/delete/pin/share flows.
- Added monthly dashboard, category bars, CSV export, bilingual settings, category management, and delete-all.

### 2026-07-17 — M8–M10 hardening, iOS profile, and distribution code

- Added camera-only Android manifest policy, offline audit, R8 rules, optional release signing config, and manual airplane-mode QA.
- Added documents-first iOS profile tests, multi-page document persistence, PDF generation/share, iOS usage strings, and iOS 15.5 deployment target.
- Added the static EN/BN GitHub Pages site, semantic HTML/CSS product previews, no-JS fallback, Pages workflow, pinned-model signed-release workflow, and release/TestFlight guide.

### 2026-07-17 — Final lightweight gate

- `flutter analyze`: clean.
- Automated tests: 87 passed.
- Offline audit: passed; no Android `INTERNET` or `ACCESS_NETWORK_STATE` permission and no direct network/analytics SDK.
- APK/IPA builds, signing, Pods, emulator/device OCR, Lighthouse, live Pages, GitHub Release, and TestFlight remain unexecuted per the user's disk/authority instruction.

## Known limitations

- Device OCR and camera behavior cannot be truthfully validated without model assets and a device/emulator pass.
- Bangla handwriting remains best-effort in V1 as specified; the TFLite seam is reserved for V2.
- Current Tesseract plugin behavior and iOS pod compatibility remain unverified until the skipped native build/device pass.
- `TASKS_V2.md` is intentionally not generated because the handover gates V2 on a fully green §13, including the skipped artifact/device/publishing checks.
