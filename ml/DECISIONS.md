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
| V2-005 | Proposed | 2026-07-18 | Start with a line-level CRNN + CTC, <= about 5M parameters, using a grapheme-aware Bangla charset; retain a compact transformer fallback only if measured gates plateau. | P0 architecture/tokenization decision packet and Tanzir approval required. |
| V2-006 | Research required | 2026-07-18 | Candidate real datasets include BN-HTRd, BanglaWriting, Ekush, and BanglaLekha-Isolated. | Verify authoritative source, current license, redistribution rights, writer metadata, version, and checksum before use. |
| V2-007 | Pending | 2026-07-18 | Storage policy for datasets, checkpoints, best weights, exported models, and metrics. | Decide Git/LFS/Release/external boundaries from licenses and artifact sizes. |
| V2-008 | Pending | 2026-07-18 | Exact Python, training framework, conversion, and TFLite versions. | Research a compatible reproducible toolchain before adding pins or a lockfile. |

## Decision protocol

1. Codex prepares a concise packet with options, evidence, tradeoffs, and a
   recommendation.
2. Tanzir approves or changes the recommendation.
3. The row is updated to `Accepted`, including the decision date and evidence.
4. Code depending on that decision may then be committed.
