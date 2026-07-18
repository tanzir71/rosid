# V2 P0 decision packet

Status: proposal awaiting Tanzir's approval. Date: 2026-07-18.

Approval authorizes experiments; it is not an accuracy claim and waives no P5
gate. `METRICS.md`, `ARTIFACT_POLICY.md`, and `research/DATASETS.md` are part of
this packet.

## Recommended decision

1. Conditionally approve a compact line-level CRNN+CTC baseline, subject to an
   untrained conversion and Android/iOS runtime spike before GPU training.
2. Use the grapheme-aware hybrid vocabulary below. Run a scalar-token ablation
   for evidence, but do not silently replace section 17's grapheme requirement.
3. Quarantine BanglaWriting and exclude Ekush unless explicit rights are later
   obtained. Treat BN-HTRd as conditional, not automatically production-safe.
4. Seal writers before learned synthesis, vocabulary construction, calibration,
   or model selection; never tune on final-test writers.
5. Ship greedy decoding first. A small beam is optional only after measured
   accuracy and device-latency improvement.
6. Route handwriting inside `OcrService` and preserve Tesseract whenever HTR is
   unavailable, invalid, uncertain, or fails.
7. Accept no model until cross-runtime, raw-accuracy, synthesis, lineage,
   routing, aggregate-size, privacy, device, and the recorded V2-009 amount
   posture all pass.

## Evidence-dependent blockers

These cannot be approved by assumption:

- BN-HTRd must expose a stable page-to-writer mapping. Tanzir must also accept
  the documented BBC-source-text rights risk after review, or obtain a rights
  determination, before BN-HTRd descendants become production-eligible. Any
  conditional audit remains conditional: after both gates pass, production use
  requires an amended production source manifest/source-evidence record and a
  fresh production acquisition rather than an in-place eligibility upgrade.
- The completed public-corpus audit found no eligible real monetary-amount
  slice. BN-HTRd has only 37 currency-plus-digit lines across 12 writers, zero
  strict amount-only lines, zero `৳` labels, and numeric transcription defects;
  Bayanno and PromitoLipi do not supply the required annotations and writer
  identity. `research/AMOUNT_BENCHMARK.md` records the evidence. Tanzir must
  choose either to retain amount CER <=12% and block release until a new
  eligible corpus exists, or explicitly remove that V2 release gate, keep only
  supplemental amount diagnostics, and make no real-amount accuracy claim.
  Synthetic amounts cannot satisfy a retained real P5 gate.
- P0 must name an available 2022 mid-range Android reference device (or an
  evidence-backed comparable rule) and a physical iOS 15.5+ runtime-test path.

## Explicit section-17 amendments requested

Approval records these owner-visible clarifications:

1. The four named public datasets are candidates, not mandatory inputs despite
   restrictive or ambiguous rights. BanglaWriting is research-only and Ekush
   excluded. Tier 3 may train on BN-HTRd alone only after its conditional gates.
2. Grapheme-aware output remains mandatory. Scalar-only production output would
   require a later explicit amendment, even if its ablation scores better.
3. “Tanzir commits checkpoints/best weights” means placing binaries in ignored
   `ml/checkpoints/` and committing only manifests, aggregate metrics, and
   hashes. License-sensitive binaries never enter a draft release in the public
   repository.
4. Section 17's “bit-for-bit comparison” means 100/100 identical decoded token
   sequences/NFC UTF-8 text plus the bounded numeric checks in `METRICS.md`.
   Quantized logit storage bytes are not expected to equal float storage bytes.
5. Model, vocabulary, classifier, and model-contract bytes share an exact
   `20,000,000`-byte HTR asset ceiling (decimal 20 MB), a stricter
   interpretation than counting only the FlatBuffer and more conservative than
   20 MiB.
6. Section 17's “Tesseract-ben” comparator is the actual shipped offline engine
   `tesseract-ben-eng` with language string `ben+eng`, both traineddata hashes,
   binary/plugin version, PSM, preprocessing, and options frozen. Also report a
   ben-only diagnostic, but gate the 30% improvement against the shipped path.
7. P0 approval freezes the verification contract and authorizes the named P1
   audits. It does not verify an undownloaded archive, extraction, dataset
   structure, writer map, normalized sample, acquisition, or global split; P1
   must produce that evidence from the actual approved bytes.

