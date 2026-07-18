# Rosid progress

## Current status

- Active milestone: V2 P0 owner approval on `codex/v2`. The architecture,
  dataset/license, metric, artifact, runtime, and amount-evidence packet is
  ready; the remaining inputs are the amount-gate and BN-HTRd risk posture plus
  Android/iOS device paths. V1.0.0 remains published and frozen as an immutable
  GitHub Release. V2 now has a disabled-by-default handwriting orchestration
  contract, CPU tooling, and an app-only preprocessing reference. No production
  Flutter dependency, native runtime, model asset, or app version has changed;
  existing transitive `crypto` 3.0.7 is now a direct dev dependency for golden
  SHA-256 generation.
- Flutter: 3.44.6 stable; Dart: 3.12.2.
- Automated Windows gate: green on 2026-07-18 (`flutter analyze` clean; the
  full Flutter suite and offline source audit passed).
- Bundled OCR data: pinned `tessdata_best` English and Bangla models are checked in and hash-verified by the release workflow.
- Native Android validation: debug and unsigned R8 release APKs built; the strict merged release-manifest audit passed; an airplane-mode emulator OCR run passed all three fixtures.
- Published release: protected tag `v1.0.0` and permanent branch `release/v1`
  preserve commit `602ca4e`; release run `29625460054` verified both native
  artifacts, locked the Release, and deployed
  `https://tanzir-lameh.github.io/rosid/`.
- Landing page: five real emulator captures are retained under
  `site/screenshots/`; the site displays four of them in place of product
  mockups. The optimized rebuilt page scored 100 in all four Lighthouse mobile
  categories; compact evidence is recorded in `docs/audits/lighthouse-v1.json`.
- The owner-amended V2 transition gate is satisfied: signed Android, unsigned
  iOS, live Pages, and the preserved V1 references are verified. V2 begins on
  `codex/v2`; deferred physical QA and unavailable Apple distribution are
  carried explicitly rather than treated as passed.

## Validation status and deferred checks

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

Release infrastructure and artifact acceptance are green. The keystore is
backed up outside the repository; all four Android secrets remain scoped to the
tag-restricted `android-release` environment; the enforced `v*` ruleset,
immutable-release setting, and Pages tag policy are active. Release run
`29625460054` compiled both platforms, matched the APK signer to the configured
keystore, published the immutable assets, and deployed Pages. Remaining checks
are intentionally deferred rather than release blockers:

- complete the camera, gallery, first-launch, search/export,
  constrained-memory PDF, native iOS, and share-sheet checks on physical
  devices later, as explicitly deferred by the owner;
- keep App Store/TestFlight signing deferred because no paid Apple Developer
  Program membership or Apple distribution credentials are available.

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
- iOS retains a 15.5 deployment floor. V1 deliberately removes the Flutter ML
  Kit plugins and routes iOS Latin/Bangla through bundled Tesseract; Android
  keeps bundled Latin ML Kit behind an Android-only MethodChannel. This prevents
  ML Kit telemetry/network support pods from entering the unsigned IPA.
- The upstream Tesseract plugin does not implement hOCR on iOS. Android uses
  hOCR geometry/confidence; iOS uses the plugin's plain-text channel, synthesizes
  line boxes, and assigns conservative 0.4 confidence so review is mandatory.
- The signed Android, unsigned iOS, immutable Release, and Pages paths completed
  successfully in release run `29625460054`. App Store/TestFlight publishing
  remains unavailable because the owner has no Apple distribution membership.

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
  the tag-restricted `android-release` environment, and documented protected
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
- Ran mobile Lighthouse against the then-current locally served site in
  Chromium; accessibility scored 100 after correcting image-container
  semantics. The later landing-page rebuild requires a fresh measurement.

### 2026-07-18 - Release infrastructure and landing-page rebuild

- Created and externally backed up the Android release keystore, configured all
  four signing secrets in the `android-release` environment, restricted that
  environment to `v*` tags, and enabled the enforced `v*` repository tag
  ruleset plus repository-level immutable releases.
