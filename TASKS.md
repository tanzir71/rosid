# Rosid build tasks

Tasks are ordered by milestone. `[x]` means the implementation and applicable
automated tests are complete. A `[BLOCKED: ...]` item is an explicit unmet
handover gate, not a pass.

## M0 - Scaffold

- [x] M0.1 Initialize Flutter project, dependencies, progress ledger, and Bash/PowerShell check scripts
- [x] M0.2 Add platform profile, Riverpod settings state, stable routing shell, theme, and EN/BN localization
- [x] M0.3 Add Drift schema, seeded categories, normalized FTS index, repositories, and migration tests
- [x] M0.4 Add parser/OCR fixture corpus scaffolding and navigation/profile widget tests

## M1 - Capture

- [x] M1.1 Implement camera/gallery capture and app-private raw-image persistence
- [x] M1.2 Add receipt/document mode, language hint, flash, and document batch capture state
- [x] M1.3 Create scan rows, thumbnails, guarded discard cleanup, and capture tests

## M2 - Preprocess

- [x] M2.1 Implement bounded grayscale, contrast, threshold, upscaling, rotation, and deskew pipeline
- [x] M2.2 Implement automatic document-quad detection, perspective correction, draggable crop UI, and two-stage enhancement preview
- [x] M2.3 Add preprocessing and crop-controller tests, coordinate-transform coverage, and large-image safeguards

## M3 - OCR core

- [x] M3.1 Define OCR contracts, script detection, merge strategy, and disabled TFLite handwriting stub
- [x] M3.2 Implement Android-only native ML Kit and cross-platform Tesseract adapters behind the common interface
- [x] M3.3 Parse Tesseract hOCR geometry/confidence and preserve repeated blocks/pages
- [x] M3.4 Implement atomic first-launch tessdata installation and routed OCR service
- [x] M3.5 Bundle and pin `ben.traineddata` and `eng.traineddata` with hash verification
- [x] M3.6 Add engine-routing, merge, hOCR, and tessdata-installer automated tests
- [x] M3.7 Add real English, mixed Bangla, and handwritten fixture PNGs plus a native OCR integration harness
- [x] M3.8 Pass the Android-emulator airplane-mode OCR fixture run (3/3: English ML Kit, mixed ML Kit + Tesseract/Bangla, and editable handwriting)

## M4 - Normalization and parser

- [x] M4.1 Implement Bangla numeral, currency, Unicode, and date normalization while preserving original raw text
- [x] M4.2 Implement pure-Dart structured receipt parser with confidence/source metadata
- [x] M4.3 Add eight receipt fixtures and at least 40 parser/normalizer tests
- [x] M4.4 Record total/date gate results (100%/100% on applicable fixtures)

## M5 - Review and save

- [x] M5.1 Implement receipt review with editable fields/items, raw OCR, validation, and confidence flags
- [x] M5.2 Implement document review with editable title/body/tags and handwriting warning
- [x] M5.3 Persist reviewed receipts/documents, tags, items, thumbnails, and search text transactionally
- [x] M5.4 Clean abandoned raw/processed/thumbnail files and cover review behavior with tests

## M6 - History, search, and detail

- [x] M6.1 Implement combined reviewed-record history, normalized FTS search, and type/category/date filters
- [x] M6.2 Implement full receipt/document detail edit, rename, delete, pin, and local image share
- [x] M6.3 Invalidate record caches after mutation and clean every associated private file
- [x] M6.4 Add migration, search (>100 results), repository, cache, and detail/profile tests

## M7 - Dashboard, export, and settings

- [x] M7.1 Implement per-currency monthly dashboard and localized category visualization
- [x] M7.2 Implement date-range expense CSV export
- [x] M7.3 Implement language/profile/currency/category/privacy settings and installed About metadata
- [x] M7.4 Verify Bangla UI and expense-off receipt/category/currency/export route gating in tests

## M8 - Android hardening

