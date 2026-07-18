"""NFC-normalized, micro-averaged HTR acceptance metrics."""

from __future__ import annotations

import hashlib
import hmac
import json
import math
import re
import unicodedata
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from enum import StrEnum
from typing import TypeVar


_T = TypeVar("_T")
_WHITESPACE = re.compile(r"\s+")
_OPAQUE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_BANGLA_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")
MIN_AMOUNT_TEST_WRITERS = 20
MIN_AMOUNT_SAMPLES = 100
MIN_AMOUNT_REFERENCE_UNITS = 1000


@dataclass(frozen=True)
class ErrorRate:
    edits: int
    reference_units: int
    samples: int

    @property
    def rate(self) -> float:
        if self.reference_units == 0:
            return 0.0 if self.edits == 0 else 1.0
        return self.edits / self.reference_units

    @property
    def percent(self) -> float:
        return self.rate * 100


@dataclass(frozen=True)
class ScoredText:
    sample_id: str
    text: str

    def __post_init__(self) -> None:
        if not _OPAQUE_ID.fullmatch(self.sample_id):
            raise ValueError("scored sample ID must be a portable opaque ID")


@dataclass(frozen=True)
class AmountReference(ScoredText):
    writer_id: str
    split_commitment: str
    monetary_verified: bool

    def __post_init__(self) -> None:
        super().__post_init__()
        if not _OPAQUE_ID.fullmatch(self.writer_id):
            raise ValueError("amount writer ID must be a portable opaque ID")
        if not _SHA256.fullmatch(self.split_commitment):
            raise ValueError("amount split commitment must be a SHA-256")
        if type(self.monetary_verified) is not bool:
            raise ValueError("monetary_verified must be a boolean")


@dataclass(frozen=True)
class AmountSliceEvidence:
    samples: int
    writers: int
    reference_units: int
    split_commitment: str


class RelativeReductionStatus(StrEnum):
    DEFINED = "defined"
    BOTH_ZERO = "baseline_and_candidate_zero"
    ZERO_BASELINE_CANDIDATE_ERROR = "zero_baseline_candidate_error"


@dataclass(frozen=True)
class RelativeReduction:
    value: float | None
    status: RelativeReductionStatus

    def passes(self, minimum: float) -> bool:
        return self.value is not None and self.value >= minimum

    def to_dict(self) -> dict[str, float | str | None]:
        return {"status": self.status.value, "value": self.value}


@dataclass(frozen=True)
class SystemComparison:
    reference_commitment: str
    baseline: ErrorRate
    candidate: ErrorRate
    relative_reduction: RelativeReduction


def normalize_for_scoring(text: str) -> str:
    """Normalize canonical equivalents and layout-only whitespace variation."""

    return _WHITESPACE.sub(" ", unicodedata.normalize("NFC", text)).strip()


def levenshtein_distance(
    reference: Sequence[_T],
    prediction: Sequence[_T],
) -> int:
    """Return edit distance with O(min(n, m)) memory."""

    if len(reference) < len(prediction):
        shorter, longer = reference, prediction
    else:
        shorter, longer = prediction, reference
    previous = list(range(len(shorter) + 1))
    for row, longer_value in enumerate(longer, start=1):
        current = [row]
        for column, shorter_value in enumerate(shorter, start=1):
            insertion = current[column - 1] + 1
            deletion = previous[column] + 1
            substitution = previous[column - 1] + (
                0 if longer_value == shorter_value else 1
            )
            current.append(min(insertion, deletion, substitution))
        previous = current
    return previous[-1]


def _score(
    pairs: Iterable[tuple[str, str]],
    tokenizer: Callable[[str], Sequence[str]],
) -> ErrorRate:
    edits = 0
    reference_units = 0
    samples = 0
    for reference, prediction in pairs:
        reference_tokens = tokenizer(normalize_for_scoring(reference))
        prediction_tokens = tokenizer(normalize_for_scoring(prediction))
        edits += levenshtein_distance(reference_tokens, prediction_tokens)
        reference_units += len(reference_tokens)
        samples += 1
    return ErrorRate(
        edits=edits,
        reference_units=reference_units,
        samples=samples,
    )


