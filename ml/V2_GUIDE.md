# Rosid V2 guided runbook

## Current step

`[READY FOR TANZIR] P0 - approve the packet, choose the amount-gate posture,
and identify device paths.`

The decision packet, publisher-source research, proposed metric/lineage
verification contracts, CPU-only scaffolds, and dormant app routing seam are
ready for review. The public-corpus audit found no eligible real monetary
holdout; this is now an explicit owner decision rather than an open research
task. No dataset download or handwriting collection is requested at this step.

Reply with this completed template (plain text is sufficient):

```text
P0 packet (V2-005 through V2-013): APPROVE / CHANGES: ...
Amount gate (V2-009): A RETAIN AND BLOCK / B AMEND AND NO AMOUNT CLAIM
BN-HTRd rights posture: ACCEPT DOCUMENTED RISK / REQUIRE RIGHTS REVIEW
Android benchmark device: <model and Android version> / NONE AVAILABLE
Physical iOS runtime path: <device and iOS version> / NONE AVAILABLE
```

Choice A preserves the original amount-CER requirement but blocks V2 release
until a qualifying licensed corpus exists. Choice B keeps amount scoring only
as a supplemental diagnostic and prohibits a real handwritten-amount accuracy
claim. `research/AMOUNT_BENCHMARK.md` contains the evidence. A rights review is
the conservative BN-HTRd choice; accepting documented risk is an owner posture,
not a legal determination. Reporting `NONE AVAILABLE` records a real device
blocker without pretending the gate passed.

## Frozen V1 baseline

- Release tag: `v1.0.0`
- Release branch: `release/v1`
- Release commit: `602ca4eda36cf7895809c4d308665392aae80db2`
- Release: `https://github.com/tanzir-lameh/rosid/releases/tag/v1.0.0`
- Landing page: `https://tanzir-lameh.github.io/rosid/`
- The initial V2 kickoff commit changed documentation and branch CI only and
  passed the preservation command below. Subsequent P0 work intentionally added
  a disabled-by-default handwriting routing contract and tests; dependencies,
  native projects, model assets, and version still match V1.

## Guide states

- `[CODEX]`: Codex can continue without user action.
- `[READY FOR TANZIR]`: runnable code and exact human instructions are committed.
- `[WAITING ON TANZIR]`: a named artifact or explicit decision is the remaining
  dependency; Codex continues any independent work.
- `[VERIFIED]`: the returned decision/artifact passed its documented checks.

## Operating rules

1. Every human step includes exact commands, expected output, artifact name,
   checksum command, and destination path.
2. Tanzir is never asked to photograph, transcribe, or annotate handwriting.
3. Dataset downloads are explicit ML-development steps only. The mobile app
   never downloads a model or performs a network call.
4. No cloud experiment tracker, hidden upload, or runtime telemetry is allowed.
5. Generated artifacts are checked for provenance, checksum, shape, and smoke
   inference before the guide advances.
6. Real evaluation is writer-disjoint. Synthetic-only results cannot satisfy an
   accuracy claim or P5 acceptance gate.
7. License terms decide whether source samples, derived datasets, checkpoints,
   and weights may be stored or redistributed.
8. No architecture or performance claim reaches the app or landing page before
   the corresponding measured gate passes.

## P0 deliverables

Codex prepares these before requesting approval:

1. A source-by-source dataset/license/provenance matrix with authoritative URLs,
   writer metadata, versions, and checksums.
2. A decision packet covering architecture, grapheme tokenization, line image
   shape, CTC decoder, printed/handwritten routing, and fallback behavior.
3. An artifact policy for datasets, checkpoints, metrics, and exported models.
4. A researched compatible Python/training/TFLite version set.
5. After approval, a pinned CPU-smokeable Python project and lockfile. GPU
   training remains a later explicit guide step.

P0 defines the verification contract from publisher evidence. It does not prove
the contents of an undownloaded archive. P1 must audit the actual approved
archive bytes, safe extraction, exact regular-file inventory, dataset structure,
writer mapping, normalized-sample adapter, acquisition evidence, and global
split before any real-data lineage claim.

Current packet:

- `ml/P0_DECISION_PACKET.md`
- `ml/METRICS.md`
- `ml/ARTIFACT_POLICY.md`
- `ml/research/DATASETS.md`
- `ml/research/AMOUNT_BENCHMARK.md`
- `ml/DECISIONS.md`

If a source is approved and its archive is downloaded later, run the verifier
from the repository root through its supported module entry point:

