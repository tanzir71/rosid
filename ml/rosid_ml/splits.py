"""Deterministic writer-disjoint dataset splitting."""

from __future__ import annotations

import hashlib
import math
import re
from collections import defaultdict
from dataclasses import dataclass
from enum import StrEnum
from typing import Iterable, Mapping


class Split(StrEnum):
    TRAIN = "train"
    VALIDATION = "validation"
    TEST = "test"


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_OPAQUE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")


@dataclass(frozen=True)
class SampleKey:
    sample_id: str
    dataset_id: str
    writer_id: str
    image_sha256: str
    reference_sha256: str

    def __post_init__(self) -> None:
        if any(
            not _OPAQUE_ID.fullmatch(value)
            for value in (self.sample_id, self.dataset_id, self.writer_id)
        ):
            raise ValueError(
                "sample, dataset, and writer IDs must be portable opaque IDs"
            )
        if not _SHA256.fullmatch(self.image_sha256):
            raise ValueError("image SHA-256 must be 64 lowercase hex digits")
        if not _SHA256.fullmatch(self.reference_sha256):
            raise ValueError("reference SHA-256 must be 64 lowercase hex digits")


@dataclass(frozen=True)
class ReleaseSplitEvidence:
    sample_counts: dict[Split, int]
    writer_counts: dict[Split, int]
    unique_image_counts: dict[Split, int]


def _writer_order(seed: str, writer_id: str) -> bytes:
    return hashlib.sha256(
        f"rosid-v2-split-v2\0{seed}\0{writer_id}".encode()
    ).digest()


def _allocate_counts(total: int, ratios: Mapping[Split, float]) -> dict[Split, int]:
    ordered = (Split.TRAIN, Split.VALIDATION, Split.TEST)
    if set(ratios) != set(ordered):
        raise ValueError("ratios must define train, validation, and test")
    if any(not math.isfinite(ratios[split]) or ratios[split] < 0 for split in ordered):
        raise ValueError("split ratios must be finite and non-negative")
    ratio_sum = sum(ratios.values())
    if not math.isclose(ratio_sum, 1.0, rel_tol=0, abs_tol=1e-9):
        raise ValueError("split ratios must sum to one")
    if total <= 0:
        return {split: 0 for split in ordered}

    exact = {split: total * ratios[split] for split in ordered}
    counts = {split: math.floor(exact[split]) for split in ordered}
    remaining = total - sum(counts.values())
    by_remainder = sorted(
        ordered,
        key=lambda split: (-(exact[split] - counts[split]), ordered.index(split)),
    )
    for split in by_remainder[:remaining]:
        counts[split] += 1

    nonzero = [split for split in ordered if ratios[split] > 0]
    if total >= len(nonzero):
        for empty in (split for split in nonzero if counts[split] == 0):
            donor = max(nonzero, key=lambda split: counts[split])
            counts[donor] -= 1
            counts[empty] += 1
    return counts


def assign_writer_splits(
    samples: Iterable[SampleKey],
    *,
    seed: str,
    ratios: Mapping[Split, float] | None = None,
) -> dict[str, Split]:
    if not seed:
        raise ValueError("split seed must be nonempty")
    chosen_ratios = ratios if ratios is not None else {
        Split.TRAIN: 0.8,
        Split.VALIDATION: 0.1,
        Split.TEST: 0.1,
    }
    _allocate_counts(0, chosen_ratios)
    materialized = list(samples)
    sample_ids = [sample.sample_id for sample in materialized]
    if len(sample_ids) != len(set(sample_ids)):
        raise ValueError("sample IDs must be globally unique")

    writers = {sample.writer_id for sample in materialized}
    ordered_writers = sorted(
        writers,
        key=lambda writer: (_writer_order(seed, writer), writer),
    )
    counts = _allocate_counts(len(ordered_writers), chosen_ratios)
    writer_split: dict[str, Split] = {}
    cursor = 0
    for split in (Split.TRAIN, Split.VALIDATION, Split.TEST):
        for writer in ordered_writers[cursor : cursor + counts[split]]:
            writer_split[writer] = split
        cursor += counts[split]

    assignments = {
        sample.sample_id: writer_split[sample.writer_id]
        for sample in materialized
    }
    assert_writer_disjoint(materialized, assignments)
    return assignments


