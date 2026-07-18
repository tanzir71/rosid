# Rosid V2 guided runbook

## Current step

`[READY FOR TANZIR] P0 - approve the packet, choose the amount-gate posture,
and identify device paths.`

The decision packet, dataset evidence, metric/lineage contracts, CPU tests,
and dormant app routing seam are complete. The public-corpus audit found no
eligible real monetary holdout; this is now an explicit owner decision rather
than an open research task. No dataset download or handwriting collection is
requested at this step.

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

Current packet:

- `ml/P0_DECISION_PACKET.md`
- `ml/METRICS.md`
- `ml/ARTIFACT_POLICY.md`
- `ml/research/DATASETS.md`
- `ml/research/AMOUNT_BENCHMARK.md`
- `ml/DECISIONS.md`

When an approved archive is downloaded later, run the verifier from the
repository root through its supported module entry point:

```powershell
python -m ml.verify_dataset <source-manifest.json> <downloaded-archive>
```

This defaults to production-only and rejects conditional, research-only, and
excluded records. `--allow-nonproduction` may be used only when a later guide
step explicitly creates a quarantined research workspace; it never authorizes
production lineage.

Direct execution as `python ml/verify_dataset.py` is not a supported entry
point because the repository root must remain on Python's import path.

## First verification command

The kickoff preservation check was run from the repository root before app
source work began:

```powershell
git diff --exit-code v1.0.0 -- pubspec.yaml pubspec.lock lib android ios assets
```

Recorded result at kickoff: no output; exit code `0`. It is historical evidence,
not a current-tree expectation after the intentional dormant routing change.
