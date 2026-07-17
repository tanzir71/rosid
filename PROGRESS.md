# Rosid progress

## Current status

- Active milestone: M0 — Scaffold
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

## Known limitations

- Device OCR and camera behavior cannot be truthfully validated without model assets and a device/emulator pass.
- Bangla handwriting remains best-effort in V1 as specified; the TFLite seam is reserved for V2.