def assert_writer_disjoint(
    samples: Iterable[SampleKey],
    assignments: Mapping[str, Split],
) -> None:
    writer_splits: dict[str, set[Split]] = defaultdict(set)
    image_splits: dict[str, set[Split]] = defaultdict(set)
    seen_samples: set[str] = set()
    for sample in samples:
        if sample.sample_id in seen_samples:
            raise ValueError(f"duplicate sample ID: {sample.sample_id}")
        seen_samples.add(sample.sample_id)
        try:
            split = assignments[sample.sample_id]
        except KeyError as error:
            raise ValueError(f"sample has no split: {sample.sample_id}") from error
        if not isinstance(split, Split):
            raise ValueError(
                f"sample has an invalid split value: {sample.sample_id}={split!r}"
            )
        writer_splits[sample.writer_id].add(split)
        image_splits[sample.image_sha256].add(split)
    extra = set(assignments) - seen_samples
    if extra:
        raise ValueError(f"assignments contain unknown samples: {sorted(extra)}")
    leaked = [writer for writer, splits in writer_splits.items() if len(splits) > 1]
    if leaked:
        raise ValueError(f"writers cross split boundaries: {sorted(leaked)}")
    duplicated_images = sorted(
        image_sha256 for image_sha256, splits in image_splits.items() if len(splits) > 1
    )
    if duplicated_images:
        raise ValueError(
            "identical image content crosses split boundaries: "
            f"{duplicated_images}"
        )


def validate_release_split(
    samples: Iterable[SampleKey],
    assignments: Mapping[str, Split],
    *,
    minimum_writers: Mapping[Split, int] | None = None,
    minimum_samples: Mapping[Split, int] | None = None,
) -> ReleaseSplitEvidence:
    materialized = list(samples)
    assert_writer_disjoint(materialized, assignments)
    default_minimums = {split: 1 for split in Split}
    required_writers = default_minimums if minimum_writers is None else minimum_writers
    required_samples = default_minimums if minimum_samples is None else minimum_samples
    for values, label in (
        (required_writers, "writer minimums"),
        (required_samples, "sample minimums"),
    ):
        if set(values) != set(Split):
            raise ValueError(f"{label} must define train, validation, and test")
        if any(type(values[split]) is not int or values[split] <= 0 for split in Split):
            raise ValueError(f"{label} must be positive integers")

    sample_counts = {split: 0 for split in Split}
    writers = {split: set() for split in Split}
    images = {split: set() for split in Split}
    for sample in materialized:
        split = assignments[sample.sample_id]
        if split != Split.TRAIN and sample.image_sha256 in images[split]:
            raise ValueError(
                f"identical image content is repeated within {split.value}: "
                f"{sample.image_sha256}"
            )
        sample_counts[split] += 1
        writers[split].add(sample.writer_id)
        images[split].add(sample.image_sha256)
    writer_counts = {split: len(values) for split, values in writers.items()}
    unique_image_counts = {split: len(values) for split, values in images.items()}
    for split in Split:
        if sample_counts[split] < required_samples[split]:
            raise ValueError(
                f"{split.value} has {sample_counts[split]} samples; "
                f"requires {required_samples[split]}"
            )
        if writer_counts[split] < required_writers[split]:
            raise ValueError(
                f"{split.value} has {writer_counts[split]} writers; "
                f"requires {required_writers[split]}"
            )
    return ReleaseSplitEvidence(
        sample_counts=sample_counts,
        writer_counts=writer_counts,
        unique_image_counts=unique_image_counts,
    )
