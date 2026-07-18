# V2 metric and evaluation contract

Status: proposed for P0 approval. These scoring semantics are independent of
the model's output-token vocabulary.

## Frozen partitions and permitted use

Writers are partitioned before vocabulary construction, learned synthesis, or
model training:

- `train`: model fitting, learned-generator fitting, and augmentation;
- `validation`: architecture/tokenization ablations, generator realism and
  synthetic-to-real trends, routing thresholds, confidence calibration,
  decoder selection, and early stopping; and
- `test`: one sealed final evaluation after the candidate and every threshold
  are frozen.

No image, transcription, style embedding, statistic, nearest neighbor,
representative sample, or vocabulary-only token from a final-test writer may
influence a learned or selected artifact. Repeated inspection of test failures
creates a new model-development round and requires a newly sealed test set or a
fully disclosed compromised-test result.

Quantization representative samples come from the training partition only.

Split membership is grouped by a verified global pseudonymous writer-group key,
not a dataset-local ID. Known cross-corpus people share one group; unresolved
identity overlap remains an explicit evidence gap. Hashes of all three
manifests are bound into every run manifest. Synthetic-to-real progress is
measured on real validation writers, never on the final test. The release-level
validator requires nonempty writer/sample counts in every partition.
Lineage represents those views as partition artifacts under one global split
commitment; final metrics reject train/test artifacts derived from different
splitter manifests or seeds.

## Text normalization

The committed CPU implementation is `ml/rosid_ml/metrics.py`.
Release evaluators use its keyed APIs: reference and prediction sequences must
contain the identical unique sample IDs in identical frozen order. Missing,
extra, duplicate, or reordered IDs fail before any rate is calculated; the
anonymous pair helpers are lower-level math primitives, not acceptance APIs.
The P5 evaluator calls the combined system-comparison API with reference,
Tesseract, and raw HTR sequences together; it emits one keyed-HMAC commitment
over the canonical ordered reference manifest so separate calls cannot drift to
different labels without publishing linkable per-sample/short-label hashes. The
minimum 256-bit commitment key remains outside Git and only its random key ID is
published.

1. Normalize reference and prediction to Unicode NFC.
2. Collapse every Unicode whitespace run to one U+0020 and trim edges.
3. Encode/decode as UTF-8 for stored predictions.
4. Never apply spelling correction or a language model only to one engine.

CER is Levenshtein distance over Unicode scalar values after normalization,
micro-averaged as total edits divided by total reference scalars. WER is the
same calculation over whitespace-delimited tokens. Empty references contribute
zero denominator; any insertion into an all-empty corpus yields rate 1.0.
Those semantics remain available in the lower-level math helpers, but the
release comparison rejects an empty corpus or a corpus with zero scored
reference scalars so a zero-denominator holdout cannot satisfy acceptance.
Extended-grapheme error rate is reported as a diagnostic after the grapheme
dependency is locked, but the P5 CER gate remains scalar CER so tokenization
cannot change its denominator.

Amounts-only CER does **not** classify arbitrary digit-bearing prose as money.
Its input manifest contains only real writer-disjoint line/field crops with a
ground-truth monetary-amount annotation or an unambiguous currency-labeled
amount span; dates, phone numbers, quantities, page numbers, and other digits
are excluded before scoring. The scorer then extracts Bangla digits, ASCII
digits, and `৳` from the matched reference/prediction span, maps both digit
systems to ASCII 0-9 (matching Rosid's parser semantics), and micro-averages the
edit counts. Exact-script scalar CER is also reported. A real amount slice must
be proven before training, including writers, lines, reference units, selection
rules, and a manual manifest audit. Synthetic amounts do not satisfy P5.

The lower-level amount scorer rejects an empty corpus and any corpus with zero
monetary reference units instead of reporting a false 0% CER. The acceptance
comparison requires typed, unique monetary references and machine-enforces at
least 20 writers, 100 samples, and 1,000 digit/`৳` units; every sample must carry
the explicitly supplied audited `monetary_verified` flag; the typed constructor
has no permissive default. Each sample binds the same frozen split-manifest
SHA-256, and sample/writer keys must be portable opaque IDs. Its keyed HMAC also
binds the split commitment, writer groups, and audit flag. If V2-009 records
Choice B, these values are supplemental only and cannot be described as passing
a real-amount release gate.

Relative CER improvement is:

```text
(tesseract_cer - htr_cer) / tesseract_cer
```

The baseline and HTR prediction must cover the identical ordered sample IDs.
If Tesseract CER is zero, the ratio is undefined. Canonical JSON stores
`value: null` plus either `baseline_and_candidate_zero` or
`zero_baseline_candidate_error`; the 30% relative-improvement gate fails in
both cases because a positive relative reduction cannot be demonstrated.

## Baseline and raw-model reporting

The run manifest freezes Tesseract version, both `ben` and `eng` traineddata
SHA-256 values, comparator engine ID `tesseract-ben-eng`, exact language string
`ben+eng`, PSM/options, and page
segmentation/crop manifest, preprocessing hash, page-segmentation mode, and all
engine options. Tesseract and HTR receive the same line image wherever their
input contracts permit.

P5 recognition gates use **raw HTR predictions on every eligible HTR test
line**, before routing, confidence rejection, merging, parser correction, or
Tesseract fallback. Separately report routed end-to-end CER and coverage. A
router cannot hide a weak model by declining difficult lines.

Required aggregate and slice results include:

- scalar CER and WER by dataset and overall;
- normalized amount CER and exact-script amount CER;
- each P1a confusion pair, Tier/source, degradation, code-switching, and line
  width bucket;
- Tesseract baseline, raw HTR, and routed/fallback output on identical IDs; and
- bootstrap confidence intervals grouped by writer, without changing the hard
  point-estimate gates in section 17.

## Trained-model versus TFLite comparison

The 100-sample parity set is frozen from validation writers and spans real,
each synthetic tier, amounts, mixed script, width buckets, and degradations.
For the float32, float16-weight, and full-int8 candidates:

1. input tensor bytes, preprocessing version, vocabulary, greedy decoder, and
   sample order are identical;
2. output shape, dtype, quantization scale/zero point, and finite-value checks
   match the committed model contract;
3. 100/100 collapsed token-ID sequences and NFC UTF-8 decoded strings must be
   byte-identical to the trained model;
4. maximum absolute softmax-probability delta is at most `1e-5` for float32,
   `5e-3` for float16 weights, and `2e-2` after int8 dequantization; and
5. the validator emits both per-sample diffs and a canonical JSON summary.

Failure rejects that conversion variant. Relaxing token identity or a numeric
tolerance is an owner-visible spec amendment, not an unlogged implementation
choice.
