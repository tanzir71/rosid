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
| Private extraction inventory | Canonical JSON | `ml/manifests/private/acquisitions/` or outside the repository | Ignored or out of repository; contains extracted-tree-relative paths and per-file hashes; keep an encrypted backup |
| Private adapter evidence | Canonical JSON | `ml/manifests/private/adapters/` or outside the repository | Ignored or out of repository; contains exact source paths, normalized-output identities, hashes, writer groups, and derivations; keep an encrypted backup |
| Public adapter config and commitment | Canonical JSON | `ml/manifests/adapters/` | Commit the approved config and path-free HMAC commitment binding its acquisition, inventory, combined code bundle, and aggregate coverage counts |
| Private split manifest | Canonical JSONL | `ml/manifests/private/` or outside the repository | Ignored or out of repository; contains local object keys, raw content/reference hashes, and private writer mapping; keep an encrypted backup |
| Split seed/HMAC keys | Random binary | `ml/manifests/private/` or outside the repository | Ignored or out of repository; never print or commit; keep an encrypted backup separate from the working copy |
| Owner split-approval policy | Canonical JSON | fixed `ml/APPROVAL_POLICY.json` | Commit the active Ed25519 public key, signer identity, and generation; distribute and independently verify its canonical SHA out of band. `pending` or `revoked` fails closed |
| Owner approval private key | External Ed25519 private key | Outside the repository | Never passed to repository Python, copied into the private-manifest subtree, committed, or released; owner uses `ssh-keygen -Y sign` externally |
| Approved split config and complete code bundle | Canonical JSON | `ml/manifests/splits/` | Commit and review before approval; preparation follows the fixed P1 entrypoints through their complete static local-import graph and requires every Python source under the fixed adapter subtree to be listed explicitly |
| Split approval request and approval | Canonical JSON | `ml/manifests/splits/` | Commit the request before external signing, then commit the finalized approval containing the verified SSHSIG; both are immutable public evidence |
| Detached approval signature | OpenSSH SSHSIG | Outside Git or strict `ml/manifests/private/` subtree | Temporary private input to finalization; never tracked. The verified signature is embedded as base64 in the public canonical approval |
| Public split commitment | Canonical summary JSON | `ml/manifests/splits/` | Commit schema V3 binding the trusted policy SHA, external approval SHA/scope, domain-separated split-key fingerprints, exact adapter commitments, config/counts, and private HMAC; never raw per-sample hashes or either key |
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
indented by two spaces, LF-only, and terminated by one newline. JSONL uses one
compact, sorted, NFC-normalized object plus one LF per record. The tested
`canonical_json_bytes` and `canonical_json_line_bytes` implementations are the
only serializers whose bytes may enter lineage or a keyed commitment;
`.gitattributes` pins JSON/JSONL/TOML checkout line endings. Hashes are lowercase
SHA-256 hex. Publisher allowlists and private directory inventories use
`schema_version: 1`; derived source evidence uses `schema_version: 2`;
acquisition records use `schema_version: 3` because they separately label
downloaded and extracted artifacts. Private adapter evidence, public adapter
commitments, combined code-bundle manifests, normalized sample records, private
split records, `ApprovalPolicy`, `SplitApprovalRequest`, and `SplitApproval` use
`schema_version: 1`; adapter configs, `SplitConfig`, and the evidence-bound
lineage graph use `schema_version: 2`; `PublicSplitCommitment` uses
`schema_version: 3`. Unknown versions fail closed.

The committed `schema_version: 1` records in `ml/manifests/datasets/` are source
allowlists, not claims that a file was downloaded, terms accepted, or archive
structure verified. They contain structured DOI/source, publisher version,
license/eligibility, attribution/rights notes, filename, bytes, and SHA-256.

Post-download acquisition records contain:

- the canonical reviewed source-evidence commitment, exact downloaded-source
  SHA-256, exact extracted-artifact SHA-256, and deterministic inventory hash;
- the extracted artifact type and role (`dataset` / `extracted_dataset` for a
  dataset directory snapshot), distinct from the reviewed publisher archive's
  `dataset` / `source_archive` role;
- acquisition UTC timestamp in the sole `YYYY-MM-DDTHH:MM:SSZ` spelling,
  terms-acceptance actor, and acceptance boolean;
