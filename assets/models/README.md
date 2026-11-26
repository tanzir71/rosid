# Bundled on-device models

Every model runs locally on the phone with zero network access.

## OCR models (Apache-2.0)

Official ONNX exports of PaddleOCR PP-OCRv5 mobile models via ONNX Runtime.

| File | Source | Licence | Bytes | SHA-256 |
|---|---|---|---:|---|
| `ocr/ppocr_v5_mobile_det.onnx` | `PaddlePaddle/PP-OCRv5_mobile_det_onnx` (`inference.onnx`) | Apache-2.0 | 4,826,518 | `a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d` |
| `ocr/ppocr_v5_en_mobile_rec.onnx` | `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx` (`inference.onnx`) | Apache-2.0 | 7,848,423 | `b5f833dfc5d0eb71da397b4efa06ebeee9b431b690a47d6af40d77d8eabc557f` |
| `ocr/ppocr_v5_en_dict.txt` | Extracted from `PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx` (`inference.yml`) | Apache-2.0 | 1,467 | see git tree |

Note: `ppocr_v5_mobile_det.yml` and `ppocr_v5_en_mobile_rec.yml` are upstream preprocessing/postprocessing metadata manifests for verification and reproducibility.

## Translation model & Bergamot WebAssembly runtime (MPL-2.0)

Official Mozilla Firefox Translations Bangla-to-English (`bn-en` v1.0) model and Bergamot Translator WebAssembly v3.0 runtime fetched from Mozilla Remote Settings (`firefox.settings.services.mozilla.com`, `translations-models` & `translations-wasm`) and `mozilla-firefox/firefox` (`toolkit/components/translations/bergamot-translator/bergamot-translator.js`, v0.6.0). Binary assets are stored deterministically gzipped (`mtime=0`, level 9) in the APK and decompressed locally in-process inside the offline WebView asset loader.

| Bundled file | Upstream file & source | Licence | Uncompressed SHA-256 | Bundled bytes | Bundled SHA-256 |
|---|---|---|---:|---:|---|
| `translation/model.bnen.intgemm.alphas.bin.gz` | Mozilla Remote Settings `translations-models` `model.bnen.intgemm.alphas.bin` (v1.0) | MPL-2.0 | `14c1d9e92918e8d04cb0ed351ae386c3b5d5c62a6dc601d9515f4c7e6c2a3a56` | 12,662,114 | `7d40338d40f5b7c837a8fe70a7f88d87737df277fd6aaf5c3b58379b095b7f8b` |
| `translation/lex.50.50.bnen.s2t.bin.gz` | Mozilla Remote Settings `translations-models` `lex.50.50.bnen.s2t.bin` (v1.0) | MPL-2.0 | `aea901a6bd8722962551c0349b8570af684444028b62bbff465be9931e6e9800` | 2,201,383 | `804096246e3f412d6812a5040026436463cc8c96fba965ea63a449eae93481c0` |
| `translation/vocab.bnen.spm.gz` | Mozilla Remote Settings `translations-models` `vocab.bnen.spm` (v1.0) | MPL-2.0 | `8a6a4de992ccd47bae4227ec6420866374137d6cc88ed6e8b2f16b36322a9d37` | 432,707 | `a48f8c1f8a187611272c8d504751a1ef96e0be42301c4f8c99903ae7c2b39e2f` |
| `translation/bergamot-translator.wasm.gz` | Mozilla Remote Settings `translations-wasm` `bergamot-translator` (v3.0) | MPL-2.0 | `a3a89d9ad0a4ed8f27bf3e403701b23f5709816f6376438503f2fa5b0182c2dc` | 1,779,343 | `c06c16e06cff3af2a8e7c46d392d5ed1717a363085e8d92064a77b90b1536ef3` |
| `translation/bergamot-translator.js` | `mozilla-firefox/firefox` `toolkit/components/translations/bergamot-translator/bergamot-translator.js` (v0.6.0) | MPL-2.0 | `faff1ef6285b0d26f01787776fd49299dfb756ecb9688aa990c250e66797b47d` | 100,187 | `faff1ef6285b0d26f01787776fd49299dfb756ecb9688aa990c250e66797b47d` |
