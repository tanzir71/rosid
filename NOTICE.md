# Third-Party Notices

Rosid bundles the following openly licensed fonts, models, and libraries inside the APK. Each notice reflects the verified upstream licence at the time the asset or dependency was added.

## Fonts

- **Anek Bangla** (Regular, Medium, SemiBold, Bold) — SIL Open Font License 1.1 (OFL-1.1). Source: Google Fonts (`google/fonts`, `ofl/anekbangla`). Subsetted for Bangla, Latin, digits, and punctuation.
- **Tiro Bangla** (Regular) — SIL Open Font License 1.1 (OFL-1.1). Source: Google Fonts (`google/fonts`, `ofl/tirobangla`). Subsetted for Bangla, Latin, digits, and punctuation.
- **JetBrains Mono** (Regular, landing page only) — SIL Open Font License 1.1 (OFL-1.1). Source: `JetBrains/JetBrainsMono`. Subsetted to ASCII for the static landing page.

## OCR & Language Data

- **PaddleOCR PP-OCRv5 Mobile Detection & English Mobile Recognition (`ppocr_v5_mobile_det.onnx`, `ppocr_v5_en_mobile_rec.onnx`, `ppocr_v5_en_dict.txt`)** — Apache License 2.0. Source: PaddlePaddle on Hugging Face (`PaddlePaddle/PP-OCRv5_mobile_det_onnx`, `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx`). See `assets/models/README.md` for SHA-256 checksums.
- **ONNX Runtime (`flutter_onnxruntime`)** — MIT License.
- **Tesseract traineddata (`ben.traineddata` from `tesseract-ocr/tessdata_best`, `eng.traineddata` from `tesseract-ocr/tessdata_fast`)** — Apache License 2.0.
- **Tesseract4Android** (`cz.adaptech.tesseract4android:tesseract4android:4.8.0`) — Apache License 2.0.

## On-Device Translation

- **Mozilla Firefox Translations Bangla-to-English (`bn-en` v1.0) model (`model.bnen.intgemm.alphas.bin`, `lex.50.50.bnen.s2t.bin`, `vocab.bnen.spm`)** — Mozilla Public License 2.0 (MPL-2.0). Source: Mozilla Remote Settings (`translations-models`). See `assets/models/README.md` for SHA-256 checksums.
- **Bergamot Translator WebAssembly Runtime (`bergamot-translator` v3.0 WASM & `bergamot-translator.js` v0.6.0)** — Mozilla Public License 2.0 (MPL-2.0). Source: Mozilla Remote Settings (`translations-wasm`) and `mozilla-firefox/firefox`.

## Core Libraries

- **Flutter & Dart SDK, `material_ui`, `cupertino_ui`** — BSD-3-Clause.
- **Drift / sqlite3** — MIT / Public Domain.
- **Riverpod, go_router, flutter_svg, pdf, archive, cryptography, local_auth, csv, share_plus, image, camera, image_picker** — MIT / BSD-3-Clause / Apache-2.0 (see `pubspec.lock` and each package's `LICENSE`).