```powershell
python -m ml.verify_dataset <source-manifest.json> <downloaded-archive>
```

This defaults to production-only and rejects conditional, research-only, and
excluded records. `--allow-nonproduction` may be used only when a later guide
step explicitly creates a quarantined research workspace; it never authorizes
production lineage.

Direct execution as `python ml/verify_dataset.py` is not a supported entry
point because the repository root must remain on Python's import path.

## Prepared P1 data-evidence tools

`[CODEX] Generic scaffold ready; real P1 evidence awaits P0 approval.`

The generic acquisition and one-global-split backbone is implemented and tested
without downloading a corpus. P1 data assembly is not complete. Do not perform
these steps until the approved source list and BN-HTRd rights posture are
recorded.

If approved for the stated role, candidate downloads go to these exact ignored
destinations:

| Source | Publisher page | Destination |
|---|---|---|
| BanglaLekha-Isolated V2 | <https://data.mendeley.com/datasets/hf6sf8zrkc/2> | `ml/data/raw/banglalekha-isolated/2/BanglaLekha-Isolated.zip` |
| BN-HTRd V4, initially only for an approved quarantined P1 audit | <https://data.mendeley.com/datasets/743k6dm543/4> | `ml/data/raw/bn-htrd/4/BN-HTR_Dataset.zip` |

If owner approval authorizes that source, download the named publisher file in
a browser, then verify the untouched bytes from the repository root. For
example:

```powershell
python -m ml.verify_dataset `
  ml/manifests/datasets/banglalekha_isolated_v2.json `
  ml/data/raw/banglalekha-isolated/2/BanglaLekha-Isolated.zip
```

The verifier always rejects `excluded` sources. `--allow-nonproduction` is only
for an explicitly quarantined conditional/research workspace and never upgrades
eligibility.

After a dataset-specific safe extractor and structure/writer-map audit has
created the ignored extracted directory, bind both snapshots without
overwriting any prior evidence:

```powershell
python -m ml.record_acquisition `
  <source-manifest.json> <verified-archive> <audited-extracted-directory> `
  --record-id <portable-record-id> `
  --acquired-at-utc <YYYY-MM-DDTHH:MM:SSZ> `
  --accepted-by <actor> `
  --terms-accepted `
  --extractor <exact-tool-and-version>
```

Add `--quarantined-research` for conditional/research-only evidence. The command
records an exact archive and extracted regular-file-set assertion; empty
directories are intentionally excluded. It deliberately does not extract an
untrusted archive or prove that the asserted directory is the correct
extraction, dataset structure, or writer map. Public source/acquisition JSON
goes under
`ml/manifests/acquisitions/`; the per-file inventory goes under the ignored
`ml/manifests/private/acquisitions/` tree or outside the repository. Keep an
encrypted backup outside the working copy.

The acquisition binds `extracted_dataset` transitively to `source_archive`
through canonical source evidence. A conditional BN-HTRd record never becomes
production evidence in place. If the rights posture and stable writer map are
later accepted, create a fresh amended production source manifest/source
evidence and a new production acquisition after those proofs are recorded.

The selected dataset-specific adapters are still pending. Each must produce one
private `AdapterEvidence` record per acquisition plus its normalized samples for
the single global sample inventory. The evidence must cover every normalized
sample's exact identity and derivations and classify every source file in the
bound extraction inventory as used or explicitly ignored with a reason. The
generic verifier proves that complete declared relationship. It cannot prove
that the dataset-specific transformation is semantically correct or that two
publisher writer IDs represent different people, so the adapter implementation
and cross-corpus `global_writer_group` audit still require review.

Each adapter must also produce an approved public `AdapterConfig` and a path-free
`PublicAdapterCommitment`. The commitment HMAC-binds the private evidence,
acquisition, inventory, config, combined code bundle, and aggregate coverage
counts without exposing paths, sample IDs, hashes, object keys, or writer groups.

The fixed `ml/APPROVAL_POLICY.json` is currently `pending`, so none of the split
commands below can produce qualifying evidence yet. Tanzir must first create an
Ed25519 signing key outside the repository, activate the policy with its
comment-free `ssh-ed25519` public key, public-key fingerprint, signer identity,
and generation, commit the policy, distribute and independently verify the
canonical policy SHA out of band, and record P0 approval. Never copy the owner
private key into the repository--including `ml/manifests/private/`--or pass it to
repository Python. This guide does not imply that Tanzir has approved a policy
or split.

