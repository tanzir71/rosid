# V2 artifact and provenance policy

Status: proposed for P0 approval. The conservative dataset eligibility rules
in `research/DATASETS.md` apply before this storage policy.

## Storage boundaries

| Artifact | Format | Location | Git / release policy |
|---|---|---|---|
| Source archives | Original publisher bytes | `ml/data/raw/<dataset>/<version>/` | Ignored; never committed or released |
| Extracted source data | Publisher layout, read-only | `ml/data/external/<dataset>/<version>/` | Ignored; never committed or released |
| Normalized samples | PNG/WebP plus local labels | `ml/data/interim/` | Ignored; reproducible and never released |
| Generated corpus | PNG/WebP plus local JSONL | `ml/data/processed/` | Ignored; regenerate from config/seed |
| Publisher source allowlist | Canonical JSON | `ml/manifests/datasets/` | Commit researched DOI/source/license/file metadata and hashes only |
| Dataset acquisition record | Canonical JSON | `ml/manifests/acquisitions/` | Commit timestamp/actor/accepted terms, allowlist hash, extraction-tool version, and deterministic inventory hash after download |
| Private split manifest | Canonical JSONL | `ml/manifests/private/` | Ignored; contains local object keys, raw content/reference hashes, and private writer mapping |
| Public split commitment | Canonical summary JSON | `ml/manifests/splits/` | Commit aggregate counts, algorithm/seed version, keyed-HMAC/Merkle commitment, and key ID only; never raw per-sample hashes or the key |
| Run configuration | TOML | `ml/configs/` | Commit |
| Training checkpoint | Keras `.keras` plus JSON manifest | `ml/checkpoints/` | Ignore binary; keep local or in an explicitly approved private artifact store only when source terms permit |
| Export baseline | SavedModel directory | `ml/artifacts/` | Ignore; reproducible intermediate |
| Candidate mobile model | `.tflite` plus JSON manifest | `ml/artifacts/` | Ignore until accepted; keep local or in an explicitly approved private artifact store |
| Selected mobile model | `.tflite` | `assets/models/` | Commit only after accuracy, parity, op, size, runtime, license, and privacy gates pass |
| Metrics | Canonical JSON plus generated Markdown summary | `ml/reports/runs/<run-id>/` | Commit aggregate results, configs, environment, and hashes; no samples |
| Logs | UTF-8 text/JSONL | `ml/reports/runs/<run-id>/` | Commit compact final logs only; strip machine paths and source text |

Large File Storage is not a substitute for permission. No raw, derived, or
learned binary enters Git LFS merely because it is large.

## Canonical manifests

All JSON is UTF-8, NFC-normalized where it contains labels, sorted by key,
indented by two spaces, LF-only, and terminated by one newline. The tested
`canonical_json_bytes` implementation is the only serialization whose hash may
enter lineage; `.gitattributes` pins JSON/JSONL/TOML checkout line endings.
Hashes are lowercase SHA-256 hex. Publisher allowlists use `schema_version: 1`;
derived source-evidence and acquisition records use `schema_version: 2`; the
evidence-bound lineage graph uses `schema_version: 2`. Unknown versions fail
closed.

The committed `schema_version: 1` records in `ml/manifests/datasets/` are source
allowlists, not claims that a file was downloaded, terms accepted, or archive
structure verified. They contain structured DOI/source, publisher version,
license/eligibility, attribution/rights notes, filename, bytes, and SHA-256.

Post-download acquisition records contain:

- the canonical reviewed source-evidence commitment, exact downloaded-source
  SHA-256, exact extracted-artifact SHA-256, and deterministic inventory hash;
- acquisition UTC timestamp in the sole `YYYY-MM-DDTHH:MM:SSZ` spelling,
  terms-acceptance actor, and acceptance boolean;
- extraction tool/version;
- eligibility state: `production`, `conditional`, `research_only`, or
  `excluded`. Dataset ID, DOI, publisher-manifest commitment, source, version,
  license, attribution, rights notes, and the reviewed external artifact
  type/role are inherited through the bound source-evidence record.

