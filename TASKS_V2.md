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

- [x] Verify publisher sources, licenses, redistribution risks, reported writer metadata, versions, and exact publisher checksums
- [x] Define the fail-closed archive, extracted regular-file inventory, dataset-adapter, global-writer, split-config/code, and lineage verification contract
- [x] Prepare the CRNN/CTC, grapheme tokenization, input shape, decoder, classifier, and fallback decision packet
- [ ] Obtain Tanzir's P0 approval and record it in `ml/DECISIONS.md`
- [ ] Decide dataset, checkpoint, model, metrics, and provenance storage formats
- [ ] Add a reproducible pinned Python project, seed/config handling, smoke tests, and one dependency lockfile
- [x] Add CPU-only ML CI that downloads no datasets and requires no GPU

## P1 - Data assembly

- [x] Implement generic canonical source/acquisition evidence and stable archive/extracted regular-file snapshot hashing
- [x] Implement and adversarially test a generic fail-closed ZIP extraction boundary with pre-parser central-directory/member limits, expansion/capacity ceilings, fresh ignored destinations, exact post-write inventory and archive-stability checks, surfaced cleanup failure, and mode-bit sealing (advisory on Windows) within the documented trusted-operator boundary
- [ ] If approved, download each selected archive, choose and review per-archive limits, invoke the generic extractor, and verify the exact regular-file inventory, dataset structure, and writer mapping against the P0 contract
- [ ] Implement each dataset-specific adapter and audit its normalized derivations and global writer groups against the real archive/inventory
- [ ] Produce approved production acquisition records; a cleared BN-HTRd requires a fresh amended production source manifest and acquisition rather than upgrading conditional evidence
- [x] Implement generic private adapter evidence with exact normalized-output identity and complete used/ignored source coverage, plus a path-free public HMAC commitment and trusted-process verified-adapter marker
- [x] Implement a generic one-global deterministic writer-disjoint manifest scaffold whose `PublicSplitCommitment` schema V3 binds the out-of-band-pinned approval-policy SHA, external split-approval SHA and scope, domain-separated seed/commitment-key fingerprints, every exact adapter commitment, config, aggregate counts, and private-manifest HMAC
- [x] Generate a reviewable transitive static-import closure from fixed P1 entrypoints and the explicit adapter subtree in a complete regular-mode Git checkout; emit its `SplitConfig`, bind every exact public input at commit A in a canonical approval request, verify an external OpenSSH SSHSIG, and require build/verify to consume the committed policy, approval, bundle, config, and adapter configs
- [x] Require the trusted-process `VerifiedSplitEvidence` marker in lineage; bind the exact public split SHA, signed scope and resulting eligibility, dataset IDs, acquisitions, canonical config, combined code bundle, approval-policy parent, and split-approval parent
- [ ] Tanzir creates an external Ed25519 signing key, activates and commits the currently pending `ml/APPROVAL_POLICY.json`, distributes/verifies its canonical SHA out of band, records P0 approval, and externally signs the exact split request; then complete real downloads, adapters/writer audits, production acquisitions, and the sealed global split
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

- [x] Harden the structural-only model-bundle audit for exact bytes/SHA, portable logical IDs, aggregate size/privacy checks, stable unlinked regular-file snapshots, and physical-alias rejection
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
- [ ] Satisfy recorded V2-009: either real amounts-only CER <= 12%, or supplemental diagnostics plus no real-amount claim
- [ ] Keep the complete HTR bundle <= 20,000,000 bytes and line-batch latency <= 1.5 seconds on a 2022 mid-range Android device
- [ ] Pass printed-receipt regressions and the full V1 manual script
- [ ] Publish immutable V2 artifacts and only measured landing-page claims