After policy activation, prepare the exact code bundle and split config. Core
executable ML code is included automatically. Repeat only `--adapter-code-file`
for every adapter implementation file; missing, stale, extra, or mis-roled core
or adapter code fails exact-closure verification. Replace the illustrative
minimums with the approved release values:

```powershell
python -m ml.prepare_split_approval `
  --adapter-code-file <tracked-dataset-adapter.py> `
  --seed-id global-writers-v1 `
  --key-id split-hmac-v1 `
  --train-weight 8 `
  --validation-weight 1 `
  --test-weight 1 `
  --train-minimum-writers <approved-train-minimum> `
  --validation-minimum-writers <approved-validation-minimum> `
  --test-minimum-writers <approved-test-minimum> `
  --train-minimum-samples <approved-train-minimum> `
  --validation-minimum-samples <approved-validation-minimum> `
  --test-minimum-samples <approved-test-minimum> `
  --code-bundle-output ml/manifests/splits/global-split-v1.code-bundle.json `
  --config-output ml/manifests/splits/global-split-v1.config.json
```

The command accepts only tracked, `HEAD`-identical code. The retained
`splitter_code_sha256` config field commits to the full required core/adapter
code closure. Commit the active policy, generated config and bundle, approved
adapter configs, public adapter commitments, source manifests/evidence,
acquisition records, and all implementation files. This is commit A: the exact
public tree the approval will bind.

Create two different 32-byte split keys in an ignored directory or outside the
repository. These are the private deterministic-assignment and HMAC keys, not
the owner's external Ed25519 signing key:

```powershell
$seedKey = New-Object byte[] 32
$commitmentKey = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($seedKey)
  $rng.GetBytes($commitmentKey)
} finally {
  $rng.Dispose()
}
[IO.Directory]::CreateDirectory('ml/manifests/private') | Out-Null
[IO.File]::WriteAllBytes('ml/manifests/private/split-seed-v1.key', $seedKey)
[IO.File]::WriteAllBytes('ml/manifests/private/split-hmac-v1.key', $commitmentKey)
```

Generate the canonical request using the policy SHA obtained through the
out-of-band channel, not a hash trusted merely because it appears in local Git:

```powershell
python -m ml.request_split_approval `
  --approval-id global-split-v1 `
  --approved-by <policy-signer-identity> `
  --trusted-approval-policy-sha256 <out-of-band-policy-sha256> `
  --approved-config ml/manifests/splits/global-split-v1.config.json `
  --approved-code-bundle ml/manifests/splits/global-split-v1.code-bundle.json `
  --acquisition-record <acquisition.json> `
  --source-evidence <source.json> `
  --source-manifest <source-manifest.json> `
  --adapter-commitment <public-adapter-commitment.json> `
  --approved-adapter-config <approved-adapter-config.json> `
  --seed-key-file ml/manifests/private/split-seed-v1.key `
  --commitment-key-file ml/manifests/private/split-hmac-v1.key `
  --request-output ml/manifests/splits/global-split-v1.approval-request.json
```

The request binds the canonical repository origin and identity; production or
quarantined-research scope; commit A; every approved public file by exact path,
role, and SHA-256; config and full code closure; acquisitions and adapter
commitments/configs; policy generation/SHA; and domain-separated fingerprints
of the actual split keys. Commit the request before signing it. Add
`--quarantined-research` to the request only for explicitly approved
conditional/research evidence; this scope cannot qualify as production.

Tanzir then signs the committed request outside repository Python:

```powershell
ssh-keygen -Y sign `
  -f <owner-private-key-outside-repo> `
  -n rosid-v2-split-approval `
  ml/manifests/splits/global-split-v1.approval-request.json

Move-Item `
  -LiteralPath ml/manifests/splits/global-split-v1.approval-request.json.sig `
  -Destination ml/manifests/private/global-split-v1.approval-request.json.sig
```

OpenSSH normally writes `<request-path>.sig`. Before finalization, move that
detached SSHSIG outside Git or into the strict ignored private-manifest subtree
as shown. Finalization accepts the signature, never the owner private key:

```powershell
python -m ml.finalize_split_approval `
  --trusted-approval-policy-sha256 <out-of-band-policy-sha256> `
  --approval-request ml/manifests/splits/global-split-v1.approval-request.json `
  --detached-signature ml/manifests/private/global-split-v1.approval-request.json.sig `
  --approval-output ml/manifests/splits/global-split-v1.approval.json
```

Finalization verifies the OpenSSH signature, canonical origin, approved commit
ancestry, and exact commit-A file tree, then embeds the SSHSIG in a new canonical
public approval. Review and commit that approval before building the split.