The acquisition commitment binds the reviewed source-evidence commitment,
exact downloaded-content and extracted-artifact hashes, deterministic inventory
hash, UTC timestamp, terms-acceptance actor/boolean, extractor identity, and
eligibility. An
acquisition may downgrade source eligibility but cannot upgrade it. A
production lineage node must match both canonical commitments; caller-supplied
eligibility alone has no authority.

Private split JSONL records contain:

- stable opaque sample ID, dataset/version, **global** pseudonymous writer-group
  ID, split,
  transformed image-content SHA-256, NFC scorer-reference SHA-256, dimensions,
  and token count;
- a relative local object key, never an absolute workstation path; and
- no demographic attributes or label text. Labels remain in the ignored local
  data store and are joined by opaque ID.

Those per-sample hashes are linkable to public source images, and short/common
labels are dictionary-recoverable, so the private JSONL is never committed.
Public evidence contains only aggregate counts and a keyed HMAC/Merkle
commitment. The random key and opaque-ID mapping remain outside Git; the public
record stores a non-secret random key identifier. Run manifests bind that
commitment, not raw sample/reference hashes.

A writer-group ID is global across all selected corpora, not scoped to one
dataset. Known shared people use the same group; unresolved cross-corpus
identity is conservatively linked or documented as a release-evidence gap.
Release validation rejects empty train/validation/test partitions even though
the lower-level research splitter permits custom ratios. Validation/test sample
minimums count unique exact image content; repeated image bytes inside either
holdout are rejected rather than allowed to inflate its size or writer counts.

An external `dataset` lineage node represents the evidence-bound source archive
and therefore has no train/validation/test label. A derived `split_manifest`
binds that archive plus exact splitter code/config; derived `data_partition`
nodes bind the split commitment and carry the only real-data partition labels.
Evaluation sets must directly bind matching partition nodes, and a sealed test
evaluation must use real `data_partition` input rather than generated data.
Every real partition ancestor of final release metrics must bind the same global
`split_manifest`; independently seeded train/test manifests cannot be combined
into release evidence.

Run manifests bind a result to:

- a clean Git commit; dirty or uncommitted qualifying runs are rejected;
- Python and locked dependency versions, platform, seed, determinism flags,
  training/config hashes, dataset/split manifest hashes, and vocabulary hash;
- architecture identifier and parameter count;
- checkpoint, exported model, and TFLite hashes;
- aggregate CER/WER, amount CER, per-dataset values, confidence calibration,
  TFLite parity, op audit, file size, and device latency evidence.

## Recursive dependency lineage

Every artifact that can influence learned weights is a node in a canonical
dependency DAG, not merely a dataset row. Node types include:

- real source archives, split commitments, partition manifests, and annotations;
- fonts and their exact license files;
- paper/receipt textures and photographic backgrounds;
- receipt vocabulary, brand/item lists, date/currency templates, and any source
  text corpus;
- code commits, container/lockfile hashes, configs, seeds, and preprocessing
  golden-vector hashes;
- pretrained weights, character encoders, learned-generator inputs/checkpoints,
  and generated corpus manifests; and
- HTR checkpoints, conversion representatives, vocabularies, model contracts,
  and final exports.

Each node records content hash, source/version, license/eligibility, role,
transformation, evidence commitments, synthesis tier where applicable, and
parents. External datasets/fonts/textures/text corpora/pretrained weights must
match reviewed canonical source and acquisition records, including the reviewed
artifact type/role and exact extracted bytes. Derived nodes cannot
claim those external commitments. Production eligibility is transitive: a
more restrictive ancestor forces an equally restrictive descendant. A
generator cannot launder restrictive source data into a public HTR model.

Completeness is type-specific and enforced for every asserted artifact, not
only the final model. Tier 1 requires font, texture, text, code, and config
lineage; Tier 2 requires procedural code/config/text plus a style source; only
Tier 3 requires a fully trained generator checkpoint. Model/generator
checkpoints, vocabularies, contracts, representative sets, evaluation sets,
prediction streams, and final metrics have their own required direct inputs and
roles/partitions. Training artifacts cannot borrow unrelated transitive
ancestors as their data/code/config evidence. A mobile model binds one explicit
conversion export; that export directly binds the training checkpoint plus
converter code/config, and an int8 export also binds a training-partition
representative set.

