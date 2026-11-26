# Current state of the repository

Audited on 26 November 2026 at commit `11e35bd` on `main`.

## What exists

A Flutter app, version `1.0.0+1`, published as an early-access release in July 2026.

| Area | Fact |
|---|---|
| Toolchain | Flutter 3.44.6 stable, Dart 3.12.2 |
| Size | About 10,300 lines of hand-written Dart in `lib/` (16,700 with generated code); 185 tests reported in `PROGRESS.md` |
| State and routing | `flutter_riverpod` 3.3.2, `go_router` 17.3.0 |
| Storage | `drift` 2.34.2 on `sqlite3` 3.4.0, schema version 2, FTS5 search |
| Camera | `camera` 0.12.0+2, `image_picker` 1.2.3 |
| Reading text | Android: bundled Google ML Kit Latin (`com.google.mlkit:text-recognition:16.0.1`) through the method channel `app.rosid.rosid/ocr`, then Tesseract `ben+eng` through `flutter_tesseract_ocr` 0.4.31 when the text looks like Bangla. iPhone: Tesseract only |
| Image work | Pure Dart with `image` 4.9.1: edge guess at 640 px, perspective warp, deskew, threshold. Photos up to 3,200 px |
| Export | `pdf` 3.13.0, `csv` 8.0.0, `share_plus` 13.2.1 |
| Languages | English and Bangla through ARB files in `lib/core/l10n/` |
| Android | `applicationId` `app.rosid.rosid`, `minSdk` 26, R8 on, only the `CAMERA` permission in the release manifest |
| Bundled data | `assets/tessdata/eng.traineddata` (15.4 MB) and `ben.traineddata` (11.0 MB), from `tessdata_best` |

### Layout of `lib/`

```
core/       app metadata, l10n, profile (Android vs iPhone defaults), routing, settings, theme, utils
data/       drift database, private file store, repositories
features/   capture, crop, detail, export, history, home, review, settings, shared
ocr/        engines (mlkit_latin, tesseract_bn, tflite_bn_stub), merge, script_detect, preprocess, tessdata_installer
parsing/    receipt parser and normalisers (Bangla numerals, currency, dates)
```

### Routes today

`/` home, `/history`, `/settings`, `/capture`, `/crop`, `/review/receipt`, `/review/document`, `/detail/:id`, `/detail/:id/edit`, `/export`.

### Tables today

`scans`, `scan_pages`, `categories`, `receipts`, `line_items`, `documents`, `tags`, `scan_tags`, plus an FTS5 index maintained by the app.

### Scripts

`tool/check.ps1` and `tool/check.sh` run code generation, format check, analysis, tests and the offline audit (`tool/audit_offline.*`). `tool/prepare_site.py` fills release values into `site/` for the old Pages workflow. Also present: `tool/setup_release_signing.ps1`, `tool/generate_ocr_fixture_bundle.dart`, `tool/audit_ios_privacy.py` and its test.

### Fixtures and notes

- Receipt parser fixtures (text and expected JSON) in `test/fixtures/receipts/`.
- Three OCR pictures in `assets/fixtures/` (`english_receipt.png`, `handwritten_bangla_note.png`, `mixed_bangla_receipt.png`), turned into `test/fixtures/receipts/ocr_fixture_bytes.g.dart` by the generator script. Check they are not bundled in release builds; if they are, keep them out of the release asset list.
- `docs/` holds version 1 notes: `ARCHITECTURE.md`, `IOS_SELF_SIGNING.md`, `MANUAL_QA.md`, `RELEASING.md`, `WEBSITE_RESEARCH.md` and `audits/`. They move to `notes/` in M0 because `docs/` becomes the Pages folder.

### GitHub

- Remote: `https://github.com/tanzir71/rosid`. It was **private** on 26 November 2026.
- Workflows in `.github/workflows/`: `checks.yml`, `ios-lock.yml`, `pages.yml`, `release.yml`. All four must go (see M0).
- Pages is currently built by `pages.yml` from `site/`.
- Release `v1.0.0` at commit `602ca4e`: `rosid.apk` (150,056,622 bytes, universal) and `rosid-ios-unsigned.ipa`.
- `v*` tags are protected by a repository ruleset and releases are set to immutable.
- Branches on the remote: `main`, `codex/v2`. The tag `v1.0.0` exists.
- There is no `LICENSE` file.
- A scan of every branch on 26 November 2026 for key files and token patterns found nothing. Repeat it before making the repository public.

## What is unproven or missing

1. **The app has never run on a physical phone.** Checks so far are unit and widget tests plus three text-reading fixtures on an emulator.
2. **Capture is basic.** A fixed white rectangle over the preview. No live edge detection, no auto capture, no blur or light hints.
3. **Image work is slow by design.** Pure Dart on photos up to 3,200 px. No shadow removal, no CLAHE.
4. **Bangla reading is weak.** Tesseract on a hard-thresholded whole page. On iPhone there are no real word boxes or confidence values.
5. **Handwriting.** `TfliteBanglaHandwritingEngine` is a stub that throws. The `codex/v2` plan to train a model needed the owner at every step and produced no model.
6. **The APK is about 150 MB.** One universal file with every ABI.
7. **Look and behaviour.** Light theme only, no bundled Bangla font, no first-run flow, raw exception text shown to users, no backup even though all data is private to the app.
8. **Scope.** Version 1 is a receipt scanner with a document mode. Version 2 is a scanner for any paper, with an English draft, bundles and richer export. Most of that is new work. See `01-product.md`.

## What to keep

- The offline rule and its audit scripts.
- The receipt parser and normalisers in `lib/parsing/` and their fixtures. Extend them.
- The private file store and its cleanup behaviour.
- The drift database, with new migrations on top.
- The test suite. Tests are updated when behaviour changes on purpose, never deleted to get green.

## What to retire

- Everything under `.github/workflows/`.
- `lib/core/profile/app_profile.dart` as the thing that decides the home screen. The user's choice on first run replaces the Android-or-iPhone split.
- `lib/ocr/engines/tflite_bn_stub.dart`.
- The old `site/` once the new landing page is live.
- ML Kit, if the M3 benchmark allows it.