- [x] M8.1 Enforce minSdk 26, strict source permission allowlist, backup/data-transfer exclusion, and bounded image handling
- [x] M8.2 Add release merged-manifest audit, database migration tests, manual QA script, and R8 rules
- [x] M8.3 Add a release workflow that verifies model hashes, the emitted APK signer, and keystore fingerprint before publishing
- [x] M8.4 Build the debug APK and inspect native plugin packaging
- [x] M8.5a Build the unsigned R8 release APK and pass the strict merged release-manifest audit
- [x] M8.5b Build and verify the signed release APK (release run `29625460054`; SHA-256 `2CBE4774FA3B0E9D4CD7869E74DE234B885BFFFDBA489BE3F0DDD813F21C4183`; signer `3980AC0407EDC1AD2E46BE86A07A266910B2EF6634A42997CAB7C1BBD3EC29F7`)
- [DEFERRED BY OWNER: physical-device testing will be completed later] M8.6 Run the full airplane-mode English/Bangla receipt and handwritten-document script

## M9 - iOS profile

- [x] M9.1 Verify documents-first home, expense toggle, stable navigation, and route/surface gating via profile tests
- [x] M9.2 Implement multi-page document persistence, pinned documents, and bounded local PDF export
- [x] M9.3 Add iOS usage strings, tessdata bundle resources, backup exclusion, and iOS 15.5 configuration
- [x] M9.4 Resolve and commit `Podfile.lock`, then compile the unsigned iOS target on GitHub-hosted macOS (privacy-safe lock run `29623751861`; compile/package run `29625460054`)
- [DEFERRED BY OWNER: physical-device testing will be completed later] M9.5 Verify native OCR, profile flow, multi-page PDF, and share sheet end to end

## M10 - Landing page and distribution

- [x] M10.1 Build the accessible static EN/BN landing page with mobile layout and no-JavaScript fallback
- [x] M10.2 Add Pages and multi-platform release workflows with repository-specific links and immutable metadata
- [x] M10.3 Document Android signing, iPhone self-signing constraints, install, and manual verification steps
- [x] M10.4 Replace landing-page mockups with four real emulator screenshots (five captures retained)
- [x] M10.5 Re-run mobile Lighthouse for the rebuilt landing page (Performance, Accessibility, Best Practices, and SEO: 100 each)
- [x] M10.6 Publish Pages and a signed Android GitHub Release (immutable `v1.0.0`; `https://tanzir71.github.io/rosid/`)
- [DEFERRED: owner has no paid Apple distribution membership] M10.7 Publish an App Store/TestFlight build
- [x] M10.8 Compile and publish the explicitly unsigned iPhone IPA for advanced self-signing (SHA-256 `2D90BA2C8F863F641B9A4A410770E3842958627EE1F131EB1FB311541C05621C`)
- [x] M10.9 Research direct-download competitors and rebuild the landing page around outcome, trust, and release integrity

## Final V1 audit

- [x] Run code generation, formatting check, analyze, all 185 automated tests, and the source offline audit
- [x] Audit and fix capture/save/delete lifecycle races, atomic FTS cleanup, formula-safe temporary exports, and desktop picker ownership
- [x] Pin workflow actions and gate signing behind protected tags plus the tag-restricted `android-release` environment
- [x] Enable immutable GitHub Releases and require the publish workflow to verify the release is locked before Pages deployment
- [x] Confirm the source Android manifest has no `INTERNET` or `ACCESS_NETWORK_STATE` permission
- [x] Build debug and unsigned R8 release APKs
- [x] Audit the merged Android release manifest (only `CAMERA` and AndroidX's app-scoped signature permission)
- [x] Build and verify a signed release APK
- [x] Pass the Android-emulator airplane-mode native OCR fixture subset (3/3)
- [DEFERRED BY OWNER: to be completed later] Pass the full section 13 camera/gallery/search/export/PDF/share physical-device script
- [x] Compile the unsigned native iOS target on a hosted macOS runner
- [DEFERRED: no Apple distribution membership] Sign and publish through App Store/TestFlight
- [x] Publish live Pages, the signed Android APK, and the unsigned iPhone IPA
- [x] Re-run local mobile Lighthouse against the rebuilt landing page and record the four 100 scores
- [x] Preserve release commit `602ca4e` on `release/v1` and `v1.0.0`; start the owner-amended section 17 ledger as `TASKS_V2.md` on `codex/v2`