def aligned_pairs(
    references: Sequence[ScoredText],
    predictions: Sequence[ScoredText],
) -> list[tuple[str, str]]:
    reference_ids = [value.sample_id for value in references]
    prediction_ids = [value.sample_id for value in predictions]
    if len(reference_ids) != len(set(reference_ids)):
        raise ValueError("reference sample IDs must be unique")
    if len(prediction_ids) != len(set(prediction_ids)):
        raise ValueError("prediction sample IDs must be unique")
    if reference_ids != prediction_ids:
        missing = sorted(set(reference_ids) - set(prediction_ids))
        extra = sorted(set(prediction_ids) - set(reference_ids))
        if missing or extra:
            raise ValueError(
                f"prediction sample IDs differ; missing={missing}, extra={extra}"
            )
        raise ValueError("prediction sample order differs from the frozen reference")
    return [
        (reference.text, prediction.text)
        for reference, prediction in zip(references, predictions, strict=True)
    ]


def cer(pairs: Iterable[tuple[str, str]]) -> ErrorRate:
    """Unicode-scalar CER after NFC and whitespace canonicalization."""

    return _score(pairs, tuple)


def keyed_cer(
    references: Sequence[ScoredText],
    predictions: Sequence[ScoredText],
) -> ErrorRate:
    return cer(aligned_pairs(references, predictions))


def wer(pairs: Iterable[tuple[str, str]]) -> ErrorRate:
    """Whitespace-tokenized WER after NFC and whitespace canonicalization."""

    return _score(pairs, str.split)


def keyed_wer(
    references: Sequence[ScoredText],
    predictions: Sequence[ScoredText],
) -> ErrorRate:
    return wer(aligned_pairs(references, predictions))


def _amount_units(text: str) -> tuple[str, ...]:
    # Both numeral systems have the same receipt meaning after app
    # normalization. Exact-script CER is still available through `cer`.
    normalized = text.translate(_BANGLA_DIGITS)
    return tuple(
        character
        for character in normalized
        if (character.isascii() and character.isdigit()) or character == "৳"
    )


def _exact_amount_units(text: str) -> tuple[str, ...]:
    return tuple(
        character
        for character in text
        if (character.isascii() and character.isdigit())
        or "০" <= character <= "৯"
        or character == "৳"
    )


def amount_cer(pairs: Iterable[tuple[str, str]]) -> ErrorRate:
    """Score preselected monetary spans over normalized digits and taka signs.

    The caller must supply pairs selected by an audited real-amount manifest;
    this function intentionally does not infer that arbitrary digits are money.
    """

    result = _score(pairs, _amount_units)
    if result.samples == 0 or result.reference_units == 0:
        raise ValueError("amount CER requires nonempty monetary reference units")
    return result


def keyed_amount_cer(
    references: Sequence[ScoredText],
    predictions: Sequence[ScoredText],
) -> ErrorRate:
    return amount_cer(aligned_pairs(references, predictions))


def exact_amount_cer(pairs: Iterable[tuple[str, str]]) -> ErrorRate:
    """Score preselected monetary spans without numeral-system folding."""

    result = _score(pairs, _exact_amount_units)
    if result.samples == 0 or result.reference_units == 0:
        raise ValueError("exact amount CER requires nonempty monetary reference units")
    return result


def keyed_exact_amount_cer(
    references: Sequence[ScoredText],
    predictions: Sequence[ScoredText],
) -> ErrorRate:
    return exact_amount_cer(aligned_pairs(references, predictions))


def relative_error_reduction(
    baseline: float,
    candidate: float,
) -> RelativeReduction:
    if not math.isfinite(baseline) or not math.isfinite(candidate):
        raise ValueError("error rates must be finite")
    if baseline < 0 or candidate < 0:
        raise ValueError("error rates must be non-negative")
    if baseline == 0:
        if candidate == 0:
            return RelativeReduction(None, RelativeReductionStatus.BOTH_ZERO)
        return RelativeReduction(
            None,
            RelativeReductionStatus.ZERO_BASELINE_CANDIDATE_ERROR,
        )
    return RelativeReduction(
        (baseline - candidate) / baseline,
        RelativeReductionStatus.DEFINED,
    )