- Configured GitHub Pages to use Actions; the first release-triggered public
  deployment later completed in run `29625460054`.
- Added the GitHub-hosted macOS dependency-lock helper. Its first run
  (`29621736516`) succeeded and the downloaded file matched its artifact, but
  review found that it still contained Google ML Kit telemetry/network support
  pods. That lock is superseded. Replacement run `29623751861` resolved only
  Flutter, `flutter_tesseract_ocr`, and SwiftyTesseract with CocoaPods 1.17.0;
  its exact artifact (SHA-256
  `A008BF3142D4527512E42AC8D92CA5C8B48EAEB8EAC1BEF441058780BFCC3A33`)
  passed the privacy audit and is committed for the protected tag workflow.
- Removed the Flutter ML Kit plugins. Android now calls the same bundled Latin
  ML Kit library through an Android-only MethodChannel; iOS and other platforms
  use the bundled Tesseract `ben+eng` path. Analyze, all 185 tests, the debug APK,
  all three airplane-mode emulator OCR fixtures, and the strict release manifest
  audit passed after the routing change.
- Rebuilt the post-routing minified/R8 APK: 150,028,058 bytes, SHA-256
  `0B4B90069BF01391080FBFB6C0FBB1EA6A591A26B5744B22F91DEF72DCF4B0FA`.
  The shrunk APK retains `MainActivity`, has no network permission, and is
  intentionally unsigned until the protected release job.
- Rebuilt the landing page after competitor research, replaced the heavy display
  images with optimized WebP variants, and added the release favicon. Mobile
  Lighthouse 13.4 scored Performance 100, Accessibility 100, Best Practices 100,
  and SEO 100; the compact audited metrics are checked in.

### 2026-07-18 - Immutable V1.0.0 publication

- Main Checks run `29625183481` passed at release commit `602ca4e`: locked
  dependencies, generation, formatting, analysis, all 185 tests, iOS privacy
  audit, site preparation, debug APK build, and portable offline audit.
- The first protected-tag run exposed a parser assumption about modern
  `apksigner` labels; the produced APK was valid, single-signer, and correctly
  signed. The second run exposed a missing checkout in the publish job. Both
  workflow defects failed before any GitHub Release existed and were corrected
  and revalidated on `main`.
- Final release run `29625460054` passed Android signing/manifest verification,
  the Tesseract-only unsigned iOS compile/package, immutable publication, and
  the tag-authorized Pages deployment.
- Published `rosid.apk`: 150,056,622 bytes, SHA-256
  `2CBE4774FA3B0E9D4CD7869E74DE234B885BFFFDBA489BE3F0DDD813F21C4183`.
  Its sole signing certificate SHA-256 is
  `3980AC0407EDC1AD2E46BE86A07A266910B2EF6634A42997CAB7C1BBD3EC29F7`.
- Published `rosid-ios-unsigned.ipa`: 58,555,375 bytes, SHA-256
  `2D90BA2C8F863F641B9A4A410770E3842958627EE1F131EB1FB311541C05621C`.
  It is explicitly unsigned and remains a user-self-signing artifact rather
  than an App Store, TestFlight, enterprise, or one-tap web distribution build.
- GitHub reports the V1 Release immutable. The public Pages smoke test returned
  HTTP 200 and displayed the exact release version, hashes, and certificate
  fingerprint. Live HTML SHA-256 is
  `EF3A071B0A1BD7D87603329746DAAC8593843BB7B8BB5477EE5D8D0168BF3889`;
  all local resources matched the tagged Git blobs and no runtime network or
  analytics call was found. Protected tag `v1.0.0` and `release/v1` both
  preserve `602ca4e`.

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

### 2026-07-18 - V2 P0 evidence and dormant integration contract

- Audited the frozen V1/mobile seam. The registered
  `TfliteBanglaHandwritingEngine` was unreachable because `OcrService` never
  invoked it and capture callers never emitted the handwriting hint.
