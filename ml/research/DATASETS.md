# V2 dataset and license evidence

Research date: 2026-07-18. This file records source facts and the conservative
engineering policy Rosid will apply to them. It is not legal advice. Dataset
files are never committed to this repository; the immutable source metadata
and publisher-provided SHA-256 values below are the acquisition allowlist.

## Eligibility summary

| Dataset | Pinned source | Publisher license | Writer metadata | Rosid default |
|---|---|---|---|---|
| BN-HTRd | Mendeley Data V4, DOI `10.17632/743k6dm543.4` | CC BY 4.0 catalog record; third-party BBC text caveat unresolved | Catalog reports 150 writers; archive mapping still must be proved | Conditional: require page-to-writer proof plus documented owner rights-risk acceptance/review before any shipped descendant |
| BanglaLekha-Isolated | Mendeley Data V2, DOI `10.17632/hf6sf8zrkc.2` | CC BY 4.0 | Form serial plus demographic fields; one form is not yet proven to equal one unique person | Allow for isolated-character pretraining; quarantine demographics and conservatively group by form serial |
| BanglaWriting | Mendeley Data V1, DOI `10.17632/r43wkvdk4w.1` | CC BY-NC 3.0 | 260 writers/pages | Research-only quarantine; exclude from any publicly shipped checkpoint or model without written permission or legal approval |
| Ekush | Mutable project/Drive distribution; no pinned dataset version | Ambiguous for images; site terms are CC BY-NC-SA 4.0 and the paper describes academic research use | Paper reports 3,086 writers | Exclude images, derived checkpoints, and shipped models until the owner grants explicit training and weight-redistribution permission |

`allow` means technically eligible, not automatically selected. `Conditional`
is not production eligibility. Every
acquisition still has to match the exact byte count and SHA-256 below, accept
the applicable terms, and create a local provenance manifest.

## BN-HTRd V4

- Authoritative record: <https://data.mendeley.com/datasets/743k6dm543/4>
- DOI: <https://doi.org/10.17632/743k6dm543.4>
- License: Creative Commons Attribution 4.0.
- Reported scope: 786 handwritten pages from 150 writers, with page, line,
  word, full-text, and YOLO-style annotations. The V4 description reports
  14,383 lines.
- Use: primary real line corpus, writer-disjoint validation/test data, and the
  real component of Tier-3 synthesis training.
- Split gate: the catalog does not prove the page-to-writer mapping. The V4
  archive must expose and pass a stable mapping audit before BN-HTRd can satisfy
  the writer-disjoint P5 holdout. The paper's 788-page count also differs from
  the V4 catalog, so downloaded-manifest counts are authoritative for a run.
- Caveat: its ground-truth passages were sourced from BBC Bangla news. Until
  that third-party text provenance is reviewed, do not redistribute source
  images, labels, or excerpts in Git, fixtures, releases, or documentation.
  Store only aggregate metrics and opaque sample IDs. The Mendeley CC BY record
  does not itself prove permission for third-party text; training and public
  weight distribution require a documented owner risk acceptance or rights
  review. Until then, lineage marks BN-HTRd and every descendant `conditional`.

Pinned publisher files:

| File | Bytes | SHA-256 |
|---|---:|---|
| `BN-HTR_Dataset.zip` | 2,608,394,039 | `9ccb7e3e8ebfadc7b57d250496e12be59e1910b4759d150a909f1bffcef2a72e` |
| `Automatic_Annotation.zip` | 1,847,761,410 | `dcb5a6760cc438aea4f84ad343cd44ce485c410f2d4c1851b5805aeebf11a7fc` |
| `Sample_Small.zip` | 76,099,297 | `88afc8ce102a90b3d93c612de68c10b351faa788f2c330c8a8c7a882de8a115c` |
| `Structure_of_Directory.pdf` | 41,039 | `bafbfa75065e95b4f5fb917e5078c0ac3aa3da5fae5a24a1ca2d55ca7f21139f` |

Only `BN-HTR_Dataset.zip` is the proposed authoritative training/evaluation
source. The automatic annotations and small sample require separate manifest
entries if they are ever used.

## BanglaLekha-Isolated V2

- Authoritative record: <https://data.mendeley.com/datasets/hf6sf8zrkc/2>
- DOI: <https://doi.org/10.17632/hf6sf8zrkc.2>
- License: Creative Commons Attribution 4.0.
- Reported scope: 166,105 accepted images in 84 classes: 50 basic characters,
  10 numerals, and 24 compound characters. Collection targeted about 2,000
  samples per class before filtering.