def reference_manifest_hmac(
    references: Sequence[ScoredText],
    *,
    commitment_key: bytes,
) -> str:
    if len(commitment_key) < 32:
        raise ValueError("reference commitment key must contain at least 32 bytes")
    ids = [value.sample_id for value in references]
    if len(ids) != len(set(ids)):
        raise ValueError("reference sample IDs must be unique")
    records = []
    for value in references:
        record: dict[str, str | bool] = {
            "sample_id": value.sample_id,
            "text": normalize_for_scoring(value.text),
        }
        if isinstance(value, AmountReference):
            record["writer_id"] = value.writer_id
            record["split_commitment"] = value.split_commitment
            record["monetary_verified"] = value.monetary_verified
        records.append(record)
    encoded = json.dumps(
        records,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hmac.new(commitment_key, encoded, hashlib.sha256).hexdigest()


def validate_amount_slice(
    references: Sequence[AmountReference],
    *,
    minimum_writers: int = MIN_AMOUNT_TEST_WRITERS,
    minimum_samples: int = MIN_AMOUNT_SAMPLES,
    minimum_reference_units: int = MIN_AMOUNT_REFERENCE_UNITS,
) -> AmountSliceEvidence:
    for value, label in (
        (minimum_writers, "minimum writers"),
        (minimum_samples, "minimum samples"),
        (minimum_reference_units, "minimum reference units"),
    ):
        if type(value) is not int or value <= 0:
            raise ValueError(f"{label} must be a positive integer")
    sample_ids = [value.sample_id for value in references]
    if len(sample_ids) != len(set(sample_ids)):
        raise ValueError("amount reference sample IDs must be unique")
    if len(references) < minimum_samples:
        raise ValueError(
            f"amount slice has {len(references)} samples; requires {minimum_samples}"
        )
    split_commitments = {value.split_commitment for value in references}
    if len(split_commitments) != 1:
        raise ValueError(
            "amount references must bind exactly one frozen split commitment"
        )
    unverified = [
        value.sample_id for value in references if not value.monetary_verified
    ]
    if unverified:
        raise ValueError(f"amount slice has unverified monetary samples: {unverified}")
    empty = [
        value.sample_id
        for value in references
        if not any(
            character.isascii() and character.isdigit()
            for character in normalize_for_scoring(value.text).translate(
                _BANGLA_DIGITS
            )
        )
    ]
    if empty:
        raise ValueError(f"amount references contain no monetary digits: {empty}")
    writers = {value.writer_id for value in references}
    if len(writers) < minimum_writers:
        raise ValueError(
            f"amount slice has {len(writers)} writers; requires {minimum_writers}"
        )
    reference_units = sum(
        len(_amount_units(normalize_for_scoring(value.text)))
        for value in references
    )
    if reference_units < minimum_reference_units:
        raise ValueError(
            f"amount slice has {reference_units} reference units; "
            f"requires {minimum_reference_units}"
        )
    return AmountSliceEvidence(
        samples=len(references),
        writers=len(writers),
        reference_units=reference_units,
        split_commitment=next(iter(split_commitments)),
    )


def compare_cer_systems(
    references: Sequence[ScoredText],
    baseline: Sequence[ScoredText],
    candidate: Sequence[ScoredText],
    *,
    commitment_key: bytes,
) -> SystemComparison:
    baseline_score = keyed_cer(references, baseline)
    candidate_score = keyed_cer(references, candidate)
    if baseline_score.samples == 0:
        raise ValueError("CER acceptance references must be nonempty")
    if baseline_score.reference_units == 0:
        raise ValueError(
            "CER acceptance references must contain at least one scored character"
        )
    return SystemComparison(
        reference_commitment=reference_manifest_hmac(
            references,
            commitment_key=commitment_key,
        ),
        baseline=baseline_score,
        candidate=candidate_score,
        relative_reduction=relative_error_reduction(
            baseline_score.rate,
            candidate_score.rate,
        ),
    )


def compare_amount_systems(
    references: Sequence[AmountReference],
    baseline: Sequence[ScoredText],
    candidate: Sequence[ScoredText],
    *,
    commitment_key: bytes,
) -> SystemComparison:
    validate_amount_slice(references)
    baseline_score = keyed_amount_cer(references, baseline)
    candidate_score = keyed_amount_cer(references, candidate)
    return SystemComparison(
        reference_commitment=reference_manifest_hmac(
            references,
            commitment_key=commitment_key,
        ),
        baseline=baseline_score,
        candidate=candidate_score,
        relative_reduction=relative_error_reduction(
            baseline_score.rate,
            candidate_score.rate,
        ),
    )
