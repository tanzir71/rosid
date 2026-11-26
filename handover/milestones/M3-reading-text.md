# M3: Reading text

Goal: measurably better reading of printed Bangla and English, with line boxes and confidence for every line. Measure first, then change.

Read first: `02-architecture.md` (Reading text), `03-verification.md` (Test data, Benchmark, Gates).

## Steps

1. **Fixture generator** and the synthetic set (at least 120 papers plus photo-like copies). Commit the generator, its templates and seed.
2. **Benchmark tool** `tool/ocr_bench.dart`. Run it on the current pipeline (ML Kit plus Tesseract, version 1 preprocessing and the M2 cleaning). Commit the result as `evidence/M3/baseline.json`. These numbers are the baseline for the Bangla gate.
3. **Engine interfaces**: `LineDetector`, `LineRecognizer`, `ScriptRouter`, `ReadingPipeline`. The result type carries lines with text, box, confidence and script.
4. **Model files**: export PP-OCRv5 mobile detection and the English mobile recogniser to ONNX on your machine with PaddleOCR's tools (or download official ONNX exports if published). Record source, version, licence and SHA-256 in `NOTICE.md` and `assets/models/README.md`.
5. **Detector and Latin recogniser** through `flutter_onnxruntime` in the reading isolate. Add the ProGuard rule.
6. **Bangla candidates**: implement Tesseract per line (psm 7) with `tessdata_fast` and `tessdata_best`; export EasyOCR Bengali to 8-bit ONNX and implement it. Run the benchmark on all candidates.
7. **Choose** by the rule in `02-architecture.md`. Record the table of results and the choice in STATUS "Decisions taken". Remove the losers from the APK.
8. **Script router** per line, with the "run both when unsure" rule.
9. **After reading**: NFC normalisation, remembered corrections, alternatives for uncertain words.
10. **Handwriting signal**: mark pages as partly handwritten by the rule in `02`; test with any handwriting fixtures you have, otherwise with synthetic pages using a handwriting-style font and record that it is synthetic.
11. **Store** lines in `text_lines`, and keep the full text in `scans` for search.
12. **Progress screen**: wire the real steps and line counter; Cancel stops the isolate work cleanly.
13. **ML Kit**: remove it if the Latin recogniser matches or beats it on the benchmark (rule in `02`). Otherwise keep it for Latin lines only.
14. Re-run the receipt parser tests; extend the parser for VAT invoices and mobile-money markers using the new line structure.

## Done when (Level B)

- [ ] `evidence/M3/baseline.json` and `evidence/M3/final.json` both committed.
- [ ] Printed English character error 5% or less.
- [ ] Printed Bangla character error at least 30% lower than baseline.
- [ ] Receipt total exact on 85% or more of receipt fixtures.
- [ ] Median time per page 4 s or less on `rosid_test`; peak memory 600 MB or less on `rosid_low`.
- [ ] Every stored line has a box and a confidence (test).
- [ ] arm64 release APK size measured and under 110 MB.
- [ ] Progress screen matches the design; Cancel works (test).
- [ ] STATUS updated with all numbers and the engine choice, pushed.

## Fallbacks

- ONNX Runtime does not work on the emulator architecture: run the benchmark on the host with ONNX Runtime for desktop (same models), and run the emulator check on an arm64 emulator image if acceleration allows. Record which.
- The Bangla gate is not met by any candidate: ship the best one, keep the number in STATUS, and make sure uncertain words are highlighted generously (lower the confidence threshold for "check").
- A model cannot be exported on this machine: try the official export, then a different PaddleOCR release. If none works, keep ML Kit for Latin and Tesseract per line for Bangla, using the M2 cleaning, and record it.
