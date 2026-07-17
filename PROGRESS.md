# Rosid progress

## Current status

- Active milestone: V1 implementation is complete; Android emulator OCR and unsigned native-artifact gates are green, while signing, physical-device, iOS, and publishing acceptance gates remain external.
- Flutter: 3.44.6 stable; Dart: 3.12.2.
- Automated Windows gate: green on 2026-07-17 (`flutter analyze` clean; all 183 tests passed; offline source audit passed).
- Bundled OCR data: pinned `tessdata_best` English and Bangla models are checked in and hash-verified by the release workflow.
- Native Android validation: debug and unsigned R8 release APKs built; the strict merged release-manifest audit passed; an airplane-mode emulator OCR run passed all three fixtures.
- Landing page: five real emulator captures are retained under
  `site/screenshots/`; the site displays four of them in place of product
  mockups. A local mobile Lighthouse run scored 100 for accessibility.
- V2 has not started because the V1 Definition of Done in `CODEX_HANDOVER.md` section 13 is not fully green.

## Validation status and blockers

The source gate ran code generation, fixture-bundle generation, formatting,
static analysis, the automated test suite, and the offline policy audit
successfully. The native Android gate subsequently built both a debug APK and an
unsigned, minified R8 release APK. The strict merged release-manifest audit
passed with only `android.permission.CAMERA` and AndroidX's app-scoped signature
permission; neither `INTERNET` nor `ACCESS_NETWORK_STATE` is present.

Gradle initially failed TLS validation because the local Avast HTTPS inspection
root was absent from Java's trust chain. The build was completed with a temporary
JDK truststore that explicitly trusted that root. No TLS-verification weakening,
truststore, or truststore password was committed.

The real fixture harness passed 3/3 on an Android emulator launched and exercised
in airplane mode: English through ML Kit, mixed English/Bangla through ML Kit +
Tesseract, and handwritten text through the editable document-review path.

The remaining section 13 gates need resources or authority that are not present
in this workspace:

- an Android release keystore and repository secrets for a signed release APK;
- a physical Android device for the complete camera, gallery, first-launch,
  search/export, constrained-memory PDF, and share-sheet script;
- macOS/Xcode and Apple credentials for an iOS compile/sign, native OCR check,
  and TestFlight build;
- repository Pages configuration and publishing authority for the live site,
  signed GitHub Release, and post-deployment smoke check.

## Decisions

- `AppProfile` is the only Android/iOS product branch point; tests can override
  it with `--dart-define=APP_PROFILE=`.
- The V1 preprocessing implementation uses the pure-Dart `image` package behind
  OCR/preprocessing contracts. It performs document-quad detection, perspective
  correction, deskew, enhancement, rotation, and bounded resizing without adding
  a native OpenCV dependency.
- Search uses an app-maintained FTS5 table that NFC-normalizes indexed and query
  text while preserving original OCR text for display.
- All data is app-private. Android backup/data transfer is disabled and iOS
  document/application-support data is excluded from backup.
- CSV/PDF exports are unique, app-private temporary files. They are deleted
  after the share sheet completes and swept on startup, record deletion, and
  delete-all together with `share_plus` cache copies.
- Debug builds are audited against the source policy because Flutter adds an
  `INTERNET` permission for its VM service. Only release merged manifests are
  accepted by the strict distributable-artifact audit.
- Currency totals are never converted or combined across currencies; dashboard
  aggregation is scoped to the selected currency.

## Deviations

- `tool/check.sh` and `tool/check.ps1` make the debug APK build opt-in
  (`ROSID_RUN_BUILD=1` or `-RunBuild`) so source checks remain usable on machines
  without a native Android toolchain. The debug build has now been exercised
  locally; the release build remains an explicit separate command.
- `image` replaces OpenCV for V1 preprocessing. Contrast normalization and
  adaptive thresholding are implemented in pure Dart rather than native CLAHE.
- `google_mlkit_text_recognition` requires iOS 15.5, so the deployment target is
  15.5 rather than the handover's 15.0 floor.
- The upstream Tesseract plugin does not implement hOCR on iOS. Android uses
  hOCR geometry/confidence; iOS uses the plugin's plain-text channel, synthesizes
  line boxes, and assigns conservative 0.4 confidence so review is mandatory.