- extraction tool/version;
- eligibility state: `production`, `conditional`, `research_only`, or
  `excluded`. Dataset ID, DOI, publisher-manifest commitment, source, version,
  license, attribution, rights notes, and the reviewed external artifact
  type/role are inherited through the bound source-evidence record.

The downloaded-content hash is the exact publisher archive. The extracted
artifact hash is domain-separated and length-frames each canonical relative
path, file size, and exact file bytes in UTF-8 path order. The inventory hash is
the SHA-256 of canonical JSON containing those paths, sizes, and per-file
hashes. These commitments cover the exact regular-file set and bytes; empty
directories are intentionally not represented. Both reject links, special
files, nonportable paths, NFC/case-fold collisions, and a regular-file set that
changes while it is being read. This proves the two recorded snapshots, not
that the asserted directory was correctly derived from the archive.
`ml.extract_dataset` supplies a guarded generic ZIP extraction boundary and then
inventories/reverifies its result. It does not validate dataset schema, labels,
writer identity, or cross-corpus identity. Its stdout is operational output,
not a canonical manifest or an attestation of the exact code that executed.
Production evidence still requires an approved exact extractor/code identity,
canonical acquisition evidence, and dataset-specific structure and writer-map
validation during P1.

The acquisition commitment binds the reviewed source-evidence commitment,
exact downloaded-content and extracted-artifact hashes, extracted type/role,
deterministic inventory hash, UTC timestamp, terms-acceptance actor/boolean,
extractor identity, and eligibility. An
acquisition may downgrade source eligibility but cannot upgrade it. A
production lineage node must match both canonical commitments; caller-supplied
eligibility alone has no authority.

For a dataset, the acquisition records a `source_archive` to
`extracted_dataset` transition. The extracted snapshot is transitively bound to
the reviewed publisher archive through its source-evidence commitment, which in
turn is derived from the canonical `DatasetSource` allowlist. If BN-HTRd later
clears its rights and stable-writer-map gates, the conditional source manifest,
source evidence, and acquisition remain conditional and immutable. Production
use requires an amended production source manifest/source-evidence record and a
fresh production acquisition after those proofs are recorded.

Private adapter evidence contains the exact dataset/version, acquisition and
directory-inventory commitments, combined code-bundle commitment, canonical
adapter config and its hash, every source-file record, every normalized output,
and each output's source derivations. A normalized output records the same exact
sample ID, global writer group, object key, image/reference SHA-256 values,
dimensions, token count, dataset/version, and acquisition as the private global
sample inventory.

Verification requires exact normalized-sample coverage: no missing or extra
outputs, and no differing identity field. Every derivation path/hash must exist
in the bound extraction inventory. Every inventoried source file must appear
exactly once as either used or explicitly ignored with a nonempty reason; the
sets cannot overlap. This proves the complete declared byte-level derivation and
identity relationship. It cannot prove that a dataset-specific transformation
is semantically correct or that publisher writer IDs represent distinct human
beings; the real adapter implementations and writer-map audit remain P1 work.

`PublicAdapterCommitment` schema V1 is path-free. It contains the
dataset/version, acquisition and inventory commitments, combined code-bundle
commitment, exact adapter config and hash, source/output/used/ignored counts,
and a domain-separated HMAC-SHA256 over the canonical private adapter evidence.
It contains no source paths, sample IDs, object keys, image/reference hashes, or
writer groups. Only exact private reverification in the fixed CLI yields the
constructor-gated `VerifiedAdapterEvidence` trusted-process marker accepted by
split verification.

These Python verification markers prevent ordinary accidental use of parsed
public data as verified evidence; they are not a sandbox against arbitrary code
already executing inside the same Python interpreter. The adversarial security
boundary is the fixed request/finalize/build/verify CLI flow in a trusted clean
process, which repeats the policy, SSHSIG, approved-tree, private-key, adapter,
and split checks. Direct library callers are trusted and cannot substitute for
that qualifying CLI flow.

Private split JSONL records contain:

- stable opaque sample ID, dataset/version, exact acquisition commitment,
  **global** pseudonymous writer-group ID, split, transformed image-content
  SHA-256, NFC scorer-reference SHA-256, dimensions, and token count;