## Recognition baseline

Input is one grayscale line at fixed `[1,48,512,1]`: preserve aspect ratio,
normalize with the app-matched pipeline, and right-pad with the measured paper
background. Width is downsampled by four to 128 CTC time steps.

Proposed graph:

1. Conv2D 32, 3x3, batch normalization, ReLU6, pool 2x2;
2. depthwise-separable Conv2D 64, pool 2x2;
3. depthwise-separable Conv2D 128, pool 2x1;
4. depthwise-separable Conv2D 192;
5. depthwise-separable Conv2D 256, pool 2x1;
6. Conv2D 256, kernel 3x1 valid, reducing height to one;
7. reshape to `[1,128,256]`;
8. two stateless bidirectional LSTM layers, 128 units per direction; and
9. dense `vocabulary+blank` logits.

CTC loss, lookup, softmax, and decoding remain outside the exported graph.
Target at most 3M parameters and never exceed section 17's approximately 5M
ceiling. Select TF Ops/Flex and custom ops are release failures.

A non-qualifying Windows CPU research spike with TensorFlow 2.21/Keras 3.15 and
1,500 output tokens produced 1,462,557 parameters, a 5,937,488-byte float32
model, a 2,996,288-byte float16 model, and output `[1,128,1501]`. Direct Keras 3
conversion emitted `WHILE` rather than fused sequence-LSTM ops, and strict int8
calibration terminated. Size feasibility is encouraging; runtime compatibility
is unproved.

Before GPU work, repository code must export this CRNN through both Keras 3 and
`tf-keras==2.21.0`, plus a TCN fallback, audit every operator/version/dtype, and
load/infer through the exact Flutter Android and physical-iOS binaries.

The fallback replaces both BiLSTMs with eight residual depthwise-separable
Conv1D blocks: 256 channels, kernel 5, dilations
`1,2,4,8,1,2,4,8`, batch normalization, ReLU6, then logits. Trigger it if the
CRNN emits `WHILE`/Flex/custom ops, fails either runtime, or misses latency. An
int8 failure triggers TCN only when float16 cannot meet size/latency and int8 is
therefore required; int8 is otherwise optional. Do not enlarge the budget to
rescue an incompatible graph.

Compare input height 48 versus 64 on the same real validation manifest only if
upper/lower Bangla marks show measured loss.

## Grapheme vocabulary and decoder

- NFC-normalize labels and predictions. Segment Unicode 17 extended grapheme
  clusters using UAX #29, including current Indic conjunct boundaries.
- Define an approved base repertoire of Bangla scalars, ZWJ/ZWNJ, ASCII digits
  and letters, space, receipt punctuation, and `৳`.
- Add multi-scalar EGC tokens occurring at least 50 times in the **training**
  split, ordered by frequency then Unicode tuple. Cap total vocabulary at 2,048.
- An EGC without a dedicated token decomposes to already-trained base scalars.
  Reject out-of-repertoire scalars; never emit `<unk>` or an untrained escape.
- Emit a token-coverage manifest. Every included base scalar needs at least 100
  training occurrences; space, both digit systems, and `৳` need at least 1,000
  each. Synthetic sampling fills deficits before training, and any
  zero/under-threshold output head fails vocabulary acceptance.
- CTC blank is ID 0, vocabulary IDs begin at 1, and training-only padding is
  `-1`. Commit Unicode version, ordered token bytes, source split hash, and
  vocabulary SHA-256.
- Require `token_count + adjacent_repeat_count <= 128`; operationally split
  labeled training lines before 96 tokens to leave alignment margin.
- Run the scalar-token ablation on identical train/validation writers. It
  measures the hybrid cost but cannot change the mandated production scheme
  without a new owner decision.
- Production decoding is greedy argmax, duplicate collapse, blank removal, and
  token concatenation in a Dart isolate. Evaluate prefix beam width 8; ship it
  only for at least 0.5 absolute validation-CER points of gain while preserving
  the device gate. No language model in the first baseline.
- Calibrate confidence on real validation writers. Raw maximum softmax is not a
  user-facing confidence.