- Use: optional isolated-character representation pretraining and
  confusion-pair diagnostics. It cannot satisfy the line-level real holdout.
- Privacy policy: filenames contain age, gender, district, institution, date,
  and form serial. Raw names remain inside the ignored, access-restricted data
  directory. Derived manifests replace form serials with random opaque IDs or
  keyed HMAC values whose key stays outside Git, and omit all demographic
  fields. Split grouping uses that private form
  serial before pseudonymization. This is conservative leakage control, not a
  claim that all 2,000 collection forms are verified unique writers; reported
  contributor ages include minors.

Pinned publisher file:

| File | Bytes | SHA-256 |
|---|---:|---|
| `BanglaLekha-Isolated.zip` | 197,085,712 | `df8a78b7a9eaf33ff776b12094a887229b9c3064b8c9600e9c63c2a12a1cf32a` |

## BanglaWriting V1

- Authoritative record: <https://data.mendeley.com/datasets/r43wkvdk4w/1>
- DOI: <https://doi.org/10.17632/r43wkvdk4w.1>
- License: Creative Commons Attribution-NonCommercial 3.0. The paper's more
  permissive license does not replace the dataset license.
- Reported scope: 260 writers/pages, 21,234 words, 32,787 characters, and 5,470
  unique words, with word boxes and Unicode labels.
- Policy: files may be inspected only in an explicitly research-only local
  workspace. They are excluded from production training, production
  evaluation, learned synthesis, checkpoints, and public model artifacts by
  default. Whether trained weights are derivative works is unsettled; Rosid
  does not use that uncertainty as permission.

Pinned publisher files for research-only verification:

| File | Bytes | SHA-256 |
|---|---:|---|
| `converted.zip` | 132,226,825 | `263ca3f31a4f0c3a197194f7e0c35b383fb7ef5f96942b08d96d9272fb9f9366` |
| `raw.zip` | 136,437,956 | `0cbe22cb7f4263f57182243e98a577bb6cd8c29466b9b4469ac9d452c896a3e3` |

## Ekush

- Project page: <https://rabby.dev/ekush/>
- Research repository: <https://github.com/ShahariarRabby/ekush>
- Terms evidence pinned at Git commit `7a65890a89f76a40df2909073c1bf3d78f68d465`:
  <https://github.com/ShahariarRabby/shahariarrabby.github.io/blob/7a65890a89f76a40df2909073c1bf3d78f68d465/ekush/dataset/termsofuse.htm#L304-L327>
- Paper scope: 367,018 isolated images, 122 classes, and 3,086 writers.
- Current page scope: 673,482 images and 242 classes after combining an
  expanded collection, but the mutable Drive distribution has no release tag
  or publisher checksum.
- Rights issue: site terms apply CC BY-NC-SA 4.0 to website/annotations while
  separately asserting consortium ownership of the images; the paper promises
  academic research access but does not expressly license image-derived public
  weights. A third-party Kaggle metadata page is not an authoritative grant.
- Policy: excluded. A later exception requires a versioned archive, locally
  recorded SHA-256, and written permission covering model training,
  modification, commercial use, and redistribution of learned weights.

## Attribution and release evidence

Every eligible training run must record:

1. dataset DOI, version, source URL, license identifier, filename, byte count,
   and SHA-256;
2. acquisition timestamp and the person who accepted any source terms;
3. exact writer-disjoint split-manifest SHA-256;
4. whether the run used source images, labels, isolated pretraining, learned
   synthesis, or evaluation only; and
5. the resulting checkpoint/model hashes and an attribution notice.

The V2 release must ship an attribution file for every dataset that influenced
the selected weights. It must not contain source samples or label excerpts.

Publisher hashes above come from the Mendeley/Elsevier public file API:
<https://elsevier.digitalcommonsdata.com/api/docs/>. License meanings and
non-copyright caveats are anchored to the official Creative Commons terms:
<https://creativecommons.org/licenses/by/4.0/>,
<https://creativecommons.org/licenses/by-nc/3.0/>, and
<https://creativecommons.org/licenses/by-nc-sa/4.0/>.

## Real monetary benchmark search

`AMOUNT_BENCHMARK.md` records the completed BN-HTRd label audit and the Bayanno
V2/PromitoLipi V2 review. None provides a qualifying real, writer-disjoint
monetary-line slice. Those two additional corpora are research evidence only;
they are not acquisition-allowlisted here or approved as production training
inputs.