- a relative local object key, never an absolute workstation path; and
- no demographic attributes or label text. Labels remain in the ignored local
  data store and are joined by opaque ID.

Those per-sample hashes are linkable to public source images, and short/common
labels are dictionary-recoverable, so the private JSONL is never committed.
`PublicSplitCommitment` schema V3 contains the canonical `SplitConfig`; exact
sorted dataset IDs, source-acquisition commitments, and public-adapter
commitments; the canonical approval-policy SHA pinned out of band; the external
split-approval SHA and production/quarantined-research scope; domain-separated
SHA-256 fingerprints of the actual seed and commitment keys; aggregate
sample/writer/unique-image counts; and a domain-separated HMAC-SHA256 over the
canonical config and exact private split bytes. The fingerprints identify held
keys without revealing them. The split-seed key, separate HMAC key, and
opaque-ID mapping remain in an ignored private location or outside the
repository; neither key is printed or committed. Private manifests and both
keys require an encrypted backup outside the working copy. Run manifests bind
the public commitment, not raw sample/reference hashes.

The fixed `ml/APPROVAL_POLICY.json` is the public root for split-approval
authority. Its current `pending` status authorizes no qualifying production or
quarantined-research split. Tanzir must create an Ed25519 signing key outside the
repository, activate the policy with the comment-free public key, fingerprint,
signer identity, and generation, commit that canonical policy, distribute and
independently verify its canonical SHA out of band, and record P0 approval.
Request, finalize, build, and verify require that separately trusted SHA;
trusting only the policy found in the local Git tree is insufficient. The owner
private signing key never enters the repository or any repository Python
process.

`prepare_split_approval` starts from the fixed P1 CLI entrypoint/role table and
every explicitly configured adapter source, then recursively includes each
statically imported local module and executable package initializer. The
reviewed core-role table must equal that discovered graph exactly: a reachable
unreviewed file and a reviewed but unreachable stale file both fail. Future P2
training/export code that is not reachable from P1 remains outside this bundle,
while every Python file below `ml/rosid_ml/adapters/` must be attributed
explicitly. Star imports, recognized dynamic import/execution paths,
unresolvable or ambiguous modules, import-name normalization/case collisions,
native/bytecode-only loaders, links, and nonportable sources fail closed.

Discovery requires a complete materialized checkout. The full stage-0 index
must match `HEAD` by path, regular mode (`100644` or `100755`), and object ID;
skip-worktree, assume-unchanged, sparse, unmerged, staged, symlink (`120000`),
submodule (`160000`), and case/NFKC-aliased path states are rejected. The
retained `SplitConfig.splitter_code_sha256` field commits to the entire
resulting closure, not splitter code alone. Commit the policy, bundle, config,
source manifests/evidence, acquisitions, public adapter commitments/configs,
and all bound implementation files as commit A before requesting approval.
Future adapter execution must import these files under the same canonical
repository-qualified module names and repository-root semantics used during
analysis; arbitrary direct-path or `spec_from_file_location` identities are not
part of the approved import contract.

`request_split_approval` verifies the out-of-band policy SHA, canonical
repository origin, stable commit A, canonical public relationships, full code
closure, and the actual private seed/commitment-key fingerprints. Its canonical
request binds the exact approved files at commit A by path, role, and SHA-256;
the approved commit; repository identity; production or
`quarantined_research` scope; policy generation/SHA; config, code, acquisition,
adapter-config, and adapter-commitment hashes; and both key fingerprints. Commit
the request before the owner externally runs `ssh-keygen -Y sign` with namespace
`rosid-v2-split-approval`. Keep the detached SSHSIG outside Git or in the strict
ignored private-manifest subtree. `finalize_split_approval` accepts the request,
detached signature, and separately trusted policy SHA. It never accepts the
owner private key. It verifies the SSHSIG, canonical origin, approved commit
ancestry, and exact approved tree before emitting a canonical public approval to
commit.

Build and verify require the committed policy and split approval plus the same
out-of-band policy SHA. Public approval verification runs before private split
inputs are trusted; private verification then checks the actual seed and HMAC
keys against the approved fingerprints and reverifies the canonical
source/acquisition/inventory/adapter relationships, assignment, minimums,
leakage, and HMACs. The builder does not rehash a live extracted directory.
Every public input and bundled file must be tracked, use Git mode `100644` or
`100755`, exist in `HEAD`, and be byte-identical to `HEAD` in the index and
worktree. Historical approved-commit verification repeats the regular-mode
check, so a symlink materialized as target-text on one platform cannot become
executable linked content on another. Private inventories, adapter
evidence, sample/split manifests, detached signatures, and split keys inside the
repository must be untracked and ignored, or may be outside the repository.