- Added an injected, disabled-by-default routing policy, typed recoverable HTR
  failures, result-arbitration boundary, strict line-output validation, and a
  reliable Tesseract-first fallback. Production recognition blocks and engine
  selection remain V1-equivalent until a model/router is explicitly enabled.
  All targeted routing/service/Tesseract seam tests pass and `flutter analyze`
  is clean.
- Researched and pinned authoritative hashes for BN-HTRd V4,
  BanglaLekha-Isolated V2, and both BanglaWriting V1 archives. BanglaWriting is
  quarantined by its noncommercial license; Ekush is excluded because image and
  public-weight rights plus an immutable archive are not established.
- BN-HTRd remains conditional despite its CC BY catalog record: the downloaded
  archive must prove page-to-writer grouping, and BBC-derived ground-truth text
  requires documented owner risk acceptance or a rights review before public
  model lineage is production-eligible. Clearing those gates does not upgrade
  existing conditional evidence: it requires an amended production source
  manifest/source-evidence record and a fresh production acquisition.
- Added strict source manifests and offline archive verification, deterministic
  writer-disjoint split/leakage checks, recursive eligibility/test-lineage
  checks, NFC micro CER/WER and normalized amount CER, relative-improvement
  scoring, and generic TFLite hash/size/header/privacy audit primitives.
  P0 now defines the intended transitive source-archive, extracted-dataset,
  global-split, partition, Tier 1/2/3, checkpoint, conversion, prediction,
  metric, and mobile-companion verification contract. The real archive/extracted
  regular-file-set, writer-map, adapter, and split audit remains P1 work.
  Empty/duplicate holdout evidence, zero-denominator CER, unverified amounts,
  and empty release
  partitions fail closed in the generic validators. Companion assets are
  privacy-scanned from one immutable byte snapshot with portable IDs and a
  non-overridable 20,000,000-byte ceiling. The 128-test ML suite passed this
  foundation without datasets, a GPU, or network access. The later independent
  audit added one quarantine-scope regression test; all 29 lineage tests and a
  70-test affected/fast group pass after that fix. On exact commit `4a7beb2`,
  [Checks run 29636752507](https://github.com/tanzir-lameh/rosid/actions/runs/29636752507)
  passed the complete 129-test ML suite in 7.078 seconds on pinned Python
  3.12.10 after local Git-heavy groups exceeded Windows process bounds without
  a test failure.
- Drafted the full P0 packet with conditional CRNN/CTC and TCN fallback,
  grapheme-aware hybrid vocabulary, exact metric/parity semantics, all-three
  synthesis gates, transitive provenance, routing acceptance, and runtime/device
  requirements. The current Flutter plugin's Android/iOS native runtime skew is
  an explicit pre-training spike gate rather than an assumed compatibility claim.
- Completed the real-amount audit across BN-HTRd V4, Bayanno V2, and
  PromitoLipi V2. No corpus can satisfy the proposed writer-disjoint monetary
  gate: BN-HTRd has only 37 digit-plus-currency lines across 12 writers, no
  strict amount-only/`৳` lines, and numeric-label defects; the other corpora
  lack the required line annotations and writer identity. V2-009 now requires
  an explicit owner choice: retain the <=12% amount CER gate and block release
  pending new licensed data, or remove it as a release gate, keep diagnostics,
  and make no real-amount accuracy claim.

### 2026-07-18 - V2 P1 provenance and global-split scaffold

- Added an executable, standard-library-only acquisition path that verifies an
  exact publisher archive from one stable opened snapshot and independently
  inventories an asserted extracted directory's exact regular-file set and
  bytes. Empty directories are intentionally outside that commitment. The
  snapshot hash is path/size/content bound and rejects links, special files,
  nonportable names, NFC/case-fold collisions, and membership/content mutation
  while hashing.
- Acquisition schema V3 now distinguishes the reviewed `source_archive` bytes
  from the typed `extracted_dataset` snapshot and binds the latter transitively
  to the former through canonical source evidence. Canonical public
  source/acquisition records are written without overwrite; per-file paths and
  hashes belong in an ignored or out-of-repository private inventory with an
  encrypted backup. The acquisition recorder intentionally does not extract an
  archive or attest which exact extractor produced a directory; it independently
  rebinds both snapshots and cannot prove dataset structure or writer mapping.
- Added canonical private adapter evidence that covers every normalized output's
  exact sample identity, global writer group, object key, image/reference hashes,
  dimensions, token count, and source derivations. Every extraction-inventory
  file must be classified exactly once as used or explicitly ignored with a
  reason. A path-free `PublicAdapterCommitment` HMAC-binds that private evidence,
  its acquisition and inventory, the approved adapter config, and the combined
  code bundle; only exact reverification produces `VerifiedAdapterEvidence`.
- Added canonical private sample/split JSONL, exact integer-weighted global
  writer assignment, acquisition-reference checks, release minimum/leakage
  validation, and `PublicSplitCommitment` schema V3. The public split binds the
  exact dataset IDs, source acquisitions, adapter commitments, canonical config,
  approval-policy SHA pinned out of band, external split-approval SHA and scope,
  domain-separated fingerprints of the actual seed and commitment keys,
  aggregate counts, and private-manifest HMAC. Separate 32-byte seed and HMAC
  keys and all private manifests remain ignored or outside the repository and
  require an encrypted backup.
- `prepare_split_approval` now auto-includes the exact required core ML code
  closure and accepts repeatable adapter implementation files only; the retained
  `SplitConfig.splitter_code_sha256` field denotes that complete bundle. After
  all public inputs are committed at commit A, `request_split_approval` binds
  their exact paths, roles, bytes, canonical repository origin, production or
  quarantine scope, full code closure, and the real private split-key
  fingerprints in a canonical request. The request must be committed before the
  owner signs it externally with OpenSSH. Repository Python never accepts the
  owner private signing key; `finalize_split_approval` verifies the detached
  SSHSIG and approved commit tree before emitting the public approval to commit.
- Hardened that bundle from a hand-maintained broad file list into a reviewed
  static transitive graph: the current core is 21 files rooted at the fixed P1
  CLIs, plus every explicitly configured source in the fixed adapter subtree.
  Local absolute/relative imports, executable
  package initializers, cycles, and case/NFKC resolution are followed; reachable
  unreviewed code, stale reviewed code, ambiguous/nonportable/native/bytecode
  loaders, star imports, and recognized dynamic execution fail closed.
  Unreachable future P2 modules are intentionally outside the P1 approval.
- Qualifying discovery now requires a complete materialized Git checkout whose
  ordinary stage-0 index exactly matches `HEAD` paths, object IDs, and
  `100644`/`100755` modes. Sparse/skip-worktree/assume-unchanged states,
  conflicts, staged drift, Git symlinks/submodules, missing tracked files, and
  path-component case/NFKC aliases are rejected. Individual current inputs and
  historical approved-commit files repeat the regular-mode check, closing the
  Windows `core.symlinks=false` target-text to Linux symlink transition.
  Documentation keeps the separate trusted/cache-sanitized interpreter and
  canonical repository-qualified adapter-import preconditions explicit.
- The fixed `ml/APPROVAL_POLICY.json` remains `pending`, so no qualifying split
  exists. Tanzir must create an external Ed25519 key, activate and commit the
  policy, distribute and independently verify its canonical SHA out of band,
  and record P0 approval before any production or quarantined split approval can
  qualify. This work does not imply that Tanzir has approved the policy or split.
- Build and verify require the committed approval plus the separately trusted
  policy SHA, reverify the actual private key fingerprints and all approved
  public/private evidence, and only then return `VerifiedSplitEvidence`.
  Lineage requires that capability and exact approval-policy, split-approval,
  config, combined-code, and external-dataset parents; a bare public commitment
  cannot qualify a split node.
- Added conditional future download destinations and commands to
  `ml/V2_GUIDE.md`.
  No dataset was downloaded, no real acquisition/split was claimed, and P0
  model/toolchain/rights/device decisions remain unaccepted. Real archive
  downloads, invocations of the generic extractor with approved per-archive
  limits, dataset-specific adapters and structure/writer-map audits, external
  owner policy activation/signing and recorded P0 approval,
  production acquisitions, and the real global split are still required after
  source approval.
- The pre-audit 128-test ML suite was green (177.182 seconds), including fixed
  inventory, adapter-coverage, assignment, HMAC, external
  approval-policy/request/SSHSIG, public-commitment, CLI round-trip,
  privacy/tamper, and verified-lineage cases. After the audit found a
  quarantined-scope eligibility-laundering path, lineage now maps signed scope
  onto both split and approval-node eligibility; all 29 lineage tests and the
  70-test affected/fast group pass locally. Exact-SHA Linux CI passed all 129 ML
  tests in 7.078 seconds, plus Flutter generation/format/analyze/tests, iOS
  privacy, static-site validation, debug APK build, and the portable offline
  audit.
  Mobile dependencies, model assets, app routing defaults, and V1 behavior
  remain unchanged.
- After code-closure hardening, the complete local ML suite passed 148 tests in
  191.107 seconds with one POSIX-only skip on Windows; all 15 structural model
  audit tests also passed. Flutter generation wrote no changes, Dart formatting
  changed no files, `flutter analyze` was clean, all Flutter tests passed, and
  the iOS privacy and offline manifest audits were green. Two independent
  adversarial reviews found no remaining concrete false-complete source-graph
  path within the documented trusted-runtime boundary.
- Exact implementation commit `88297f3b952d2c52aa72af0b76a2e59a2b69ace2`
  passed [Checks run 29639672402](https://github.com/tanzir-lameh/rosid/actions/runs/29639672402)
  on a fresh Linux checkout in 7 minutes 52 seconds: all 148 ML tests, 15 model
  audit tests, Flutter generation/format/analyze/tests, iOS privacy, static-site
  validation, debug APK build, and the portable offline audit were green. The
  preceding run exposed a test-fixture-only executable-bit mismatch on Linux;
  the production mode checker rejected it correctly, the fixture now
  materializes `100755`, and the exact-SHA rerun passed.

### 2026-07-18 - V2 generic extraction and structural audit hardening

- Added `ml.extract_dataset` and `ml/rosid_ml/safe_extract.py` to the reviewed
  P1 closure. The extractor verifies the tracked canonical source manifest and
  exact archive, scans a bounded conventional single-disk ZIP/ZIP64 central
  directory before `ZipFile` allocation, accepts only stored/deflated regular
  members with portable collision-free paths, and enforces mandatory member,
  central-directory, per-file, total, ratio, and free-space ceilings plus an
  inode reserve where the filesystem exposes inode capacity.
- Extraction reserves a fresh ignored private destination, materializes without
  delegating paths to `zipfile`, re-hashes the still-open archive, inventories
  and reverifies the exact regular-file tree, rechecks capacity and directory
  identity, then removes write mode bits. Failure cleanup is identity-bound and
  surfaced if private residue cannot be removed. The successful mode-bit seal is
  advisory on Windows rather than an ACL-enforced immutable directory.
- `.gitignore` now keeps `ml/data/`, `ml/checkpoints/`, `ml/artifacts/`, and the
  existing private-manifest tree outside Git. Nonproduction mode is explicitly
  quarantine-only, but the CLI does not yet choose or enforce a quarantine
  location. Its path-free JSON is an operational summary, not a canonical
  acquisition receipt or proof of exact code execution. Qualifying provenance
  still requires the approved P1 code identity, canonical acquisition evidence,
  and dataset-specific structure/writer-map review.
- Hardened `tool/audit_v2_model.py` around stable unlinked regular-file
  snapshots, canonical lowercase hashes and portable logical IDs, NTFS alternate
  streams, symlink/reparse/hardlink and physical-alias rejection, aggregate
  bundle limits, and path-free diagnostics. The result remains explicitly
  `structural_only`: it proves no operator/tensor/quantization contract,
  interpreter loadability, trained-model parity, accuracy, routing, or device
  performance gate.
- Both filesystem tools assume a trusted clean process without hostile
  concurrent mutation of source, parent, or destination namespaces. Their
  repeated snapshots detect ordinary drift; neither is a descriptor-relative
  hostile-filesystem sandbox.
- Local focused verification passed the 19-test extractor suite in 433.315
  seconds, then separately passed the added path-private CLI failure regression
  and corrected implicit-directory reporting case. The 23 structural model
  tests and 17 P1 closure tests passed (with the expected Windows reserved-name
  skip), Ruff was clean, Flutter generation wrote no changes, Dart formatting
  changed none of 101 files, analysis was clean, all 209 Flutter tests passed,
  and the iOS privacy and offline audits were green. A unified Windows ML
  discovery run remained healthy but exceeded its 30-minute process limit in
  slow temporary-Git calls; fresh Linux exact-SHA CI remains the unified gate.
- Exact implementation commit `7d157cc7b0d839ebdeab3eb40bf2a0493fffa125`
  first exposed a Linux test-fixture collision in
  [Checks run 29644627537](https://github.com/tanzir-lameh/rosid/actions/runs/29644627537):
  its `os.statvfs` mock also reached `shutil.disk_usage`, producing a `Mock`
  arithmetic error before reaching the intended inode-reserve assertion. Fix
  commit `f689ac0e3e23ffe558192fee6a713f124f5e4beb` now mocks the dedicated inode
  seam. That exact SHA passed
  [Checks run 29644810246](https://github.com/tanzir-lameh/rosid/actions/runs/29644810246)
  on a fresh Linux checkout: the 23-test structural model suite was OK with its
  expected Windows-only ADS case skipped, all 168 ML tests passed, and Flutter
  generation/format/analyze and 209 tests, iOS privacy, static-site validation,
  debug APK build, and the portable offline audit were green.
- No publisher archive was downloaded, no real extraction/acquisition was
  recorded, no model or runtime was selected, and no P0 owner decision changed.

### 2026-07-18 - V2 app-side preprocessing reference

- Refactored `ImagePreprocessor.process()` through one private image-stage path
  and added `processPlanes()` for tightly packed pre-JPEG R8G8B8A8, grayscale
  Y8, and binary Y8 bytes. The production JPEG path does not retain the extra
  grayscale plane. An exact regression reconstructs both JPEG inputs from the
  raw seam, and an isolated run against pre-refactor commit `f689ac0` matched
  the frozen English color and binary JPEG byte counts and SHA-256 values.
- Added three fixed vectors over the synthetic English receipt, mixed Bangla
  receipt, and handwritten Bangla fixtures. Canonical sorted/NFC/LF manifest
  `test/fixtures/v2_preprocessing/app_reference_v1.json` binds each encoded
  source plus decoded source plane, explicit quad/options, result dimensions,
  half-degree deskew ticks, raw plane hashes, and reviewable channel/value
  statistics. The paired digest is currently
  `0c69472d1aacf75de3b724edf149bf1c55b9e82364b65f7a61e87e0aa3a2dd83`.
- Linux CI and both local check scripts run the generator in non-writing
  `--check` mode. Flutter recomputes every app plane and enforces nontrivial
  grayscale/binary semantics; Python independently checks canonical manifest
  bytes, the digest, and public fixture bindings. The manifest remains
  `app_reference_only` with `python_parity_status=not_implemented`.
- Local verification passed the 12 focused preprocessing tests, the Python
  canonical/source-binding test and Ruff, formatting across 104 Dart files with
  no changes, clean analysis, all 211 Flutter tests, and the four-manifest
  offline audit; the debug APK built successfully. Exact implementation commit
  `0f8279c324e43aa9a2edc019501196313aa52e0f` passed
  [Checks run 29646688206](https://github.com/tanzir-lameh/rosid/actions/runs/29646688206)
  on a fresh Linux checkout: the Dart generator reproduced the tracked bytes,
  all 169 ML tests and 23 structural model tests passed (with the expected
  Windows-only ADS case skipped), and Flutter generation/format/analyze/tests,
  iOS privacy, site validation, debug APK build, and offline audit were green.
- Added a strict Python verifier for this deliberately non-qualifying app-only
  reference. It requires unique-key canonical JSON, exact schema/constants and
  nested invariants, the exact digest record, and ordinary tracked sources whose
  index/worktree bytes match Git `HEAD`. Its typed result exposes no parity,
  eligibility, lineage, or production marker, and the module remains outside
  the reviewed 21-file P1 import closure.
- Adversarial coverage rejects schema/type/key drift, noncanonical and deeply
  nested JSON, oversized inputs before unbounded reads, malformed quads/options/
  plane statistics, dirty or untracked sources, and hardlinks. All 175 ML tests
  passed locally with the expected POSIX-only skip on Windows; all 23 structural
  model tests, 211 Flutter tests, generation, formatting, analysis, iOS privacy,
  and the four-manifest offline audit were also green.
- Exact verifier commit `4585c6bf5354bdfe37733e18cc26da4b458681e3`
  passed [Checks run 29647727106](https://github.com/tanzir-lameh/rosid/actions/runs/29647727106)
  on a fresh Linux checkout: all 175 ML tests passed, the 23-test structural
  model suite was green with its expected Windows-only ADS case skipped, the
  Dart reference regenerated byte-for-byte, and Flutter generation/format/
  analyze/tests, iOS privacy, site validation, debug APK build, and the portable
  offline audit were green.
- Added a deliberately non-qualifying in-memory plane oracle for a future
  independent Python implementation. It accepts immutable raw bytes rather than
  caller-supplied hashes, derives the layout/shape byte count, recomputes
  SHA-256, channel extrema, and Y8 endpoint counts, and returns only `None` or a
  payload-safe `ValueError`. It emits no report, persistent evidence, parity,
  eligibility, or lineage capability. Synthetic adversarial tests cover exact
  RGBA/grayscale/binary matches, mutations, forged reference metadata, mutable
  inputs, opacity, shape/layout drift, and API-surface isolation. The expanded
  local ML suite passed all 182 tests with the expected POSIX-only skip on
  Windows.
- This does not implement Python preprocessing, dataset loaders, line
  segmentation, tensor normalization, a model/runtime contract, or enforced
  preprocessing-golden lineage. Cross-language parity, P2 completion, and all
  pending owner decisions remain open.

## Known limitations

- Bangla handwriting remains explicitly best-effort in V1; the disabled TFLite
  seam is reserved for V2 and user correction remains the reliable path.
- Real fixture PNGs and the native `integration_test/` harness are checked in,
  and the Android emulator OCR subset is green. Camera/gallery hardware behavior,
  first-launch install from a clean physical device, constrained-memory export,
  and platform share sheets still require the full physical-device script.
- The signed release APK passed the protected tag workflow, strict merged
  manifest allowlist, single-signer check, and configured-keystore fingerprint
  comparison. A clean physical-device install remains owner-deferred.
- A GitHub-hosted macOS runner produced the committed privacy-safe lock artifact
  after the first artifact exposed and prompted removal of iOS ML Kit support
  pods. The protected tag workflow compiled and packaged the unsigned IPA.
  Apple signing and TestFlight remain unavailable without membership.
- The displayed screenshots are optimized versions of real emulator captures.
  The rebuilt page's four mobile Lighthouse category scores are 100. The live
  Release/Pages smoke test is green; physical mobile visual QA remains deferred.
- The owner-amended V1 transition gate is met. `TASKS_V2.md` and the guided ML
  ledger begin on `codex/v2`; physical-device QA and Apple distribution remain
  explicitly deferred rather than falsely marked complete.
