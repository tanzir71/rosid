# Rosid V2 tasks

V2 replaces the disabled Bangla-handwriting seam with a measured, bundled,
fully offline model. V1 remains frozen at `v1.0.0` and `release/v1`, commit
`602ca4eda36cf7895809c4d308665392aae80db2`.

The V1 physical-device script and Apple distribution remain explicitly
deferred; neither is silently treated as passed. V2's final regression gate
still requires the full V1 manual script unless the owner makes a new decision.

## V2.0 - Transition and preservation

- [x] Verify the signed APK, unsigned IPA, live Pages, release checksums, and immutable V1 references
- [x] Create `codex/v2` with no mobile-source difference from `v1.0.0`
- [x] Create the guided runbook and decision ledger
- [x] Enable full Checks for pushes to `codex/v2`

## P0 - Design decisions

- [ ] Verify primary dataset sources, current licenses, redistribution terms, writer metadata, versions, and checksums
- [ ] Prepare the CRNN/CTC, grapheme tokenization, input shape, decoder, classifier, and fallback decision packet
- [ ] Obtain Tanzir's P0 approval and record it in `ml/DECISIONS.md`
- [ ] Decide dataset, checkpoint, model, metrics, and provenance storage formats
- [ ] Add a reproducible pinned Python project, seed/config handling, smoke tests, and one dependency lockfile
- [ ] Add CPU-only ML CI that downloads no datasets and requires no GPU

## P1 - Data assembly

- [ ] Implement validated dataset manifests and download instructions
- [ ] Implement deterministic writer-disjoint train/validation/test manifests and leakage tests
- [ ] Implement grapheme-aware receipt-domain text sampling
- [ ] Implement Tier 1 font/degradation synthesis
- [ ] Implement Tier 2 stroke surgery, writer hierarchy, and confusion-pair slices
- [ ] Implement Tier 3 learned synthesis
- [ ] Implement and pass the realism-AUC and synthetic-to-real CER gates

## P2 - Training

- [ ] Implement app-aligned preprocessing and dataset loaders
- [ ] Implement the compact CRNN+CTC model, metrics, and deterministic training
- [ ] Produce one runnable GPU notebook and an artifact manifest for each training run
- [ ] Run curriculum training and verify returned metrics/checkpoints

## P3 - Conversion and validation

- [ ] Export and compare float16 and int8 TFLite models
- [ ] Validate trained-versus-TFLite outputs on 100 frozen samples
- [ ] Build and run the real-device latency harness

## P4 - App integration

- [ ] Replace the disabled stub with line detection, TFLite inference, CTC decoding, and confidence output
- [ ] Add handwritten/printed routing with a reliable Tesseract fallback
- [ ] Bundle and hash the selected model; add size and privacy audits
- [ ] Add routing, failure, native inference, and printed-receipt regression tests

## P5 - Acceptance and release

- [ ] Meet Bangla handwriting CER <= 25% and at least 30% relative improvement over Tesseract on the writer-disjoint real holdout
- [ ] Meet amounts-only CER <= 12%
- [ ] Keep the quantized model <= 20 MB and line-batch latency <= 1.5 seconds on a 2022 mid-range Android device
- [ ] Pass printed-receipt regressions and the full V1 manual script
- [ ] Publish immutable V2 artifacts and only measured landing-page claims

