# V2 real-amount benchmark audit

Research date: 2026-07-18. Status: public-corpus search complete; owner
decision required.

## Conclusion

No public corpus found can honestly satisfy Rosid's proposed real,
writer-disjoint Bangla monetary-line gate. BN-HTRd V4 has too few
currency-plus-digit lines, too few represented writers, no strict amount-only
lines, and unreliable numeric transcription in part of the archive. Bayanno V2
and PromitoLipi V2 do not provide the required line annotations and writer
identity.

Synthetic amounts remain useful for training and diagnostics, but they cannot
substitute for real P5 evidence. Rosid must either retain the gate and block V2
release until an eligible corpus is obtained, or explicitly remove the amount
CER release gate and make no real-amount accuracy claim.

## Acceptance preflight

The P0 proposal requires at least 20 sealed-test writers, 100 annotated or
currency-unambiguous real line/field crops, and 1,000 normalized digit/`৳`
reference units. Dates, phone numbers, page numbers, quantities, arbitrary
numeric prose, isolated characters, and synthetic lines do not qualify.

## BN-HTRd V4 audit

- Official record: <https://data.mendeley.com/datasets/743k6dm543/4>
- DOI: `10.17632/743k6dm543.4`
- Catalog license: CC BY 4.0, with the BBC-source-text caveat recorded in
  `DATASETS.md`.
- Published scope: 150 writers, 786 pages, and 14,383 lines.

Pinned official files:

| File | Bytes | SHA-256 |
|---|---:|---|
| `BN-HTR_Dataset.zip` | 2,608,394,039 | `9ccb7e3e8ebfadc7b57d250496e12be59e1910b4759d150a909f1bffcef2a72e` |
| `Automatic_Annotation.zip` | 1,847,761,410 | `dcb5a6760cc438aea4f84ad343cd44ce485c410f2d4c1851b5805aeebf11a7fc` |
| `Sample_Small.zip` | 76,099,297 | `88afc8ce102a90b3d93c612de68c10b351faa788f2c330c8a8c7a882de8a115c` |
| `Structure_of_Directory.pdf` | 41,039 | `bafbfa75065e95b4f5fb917e5078c0ac3aa3da5fae5a24a1ca2d55ca7f21139f` |

The research audit read the official V4 snapshot/file APIs, followed the main
archive's official redirect with HTTP byte ranges, and inspected all 150 XLSX
ground-truth workbooks without downloading the 2.6 GB archive. XLSX OOXML was
parsed directly because several invalid workbook styles are rejected by
`openpyxl`. Word IDs were grouped into lines after dropping the final word
component.

Reconstructed-label results:

| Measure | Result |
|---|---:|
| Usable word-label rows | 107,790 |
| Reconstructed line groups | 14,290 |
| Malformed word IDs | 5 |
| Lines containing digits | 1,674 |
| Lines containing ASCII digits | 1,402 |
| Lines containing Bengali digits | 332 |
| Lines containing `টাকা` or an inflected form | 138 |
| Lines containing both digits and a currency word | 37 |
| Writers represented by those 37 lines | 12 |
| Strict amount-only lines | 0 |
| Lines containing the `৳` symbol | 0 |

The 37 currency-plus-digit lines are concentrated in writers 6 (11 lines), 14
and 100 (5 each), 4 (4), 79 (3), 21 and 145 (2 each), and 5, 18, 46, 83, and
108 (1 each). This cannot form the proposed 20-writer holdout.

Numeric labels also need repair before CER scoring. Some Bengali-digit cells
were stored as Excel numbers and exposed through OOXML as ASCII values,
occasionally with an added `.0`. Visual inspection of `4_1_13.jpg`, for
example, showed Bengali digits while the reconstructed XLSX label began with
ASCII `63`. Those labels cannot be treated as trusted numeric ground truth.

The remote directory layout is evidence that writer grouping probably exists,
but a production run must still verify the complete locally downloaded archive
and persist a machine-generated writer-map report before sealing splits.

## Bayanno V2

- Official record: <https://data.mendeley.com/datasets/jtpfd6j55n/2>
- DOI: `10.17632/jtpfd6j55n.2`
- Catalog license: CC BY 4.0.

| File | Bytes | SHA-256 |
|---|---:|---|
| `Bangla Handwritten Text Collection Metadata.xlsx` | 7,630 | `2f985d4e4b6256790858ede0a877fee62c3d543ff5875938655862c62b9d3ece` |
| `Preprocessed.zip` | 4,985,773 | `3c9014653ec13e0a13b8874a1de5f8210b27c5ca134856395d4854a7033faf2f` |
| `Raw.zip` | 164,866,940 | `26ba136cbd6fd2c4d968ece2c211a3a6cd4af15b9d55246afe169b1c24cdb382` |

The metadata has 58 contributor rows and the preprocessed archive exposes 52
unique writer IDs, but the images are narrative/page regions and character
sheets. There are no line transcriptions, line boxes, or monetary/receipt
subset. Isolated digits cannot satisfy a real amount-line gate.

## PromitoLipi V2

- Official record: <https://data.mendeley.com/datasets/fnw59h7y89/2>
- DOI: `10.17632/fnw59h7y89.2`
- Catalog license: CC BY 4.0.
- Generated archive `fnw59h7y89-2.zip`: 597,446,632 bytes, SHA-256
  `3610e4ce29395ebc9aca327ce285ac9742b407a32da0fbf5f8b76e49728ae948`.

The corpus reports 80 paragraph pages and 9,830 isolated word images. It does
not document an official writer-ID field or monetary subset, and the paragraph
data has no line-level amount annotations. Thirty percent is sourced from
unspecified CMATERdb material, which also needs separate provenance review.

## Owner decision

Choose exactly one posture for V2-009:

1. **Retain the gate.** Keep real amount CER at most 12% as a release blocker.
   V2 may not claim or ship accepted handwritten-amount support until a newly
   licensed, writer-identified real monetary-line corpus passes the preflight.
   This preserves section 17 but leaves the release blocked by unavailable
   data.
2. **Amend the gate.** Remove real amount CER from V2 release acceptance. Keep
   normalized and exact-script amount CER as synthetic/supplemental diagnostics
   only, publish their provenance, and make no handwritten-amount accuracy
   claim. General real-handwriting CER and the Tesseract-relative gate remain.

Lowering the writer/sample minimums or treating the 37 BN-HTRd lines as a
qualifying slice is rejected: it would combine sparse, concentrated, non-amount
prose with known numeric-label defects and overstate the evidence.