CER/WER denominators do not depend on vocabulary tokens; `METRICS.md` freezes
NFC scalar CER, amount extraction, micro averaging, relative improvement,
Tesseract baseline identity, raw-vs-routed reporting, and 100-sample parity.

## Long-line handling

Training labels are known, so split before rendering/cropping at label
whitespace while preserving a source-line/reassembly manifest. At inference
text is unknown: after height normalization, locate strong whitespace valleys
in the image's vertical ink projection near each 512-pixel boundary. Split at a
validated valley with context padding. If no valley is reliable, use overlapping
512-pixel windows and reassemble only on a unique token suffix/prefix overlap.
An ambiguous overlap, saturated CTC path, or uncovered pixels sets an overflow
diagnostic, lowers confidence, and preserves the Tesseract fallback; it never
silently truncates or pretends text whitespace was known in advance.

## Routing and fallback

The V1 seam was registered but unreachable. The architecture-independent V2
contract now lives inside `OcrService`: a disabled production policy preserves
V1, fake engines can exercise the route, recoverable HTR failures keep a
complete Tesseract baseline, invalid blocks are rejected, and programmer errors
still propagate.

After a model exists:

1. explicit `banglaHandwriting` attempts available HTR;
2. automatic/Bangla modes combine first-pass coverage/confidence evidence with
   connected-component and stroke-width variation;
3. a future tiny three-class DS-CNN (`printed`, `handwritten`, `uncertain`) may
   replace the heuristic, but all its bytes share the 20,000,000-byte ceiling;
4. uncertain lines may run both engines; model load/integrity/op/inference,
   timeout, empty, geometry, or confidence failures preserve Tesseract and show
   an editable-review warning; and
5. engine/model IDs, model hash, and routing reason are retained in diagnostics.

Freeze a mixed routing set of printed fixtures, real public handwriting,
mixed/noisy pages, and uncertain cases. Proposed release gates are printed
false-positive rate at most 2%, handwriting recall at least 80%, full confusion
matrix/reject curve reported, and no printed-fixture regression. P5 still uses
raw HTR predictions on every eligible HTR test line before routing/fallback, so
rejection cannot hide recognition failures.

## Data, synthesis, and leakage policy

If approved, use BN-HTRd V4 for real lines only under its recorded eligibility
and BanglaLekha-Isolated V2 only for optional isolated-character
pretraining/confusion diagnostics. Their catalogs are CC BY 4.0, but BN-HTRd
remains conditional on writer-map and BBC-source-text risk acceptance. A
quarantined P1 audit may establish the writer map; if both gates later clear,
create an amended production source manifest/source evidence and a fresh
production acquisition. Quarantine BanglaWriting (CC BY-NC 3.0) and exclude
Ekush because its image/weight rights and immutable version are not established.

Writer-disjoint train, validation, and sealed final-test partitions must be
created before vocabulary construction or Tier-3 learned synthesis.
Writer-group keys are global across datasets; known shared people remain
together and unresolved cross-corpus identity is an evidence gap, not silently
treated as disjoint.
Tier 3 may learn only from eligible **training-writer** styles. Validation
writers drive realism, synthetic-to-real trends, routing, confidence, decoder,
and model selection. Final-test writers influence only final metrics.

The recursive lineage contract in `ARTIFACT_POLICY.md` covers datasets, fonts,
textures, receipt vocabularies/text sources, pretrained weights, generator
code/checkpoints, and generated corpora. A post-download acquisition binds an
`extracted_dataset` transitively to the canonical reviewed `source_archive`,
including the exact regular-file-set hash and private inventory commitment;
empty directories are outside that snapshot. A qualifying global split binds
one path-free public adapter commitment per exact source acquisition, the
`PublicSplitCommitment` schema V3 record, approved adapter/split configs, and the
complete core/adapter executable code closure before any train/validation/test
claim. Schema V3 also binds the canonical approval-policy SHA pinned out of
band, external split-approval SHA and production/quarantined-research scope,
domain-separated fingerprints of the actual split seed and HMAC keys, aggregate
counts, and private-manifest HMAC. The retained
`SplitConfig.splitter_code_sha256` field denotes that entire closure, not only
the splitter. Derived nodes record their role/transformation, synthesis tier,
and parents. Type-specific completeness binds generator/model checkpoints,
vocabularies, conversion code/config, representative sets, contracts,
prediction streams, final metrics, and exports. Eligibility is transitive, so a
generator cannot launder restrictive inputs. Tier 3 also requires exact and
perceptual memorization/nearest-neighbor audits.

