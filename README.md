# Rosid (রসিদ)

Rosid is a fully offline Flutter scanner for Bangla and English receipts and
documents. Android defaults to receipt scanning and expense tracking; iOS
defaults to a documents-first experience. `AppProfile` keeps those variants in
one codebase.

Download the signed Android APK or the advanced unsigned iPhone package from
the [Rosid landing page](https://tanzir71.github.io/rosid/). GitHub Releases
hosts every version, checksum, and Android signing-certificate fingerprint.
The iPhone package requires user-managed self-signing; it is not an App Store or
TestFlight build.

## Features

- Fully offline: no HTTP client, analytics, crash reporter, account, or Android internet permission.
- Capture from the camera or gallery, then crop, perspective-correct, and enhance the page.
- On-device OCR for Bangla and English. Android uses ML Kit Latin plus bundled Tesseract `ben+eng`; iOS uses bundled Tesseract only.
- Editable review screens for receipts (with line items) and for documents, with per-field confidence.
- Searchable local history stored in SQLite (Drift, FTS5).
- Export to CSV and PDF through the system share sheet; temporary export files are deleted afterwards.
- English and Bangla UI.

## Tech stack

Flutter and Dart, Riverpod, go_router, Drift/SQLite, Tesseract (`flutter_tesseract_ocr`), Google ML Kit on Android.

## Local development

```sh
flutter pub get
FLUTTER_BIN="$(command -v flutter)" tool/check.sh
```

On Windows PowerShell, use the equivalent native entrypoint:

```powershell
flutter pub get
.\tool\check.ps1
```

The lightweight check runs localization/code generation, formatting, analysis,
tests, and the offline audit. Set `ROSID_RUN_BUILD=1` (or pass `-RunBuild` to the
PowerShell script) to include a debug APK on a machine with Android tooling and
sufficient disk.

After producing a release APK, run `tool/audit_offline.sh --require-merged` or
`.\tool\audit_offline.ps1 -RequireMerged`; release/tag audits fail if the merged
manifest cannot be located or contains a permission outside the privacy policy.

Release builds must include `eng.traineddata` and `ben.traineddata` in
`assets/tessdata/`; the tag workflow verifies the checked-in files against their
pinned SHA-256 values before building.

See [PROGRESS.md](PROGRESS.md), [TASKS.md](TASKS.md),
[docs/RELEASING.md](docs/RELEASING.md), and the recorded
[landing-page research](docs/WEBSITE_RESEARCH.md).

Architecture notes are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
