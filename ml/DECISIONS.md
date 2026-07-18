# Rosid V2 decision ledger

Only accepted decisions may constrain implementation. Proposed architecture and
toolchain choices remain reversible until the P0 packet is reviewed. Dataset
license evidence governs whether samples, derived data, checkpoints, or weights
may be committed or redistributed.

| ID | Status | Date | Decision | Evidence / next proof |
|---|---|---|---|---|
| V2-001 | Accepted | 2026-07-18 | Preserve V1 at `v1.0.0` and `release/v1`, commit `602ca4eda36cf7895809c4d308665392aae80db2`. | Immutable release and public artifact audit passed. |
| V2-002 | Accepted | 2026-07-18 | Target Bangla handwriting first; require no manual photography or annotation from Tanzir. | `CODEX_HANDOVER.md` section 17. |
| V2-003 | Accepted | 2026-07-18 | Runtime inference and model assets remain fully offline and bundled; no cloud experiment tracker is permitted. | Existing offline policy plus section 17. |
| V2-004 | Accepted | 2026-07-18 | Hard budgets: quantized model <= 20 MB and <= 1.5 seconds per line batch on a 2022 mid-range Android device. | Section 17 P0 and future real-device benchmark. |
| V2-005 | Proposed | 2026-07-18 | Conditionally start with the <=3M line CRNN+CTC and coverage-gated grapheme-aware hybrid vocabulary in `P0_DECISION_PACKET.md`; use TCN-CTC if the recurrent graph fails op/runtime/latency gates, or if int8 is required to meet them and recurrent int8 fails. Float16 remains viable when it clears all gates. | Tanzir approval plus an untrained dual-runtime spike required before GPU training. |
| V2-006 | Proposed | 2026-07-18 | Quarantine BanglaWriting, exclude Ekush, use BanglaLekha only for optional character pretraining, and treat BN-HTRd as conditional on writer-map proof and BBC-text rights-risk acceptance/review. This explicitly narrows section 17's candidate list. | Primary-source matrix and hashes are in `research/DATASETS.md`; Tanzir must approve the amendment/risk posture. |
| V2-007 | Proposed | 2026-07-18 | Use the recursive, transitive lineage/storage policy in `ARTIFACT_POLICY.md`; external nodes bind canonical reviewed source, artifact type/role, extracted bytes, and acquisition evidence; source archives bind split/partition artifacts; derived nodes record role/transformation; and training, conversion, prediction, metric, and Tier-specific completeness is mandatory. Raw data/checkpoints stay ignored/private, while manifests, aggregate metrics, and hashes are committed. | Tanzir approval; evidence-binding, canonical-byte, and completeness tests now pass. |
| V2-008 | Proposed | 2026-07-18 | Pin CPython 3.12.10, TensorFlow 2.21.0, Keras 3.15.0, tf-keras 2.21.0 compatibility export, regex 2026.7.10, ai-edge-litert 2.1.6, and tflite_flutter 0.12.1. | Tanzir approval, one uv lockfile, immutable CPU image, and actual Android/iOS runtime spike required. |
| V2-009 | Owner decision required | 2026-07-18 | The public-corpus audit found no qualifying real amount slice. BN-HTRd has only 37 currency-plus-digit lines across 12 writers, zero strict amount-only lines, zero `৳` labels, and numeric transcription defects; Bayanno and PromitoLipi lack the required line annotations/writer identity. Choose either (A) retain amount CER <=12% and block V2 release until an eligible corpus exists, or (B) remove it as a V2 release gate, keep synthetic/supplemental amount diagnostics, and make no real-amount accuracy claim. | Evidence and rejected shortcuts are recorded in `research/AMOUNT_BENCHMARK.md`; Tanzir must explicitly choose A or B. |
| V2-010 | Proposed | 2026-07-18 | Freeze the NFC scalar/micro CER, normalized amount CER, relative-improvement, raw-vs-routed, and 100-sample decoded/numeric parity contract in `METRICS.md`; explicitly amend “Tesseract-ben” to the shipped `tesseract-ben-eng`/`ben+eng` comparator while reporting ben-only separately. | Tanzir approval required. |
| V2-011 | Proposed | 2026-07-18 | Seal global pseudonymous writer groups before vocabulary/generator work; a known or possibly shared person must keep one group across datasets, and no final-test writer may influence synthesis, calibration, representatives, routing, or model selection. | Split/leakage code and release-level nonvacuity gates must pass on downloaded archives. |
| V2-012 | Proposed | 2026-07-18 | Routing release gates: printed false-positive <=2%, handwriting recall >=80%, full reject/confusion reporting, and raw HTR P5 metrics before fallback. | Tanzir approval and frozen routing corpus required. |
| V2-013 | Proposed | 2026-07-18 | Count model+vocabulary+classifier+contract under exactly 20,000,000 bytes (decimal 20 MB); add <=128 MB incremental HTR RSS and <=30 MB APK/IPA delta; define p95 warm HTR page-path latency <=1.5 s. | Tanzir approval and exact Android/iOS device paths required. |

## Decision protocol

1. Codex prepares a concise packet with options, evidence, tradeoffs, and a
   recommendation.
2. Tanzir approves or changes the recommendation.
3. The row is updated to `Accepted`, including the decision date and evidence.
4. Code depending on that decision may then be committed.