```powershell
python -m ml.build_split_manifest `
  ml/manifests/private/global-samples-v1.jsonl `
  --acquisition-record <acquisition.json> `
  --source-evidence <source.json> `
  --source-manifest <source-manifest.json> `
  --directory-inventory <private-inventory.json> `
  --adapter-evidence <private-adapter-evidence.json> `
  --adapter-commitment <public-adapter-commitment.json> `
  --approved-adapter-config <approved-adapter-config.json> `
  --seed-key-file ml/manifests/private/split-seed-v1.key `
  --commitment-key-file ml/manifests/private/split-hmac-v1.key `
  --approved-config ml/manifests/splits/global-split-v1.config.json `
  --approved-code-bundle ml/manifests/splits/global-split-v1.code-bundle.json `
  --split-approval ml/manifests/splits/global-split-v1.approval.json `
  --trusted-approval-policy-sha256 <out-of-band-policy-sha256> `
  --private-output ml/manifests/private/global-split-v1.jsonl `
  --public-output ml/manifests/splits/global-split-v1.json
```

Build verifies public approval before trusting private evidence and verifies the
actual split keys against the signed fingerprints. It writes a schema V3 public
commitment without overwrite. That commitment binds the trusted policy SHA,
approval SHA and scope, key fingerprints, adapter commitments, config, counts,
and private HMAC. Review and commit the public output; the independent verifier
refuses it until it is tracked and byte-identical to `HEAD`. Then run:

```powershell
python -m ml.verify_split_manifest `
  ml/manifests/private/global-split-v1.jsonl `
  ml/manifests/splits/global-split-v1.json `
  --acquisition-record <acquisition.json> `
  --source-evidence <source.json> `
  --source-manifest <source-manifest.json> `
  --directory-inventory <private-inventory.json> `
  --adapter-evidence <private-adapter-evidence.json> `
  --adapter-commitment <public-adapter-commitment.json> `
  --approved-adapter-config <approved-adapter-config.json> `
  --seed-key-file ml/manifests/private/split-seed-v1.key `
  --commitment-key-file ml/manifests/private/split-hmac-v1.key `
  --approved-config ml/manifests/splits/global-split-v1.config.json `
  --approved-code-bundle ml/manifests/splits/global-split-v1.code-bundle.json `
  --split-approval ml/manifests/splits/global-split-v1.approval.json `
  --trusted-approval-policy-sha256 <out-of-band-policy-sha256>
```

Repeat the five public evidence flags once per selected source when requesting
approval: `--acquisition-record`, `--source-evidence`, `--source-manifest`,
`--adapter-commitment`, and `--approved-adapter-config`. Repeat all seven public
and private evidence flags once per selected source for build and verify: those
five plus `--directory-inventory` and `--adapter-evidence`. Add
`--quarantined-research` to build and verify only when the signed request uses
that scope. The build is global across all datasets; independently splitting
each corpus is not release evidence.

Build and verify derive seed/key IDs, weights, minimums, and the complete code
commitment from the committed approved config/bundle and reject caller-supplied
substitutes. Every public input and bundled code file must be tracked,
`HEAD`-identical, and canonical. Private inventories, adapter evidence, JSONL,
sample/reference hashes, writer groups, object keys, detached signature, and
both split keys remain ignored/untracked or outside the repository and require
an encrypted backup. The owner Ed25519 private key remains outside the repository
entirely.

Successful verification yields `VerifiedSplitEvidence`, not just a parsed
`PublicSplitCommitment`. Lineage requires that trusted-process marker and
exactly one
approval-policy parent, split-approval parent, config parent, complete-code
parent, and each external dataset parent, matching the public split SHA, policy
SHA, approval SHA, dataset IDs, acquisitions, config, and code commitments. Real
downloads, dataset-specific adapters/writer audits, owner policy activation and
P0 approval, production acquisitions, external request signing, and the real
global split remain pending.

The verification objects are constructor-gated markers inside a trusted Python
process, not a sandbox against arbitrary code already running in that
interpreter. The qualifying adversarial boundary is the fixed CLI flow above.
Lineage enforces the signed scope: `production` maps to production eligibility,
while `quarantined_research` maps to research-only approval and split nodes and
cannot support production metrics.

## First verification command

The kickoff preservation check was run from the repository root before app
source work began:

```powershell
git diff --exit-code v1.0.0 -- pubspec.yaml pubspec.lock lib android ios assets
```

Recorded result at kickoff: no output; exit code `0`. It is historical evidence,
not a current-tree expectation after the intentional dormant routing change.
