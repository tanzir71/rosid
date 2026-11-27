# Verification summary: M9

- **Date**: 2026-11-27 06:38:28 +06:00
- **Commit**: `dbfb3d3`
- **Level**: Release
- **Flutter**: Flutter 3.50.1 • channel stable • https://github.com/flutter/flutter.git

## Steps

| Step | Status | Duration (s) |
|---|---|---|
| Generate localizations (gen-l10n) | pass | 1.93 |
| Code generation (build_runner) | pass | 5.83 |
| Generate OCR fixture bundle | pass | 4.97 |
| Format check | pass | 2.88 |
| Static analysis | pass | 6.81 |
| Unit and widget tests | pass | 50.05 |
| Offline audit (source) | pass | 0.23 |
| Build debug APK | pass | 91.15 |
| Start emulator and install debug APK | pass | 45.62 |
| Cold start launch and screenshot | pass | 17.79 |
| Integration tests (6 flow file(s)) | pass | 410.85 |
| Verify signing files are not tracked by git | pass | 0.11 |
| Build split release APKs | pass | 18.72 |
| Offline audit (merged release manifest) | pass | 0.14 |
| Release APK checks (size, permissions, DEX packages, 16KB alignment, signing) | pass | 4.34 |
| Release cold start and random-input monkey test (5000 events) | pass | 161.45 |

## Measured numbers

| Metric | Value |
|---|---|
| Tests | 00:43 +281: All tests passed! |
| Cold start (ms) | 7786 |
| Integration flows | 6 file(s) passed |
| arm64 APK size (MB) | 99.75 |
| armeabi-v7a APK size (MB) | 88.53 |
| Version codes | v2.0.0 (arm64=22000, armeabi-v7a=21000) |
| DEX packages audit | 0 Firebase/Play Services/analytics/ads classes |
| 16 KB ELF LOAD check | pass (13 arm64-v8a .so libs) |
| Signing cert SHA-256 | 1B:83:A5:29:55:86:4B:A1:C9:8D:1B:52:36:C2:96:72:57:B3:63:41:3F:40:74:BA:C7:35:68:95:FB:9D:FE:47 |
| Release cold start (ms) | 703 |
| Monkey 5000 events | pass (0 crashes) |
| arm64 APK SHA-256 | `4af5a9f041ebdf521013777030adffdcc9c5ea38ba65ed4c8d79daa9e77bd3b4` |
| armeabi-v7a APK SHA-256 | `4371d02f47eb1d5c9ecabd9dac0c4b0a01d0e85bffd9e98f105b351528c76735` |
| Landing page weight (excl. lazy screens) | bn 353.3 KB, en 349.4 KB (< 600 KB) |
| Landing page external requests | 0 (verified via headless Chrome) |

## M9 verification notes

- **Published GitHub Release**: `https://github.com/tanzir71/rosid/releases/tag/v2.0.0` (published as latest after downloading draft assets to `build/check/`, confirming SHA-256 checksums match `SHA256SUMS.txt`, and re-running `aapt2 dump permissions`, `zipalign -c -P 16 -v 4`, and `apksigner verify --print-certs` on the downloaded APKs).
- **APK size optimization**: Swapped `assets/tessdata/eng.traineddata` from `tessdata_best` (15.40 MB) to `tessdata_fast` (3.92 MB) because pure-English lines use PP-OCRv5 ONNX (0.09% CER) and `eng.traineddata` is only secondary on mixed lines. Final `rosid-arm64-v8a.apk` is **99.75 MB** (10.25 MB under the 110 MB limit) and `rosid-armeabi-v7a.apk` is **88.53 MB**.
- **Landing page (`docs/`)**: Built static Bangla (`/`) and English (`/en/`) pages + `404.html`, self-hosted subsetted WOFF2 fonts (`Anek Bangla`, `Tiro Bangla`, `JetBrains Mono`), HTML/CSS paper pair, 6 paper SVGs, 8 built-app WebP screenshots (4 EN + 4 BN), `og-bn.png` & `og-en.png` (1200x630), and real v2.0.0 checksums/download links injected by `tool/prepare_site.py`. Verified by `tool/check_site.py` (HTML tag balance, local asset resolution, 0 external requests in headless Chrome, < 600 KB weight, screenshots in `evidence/M9/site/`). Lighthouse CLI was not installed on host (recorded as not run in `handover/STATUS.md`).
- **Cleanup**: Removed legacy `site/` directory and stale `test/features/failures/`.


