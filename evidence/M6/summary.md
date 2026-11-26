# Verification summary: M6

- **Date**: 2026-11-27 04:09:07 +06:00
- **Commit**: `0ba81ee`
- **Level**: B
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 1.91 |
| Code generation (build_runner) | pass | 22.98 |
| Generate OCR fixture bundle | pass | 4.39 |
| Format check | pass | 2.39 |
| Static analysis | pass | 6.85 |
| Unit and widget tests | pass | 48.75 |
| Offline audit (source) | pass | 0.23 |
| Build debug APK | pass | 73.88 |
| Start emulator and install debug APK | pass | 15.42 |
| Cold start launch and screenshot | pass | 14.57 |
| Integration tests (4 flow file(s)) | pass | 253.65 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:41 +257: All tests passed! |
| Cold start (ms) | 4711 |
| Integration flows | 4 file(s) passed |


## M6 Export Verification Notes

- **PDF checks (`test/export/m6_export_test.dart`)**: verified page count, A4 (`595.28 x 841.89 pt`) & Letter (`612 x 792 pt`) MediaBox sizes, real selectable `DRAFT TRANSLATION` stamp & `Draft translation from Bangla` footer on every English page, watermark text present when enabled and absent when disabled, and `Translator's Certification` page.
- **Size limit compression**: verified a 6-page synthetic scan compresses under 2 MB at >= 150 DPI A4 floor (`exceededSizeLimit == false`), and an impossible limit (`20 KB`) sets `exceededSizeLimit == true` rather than producing unreadable output.
- **Cover a detail**: verified black-bar and coarse blur/mosaic modes destructively overwrite 100% of covered pixels while leaving surrounding pixels and original saved scans untouched.
- **Word (`.docx`)**: verified ZIP archive structure (`[Content_Types].xml`, `_rels/.rels`, `word/_rels/document.xml.rels`, `word/document.xml`, `word/header1.xml`), Bangla runs with `w:cs="Nirmala UI"` & `w:bidi="bn-BD"`, `DRAFT TRANSLATION` header, and both Bangla + English content in Flows 5 E2E on `rosid_test`.
- **LibreOffice headless `.docx -> PDF` check**: not run (`soffice` is not installed on this machine).
- **PDF password protection**: hidden in UI (no verified permissively-licensed pure-Dart PDF encryption package available; recorded in `handover/STATUS.md`).
- **Design comparisons**: `evidence/M6/compare/{export-options,export-preview-certification,export-id-one-page,export-saved,safety-cover-detail}.png`.
