# Rosid build tasks

Tasks are ordered by milestone. Each checked task has passed the lightweight
`tool/check.sh` gate (analyze + tests). Disk-heavy builds and signed artifacts
are explicitly deferred at the user's request and remain visible below.

## M0 — Scaffold

- [x] M0.1 Initialize Flutter project, dependencies, task log, and check script
- [x] M0.2 Add platform profile, Riverpod settings state, routing shell, theme, and EN/BN l10n
- [x] M0.3 Add Drift schema, seed categories, search index, repositories, and migration tests
- [x] M0.4 Add parser/OCR fixture corpus scaffolding and navigation widget tests

## M1 — Capture

- [x] M1.1 Implement camera/gallery capture and private image persistence
- [x] M1.2 Add receipt/document mode, language hint, flash, and document batch capture state
- [x] M1.3 Create scan rows and cover capture controller with tests

## M2 — Preprocess

- [x] M2.1 Implement pure-Dart grayscale, contrast, threshold, upscaling, and rotation pipeline
- [x] M2.2 Implement quad model, perspective/deskew seam, crop-and-enhance review UI
- [x] M2.3 Add preprocessing fixture/unit tests and large-image safeguards

## M3 — OCR core

- [x] M3.1 Define OCR contracts, script detection, merge strategy, and TFLite handwriting stub
- [x] M3.2 Implement ML Kit and Tesseract adapters behind the common interface
- [x] M3.3 Implement first-launch tessdata installer and routed OCR service
- [x] M3.4 Add OCR routing/merge unit tests
- [SKIPPED: disk constraint] M3.5 Bundle `ben.traineddata` and `eng.traineddata` binaries and run device integration fixtures

## M4 — Normalization + parser

- [x] M4.1 Implement Bangla numeral, currency, Unicode, and date normalization
- [x] M4.2 Implement pure-Dart structured receipt parser with confidence/source metadata
- [x] M4.3 Add receipt fixture corpus and at least 40 parser/normalizer tests
- [x] M4.4 Record total/date accuracy gate results

## M5 — Review and save

- [x] M5.1 Implement receipt review with editable fields, line items, raw OCR, and confidence flags
- [x] M5.2 Implement document review with editable title/body/tags and handwriting warning
- [x] M5.3 Persist reviewed receipts/documents and cover mapping with tests

## M6 — History, search, detail

- [x] M6.1 Implement combined history, filters, and FTS-backed search
- [x] M6.2 Implement receipt/document detail, edit, delete, pin, and local image share
- [x] M6.3 Add repository/search/detail tests

## M7 — Dashboard, export, settings

- [x] M7.1 Implement monthly dashboard and category visualization
- [x] M7.2 Implement date-range expense CSV export
- [x] M7.3 Implement language/profile/currency/category/privacy settings
- [x] M7.4 Verify Bangla UI and profile-gated receipt surfaces in widget tests

## M8 — Android hardening

- [x] M8.1 Audit manifest permissions, minSdk 26, offline policy, and large-image handling
- [x] M8.2 Add migration/offline/manual QA scripts and R8 configuration notes
- [SKIPPED: user requested no disk-heavy validation] M8.3 Build/sign/install release APK and run airplane-mode device script

## M9 — iOS profile

- [x] M9.1 Verify documents-first home, expense toggle, and route gating through profile override tests
- [x] M9.2 Implement multi-page document persistence and local PDF export
- [x] M9.3 Add iOS permission strings and deployment target 15 configuration
- [SKIPPED: user requested no disk-heavy validation] M9.4 Run Pod install, iOS compile, simulator OCR, and physical share-sheet checks

## M10 — Landing page and distribution

- [x] M10.1 Build accessible static EN/BN landing page with no-JS fallback
- [x] M10.2 Add Pages/release workflows without running artifact builds locally
- [x] M10.3 Write release/signing/TestFlight instructions and manual verification checklist
- [SKIPPED: requires repository/secrets/signing authority] M10.4 Publish Pages, GitHub Release, APK, and TestFlight build

## Final V1 audit

- [x] Run analyze + full automated tests
- [x] Confirm Android manifest contains no `INTERNET` permission
- [x] Record every skipped device/build/signing/publishing gate in `PROGRESS.md`
- [BLOCKED: full §13 device/artifact/publishing gate was explicitly skipped] Generate `TASKS_V2.md`