The generic tooling now rebinds the canonical `DatasetSource`, source evidence,
acquisition, private extraction inventory, and normalized sample inventory.
Each private adapter-evidence record must enumerate every exact normalized
sample identity and source derivation and classify every inventoried source file
as used or explicitly ignored with a reason. Its public commitment is path-free
and HMAC-binds the private evidence plus the acquisition, inventory, adapter
config, and combined code bundle. This proves the declared byte-level
relationships and complete coverage; it does not establish that a
dataset-specific transformation is semantically correct or that two publisher
writer IDs denote different people. The real adapters and writer audit remain
P1 work.

The fixed `ml/APPROVAL_POLICY.json` is deliberately `pending` and currently
authorizes no qualifying split. Before either production or quarantined research
can qualify, Tanzir must create an Ed25519 key outside the repository, activate
and commit the policy, distribute and independently verify its canonical SHA out
of band, and record P0 approval. The owner private signing key never enters the
repository or a repository Python process. This packet records a proposal, not
Tanzir's approval.

`prepare_split_approval` auto-includes the exact core code closure and accepts
only repeatable adapter implementation files. Commit the policy, generated
bundle/config, source manifests/evidence, acquisitions, public adapter
commitments/configs, and bound implementation files as commit A.
`request_split_approval` uses the separately trusted policy SHA and actual
private split keys to generate a canonical request binding the exact paths,
roles, and hashes at commit A, canonical repository origin, scope, full code
closure, and domain-separated key fingerprints. Commit that request. Tanzir
then signs the canonical request externally with
`ssh-keygen -Y sign -n rosid-v2-split-approval`; repository Python receives only
the request and detached SSHSIG. `finalize_split_approval` verifies the SSHSIG,
canonical origin, commit ancestry, and exact approved tree, emits the canonical
approval, and that approval is committed.

Split build/verify require the committed approval and out-of-band policy SHA in
addition to all committed public records and private evidence. They reverify the
actual split keys against the approved fingerprints and return
the trusted-process `VerifiedSplitEvidence` marker only after the complete
public/private proof succeeds. The fixed CLI is the adversarial boundary;
arbitrary code already running in the same Python interpreter is trusted.
Lineage requires that marker, exact approval-policy, split-approval, config,
complete-code, and external-dataset parents, and scope-derived eligibility.
HMAC verification alone proves consistency, not approval. Real downloads,
dataset-specific
adapters/writer audits, owner policy activation and P0 approval, production
acquisitions, external request signing, and the production split remain pending.

All three synthesis tiers, at least 500k lines, Tier 1 at most 40%, every P1a
slice, per-tier/combined realism AUC at most 0.85, improving synthetic-to-real
validation CER, and cross-language app-preprocessing golden hashes are
machine-checkable preconditions to production HTR curriculum training and model
selection. A quarantined generator-probe HTR is permitted only to produce the
synthetic-to-real gate evidence and cannot seed production weights.

## Toolchain proposal

Pin one `uv` lockfile and immutable Linux CPU container after approval:

| Layer | Proposed pin / rule |
|---|---|
| Python | CPython `3.12.10`; project range `>=3.12,<3.13` |
| TensorFlow | `2.21.0` |
| Keras | `3.15.0` |
| Compatibility export | `tf-keras==2.21.0` |
| Grapheme rules | `regex==2026.7.10` |
| Desktop validation | `ai-edge-litert==2.1.6` |
| Flutter inference | `tflite_flutter==0.12.1`, exact resolved archive/revision |

The Flutter plugin packages asymmetric runtimes: LiteRT 1.4.0 on Android and
TensorFlowLiteSwift 2.12.0 on iOS. Host execution in LiteRT 2.1.6 therefore does
not prove app compatibility. A simulator alone does not satisfy the physical
iOS load/inference gate.