Final metric lineage directly binds scorer code/config, the exact mobile model,
one real sealed-test evaluation set, raw-HTR predictions, and Tesseract baseline
predictions. The baseline prediction node also binds the exact `ben` and `eng`
traineddata artifacts and inference code/config; both prediction streams bind
the same evaluation artifact.
Only `validation` and `final` metric roles are valid. Test-partition evidence is
accepted only for `final`, and the release assertion rejects any other artifact
role even when its transitive inputs are production-eligible.

Training lineage and evaluation lineage are separate. Test nodes may be parents
of final metrics only, never of a vocabulary, generator, representative set,
threshold, decoder, checkpoint, or model-selection node. Private writer mapping
uses random opaque IDs or keyed HMAC with the key outside Git; unsalted/salted
hashes of low-entropy form serials are forbidden.

For Tier-3 synthesis, record the generator checkpoint and its real-writer
partition. Exact-image/content hashes must have zero overlap with validation or
test. Perceptual nearest-neighbor and transcription-memorization audits are
required before generated samples become production-eligible.

## Synthetic-corpus acceptance

A production curriculum/model-selection run cannot consume a synthetic corpus
until its manifest proves:

1. at least 500,000 generated lines with deterministic config/seed lineage;
2. all three required tiers are present, Tier 1 is at most 40%, and Tier 2 is
   the procedural core rather than a token sample;
3. every P1a failure point and required confusion-pair slice has nonzero,
   machine-counted coverage;
4. real-vs-synthetic discriminator AUC is at most 0.85 for every tier and for
   the combined mix, evaluated without writer leakage;
5. a quarantined generator-probe HTR trained only to evaluate that candidate
   corpus has synthetic-only CER on real validation writers that trends down
   relative to the previously accepted generator version; and
6. app and Python preprocessing match cross-language golden input/output byte
   hashes. A version string alone is insufficient.

These gates are evaluated on validation partitions. The sealed final test is
not opened to tune synthesis. A generator-probe run may consume a not-yet-
accepted corpus solely to produce gate evidence; its checkpoint is ineligible
for production and cannot seed the production recognizer.

## Release gate for a bundled model

The `.tflite` file may move into `assets/models/` only when one manifest proves
all of the following:

1. every transitive influencing input is production-eligible and attributed;
2. the real holdout is writer-disjoint and its manifest has no leakage;
3. the exact raw-model metric contract in `METRICS.md` proves Bangla handwriting
   CER is at most 25% and relative CER improves at least 30% over Tesseract on
   identical samples; if V2-009 records Choice A, real amounts-only CER must
   also be at most 12%, while Choice B instead requires provenance-bound
   supplemental amount diagnostics and prohibits a real-amount accuracy claim;
4. trained-model versus TFLite comparison passes all 100 frozen samples and
   numeric tolerances in `METRICS.md`;
5. the model contains no `WHILE`, Flex, or custom ops and loads in the bundled
   Android and iOS runtimes;
6. total bundled HTR model, vocabulary, classifier, and contract bytes are at
   most exactly 20,000,000 bytes (decimal 20 MB), as shared by
   `ml/rosid_ml/limits.py`, and the agreed 2022 mid-range device benchmark is at
   most 1.5 seconds per receipt batch;
7. no sample, label, path, demographic field, training secret, or network
   endpoint is embedded in the FlatBuffer; and
8. the asset SHA-256, vocabulary SHA-256, preprocessing golden hash, input and
   output shapes/dtypes/scales/zero points, and license notice are committed
   together;
9. the mandatory synthetic-corpus gates above pass; and
10. raw HTR and routed-output results plus the routing confusion matrix pass
    their separately frozen gates;
11. incremental HTR-path peak RSS is at most 128 MB; and
12. both APK and IPA grow by at most 30 MB relative to the frozen V1 artifacts.

No metric is inferred from a filename or handwritten report. Verification code
must parse the machine-readable manifest and independently hash every binary.
Each at-most-20,000,000-byte model/companion is read once into an immutable
snapshot for byte count, structure, privacy, and hash checks; reports emit only
portable logical asset IDs, never caller/workstation paths.
The audit permits a lower temporary byte limit but never a value above the hard
20,000,000-byte ceiling. Privacy scanning normalizes common nested JSON escapes
before checking network endpoints and workstation-profile paths.
