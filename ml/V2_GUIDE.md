# Rosid V2 guided runbook

## Current step

`[CODEX] P0 - architecture, dataset-license, and artifact-policy research.`

No action is currently required from Tanzir. Codex must research the candidate
datasets and compatible toolchain, then commit the decision packet and runnable
code before marking any human step `[READY FOR TANZIR]` or
`[WAITING ON TANZIR]`.

## Frozen V1 baseline

- Release tag: `v1.0.0`
- Release branch: `release/v1`
- Release commit: `602ca4eda36cf7895809c4d308665392aae80db2`
- Release: `https://github.com/tanzir-lameh/rosid/releases/tag/v1.0.0`
- Landing page: `https://tanzir-lameh.github.io/rosid/`
- V2 kickoff changed documentation and branch CI only. `pubspec`, dependencies,
  mobile source, native projects, and bundled assets match the V1 tag.

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

## First verification command

From the repository root, V2 must initially preserve all mobile behavior:

```powershell
git diff --exit-code v1.0.0 -- pubspec.yaml pubspec.lock lib android ios assets
```

Expected output: none; exit code `0`.