Ubuntu CPU CI is authoritative and uses a clean commit, `PYTHONHASHSEED=0`,
`TF_ENABLE_ONEDNN_OPTS=0`, `CUDA_VISIBLE_DEVICES=-1`, deterministic TensorFlow
ops/data/augmentation, fixed seeds, one intra/inter/OpenMP thread, and no
dataset/pretrained-weight downloads. GPU runs record exact Python patch, image,
driver, accelerator, config, and hashes; cross-hardware bit identity is not
promised.

Primary evidence:

- TensorFlow 2.21 release: <https://github.com/tensorflow/tensorflow/releases/tag/v2.21.0>
- TensorFlow install support: <https://www.tensorflow.org/install/pip>
- Keras 3.15: <https://pypi.org/project/keras/3.15.0/>
- LiteRT 2.1.6: <https://github.com/google-ai-edge/LiteRT/releases/tag/v2.1.6>
- Flutter plugin Android runtime: <https://github.com/tensorflow/flutter-tflite/blob/main/android/build.gradle>
- Flutter plugin iOS runtime: <https://github.com/tensorflow/flutter-tflite/blob/main/ios/tflite_flutter.podspec>
- LiteRT RNN conversion: <https://ai.google.dev/edge/litert/models/convert/rnn>
- Post-training quantization: <https://www.tensorflow.org/model_optimization/guide/quantization/post_training>
- TensorFlow determinism: <https://www.tensorflow.org/api_docs/python/tf/config/experimental/enable_op_determinism>
- Unicode UAX #29: <https://unicode.org/reports/tr29/>
- GraDeT-HTR evidence: <https://aclanthology.org/2025.emnlp-demos.52.pdf>

## Conversion and device experiment

Export float32 and float16-weight variants for every candidate. Full-int8 is
conditional on a stable conversion spike and uses 500 frozen,
production-eligible **training-partition** representative lines spanning real,
all synthetic tiers, amounts, mixed script, widths, and degradations. It must
enforce integer input/output, `TFLITE_BUILTINS_INT8`, and no float/Flex/custom
fallback. Float16 is the first viable CRNN milestone; int8 is not promised.

Every variant must pass the operator audit, exact 100-sample parity contract,
both packaged app runtimes, CER deltas, aggregate HTR asset size, and device
evidence. Quantization-aware training is not assumed as an LSTM rescue path.

Derive the hard receipt-batch line count as the greater of eight and p95 across
frozen V1 printed receipt fixtures plus generated receipt validation layouts.
The 1.5-second boundary covers HTR line detection, crop normalization/tiling,
all HTR inference calls, decoding, and reassembly for that page; it excludes the
existing first-pass Tesseract/ML Kit time. Report full routed page time
separately. After five warm-ups, p95 across at least 30 airplane-mode runs must
be at most 1.5 seconds. Also report cold interpreter load, p50, maximum,
delegate/threads, activation memory, and total process peak.

Proposed companion budgets are at most 128 MB incremental peak RSS for the HTR
path and at most 30 MB APK/IPA increase versus V1.

## Rejected first-baseline alternatives

- GraDeT-HTR-style decoder-only transformer: useful grapheme/synthesis evidence,
  but roughly 87M parameters and GPU/server deployment exceed mobile budgets.
- Word detector plus recognizer: adds detection, ordering, memory, and latency
  risk before a compact line baseline is measured.
- Noncommercial/ambiguous data in a public model: benchmark gains do not cure
  rights uncertainty.
- Synthetic-only acceptance: cannot satisfy writer-disjoint real P5 gates.
- Flex/custom ops or runtime model downloads: violate portability/offline rules.

## Approval record

Record exact answers in `DECISIONS.md`:

- architecture/runtime spike and TCN fallback;
- grapheme vocabulary, scalar ablation, decoder, and long-line policy;
- conditional BN-HTRd decision, BanglaLekha role, and restrictive exclusions;
- amount-preflight minimums and response if no eligible real slice exists;
- recursive artifact/synthesis policy and checkpoint-storage amendment;
- toolchain and metric/parity contract;
- shipped `ben+eng` comparator amendment and ben-only diagnostic;
- routing gates;
- aggregate size, memory, and latency rules;
- exact Android device/comparable rule; and
- exact physical-iOS runtime validation path.