- Signed binaries, a live GitHub Pages deployment, a GitHub Release, and
  TestFlight publishing require external credentials/authority and have not
  been performed.

## Log

### 2026-07-17 - M0 scaffold and data foundation

- Initialized the Flutter Android/iOS project, dependency graph, build ledger,
  and cross-platform quality-gate scripts.
- Added the single platform profile, persisted Riverpod settings, EN/BN ARB
  localization, Material 3 theme, and stable GoRouter shell.
- Added the Drift schema, seven seeded categories, FTS5 index, schema migration,
  and repository tests. The v1-to-v2 migration rebuilds normalized FTS content
  without losing receipt, document, tag, or line-item data.

### 2026-07-17 - M1-M3 capture, preprocessing, and OCR

- Implemented camera/gallery capture, flash, profile-gated modes, language hints,
  app-private image persistence, guarded discard cleanup, and document batches.
- Added automatic quad detection, draggable crop handles with correct transform
  mapping, perspective correction, deskew, enhancement preview/toggle, rotation,
  thumbnails, and input/output memory limits.
- Added the common OCR contract, ML Kit Latin and Tesseract `ben+eng` engines,
  routed script detection, geometry-aware merge, and the disabled V2 TFLite
  handwriting seam.
- Tesseract now parses hOCR word geometry/confidence instead of fabricating block
  boxes. Repeated text on one or multiple pages is preserved.
- Added an atomic tessdata installer with exact-length verification and recovery.
  Missing Bangla language data produces an actionable typed error rather than a
  silent Latin-only fallback.
- Checked in `tessdata_best` revision
  `e12c65a915945e4c28e237a9b52bc4a8f39a0cec`:
  - `eng.traineddata`: 15,400,601 bytes,
    SHA-256 `8280AED0782FE27257A68EA10FE7EF324CA0F8D85BD2FD145D1C2B560BCB66BA`;
  - `ben.traineddata`: 11,045,427 bytes,
    SHA-256 `1CD0129288D1F74F6661C35E638E487BD146A66BB732ECD9E011E48DCB0DF623`.
- Added real English receipt, mixed Bangla receipt, and handwritten-note PNGs
  plus a generated-bytes `integration_test/` harness.
- Passed all three fixtures on an Android emulator in airplane mode: ML Kit for
  English, ML Kit + Tesseract for mixed/Bangla, and editable handwritten text.

### 2026-07-17 - M4 normalization and parser gate

- Added Unicode NFC, Bangla numeral/currency/date normalization, structured
  fields with original `rawText`, confidence, and source metadata.
- Added eight OCR-text fixtures covering English, Bangla, mixed script,
  discounts, multiple totals, missing dates, Bangla month names, and noisy
  handwriting-like output.
- Parser gate: totals 8/8 (100%); dates 7/7 fixtures containing a date (100%).
  The milestone requires at least 90% and 80%, respectively.
- Normalizer/parser tests: 54 (minimum required: 40).

### 2026-07-17 - M5-M7 review, library, dashboard, and settings

- Added editable receipt/document review, stable confidence fields, handwriting
  warnings, raw OCR inspection, receipt validation, editable line-item quantity,
  unit price and amount, transactional save, tags, and thumbnail persistence.
- Shared strict UI numeric validation accepts Latin/Bangla digits and intended
  BDT wrappers while rejecting embedded garbage and malformed grouping in both
  create and edit flows; permissive OCR normalization remains separate.
- Added combined history, unbounded FTS search, type/category/date filters,
  localized categories, full detail edit, rename/delete/pin, image share, cache
  invalidation, and complete raw/processed/thumbnail cleanup.
- Added documents-first and pinned-document home surfaces, monthly per-currency
  dashboard/category bars, CSV export, bilingual settings, category management,
  installed version/build metadata, release URL, and delete-all-data cleanup.
- Expense-off profile tests verify receipt routes and all category/currency/export
  surfaces are inaccessible while document features remain available.

### 2026-07-17 - M8-M10 hardening, iOS profile, and distribution preparation

