# Bundled OCR models

Rosid bundles official ONNX exports of PaddleOCR PP-OCRv5 mobile models under the Apache-2.0 licence. Every model runs locally on the phone via ONNX Runtime with zero network access.

| File | Source | Licence | Bytes | SHA-256 |
|---|---|---|---:|---|
| `ocr/ppocr_v5_mobile_det.onnx` | `PaddlePaddle/PP-OCRv5_mobile_det_onnx` (`inference.onnx`) | Apache-2.0 | 4,826,518 | `a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d` |
| `ocr/ppocr_v5_en_mobile_rec.onnx` | `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx` (`inference.onnx`) | Apache-2.0 | 7,848,423 | `b5f833dfc5d0eb71da397b4efa06ebeee9b431b690a47d6af40d77d8eabc557f` |
| `ocr/ppocr_v5_en_dict.txt` | Extracted from `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx` (`inference.yml`) | Apache-2.0 | 1,467 | see git tree |

Note: `ppocr_v5_mobile_det.yml` and `ppocr_v5_en_mobile_rec.yml` are upstream preprocessing/postprocessing metadata manifests for verification and reproducibility.