The import graph is a source-commitment proof, not a Python sandbox. Qualifying
execution therefore also requires the documented trusted clean process and,
once P2 dependencies exist, the approved pinned runtime/container with no
attacker-controlled import path, hooks, or bytecode cache. Code already able to
execute inside that interpreter is outside what a source manifest can contain.

Possession of either split key proves consistency with held private bytes, not
approval. A valid split approval authorizes only its exact commit-A files,
scope, code closure, and key fingerprints; it does not prove semantic adapter
correctness or writer identity. The policy remains pending and no approval has
been signed. Qualifying production evidence still requires recorded P0 approval
and the real dataset-specific adapter, writer, acquisition, and split audits.

A writer-group ID is global across all selected corpora, not scoped to one
dataset. Known shared people use the same group; unresolved cross-corpus
identity is conservatively linked or documented as a release-evidence gap.
Release validation rejects empty train/validation/test partitions even though
the lower-level research splitter permits custom ratios. Validation/test sample
minimums count unique exact image content; repeated image bytes inside either
holdout are rejected rather than allowed to inflate its size or writer counts.

Under the required lineage contract, an external `dataset` node represents the
evidence-bound extracted dataset regular-file snapshot and therefore has no
train/validation/test label. Its acquisition transitively binds the exact
reviewed publisher archive. Successful exact private reverification in the
fixed CLI returns the constructor-gated `VerifiedSplitEvidence` trusted-process
marker; lineage rejects a bare `PublicSplitCommitment`. A derived
`split_manifest` must bind that
verified public commitment and have exactly one config parent, one combined
code-bundle parent, one approval-policy parent, one split-approval parent, and
the exact external dataset parents. The lineage validator matches the split node
SHA, exact dataset IDs and acquisitions, canonical config and full code-bundle
commitments, out-of-band-pinned policy SHA, and external approval SHA. Derived
`data_partition` nodes bind the split commitment and carry the only real-data
partition labels. Generating the records still is not qualifying production
evidence while the policy is pending and before Tanzir records P0 approval,
externally signs the exact request, and approves the real adapters/writer audit,
acquisitions, and sealed global split.
Lineage also maps signed `production` scope to `production` eligibility and
signed `quarantined_research` scope to `research_only` eligibility on both the
approval and split nodes. A quarantined approval therefore cannot be relabeled
as production evidence downstream.
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
uses random opaque IDs or keyed HMAC with the key in an ignored private location
or outside the repository and backed up encrypted; unsalted/salted hashes of
low-entropy form serials are forbidden.

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

The tracked `test/fixtures/v2_preprocessing/app_reference_v1.json` and its
digest are a non-qualifying app-side precursor to item 6. Recomputing that
manifest in Dart, checking its canonical form in Python, and binding the public
fixture sources prove only app-reference stability and manifest integrity.
Item 6 remains unmet until an independently implemented, approved Python path
recomputes matching source and result plane hashes. Before any synthetic corpus
or trained artifact becomes production-eligible, lineage verification must
also require the exact golden-manifest SHA plus both app and Python
implementation/config commitments; the current lineage schema does not yet
enforce that preprocessing-golden parent.

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

`tool/audit_v2_model.py` implements only this bundle's structural precursor: it
binds stable unlinked regular-file snapshots to portable logical asset IDs,
checks exact bytes and SHA-256 values, enforces the aggregate byte ceiling, and
scans for prohibited path/network markers and physical aliases. A
`"structural_only": true` result does **not** prove operator/tensor/quantization
contracts, interpreter loadability, trained-model parity, accuracy, routing, or
device latency/memory behavior. Those remain P3-P5 gates.

The generic ZIP extractor and structural model auditor assume a trusted clean
filesystem with no hostile concurrent mutation of their source, parent, or
destination namespaces. Their repeated snapshots detect ordinary drift; neither
tool is a descriptor-relative hostile-filesystem sandbox.