- Added strict source/merged-manifest permission audits, Android backup and
  device-transfer exclusions, R8 rules, bounded gallery import, database migration
  coverage, and the manual airplane-mode QA script.
- Hardened capture and mutation lifecycles with generation tokens, temporary
  picker cleanup, desktop-original preservation, pop guards, and dependency
  capture across asynchronous database/file deletion.
- Made scan/FTS writes and deletes atomic, added startup orphan-FTS cleanup, and
  made CSV text formula-safe without changing numeric/date columns.
- Moved generated exports to scoped temporary storage with path traversal
  rejection and cleanup after share, failure, restart, record deletion, and
  delete-all.
- Added sequential/downscaled PDF generation with a typed 20-page limit and tests.
- Added iOS tessdata resources, camera/photo usage strings, 15.5 deployment target,
  private-data backup exclusion, profile override tests, multi-page document
  persistence, and local PDF sharing.
- Added the EN/BN static Pages site, no-JavaScript fallback, repository-link
  substitution, tag release/Pages workflows, pinned tessdata verification, APK
  signer verification, single-certificate enforcement, and keystore/APK
  fingerprint comparison before publishing.
- Pinned every workflow action to an audited immutable commit, gated signing on
  the reviewer-protected `android-release` environment, and documented protected
  `v*` tags plus environment-scoped secrets.
- Built the debug APK and unsigned minified/R8 release APK on Windows. The local
  TLS interception issue was handled only through a temporary trusted-root JDK
  truststore; no insecure build setting was committed.
- Passed the strict merged release-manifest audit. The resulting release manifest
  contains `CAMERA` plus AndroidX's signature-only compatibility permission and
  no networking permission.
- Replaced landing-page mockups with four real emulator captures: dashboard,
  crop/enhance, receipt review, and settings. A fifth enhanced-result capture is
  retained alongside them.
- Ran mobile Lighthouse against the local served site in Chromium; accessibility
  scored 100 after correcting image-container semantics.

### 2026-07-17 - Final automated and Android native gates

- `flutter gen-l10n`: passed.
- `dart run build_runner build`: passed.
- `dart format --output=none --set-exit-if-changed lib test integration_test tool`: passed.
- `flutter analyze`: no issues.
- `flutter test`: all 183 tests passed.
- Offline source audit: passed; the main Android manifest has only `CAMERA`, no
  runtime networking dependency is declared, and backup/data-transfer exclusions
  are present.
- Debug APK build: passed.
- Unsigned minified/R8 release APK build: passed.
- Final ordinary debug APK: 254,530,293 bytes, SHA-256
  `19A128607123662ACDF9A6166B3C76F8AD79CDA0E7B14CDEDD731DFD39BC14CE`.
- Final unsigned release APK: 150,077,194 bytes, SHA-256
  `DA858408D6AC3CC82D647ECD485B35A35BB6312BAD12C319339F7D95F9680A0C`;
  `apksigner` correctly reports it as unsigned until release secrets are added.
- Two clean ordinary-entrypoint R8 builds produced the same release size and
  SHA-256. The integration-test APK was not used as the final debug artifact.
- Strict merged release-manifest audit: passed; only `CAMERA` and AndroidX's
  app-scoped signature permission are present.
- Android emulator airplane-mode OCR fixture integration: 3/3 passed.

## Known limitations

- Bangla handwriting remains explicitly best-effort in V1; the disabled TFLite
  seam is reserved for V2 and user correction remains the reliable path.
- Real fixture PNGs and the native `integration_test/` harness are checked in,
  and the Android emulator OCR subset is green. Camera/gallery hardware behavior,
  first-launch install from a clean physical device, constrained-memory export,
  and platform share sheets still require the full physical-device script.
- The unsigned release manifest has been produced and strictly audited. A signed
  APK is still unavailable solely because no release keystore/secrets were
  provided.
- iOS native plugin/pod compatibility is configured but uncompiled because no
  macOS/Xcode environment or Apple signing credentials are available.
- The displayed screenshots are real emulator captures and local Lighthouse
  accessibility is 100, but live Pages/Release/TestFlight publishing and the
  post-deployment smoke check still require external authority.
- `TASKS_V2.md` is intentionally absent: section 17 starts only after every V1
  section 13 gate is green.
