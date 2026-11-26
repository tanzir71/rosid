# Third-Party Notices

Rosid bundles the following openly licensed fonts, models, and libraries inside the APK. Each notice reflects the verified upstream licence at the time the asset or dependency was added.

## Fonts

- **Anek Bangla** (Regular, Medium, SemiBold, Bold) — SIL Open Font License 1.1 (OFL-1.1). Source: Google Fonts (`google/fonts`, `ofl/anekbangla`). Subsetted for Bangla, Latin, digits, and punctuation.
- **Tiro Bangla** (Regular) — SIL Open Font License 1.1 (OFL-1.1). Source: Google Fonts (`google/fonts`, `ofl/tirobangla`). Subsetted for Bangla, Latin, digits, and punctuation.

## OCR & Language Data

- **PaddleOCR PP-OCRv5 Mobile Detection & English Mobile Recognition (`ppocr_v5_mobile_det.onnx`, `ppocr_v5_en_mobile_rec.onnx`, `ppocr_v5_en_dict.txt`)** — Apache License 2.0. Source: PaddlePaddle on Hugging Face (`PaddlePaddle/PP-OCRv5_mobile_det_onnx`, `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx`). See `assets/models/README.md` for SHA-256 checksums.
- **ONNX Runtime (`flutter_onnxruntime`)** — MIT License.
- **Tesseract traineddata (`eng.traineddata`, `ben.traineddata`)** — Apache License 2.0. Source: `tesseract-ocr/tessdata_best`.
- **Tesseract4Android** (`cz.adaptech.tesseract4android:tesseract4android:4.8.0`) — Apache License 2.0.

## Core Libraries

- **Flutter & Dart SDK, `material_ui`, `cupertino_ui`** — BSD-3-Clause.
- **Drift / sqlite3** — MIT / Public Domain.
- **Riverpod, go_router, flutter_svg, pdf, csv, share_plus, image, camera, image_picker** — MIT / BSD-3-Clause / Apache-2.0 (see `pubspec.lock` and each package's `LICENSE`).
