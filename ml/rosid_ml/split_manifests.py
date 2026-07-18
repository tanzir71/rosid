"""Canonical private splits and privacy-preserving public commitments."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import stat
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Callable, Mapping, TypeVar

from .acquisition import (
    DirectoryInventory,
    validate_portable_relative_path,
)
from .adapter_evidence import (
    AdapterConfig,
    AdapterEvidence,
    PublicAdapterCommitment,
    VerifiedAdapterEvidence,
    adapter_commitment_key_fingerprint,
    verify_adapter_evidence,
)
from .code_bundles import CodeBundleManifest
from .provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    SourceEvidence,
    canonical_json_bytes,
    canonical_json_line_bytes,
)
from .split_approvals import (
    ApprovalFileRole,
    ApprovalPolicy,
    ApprovedFile,
    ApprovalScope,
    VerifiedSplitApproval,
    approved_file_set,
    split_commitment_key_fingerprint,
    split_seed_key_fingerprint,
)
from .splits import (
    DEFAULT_SPLIT_WEIGHTS,
    WRITER_SPLIT_ALGORITHM,
    ReleaseSplitEvidence,
    SampleKey,
    Split,
    assign_writer_splits_weighted,
    validate_release_split,
)
from .storage import require_private_path, require_tracked_unchanged_path


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_OPAQUE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
_DATASET_ID = re.compile(r"[a-z0-9][a-z0-9_.-]{0,127}\Z")
_HMAC_DOMAIN = b"rosid-v2-private-split-commitment-v1\0"
_SEED_DOMAIN = b"rosid-v2-writer-split-seed-v1\0"
_SPLIT_NAMES = {split.value for split in Split}
_Record = TypeVar("_Record")


def _validate_sha256(value: str, *, label: str) -> None:
    if not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")


def _validate_opaque_id(value: str, *, label: str) -> None:
    if not _OPAQUE_ID.fullmatch(value):
        raise ValueError(f"{label} must be a portable opaque ID")


def _validate_sample_fields(
    *,
    schema_version: int,
    sample_id: str,
    dataset_id: str,
    dataset_version: str,
    acquisition_sha256: str,
    writer_group_id: str,
    object_key: str,
    image_sha256: str,
    reference_sha256: str,
    width: int,
    height: int,
    token_count: int,
) -> None:
    if type(schema_version) is not int or schema_version != 1:
        raise ValueError(f"unsupported local-sample schema: {schema_version}")
    _validate_opaque_id(sample_id, label="sample ID")
    if not _DATASET_ID.fullmatch(dataset_id):
        raise ValueError("dataset ID must be a portable lowercase token")
    _validate_opaque_id(dataset_version, label="dataset version")
    _validate_sha256(acquisition_sha256, label="acquisition SHA-256")
    _validate_opaque_id(writer_group_id, label="writer-group ID")
    validate_portable_relative_path(object_key)
    _validate_sha256(image_sha256, label="image SHA-256")
    _validate_sha256(reference_sha256, label="reference SHA-256")
    for value, label in (
        (width, "sample width"),
        (height, "sample height"),
        (token_count, "sample token count"),
    ):
        if type(value) is not int or value <= 0:
            raise ValueError(f"{label} must be a positive integer")


@dataclass(frozen=True)
class UnsplitSample:
    schema_version: int
    sample_id: str
    dataset_id: str
    dataset_version: str
    acquisition_sha256: str
    writer_group_id: str
    object_key: str
    image_sha256: str
    reference_sha256: str
    width: int
    height: int
    token_count: int

    def __post_init__(self) -> None:
        _validate_sample_fields(**self.__dict__)

    def to_dict(self) -> dict[str, object]:
        return {
            "acquisition_sha256": self.acquisition_sha256,
            "dataset_id": self.dataset_id,
            "dataset_version": self.dataset_version,
            "height": self.height,
            "image_sha256": self.image_sha256,
            "object_key": self.object_key,
            "reference_sha256": self.reference_sha256,
            "sample_id": self.sample_id,
            "schema_version": self.schema_version,
            "token_count": self.token_count,
            "width": self.width,
            "writer_group_id": self.writer_group_id,
        }

    def to_sample_key(self) -> SampleKey:
        return SampleKey(
            sample_id=self.sample_id,
            dataset_id=self.dataset_id,
            writer_id=self.writer_group_id,
            image_sha256=self.image_sha256,
            reference_sha256=self.reference_sha256,
        )

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> UnsplitSample:
        expected = {
            "acquisition_sha256",
            "dataset_id",
            "dataset_version",
            "height",
            "image_sha256",
            "object_key",
            "reference_sha256",
            "sample_id",
            "schema_version",
            "token_count",
            "width",
            "writer_group_id",
        }
        if set(value) != expected:
            raise ValueError("local sample keys differ from the schema")
        for field in ("height", "schema_version", "token_count", "width"):
            if type(value[field]) is not int:
                raise ValueError(f"local sample {field} must be an integer")
        for field in expected - {"height", "schema_version", "token_count", "width"}:
            if type(value[field]) is not str:
                raise ValueError(f"local sample {field} must be a string")
        return cls(
            schema_version=value["schema_version"],
            sample_id=value["sample_id"],
            dataset_id=value["dataset_id"],
            dataset_version=value["dataset_version"],
            acquisition_sha256=value["acquisition_sha256"],
            writer_group_id=value["writer_group_id"],
            object_key=value["object_key"],
            image_sha256=value["image_sha256"],
            reference_sha256=value["reference_sha256"],
            width=value["width"],
            height=value["height"],
            token_count=value["token_count"],
        )


@dataclass(frozen=True)
class PrivateSplitRecord:
    sample: UnsplitSample
    split: Split

    def __post_init__(self) -> None:
        if not isinstance(self.split, Split):
            raise ValueError("private split record has an invalid split")

    def to_dict(self) -> dict[str, object]:
        return {
            **self.sample.to_dict(),
            "split": self.split.value,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> PrivateSplitRecord:
        if "split" not in value:
            raise ValueError("private split record is missing its split")
        if type(value["split"]) is not str:
            raise ValueError("private split value must be a string")
        sample_value = {key: item for key, item in value.items() if key != "split"}
        return cls(
            sample=UnsplitSample.from_dict(sample_value),
            split=Split(value["split"]),
        )


def _split_mapping(
    value: object,
    *,
    label: str,
    positive: bool,
) -> dict[Split, int]:
    if not isinstance(value, dict) or set(value) != _SPLIT_NAMES:
        raise ValueError(f"{label} must define train, validation, and test")
    result: dict[Split, int] = {}
    for split in Split:
        item = value[split.value]
        if type(item) is not int or item < (1 if positive else 0):
            qualifier = "positive" if positive else "non-negative"
            raise ValueError(f"{label} must contain {qualifier} integers")
        result[split] = item
    return result


def _mapping_to_dict(value: Mapping[Split, int]) -> dict[str, int]:
    return {split.value: value[split] for split in Split}


@dataclass(frozen=True)
class SplitConfig:
    schema_version: int
    algorithm: str
    splitter_code_sha256: str
    seed_id: str
    key_id: str
    weights: Mapping[Split, int]
    minimum_writers: Mapping[Split, int]
    minimum_samples: Mapping[Split, int]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 2:
            raise ValueError(f"unsupported split-config schema: {self.schema_version}")
        if self.algorithm != WRITER_SPLIT_ALGORITHM:
            raise ValueError(f"unsupported writer-split algorithm: {self.algorithm}")
        _validate_sha256(
            self.splitter_code_sha256,
            label="splitter code SHA-256",
        )
        _validate_opaque_id(self.seed_id, label="split seed ID")
        _validate_opaque_id(self.key_id, label="split commitment-key ID")
        for values, label in (
            (self.weights, "split weights"),
            (self.minimum_writers, "writer minimums"),
            (self.minimum_samples, "sample minimums"),
        ):
            if set(values) != set(Split):
                raise ValueError(
                    f"{label} must define train, validation, and test"
                )
        if any(
            type(self.weights[split]) is not int or self.weights[split] <= 0
            for split in Split
        ):
            raise ValueError("split weights must be positive integers")
        for values, label in (
            (self.minimum_writers, "writer minimums"),
            (self.minimum_samples, "sample minimums"),
        ):
            if any(
                type(values[split]) is not int or values[split] <= 0
                for split in Split
            ):
                raise ValueError(f"{label} must be positive integers")
        object.__setattr__(
            self,
            "weights",
            MappingProxyType(dict(self.weights)),
        )
        object.__setattr__(
            self,
            "minimum_writers",
            MappingProxyType(dict(self.minimum_writers)),
        )
        object.__setattr__(
            self,
            "minimum_samples",
            MappingProxyType(dict(self.minimum_samples)),
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "algorithm": self.algorithm,
            "key_id": self.key_id,
            "minimum_samples": _mapping_to_dict(self.minimum_samples),
            "minimum_writers": _mapping_to_dict(self.minimum_writers),
            "schema_version": self.schema_version,
            "seed_id": self.seed_id,
            "splitter_code_sha256": self.splitter_code_sha256,
            "weights": _mapping_to_dict(self.weights),
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> SplitConfig:
        expected = {
            "algorithm",
            "key_id",
            "minimum_samples",
            "minimum_writers",
            "schema_version",
            "seed_id",
            "splitter_code_sha256",
            "weights",
        }
        if set(value) != expected:
            raise ValueError("split config keys differ from the schema")
        if type(value["schema_version"]) is not int:
            raise ValueError("split config schema_version must be an integer")
        for field in (
            "algorithm",
            "key_id",
            "seed_id",
            "splitter_code_sha256",
        ):
            if type(value[field]) is not str:
                raise ValueError(f"split config {field} must be a string")
        return cls(
            schema_version=value["schema_version"],
            algorithm=value["algorithm"],
            splitter_code_sha256=value["splitter_code_sha256"],
            seed_id=value["seed_id"],
            key_id=value["key_id"],
            weights=_split_mapping(
                value["weights"],
                label="split weights",
                positive=True,
            ),
            minimum_writers=_split_mapping(
                value["minimum_writers"],
                label="writer minimums",
                positive=True,
            ),
            minimum_samples=_split_mapping(
                value["minimum_samples"],
                label="sample minimums",
                positive=True,
            ),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> SplitConfig:
        value, raw = _read_strict_json_object(path)
        config = cls.from_dict(value)
        if raw != config.canonical_bytes():
            raise ValueError(
                f"split config is not canonical UTF-8/LF JSON: {path}"
            )
        return config


@dataclass(frozen=True)
class PublicSplitCommitment:
    schema_version: int
    config: SplitConfig
    approval_policy_sha256: str
    split_approval_sha256: str
    approval_scope: ApprovalScope
    seed_key_fingerprint_sha256: str
    commitment_key_fingerprint_sha256: str
    dataset_ids: tuple[str, ...]
    source_acquisition_sha256s: tuple[str, ...]
    adapter_commitment_sha256s: tuple[str, ...]
    sample_counts: Mapping[Split, int]
    writer_counts: Mapping[Split, int]
    unique_image_counts: Mapping[Split, int]
    private_manifest_hmac_sha256: str

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 3:
            raise ValueError(
                f"unsupported public split schema: {self.schema_version}"
            )
        for value, label in (
            (self.approval_policy_sha256, "approval policy SHA-256"),
            (self.split_approval_sha256, "split approval SHA-256"),
            (self.seed_key_fingerprint_sha256, "split seed-key fingerprint"),
            (
                self.commitment_key_fingerprint_sha256,
                "split commitment-key fingerprint",
            ),
        ):
            _validate_sha256(value, label=label)
        if not isinstance(self.approval_scope, ApprovalScope):
            raise ValueError("public split approval scope is invalid")
        if not self.dataset_ids or tuple(
            sorted(self.dataset_ids, key=lambda value: value.encode("utf-8"))
        ) != self.dataset_ids:
            raise ValueError("public dataset IDs must be nonempty and sorted")
        if len(self.dataset_ids) != len(set(self.dataset_ids)):
            raise ValueError("public dataset IDs must be unique")
        if any(not _DATASET_ID.fullmatch(value) for value in self.dataset_ids):
            raise ValueError("public dataset IDs must be portable lowercase tokens")
        if not self.source_acquisition_sha256s or tuple(
            sorted(self.source_acquisition_sha256s)
        ) != self.source_acquisition_sha256s:
            raise ValueError(
                "source acquisition commitments must be nonempty and sorted"
            )
        if len(self.source_acquisition_sha256s) != len(
            set(self.source_acquisition_sha256s)
        ):
            raise ValueError("source acquisition commitments must be unique")
        for value in self.source_acquisition_sha256s:
            _validate_sha256(value, label="source acquisition SHA-256")
        if not self.adapter_commitment_sha256s or tuple(
            sorted(self.adapter_commitment_sha256s)
        ) != self.adapter_commitment_sha256s:
            raise ValueError(
                "adapter commitments must be nonempty and sorted"
            )
        if len(self.adapter_commitment_sha256s) != len(
            set(self.adapter_commitment_sha256s)
        ):
            raise ValueError("adapter commitments must be unique")
        if len(self.adapter_commitment_sha256s) != len(
            self.source_acquisition_sha256s
        ):
            raise ValueError(
                "every source acquisition must have one adapter commitment"
            )
        for value in self.adapter_commitment_sha256s:
            _validate_sha256(value, label="adapter commitment SHA-256")
        for values, label in (
            (self.sample_counts, "sample counts"),
            (self.writer_counts, "writer counts"),
            (self.unique_image_counts, "unique-image counts"),
        ):
            if set(values) != set(Split) or any(
                type(values[split]) is not int or values[split] < 0
                for split in Split
            ):
                raise ValueError(f"{label} must contain non-negative split integers")
        for split in Split:
            if self.writer_counts[split] > self.sample_counts[split]:
                raise ValueError("writer count cannot exceed sample count")
            if self.unique_image_counts[split] > self.sample_counts[split]:
                raise ValueError("unique-image count cannot exceed sample count")
            if (
                self.writer_counts[split] < self.config.minimum_writers[split]
                or self.sample_counts[split] < self.config.minimum_samples[split]
            ):
                raise ValueError("public split counts do not satisfy their minimums")
        _validate_sha256(
            self.private_manifest_hmac_sha256,
            label="private manifest HMAC-SHA256",
        )
        object.__setattr__(
            self,
            "sample_counts",
            MappingProxyType(dict(self.sample_counts)),
        )
        object.__setattr__(
            self,
            "writer_counts",
            MappingProxyType(dict(self.writer_counts)),
        )
        object.__setattr__(
            self,
            "unique_image_counts",
            MappingProxyType(dict(self.unique_image_counts)),
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "approval_policy_sha256": self.approval_policy_sha256,
            "approval_scope": self.approval_scope.value,
            "adapter_commitment_sha256s": list(
                self.adapter_commitment_sha256s
            ),
            "commitment_key_fingerprint_sha256": (
                self.commitment_key_fingerprint_sha256
            ),
            "config": self.config.to_dict(),
            "dataset_ids": list(self.dataset_ids),
            "private_manifest_hmac_sha256": self.private_manifest_hmac_sha256,
            "sample_counts": _mapping_to_dict(self.sample_counts),
            "schema_version": self.schema_version,
            "seed_key_fingerprint_sha256": (
                self.seed_key_fingerprint_sha256
            ),
            "source_acquisition_sha256s": list(
                self.source_acquisition_sha256s
            ),
            "split_approval_sha256": self.split_approval_sha256,
            "unique_image_counts": _mapping_to_dict(self.unique_image_counts),
            "writer_counts": _mapping_to_dict(self.writer_counts),
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> PublicSplitCommitment:
        expected = {
            "approval_policy_sha256",
            "approval_scope",
            "adapter_commitment_sha256s",
            "commitment_key_fingerprint_sha256",
            "config",
            "dataset_ids",
            "private_manifest_hmac_sha256",
            "sample_counts",
            "schema_version",
            "seed_key_fingerprint_sha256",
            "source_acquisition_sha256s",
            "split_approval_sha256",
            "unique_image_counts",
            "writer_counts",
        }
        if set(value) != expected:
            raise ValueError("public split keys differ from the schema")
        if type(value["schema_version"]) is not int:
            raise ValueError("public split schema_version must be an integer")
        if not isinstance(value["config"], dict):
            raise ValueError("public split config must be an object")
        for field in (
            "adapter_commitment_sha256s",
            "dataset_ids",
            "source_acquisition_sha256s",
        ):
            if not isinstance(value[field], list) or any(
                type(item) is not str for item in value[field]
            ):
                raise ValueError(f"public split {field} must be a string list")
        if type(value["private_manifest_hmac_sha256"]) is not str:
            raise ValueError("public split HMAC must be a string")
        for field in (
            "approval_policy_sha256",
            "approval_scope",
            "commitment_key_fingerprint_sha256",
            "seed_key_fingerprint_sha256",
            "split_approval_sha256",
        ):
            if type(value[field]) is not str:
                raise ValueError(f"public split {field} must be a string")
        try:
            approval_scope = ApprovalScope(value["approval_scope"])
        except ValueError as error:
            raise ValueError("public split approval scope is unsupported") from error
        return cls(
            schema_version=value["schema_version"],
            config=SplitConfig.from_dict(value["config"]),
            approval_policy_sha256=value["approval_policy_sha256"],
            split_approval_sha256=value["split_approval_sha256"],
            approval_scope=approval_scope,
            seed_key_fingerprint_sha256=value[
                "seed_key_fingerprint_sha256"
            ],
            commitment_key_fingerprint_sha256=value[
                "commitment_key_fingerprint_sha256"
            ],
            adapter_commitment_sha256s=tuple(
                value["adapter_commitment_sha256s"]
            ),
            dataset_ids=tuple(value["dataset_ids"]),
            source_acquisition_sha256s=tuple(
                value["source_acquisition_sha256s"]
            ),
            sample_counts=_split_mapping(
                value["sample_counts"],
                label="sample counts",
                positive=False,
            ),
            writer_counts=_split_mapping(
                value["writer_counts"],
                label="writer counts",
                positive=False,
            ),
            unique_image_counts=_split_mapping(
                value["unique_image_counts"],
                label="unique-image counts",
                positive=False,
            ),
            private_manifest_hmac_sha256=value[
                "private_manifest_hmac_sha256"
            ],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> PublicSplitCommitment:
        value, raw = _read_strict_json_object(path)
        commitment = cls.from_dict(value)
        if raw != commitment.canonical_bytes():
            raise ValueError(
                f"public split is not canonical UTF-8/LF JSON: {path}"
            )
        return commitment


@dataclass(frozen=True)
class SplitArtifacts:
    private_records: tuple[PrivateSplitRecord, ...]
    private_bytes: bytes
    public: PublicSplitCommitment


_VERIFIED_SPLIT_TOKEN = object()


@dataclass(frozen=True, init=False)
class VerifiedSplitEvidence:
    """Trusted-process marker returned after private verification succeeds.

    The fixed CLI is the adversarial security boundary. As with every Python
    object, arbitrary code already executing in this interpreter is trusted.
    """

    public: PublicSplitCommitment
    private_manifest_sha256: str
    acquisition_sha256s: tuple[str, ...]

    def __init__(
        self,
        *,
        public: PublicSplitCommitment,
        private_manifest_sha256: str,
        acquisition_sha256s: tuple[str, ...],
        _token: object,
    ) -> None:
        if _token is not _VERIFIED_SPLIT_TOKEN:
            raise ValueError(
                "verified split evidence must come from split verification"
            )
        _validate_sha256(
            private_manifest_sha256,
            label="private split manifest SHA-256",
        )
        if acquisition_sha256s != public.source_acquisition_sha256s:
            raise ValueError(
                "verified acquisition commitments differ from the public split"
            )
        object.__setattr__(self, "public", public)
        object.__setattr__(
            self,
            "private_manifest_sha256",
            private_manifest_sha256,
        )
        object.__setattr__(self, "acquisition_sha256s", acquisition_sha256s)

    @property
    def public_commitment_sha256(self) -> str:
        return self.public.commitment_sha256

    @property
    def split_approval_sha256(self) -> str:
        return self.public.split_approval_sha256

    @property
    def approval_policy_sha256(self) -> str:
        return self.public.approval_policy_sha256


@dataclass(frozen=True)
class AcquisitionBinding:
    acquisition: AcquisitionRecord
    source: SourceEvidence
    source_manifest: DatasetSource
    inventory: DirectoryInventory

    def __post_init__(self) -> None:
        if self.source != self.source_manifest.to_source_evidence():
            raise ValueError(
                "source evidence differs from its reviewed dataset manifest"
            )
        self.acquisition.validate_source(self.source)
        if (
            self.source.artifact_type != "dataset"
            or self.source.artifact_role != "source_archive"
            or self.source.dataset_id is None
            or self.acquisition.artifact_type != "dataset"
            or self.acquisition.artifact_role != "extracted_dataset"
        ):
            raise ValueError(
                "split acquisition must bind a source archive to an extracted dataset"
            )
        if self.acquisition.inventory_sha256 != self.inventory.commitment_sha256:
            raise ValueError(
                "acquisition inventory commitment differs from its private inventory"
            )
        if self.acquisition.artifact_sha256 != self.inventory.artifact_sha256:
            raise ValueError(
                "acquisition artifact commitment differs from its private inventory"
            )

    @property
    def commitment_sha256(self) -> str:
        return self.acquisition.commitment_sha256


def default_split_config(
    *,
    seed_id: str,
    key_id: str,
    splitter_code_sha256: str,
) -> SplitConfig:
    minimums = {split: 1 for split in Split}
    return SplitConfig(
        schema_version=2,
        algorithm=WRITER_SPLIT_ALGORITHM,
        splitter_code_sha256=splitter_code_sha256,
        seed_id=seed_id,
        key_id=key_id,
        weights=dict(DEFAULT_SPLIT_WEIGHTS),
        minimum_writers=dict(minimums),
        minimum_samples=dict(minimums),
    )


def split_seed_from_key(key: bytes) -> str:
    if len(key) < 32:
        raise ValueError("split seed key must contain at least 32 bytes")
    return hashlib.sha256(_SEED_DOMAIN + key).hexdigest()


def read_secret_file(path: Path, *, label: str) -> bytes:
    path = require_private_path(path)
    try:
        initial = path.stat(follow_symlinks=False)
        reparse = getattr(initial, "st_file_attributes", 0) & getattr(
            stat,
            "FILE_ATTRIBUTE_REPARSE_POINT",
            0,
        )
        if (
            path.is_symlink()
            or reparse
            or not stat.S_ISREG(initial.st_mode)
            or initial.st_nlink != 1
        ):
            raise ValueError(f"{label} must be one unlinked plain file")
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_secret_identity(initial, opened):
                raise ValueError(f"{label} changed before reading")
            content = source.read()
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(f"cannot read {label}: {error}") from error
    if (
        not _same_secret_snapshot(opened, finished)
        or not _same_secret_snapshot(initial, final)
        or not _same_secret_identity(finished, final)
    ):
        raise ValueError(f"{label} changed while reading")
    if len(content) != 32:
        raise ValueError(f"{label} must contain exactly 32 bytes")
    return content


def _same_secret_identity(
    first: os.stat_result,
    second: os.stat_result,
) -> bool:
    return (
        first.st_dev == second.st_dev
        and (first.st_ino == 0 or second.st_ino == 0 or first.st_ino == second.st_ino)
        and first.st_mode == second.st_mode
        and first.st_size == second.st_size
        and first.st_mtime_ns == second.st_mtime_ns
        and first.st_nlink == second.st_nlink
        and getattr(first, "st_file_attributes", 0)
        == getattr(second, "st_file_attributes", 0)
    )


def _same_secret_snapshot(
    first: os.stat_result,
    second: os.stat_result,
) -> bool:
    return (
        _same_secret_identity(first, second)
        and first.st_ctime_ns == second.st_ctime_ns
    )


def validate_acquisition_bindings(
    records: tuple[UnsplitSample, ...],
    bindings: tuple[AcquisitionBinding, ...],
    *,
    allow_nonproduction: bool,
) -> None:
    if not bindings:
        raise ValueError("at least one acquisition binding is required")
    by_commitment: dict[str, AcquisitionBinding] = {}
    for binding in bindings:
        commitment = binding.commitment_sha256
        if commitment in by_commitment:
            raise ValueError(f"duplicate acquisition binding: {commitment}")
        if binding.acquisition.eligibility == Eligibility.EXCLUDED:
            raise ValueError("excluded acquisition cannot enter a split")
        if not binding.acquisition.terms_accepted:
            raise ValueError("split acquisition requires accepted source terms")
        if (
            not allow_nonproduction
            and binding.acquisition.eligibility != Eligibility.PRODUCTION
        ):
            raise ValueError(
                "nonproduction acquisition requires explicit quarantined mode"
            )
        by_commitment[commitment] = binding

    used: set[str] = set()
    for sample in records:
        try:
            binding = by_commitment[sample.acquisition_sha256]
        except KeyError as error:
            raise ValueError(
                f"sample references an unbound acquisition: {sample.sample_id}"
            ) from error
        source = binding.source
        if (
            sample.dataset_id != source.dataset_id
            or sample.dataset_version != source.version
        ):
            raise ValueError(
                f"sample dataset differs from its acquisition: {sample.sample_id}"
            )
        used.add(sample.acquisition_sha256)
    unused = set(by_commitment) - used
    if unused:
        raise ValueError(
            f"split includes unused acquisition bindings: {sorted(unused)}"
        )


def verify_adapter_bindings(
    records: tuple[UnsplitSample, ...],
    bindings: tuple[AcquisitionBinding, ...],
    private_evidence: tuple[AdapterEvidence, ...],
    public_commitments: tuple[PublicAdapterCommitment, ...],
    approved_configs: tuple[AdapterConfig, ...],
    *,
    commitment_key: bytes,
    code_bundle: CodeBundleManifest,
    worktree: Path,
) -> tuple[VerifiedAdapterEvidence, ...]:
    """Verify exactly one approved adapter derivation for each acquisition."""

    if not all((private_evidence, public_commitments, approved_configs)):
        raise ValueError(
            "private/public adapter evidence and approved configs are required"
        )

    def unique_by_acquisition(
        values: tuple[AdapterEvidence, ...] | tuple[PublicAdapterCommitment, ...],
        *,
        label: str,
    ) -> dict[str, AdapterEvidence | PublicAdapterCommitment]:
        result: dict[str, AdapterEvidence | PublicAdapterCommitment] = {}
        for value in values:
            if value.acquisition_sha256 in result:
                raise ValueError(
                    f"duplicate {label} acquisition: {value.acquisition_sha256}"
                )
            result[value.acquisition_sha256] = value
        return result

    private_by_acquisition = unique_by_acquisition(
        private_evidence,
        label="private adapter evidence",
    )
    public_by_acquisition = unique_by_acquisition(
        public_commitments,
        label="public adapter commitment",
    )
    binding_by_acquisition = {
        binding.commitment_sha256: binding for binding in bindings
    }
    expected_acquisitions = set(binding_by_acquisition)
    for actual, label in (
        (set(private_by_acquisition), "private adapter evidence"),
        (set(public_by_acquisition), "public adapter commitments"),
    ):
        missing = sorted(expected_acquisitions - actual)
        extra = sorted(actual - expected_acquisitions)
        if missing or extra:
            raise ValueError(
                f"{label} do not exactly cover split acquisitions; "
                f"missing={missing}, extra={extra}"
            )

    config_by_commitment: dict[str, AdapterConfig] = {}
    for config in approved_configs:
        commitment = config.commitment_sha256
        if commitment in config_by_commitment:
            raise ValueError(f"duplicate approved adapter config: {commitment}")
        config_by_commitment[commitment] = config
    used_config_sha256s = {
        value.adapter_config_sha256 for value in public_commitments
    }
    missing_configs = sorted(used_config_sha256s - set(config_by_commitment))
    extra_configs = sorted(set(config_by_commitment) - used_config_sha256s)
    if missing_configs or extra_configs:
        raise ValueError(
            "approved adapter configs do not exactly cover commitments; "
            f"missing={missing_configs}, extra={extra_configs}"
        )
    code_bundle.require_exact_implementation(
        adapter_paths=(
            implementation_path
            for config in approved_configs
            for implementation_path in config.implementation_paths
        ),
        worktree_root=worktree,
    )

    records_by_acquisition: dict[str, list[UnsplitSample]] = {}
    for record in records:
        records_by_acquisition.setdefault(record.acquisition_sha256, []).append(
            record
        )

    verified: list[VerifiedAdapterEvidence] = []
    for acquisition_sha256 in sorted(expected_acquisitions):
        binding = binding_by_acquisition[acquisition_sha256]
        private = private_by_acquisition[acquisition_sha256]
        public = public_by_acquisition[acquisition_sha256]
        if not isinstance(private, AdapterEvidence) or not isinstance(
            public,
            PublicAdapterCommitment,
        ):
            raise AssertionError("adapter evidence mapping lost its concrete type")
        config = config_by_commitment[public.adapter_config_sha256]
        if public.adapter_config != config:
            raise ValueError(
                "public adapter config differs from its approved config"
            )
        verified.append(
            verify_adapter_evidence(
                private,
                public,
                source=binding.source,
                acquisition=binding.acquisition,
                inventory=binding.inventory,
                normalized_samples=tuple(
                    records_by_acquisition.get(acquisition_sha256, ())
                ),
                commitment_key=commitment_key,
                expected_code_bundle_sha256=code_bundle.commitment_sha256,
                expected_config_sha256=config.commitment_sha256,
            )
        )
    return tuple(verified)


def load_acquisition_bindings(
    acquisition_paths: tuple[Path, ...],
    source_paths: tuple[Path, ...],
    source_manifest_paths: tuple[Path, ...],
    inventory_paths: tuple[Path, ...],
) -> tuple[AcquisitionBinding, ...]:
    if not all(
        (acquisition_paths, source_paths, source_manifest_paths, inventory_paths)
    ):
        raise ValueError(
            "acquisition, source-evidence, source-manifest, and inventory paths "
            "are required"
        )
    source_manifests: dict[str, DatasetSource] = {}
    for path in source_manifest_paths:
        manifest = DatasetSource.from_json_file(path)
        commitment = manifest.commitment_sha256
        if commitment in source_manifests:
            raise ValueError(f"duplicate dataset-source commitment: {commitment}")
        source_manifests[commitment] = manifest

    inventories: dict[str, DirectoryInventory] = {}
    for path in inventory_paths:
        inventory = DirectoryInventory.from_json_file(path)
        commitment = inventory.commitment_sha256
        if commitment in inventories:
            raise ValueError(f"duplicate directory-inventory commitment: {commitment}")
        inventories[commitment] = inventory

    sources: dict[str, SourceEvidence] = {}
    for path in source_paths:
        source = SourceEvidence.from_json_file(path)
        commitment = source.commitment_sha256
        if commitment in sources:
            raise ValueError(f"duplicate source-evidence commitment: {commitment}")
        sources[commitment] = source

    bindings: list[AcquisitionBinding] = []
    used_sources: set[str] = set()
    used_source_manifests: set[str] = set()
    used_inventories: set[str] = set()
    for path in acquisition_paths:
        acquisition = AcquisitionRecord.from_json_file(path)
        try:
            source = sources[acquisition.source_evidence_sha256]
        except KeyError as error:
            raise ValueError(
                f"acquisition has no matching source evidence: {path}"
            ) from error
        if source.source_manifest_sha256 is None:
            raise ValueError("dataset source evidence lacks its manifest commitment")
        try:
            source_manifest = source_manifests[source.source_manifest_sha256]
        except KeyError as error:
            raise ValueError(
                f"source evidence has no matching reviewed dataset manifest: {path}"
            ) from error
        try:
            inventory = inventories[acquisition.inventory_sha256]
        except KeyError as error:
            raise ValueError(
                f"acquisition has no matching private directory inventory: {path}"
            ) from error
        bindings.append(
            AcquisitionBinding(
                acquisition=acquisition,
                source=source,
                source_manifest=source_manifest,
                inventory=inventory,
            )
        )
        used_sources.add(source.commitment_sha256)
        used_source_manifests.add(source_manifest.commitment_sha256)
        used_inventories.add(inventory.commitment_sha256)
    unused = set(sources) - used_sources
    if unused:
        raise ValueError(f"unused source-evidence commitments: {sorted(unused)}")
    unused_manifests = set(source_manifests) - used_source_manifests
    if unused_manifests:
        raise ValueError(
            f"unused dataset-source commitments: {sorted(unused_manifests)}"
        )
    unused_inventories = set(inventories) - used_inventories
    if unused_inventories:
        raise ValueError(
            f"unused directory-inventory commitments: {sorted(unused_inventories)}"
        )
    return tuple(bindings)


def rebind_acquisition_inputs_to_head(
    acquisition_paths: tuple[Path, ...],
    source_paths: tuple[Path, ...],
    source_manifest_paths: tuple[Path, ...],
    bindings: tuple[AcquisitionBinding, ...],
    *,
    worktree: Path,
) -> None:
    """Bind every parsed public acquisition input back to its exact HEAD blob."""

    expected_acquisitions = {
        value.acquisition.commitment_sha256: value.acquisition.canonical_bytes()
        for value in bindings
    }
    expected_sources = {
        value.source.commitment_sha256: value.source.canonical_bytes()
        for value in bindings
    }
    expected_manifests = {
        value.source_manifest.commitment_sha256: value.source_manifest.canonical_bytes()
        for value in bindings
    }

    def check_exact(
        paths: tuple[Path, ...],
        expected: dict[str, bytes],
        parser: Callable[[Path], object],
        *,
        label: str,
    ) -> None:
        seen: set[str] = set()
        for path in paths:
            value = parser(path)
            commitment = getattr(value, "commitment_sha256", None)
            if type(commitment) is not str or commitment not in expected:
                raise ValueError(
                    f"{label} path differs from loaded acquisition evidence"
                )
            if commitment in seen:
                raise ValueError(f"duplicate {label} path commitment: {commitment}")
            seen.add(commitment)
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
                expected_bytes=expected[commitment],
            )
        missing = sorted(set(expected) - seen)
        extra = sorted(seen - set(expected))
        if missing or extra:
            raise ValueError(
                f"{label} paths do not match loaded acquisition evidence; "
                f"missing={missing}, extra={extra}"
            )

    check_exact(
        acquisition_paths,
        expected_acquisitions,
        AcquisitionRecord.from_json_file,
        label="acquisition record",
    )
    check_exact(
        source_paths,
        expected_sources,
        SourceEvidence.from_json_file,
        label="source evidence",
    )
    check_exact(
        source_manifest_paths,
        expected_manifests,
        DatasetSource.from_json_file,
        label="dataset source manifest",
    )


def assemble_split_approved_files(
    *,
    worktree: Path,
    policy_path: Path,
    policy: ApprovalPolicy,
    config_path: Path,
    config: SplitConfig,
    code_bundle_path: Path,
    code_bundle: CodeBundleManifest,
    acquisition_paths: tuple[Path, ...],
    source_paths: tuple[Path, ...],
    source_manifest_paths: tuple[Path, ...],
    adapter_commitment_paths: tuple[Path, ...],
    adapter_commitments: tuple[PublicAdapterCommitment, ...],
    adapter_config_paths: tuple[Path, ...],
    adapter_configs: tuple[AdapterConfig, ...],
) -> tuple[ApprovedFile, ...]:
    """Assemble the exact public path/blob set covered by owner approval."""

    if len(adapter_commitment_paths) != len(adapter_commitments):
        raise ValueError("adapter commitment paths and records differ")
    if len(adapter_config_paths) != len(adapter_configs):
        raise ValueError("adapter config paths and records differ")
    entries: list[tuple[Path, ApprovalFileRole, bytes]] = [
        (policy_path, ApprovalFileRole.POLICY, policy.canonical_bytes()),
        (config_path, ApprovalFileRole.SPLIT_CONFIG, config.canonical_bytes()),
        (
            code_bundle_path,
            ApprovalFileRole.CODE_BUNDLE,
            code_bundle.canonical_bytes(),
        ),
    ]
    entries.extend(
        (
            path,
            ApprovalFileRole.ACQUISITION,
            AcquisitionRecord.from_json_file(path).canonical_bytes(),
        )
        for path in acquisition_paths
    )
    entries.extend(
        (
            path,
            ApprovalFileRole.SOURCE_EVIDENCE,
            SourceEvidence.from_json_file(path).canonical_bytes(),
        )
        for path in source_paths
    )
    entries.extend(
        (
            path,
            ApprovalFileRole.SOURCE_MANIFEST,
            DatasetSource.from_json_file(path).canonical_bytes(),
        )
        for path in source_manifest_paths
    )
    entries.extend(
        (
            path,
            ApprovalFileRole.ADAPTER_COMMITMENT,
            value.canonical_bytes(),
        )
        for path, value in zip(
            adapter_commitment_paths,
            adapter_commitments,
            strict=True,
        )
    )
    entries.extend(
        (
            path,
            ApprovalFileRole.ADAPTER_CONFIG,
            value.canonical_bytes(),
        )
        for path, value in zip(
            adapter_config_paths,
            adapter_configs,
            strict=True,
        )
    )
    implementation = tuple(
        ApprovedFile(
            path=entry.path,
            role=ApprovalFileRole.IMPLEMENTATION_CODE,
            sha256=entry.sha256,
        )
        for entry in code_bundle.files
    )
    return approved_file_set(
        worktree,
        entries,
        implementation_files=implementation,
    )


def canonical_unsplit_jsonl(records: tuple[UnsplitSample, ...]) -> bytes:
    ordered = _validate_local_samples(records)
    return b"".join(canonical_json_line_bytes(item.to_dict()) for item in ordered)


def canonical_private_jsonl(
    records: tuple[PrivateSplitRecord, ...],
) -> bytes:
    ordered = tuple(sorted(records, key=lambda item: item.sample.sample_id))
    sample_ids = [item.sample.sample_id for item in ordered]
    if len(sample_ids) != len(set(sample_ids)):
        raise ValueError("private split sample IDs must be unique")
    return b"".join(canonical_json_line_bytes(item.to_dict()) for item in ordered)


def _validate_local_samples(
    records: tuple[UnsplitSample, ...],
) -> tuple[UnsplitSample, ...]:
    if not records:
        raise ValueError("local sample inventory must not be empty")
    ordered = tuple(sorted(records, key=lambda item: item.sample_id))
    sample_ids = [item.sample_id for item in ordered]
    object_keys = [item.object_key for item in ordered]
    if len(sample_ids) != len(set(sample_ids)):
        raise ValueError("local sample IDs must be globally unique")
    if len(object_keys) != len(set(object_keys)):
        raise ValueError("local sample object keys must be globally unique")
    folded_object_keys = [value.casefold() for value in object_keys]
    if len(folded_object_keys) != len(set(folded_object_keys)):
        raise ValueError(
            "local sample object keys collide under Unicode case folding"
        )
    acquisition_sources: dict[str, tuple[str, str]] = {}
    for sample in ordered:
        source = (sample.dataset_id, sample.dataset_version)
        previous = acquisition_sources.setdefault(sample.acquisition_sha256, source)
        if previous != source:
            raise ValueError(
                "one acquisition commitment cannot identify multiple datasets"
            )
    return ordered


def _private_hmac(
    *,
    key: bytes,
    config_bytes: bytes,
    private_bytes: bytes,
) -> str:
    if len(key) < 32:
        raise ValueError("split commitment key must contain at least 32 bytes")
    digest = hmac.new(key, digestmod=hashlib.sha256)
    digest.update(_HMAC_DOMAIN)
    for payload in (config_bytes, private_bytes):
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
    return digest.hexdigest()


def _validate_split_approval_binding(
    records: tuple[UnsplitSample, ...],
    *,
    config: SplitConfig,
    adapter_commitment_sha256s: tuple[str, ...],
    approval: VerifiedSplitApproval,
    allow_nonproduction: bool,
) -> None:
    if not isinstance(approval, VerifiedSplitApproval):
        raise ValueError("verified owner approval is required for every split")
    if type(allow_nonproduction) is not bool:
        raise ValueError("nonproduction approval mode must be a boolean")
    expected_scope = (
        ApprovalScope.QUARANTINED_RESEARCH
        if allow_nonproduction
        else ApprovalScope.PRODUCTION
    )
    request = approval.approval.request
    acquisitions = tuple(
        sorted({record.acquisition_sha256 for record in records})
    )
    adapters = tuple(sorted(adapter_commitment_sha256s))
    if (
        approval.scope != expected_scope
        or request.split_config_sha256 != config.commitment_sha256
        or request.code_bundle_sha256 != config.splitter_code_sha256
        or request.acquisition_sha256s != acquisitions
        or request.adapter_commitment_sha256s != adapters
    ):
        raise ValueError("verified owner approval differs from the split inputs")


def create_split_artifacts(
    records: tuple[UnsplitSample, ...],
    *,
    seed_key: bytes,
    commitment_key: bytes,
    config: SplitConfig,
    adapter_commitment_sha256s: tuple[str, ...],
    approval: VerifiedSplitApproval,
    allow_nonproduction: bool,
) -> SplitArtifacts:
    if len(seed_key) != 32 or len(commitment_key) != 32:
        raise ValueError("split artifact keys must contain exactly 32 bytes")
    if hmac.compare_digest(seed_key, commitment_key):
        raise ValueError("split seed and commitment keys must be different")
    if (
        split_seed_key_fingerprint(seed_key)
        != approval.seed_key_fingerprint_sha256
        or split_commitment_key_fingerprint(commitment_key)
        != approval.commitment_key_fingerprint_sha256
    ):
        raise ValueError("split artifact keys differ from the owner approval")
    seed = split_seed_from_key(seed_key)
    ordered = _validate_local_samples(records)
    _validate_split_approval_binding(
        ordered,
        config=config,
        adapter_commitment_sha256s=adapter_commitment_sha256s,
        approval=approval,
        allow_nonproduction=allow_nonproduction,
    )
    assignments = assign_writer_splits_weighted(
        (sample.to_sample_key() for sample in ordered),
        seed=seed,
        weights=config.weights,
    )
    evidence: ReleaseSplitEvidence = validate_release_split(
        (sample.to_sample_key() for sample in ordered),
        assignments,
        minimum_writers=config.minimum_writers,
        minimum_samples=config.minimum_samples,
    )
    private_records = tuple(
        PrivateSplitRecord(sample=sample, split=assignments[sample.sample_id])
        for sample in ordered
    )
    private_bytes = canonical_private_jsonl(private_records)
    manifest_hmac = _private_hmac(
        key=commitment_key,
        config_bytes=config.canonical_bytes(),
        private_bytes=private_bytes,
    )
    public = PublicSplitCommitment(
        schema_version=3,
        config=config,
        approval_policy_sha256=approval.policy_sha256,
        split_approval_sha256=approval.approval_sha256,
        approval_scope=approval.scope,
        seed_key_fingerprint_sha256=(
            approval.seed_key_fingerprint_sha256
        ),
        commitment_key_fingerprint_sha256=(
            approval.commitment_key_fingerprint_sha256
        ),
        dataset_ids=tuple(
            sorted(
                {sample.dataset_id for sample in ordered},
                key=lambda value: value.encode("utf-8"),
            )
        ),
        source_acquisition_sha256s=tuple(
            sorted({sample.acquisition_sha256 for sample in ordered})
        ),
        adapter_commitment_sha256s=tuple(
            sorted(adapter_commitment_sha256s)
        ),
        sample_counts=evidence.sample_counts,
        writer_counts=evidence.writer_counts,
        unique_image_counts=evidence.unique_image_counts,
        private_manifest_hmac_sha256=manifest_hmac,
    )
    return SplitArtifacts(
        private_records=private_records,
        private_bytes=private_bytes,
        public=public,
    )


def verify_split_artifacts(
    private_records: tuple[PrivateSplitRecord, ...],
    public: PublicSplitCommitment,
    *,
    seed_key: bytes,
    commitment_key: bytes,
    approval: VerifiedSplitApproval,
    allow_nonproduction: bool,
) -> None:
    expected = create_split_artifacts(
        tuple(record.sample for record in private_records),
        seed_key=seed_key,
        commitment_key=commitment_key,
        config=public.config,
        adapter_commitment_sha256s=public.adapter_commitment_sha256s,
        approval=approval,
        allow_nonproduction=allow_nonproduction,
    )
    actual_private = canonical_private_jsonl(private_records)
    if actual_private != expected.private_bytes:
        raise ValueError("private split assignments do not match the configured seed")
    if public != expected.public:
        raise ValueError("public split commitment does not match the private manifest")


def verify_split_evidence(
    private_records: tuple[PrivateSplitRecord, ...],
    public: PublicSplitCommitment,
    *,
    seed_key: bytes,
    commitment_key: bytes,
    bindings: tuple[AcquisitionBinding, ...],
    adapter_evidence: tuple[VerifiedAdapterEvidence, ...],
    approval: VerifiedSplitApproval,
    allow_nonproduction: bool,
) -> VerifiedSplitEvidence:
    """Verify private bytes, keyed assignment, and exact acquisition inputs."""

    if len(seed_key) != 32 or len(commitment_key) != 32:
        raise ValueError("split verification keys must contain exactly 32 bytes")
    if hmac.compare_digest(seed_key, commitment_key):
        raise ValueError("split seed and commitment keys must be different")
    if not isinstance(approval, VerifiedSplitApproval):
        raise ValueError("verified owner approval is required for every split")
    if (
        public.approval_policy_sha256 != approval.policy_sha256
        or public.split_approval_sha256 != approval.approval_sha256
        or public.approval_scope != approval.scope
        or public.seed_key_fingerprint_sha256
        != approval.seed_key_fingerprint_sha256
        or public.commitment_key_fingerprint_sha256
        != approval.commitment_key_fingerprint_sha256
    ):
        raise ValueError("public split differs from its verified owner approval")
    if not adapter_evidence or any(
        not isinstance(value, VerifiedAdapterEvidence)
        for value in adapter_evidence
    ):
        raise ValueError("verified adapter evidence is required for every split")
    key_fingerprint = adapter_commitment_key_fingerprint(commitment_key)
    if any(
        not hmac.compare_digest(
            value.key_fingerprint_sha256,
            key_fingerprint,
        )
        for value in adapter_evidence
    ):
        raise ValueError(
            "adapter evidence was verified with a different commitment key"
        )
    adapter_commitments = tuple(
        sorted(value.public.commitment_sha256 for value in adapter_evidence)
    )
    if adapter_commitments != public.adapter_commitment_sha256s:
        raise ValueError(
            "verified adapter commitments differ from the public split"
        )
    adapter_acquisitions = tuple(
        sorted(value.public.acquisition_sha256 for value in adapter_evidence)
    )
    if len(adapter_acquisitions) != len(set(adapter_acquisitions)):
        raise ValueError("split has duplicate adapter acquisition evidence")
    if adapter_acquisitions != public.source_acquisition_sha256s:
        raise ValueError(
            "verified adapter acquisitions differ from the public split"
        )
    adapter_dataset_ids = tuple(
        sorted(
            {value.public.dataset_id for value in adapter_evidence},
            key=lambda value: value.encode("utf-8"),
        )
    )
    if adapter_dataset_ids != public.dataset_ids:
        raise ValueError("verified adapter dataset IDs differ from the public split")
    samples = tuple(record.sample for record in private_records)
    validate_acquisition_bindings(
        samples,
        bindings,
        allow_nonproduction=allow_nonproduction,
    )
    verify_split_artifacts(
        private_records,
        public,
        seed_key=seed_key,
        commitment_key=commitment_key,
        approval=approval,
        allow_nonproduction=allow_nonproduction,
    )
    private_bytes = canonical_private_jsonl(private_records)
    return VerifiedSplitEvidence(
        public=public,
        private_manifest_sha256=hashlib.sha256(private_bytes).hexdigest(),
        acquisition_sha256s=tuple(
            sorted(binding.commitment_sha256 for binding in bindings)
        ),
        _token=_VERIFIED_SPLIT_TOKEN,
    )


def read_unsplit_jsonl(path: Path) -> tuple[UnsplitSample, ...]:
    return _read_jsonl(path, UnsplitSample.from_dict, lambda item: item.sample_id)


def read_private_jsonl(path: Path) -> tuple[PrivateSplitRecord, ...]:
    return _read_jsonl(
        path,
        PrivateSplitRecord.from_dict,
        lambda item: item.sample.sample_id,
    )


def _read_jsonl(
    path: Path,
    parser: Callable[[dict[str, object]], _Record],
    identifier: Callable[[_Record], str],
) -> tuple[_Record, ...]:
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise ValueError(f"cannot read JSONL manifest {path}: {error}") from error
    if not raw:
        raise ValueError("JSONL manifest must not be empty")
    lines = raw.splitlines(keepends=True)
    records: list[_Record] = []
    for index, line in enumerate(lines, start=1):
        if not line.endswith(b"\n") or line.endswith(b"\r\n"):
            raise ValueError(f"JSONL line {index} must end with one LF")
        value = _strict_json_object_bytes(line, label=f"JSONL line {index}")
        if line != canonical_json_line_bytes(value):
            raise ValueError(f"JSONL line {index} is not canonical")
        records.append(parser(value))
    identifiers = [identifier(record) for record in records]
    if identifiers != sorted(identifiers):
        raise ValueError("JSONL records must be sorted by sample ID")
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("JSONL sample IDs must be unique")
    return tuple(records)


def _strict_json_object_bytes(raw: bytes, *, label: str) -> dict[str, object]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in {label}: {key}")
            result[key] = value
        return result

    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot parse {label}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _read_strict_json_object(path: Path) -> tuple[dict[str, object], bytes]:
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise ValueError(f"cannot read JSON manifest {path}: {error}") from error
    return _strict_json_object_bytes(raw, label=str(path)), raw
