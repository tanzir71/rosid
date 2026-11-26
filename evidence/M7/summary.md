# Verification summary: M7

- **Date**: 2026-11-27 04:31:01 +06:00
- **Commit**: `32f7ce1`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 1.93 |
| Code generation (build_runner) | pass | 24.3 |
| Generate OCR fixture bundle | pass | 4.72 |
| Format check | pass | 3.56 |
| Static analysis | pass | 7.34 |
| Unit and widget tests | pass | 52.74 |
| Offline audit (source) | pass | 0.22 |
| Build debug APK | pass | 73.69 |
| Start emulator and install debug APK | pass | 15 |
| Cold start launch and screenshot | pass | 14.82 |
| Integration tests (5 flow file(s)) | pass | 303.7 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:43 +269: All tests passed! |
| Cold start (ms) | 4813 |
| Integration flows | 5 file(s) passed |
| 500-paper search (`rosid_test`) | Bangla 3 ms (2 hits), English via Name Book 2 ms (2 hits) — gate <= 150 ms |

## M7 verification notes

- **Search normalization & cross-script index**: `TextNormalizer.normalizeForSearch` normalizes NFC, strips ZWJ/ZWNJ/BOM, and canonicalizes decomposed `য়` (`য+়`), `ড়` (`ড+়`), `ঢ়` (`ঢ+়`). `LibrarySearchService` expands FTS5 queries bidirectionally through the Name Book (`Bangla <-> English`) and searches `text_lines`, `translations`, and `names`, highlighting hits per paper ("Page N, Bangla text" / "English draft").
- **Renew by date**: editable from `PaperScreen` ("Set renewal date"), shown as a `"Renew by <date>"` pill in Library and on Home when due within 30 days.
- **Checklists & bundles**: 5 templates in `assets/data/checklists.json` (Student visa, Visit visa, Land papers, Bank loan, Empty bundle), each carrying `"Check the official list for your application."` Live status computation (`ready`, `needsWork`, `missing`), link existing paper / scan / add / remove / reorder / due date, and Home + Export Saved bundle hooks.
- **Bundle export**: `BundlePdfBuilder` builds either One PDF with Page 1 numbered Contents table in checklist order and exact page numbers (plus `DRAFT TRANSLATION` on draft pages, optional watermark, and per-file size limit) or Separate numbered files (`01-Passport.pdf`, ...) in a ZIP.
- **Visual comparisons**: 6 side-by-side comparisons against Figma committed in `evidence/M7/compare/` (`library.png`, `library-search.png`, `bundles.png`, `bundle-checklist.png`, `bundle-checklist-bn.png`, `bundle-export.png`).
- **Flows 6 & 7**: Verified end to end on `rosid_test` in `integration_test/flow_6_7_library_bundles_test.dart` alongside the 500-paper search benchmark.


