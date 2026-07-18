"""Canonical evidence binding normalized samples to reviewed source bytes.

The detailed derivation manifest is private because source paths, normalized
object keys, and per-sample content hashes can identify publisher records.  A
separate public commitment exposes only reviewed identities, public adapter
configuration, aggregate counts, and a domain-separated HMAC of the exact
private manifest.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import re
import unicodedata
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path, PurePosixPath, PureWindowsPath
from types import MappingProxyType
from typing import Iterable, Mapping, Protocol

from .acquisition import DirectoryInventory, validate_portable_relative_path
from .provenance import AcquisitionRecord, SourceEvidence, canonical_json_bytes


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_OPAQUE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
_DATASET_ID = re.compile(r"[a-z0-9][a-z0-9_.-]{0,127}\Z")
_ADAPTER_ID = re.compile(r"[a-z0-9][a-z0-9_.-]{0,127}\Z")
_HMAC_DOMAIN = b"rosid-v2-private-adapter-evidence-v1\0"
_KEY_FINGERPRINT_DOMAIN = b"rosid-v2-adapter-key-fingerprint-v1\0"


def _validate_sha256(value: str, *, label: str) -> None:
    if type(value) is not str or not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")


def _validate_opaque_id(value: str, *, label: str) -> None:
    if type(value) is not str or not _OPAQUE_ID.fullmatch(value):
        raise ValueError(f"{label} must be a portable opaque ID")


def _validate_dataset_identity(dataset_id: str, version: str) -> None:
    if type(dataset_id) is not str or not _DATASET_ID.fullmatch(dataset_id):
        raise ValueError("adapter dataset ID must be a portable lowercase token")
    _validate_opaque_id(version, label="adapter dataset version")


def _validate_public_string(value: str, *, label: str) -> str:
    if value != unicodedata.normalize("NFC", value):
        raise ValueError(f"{label} must be NFC-normalized")
    if any(unicodedata.category(character) == "Cc" for character in value):
        raise ValueError(f"{label} must not contain control characters")
    lowered = value.casefold()
    embedded_posix_path = re.search(r"(?:^|[=\s])/(?!/)", value) is not None
    embedded_home_path = re.search(r"(?:^|[=\s])~[/\\]", value) is not None
    if (
        PurePosixPath(value).is_absolute()
        or PureWindowsPath(value).is_absolute()
        or "\\" in value
        or re.search(r"[A-Za-z]:", value) is not None
        or embedded_posix_path
        or embedded_home_path
        or "file:" in lowered
    ):
        raise ValueError(f"{label} must not contain an absolute host path")
    return value


def _freeze_json(value: object, *, label: str) -> object:
    if value is None or type(value) in {bool, int}:
        return value
    if type(value) is str:
        return _validate_public_string(value, label=label)
    if isinstance(value, (list, tuple)):
        return tuple(_freeze_json(item, label=f"{label} array item") for item in value)
    if isinstance(value, Mapping):
        normalized: dict[str, object] = {}
        for key, item in value.items():
            if type(key) is not str:
                raise ValueError(f"{label} object keys must be strings")
            normalized_key = _validate_public_string(key, label=f"{label} key")
            if normalized_key in normalized:
                raise ValueError(f"{label} keys collide after normalization")
            normalized[normalized_key] = _freeze_json(
                item,
                label=f"{label}.{normalized_key}",
            )
        return MappingProxyType(
            {
                key: normalized[key]
                for key in sorted(normalized, key=lambda item: item.encode("utf-8"))
            }
        )
    raise ValueError(
        f"{label} must contain only null, booleans, integers, strings, arrays, "
        "and objects"
    )


def _thaw_json(value: object) -> object:
    if isinstance(value, Mapping):
        return {key: _thaw_json(item) for key, item in value.items()}
    if isinstance(value, tuple):
        return [_thaw_json(item) for item in value]
    return value


def _json_strings(value: object) -> set[str]:
    if type(value) is str:
        return {value}
    if isinstance(value, Mapping):
        result = set(value)
        for item in value.values():
            result.update(_json_strings(item))
        return result
    if isinstance(value, tuple):
        result: set[str] = set()
        for item in value:
            result.update(_json_strings(item))
        return result
    return set()


def _strict_json_object(path: Path, *, label: str) -> tuple[dict[str, object], bytes]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in {label}: {key}")
            result[key] = value
        return result

    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{label} root must be an object")
    return value, raw


def _require_keys(value: dict[str, object], expected: set[str], *, label: str) -> None:
    if set(value) != expected:
        missing = sorted(expected - set(value))
        extra = sorted(set(value) - expected)
        raise ValueError(f"{label} keys differ; missing={missing}, extra={extra}")


@dataclass(frozen=True)
class AdapterConfig:
    """Canonical, public adapter configuration content."""

    schema_version: int
    adapter_id: str
    implementation_paths: tuple[str, ...]
    parameters: Mapping[str, object]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 2:
            raise ValueError(
                f"unsupported adapter-config schema: {self.schema_version}"
            )
        if type(self.adapter_id) is not str or not _ADAPTER_ID.fullmatch(
            self.adapter_id
        ):
            raise ValueError("adapter ID must be a portable lowercase token")
        if not self.implementation_paths:
            raise ValueError("adapter config must name implementation paths")
        if self.implementation_paths != tuple(
            sorted(
                self.implementation_paths,
                key=lambda value: value.encode("utf-8"),
            )
        ):
            raise ValueError("adapter implementation paths must be sorted")
        folded_paths: set[str] = set()
        for path in self.implementation_paths:
            validate_portable_relative_path(path)
            if (
                not path.startswith("ml/rosid_ml/adapters/")
                or not path.endswith(".py")
            ):
                raise ValueError(
                    "adapter implementation paths must be Python files below "
                    "ml/rosid_ml/adapters"
                )
            folded = path.casefold()
            if folded in folded_paths:
                raise ValueError(
                    "adapter implementation paths collide after case folding"
                )
            folded_paths.add(folded)
        if not isinstance(self.parameters, Mapping):
            raise ValueError("adapter config parameters must be an object")
        frozen = _freeze_json(self.parameters, label="adapter config")
        if not isinstance(frozen, Mapping):
            raise AssertionError("adapter config freezing did not return a mapping")
        object.__setattr__(self, "parameters", frozen)

    def to_dict(self) -> dict[str, object]:
        return {
            "adapter_id": self.adapter_id,
            "implementation_paths": list(self.implementation_paths),
            "parameters": _thaw_json(self.parameters),
            "schema_version": self.schema_version,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> AdapterConfig:
        _require_keys(
            value,
            {
                "adapter_id",
                "implementation_paths",
                "parameters",
                "schema_version",
            },
            label="adapter config",
        )
        if type(value["schema_version"]) is not int:
            raise ValueError("adapter config schema_version must be an integer")
        if type(value["adapter_id"]) is not str:
            raise ValueError("adapter config adapter_id must be a string")
        if not isinstance(value["implementation_paths"], list) or any(
            type(item) is not str for item in value["implementation_paths"]
        ):
            raise ValueError(
                "adapter config implementation_paths must be a string list"
            )
        if not isinstance(value["parameters"], dict):
            raise ValueError("adapter config parameters must be an object")
        return cls(
            schema_version=value["schema_version"],
            adapter_id=value["adapter_id"],
            implementation_paths=tuple(value["implementation_paths"]),
            parameters=value["parameters"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> AdapterConfig:
        value, raw = _strict_json_object(path, label="adapter config")
        config = cls.from_dict(value)
        if raw != config.canonical_bytes():
            raise ValueError("adapter config is not canonical UTF-8/LF JSON")
        return config


class SourceDisposition(StrEnum):
    USED = "used"
    IGNORED = "ignored"


class SourceRole(StrEnum):
    IMAGE = "image"
    REFERENCE = "reference"


@dataclass(frozen=True)
class AdapterSourceFile:
    """One exact inventory entry and its explicit adapter disposition."""

    path: str
    bytes: int
    sha256: str
    disposition: SourceDisposition
    ignore_reason: str | None = None

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        if type(self.bytes) is not int or self.bytes < 0:
            raise ValueError("adapter source byte count must be non-negative")
        _validate_sha256(self.sha256, label="adapter source SHA-256")
        if not isinstance(self.disposition, SourceDisposition):
            raise ValueError("adapter source disposition is invalid")
        if self.disposition == SourceDisposition.USED:
            if self.ignore_reason is not None:
                raise ValueError("used adapter sources cannot have an ignore reason")
        elif (
            type(self.ignore_reason) is not str
            or not self.ignore_reason.strip()
            or self.ignore_reason != unicodedata.normalize("NFC", self.ignore_reason)
        ):
            raise ValueError("ignored adapter sources require an NFC reason")

    def to_dict(self) -> dict[str, object]:
        return {
            "bytes": self.bytes,
            "disposition": self.disposition.value,
            "ignore_reason": self.ignore_reason,
            "path": self.path,
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> AdapterSourceFile:
        _require_keys(
            value,
            {"bytes", "disposition", "ignore_reason", "path", "sha256"},
            label="adapter source",
        )
        if type(value["bytes"]) is not int:
            raise ValueError("adapter source bytes must be an integer")
        for field in ("disposition", "path", "sha256"):
            if type(value[field]) is not str:
                raise ValueError(f"adapter source {field} must be a string")
        if (
            value["ignore_reason"] is not None
            and type(value["ignore_reason"]) is not str
        ):
            raise ValueError("adapter source ignore_reason must be a string or null")
        return cls(
            path=value["path"],
            bytes=value["bytes"],
            sha256=value["sha256"],
            disposition=SourceDisposition(value["disposition"]),
            ignore_reason=value["ignore_reason"],
        )


@dataclass(frozen=True)
class SourceUse:
    """An exact source file used to derive image and/or reference bytes."""

    path: str
    sha256: str
    roles: tuple[SourceRole, ...]

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        _validate_sha256(self.sha256, label="source-use SHA-256")
        roles = tuple(self.roles)
        if any(not isinstance(role, SourceRole) for role in roles):
            raise ValueError("source-use roles are invalid")
        canonical = tuple(sorted(set(roles), key=lambda role: role.value))
        if not roles or roles != canonical:
            raise ValueError("source-use roles must be nonempty, unique, and sorted")
        object.__setattr__(self, "roles", roles)

    def to_dict(self) -> dict[str, object]:
        return {
            "path": self.path,
            "roles": [role.value for role in self.roles],
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> SourceUse:
        _require_keys(value, {"path", "roles", "sha256"}, label="source use")
        if type(value["path"]) is not str or type(value["sha256"]) is not str:
            raise ValueError("source-use path and SHA-256 must be strings")
        if not isinstance(value["roles"], list) or any(
            type(role) is not str for role in value["roles"]
        ):
            raise ValueError("source-use roles must be a string array")
        return cls(
            path=value["path"],
            sha256=value["sha256"],
            roles=tuple(SourceRole(role) for role in value["roles"]),
        )


def _validate_source_uses(sources: tuple[SourceUse, ...], *, label: str) -> None:
    if not sources:
        raise ValueError(f"{label} must reference at least one source file")
    if any(not isinstance(source, SourceUse) for source in sources):
        raise ValueError(f"{label} source references are invalid")
    paths = [source.path for source in sources]
    if paths != sorted(paths, key=lambda path: path.encode("utf-8")):
        raise ValueError(f"{label} sources must use canonical UTF-8 path order")
    if len(paths) != len(set(paths)):
        raise ValueError(f"{label} contains duplicate source paths")
    folded = [path.casefold() for path in paths]
    if len(folded) != len(set(folded)):
        raise ValueError(f"{label} source paths collide under Unicode case folding")
    roles = {role for source in sources for role in source.roles}
    if roles != set(SourceRole):
        raise ValueError(f"{label} must bind both image and reference source roles")


@dataclass(frozen=True)
class SampleDerivation:
    """Adapter-declared source derivation for one normalized sample ID."""

    sample_id: str
    sources: tuple[SourceUse, ...]

    def __post_init__(self) -> None:
        _validate_opaque_id(self.sample_id, label="derivation sample ID")
        sources = tuple(self.sources)
        _validate_source_uses(sources, label=f"sample {self.sample_id}")
        object.__setattr__(self, "sources", sources)


@dataclass(frozen=True)
class NormalizedOutputEvidence:
    """Private exact output identity and the source files that derived it."""

    schema_version: int
    sample_id: str
    writer_group_id: str
    object_key: str
    image_sha256: str
    reference_sha256: str
    width: int
    height: int
    token_count: int
    sources: tuple[SourceUse, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported normalized-output schema: {self.schema_version}"
            )
        _validate_opaque_id(self.sample_id, label="normalized sample ID")
        _validate_opaque_id(self.writer_group_id, label="normalized writer-group ID")
        validate_portable_relative_path(self.object_key)
        _validate_sha256(self.image_sha256, label="normalized image SHA-256")
        _validate_sha256(self.reference_sha256, label="normalized reference SHA-256")
        for value, label in (
            (self.width, "normalized output width"),
            (self.height, "normalized output height"),
            (self.token_count, "normalized output token count"),
        ):
            if type(value) is not int or value <= 0:
                raise ValueError(f"{label} must be a positive integer")
        sources = tuple(self.sources)
        _validate_source_uses(sources, label=f"normalized output {self.sample_id}")
        object.__setattr__(self, "sources", sources)

    def to_dict(self) -> dict[str, object]:
        return {
            "height": self.height,
            "image_sha256": self.image_sha256,
            "object_key": self.object_key,
            "reference_sha256": self.reference_sha256,
            "sample_id": self.sample_id,
            "schema_version": self.schema_version,
            "sources": [source.to_dict() for source in self.sources],
            "token_count": self.token_count,
            "width": self.width,
            "writer_group_id": self.writer_group_id,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> NormalizedOutputEvidence:
        _require_keys(
            value,
            {
                "height",
                "image_sha256",
                "object_key",
                "reference_sha256",
                "sample_id",
                "schema_version",
                "sources",
                "token_count",
                "width",
                "writer_group_id",
            },
            label="normalized output",
        )
        for field in (
            "image_sha256",
            "object_key",
            "reference_sha256",
            "sample_id",
            "writer_group_id",
        ):
            if type(value[field]) is not str:
                raise ValueError(f"normalized output {field} must be a string")
        if not isinstance(value["sources"], list) or any(
            not isinstance(source, dict) for source in value["sources"]
        ):
            raise ValueError("normalized output sources must be an object array")
        for field in ("height", "schema_version", "token_count", "width"):
            if type(value[field]) is not int:
                raise ValueError(f"normalized output {field} must be an integer")
        return cls(
            schema_version=value["schema_version"],
            sample_id=value["sample_id"],
            writer_group_id=value["writer_group_id"],
            object_key=value["object_key"],
            image_sha256=value["image_sha256"],
            reference_sha256=value["reference_sha256"],
            width=value["width"],
            height=value["height"],
            token_count=value["token_count"],
            sources=tuple(SourceUse.from_dict(source) for source in value["sources"]),
        )


def _validate_canonical_outputs(outputs: tuple[NormalizedOutputEvidence, ...]) -> None:
    if not outputs:
        raise ValueError("adapter evidence must contain at least one normalized output")
    if any(not isinstance(output, NormalizedOutputEvidence) for output in outputs):
        raise ValueError("adapter outputs must be normalized-output evidence records")
    sample_ids = [output.sample_id for output in outputs]
    if sample_ids != sorted(sample_ids, key=lambda item: item.encode("utf-8")):
        raise ValueError("adapter outputs must use canonical UTF-8 sample-ID order")
    if len(sample_ids) != len(set(sample_ids)):
        raise ValueError("adapter outputs contain duplicate sample IDs")
    folded_ids = [sample_id.casefold() for sample_id in sample_ids]
    if len(folded_ids) != len(set(folded_ids)):
        raise ValueError("adapter sample IDs collide under Unicode case folding")
    object_keys = [output.object_key for output in outputs]
    if len(object_keys) != len(set(object_keys)):
        raise ValueError("adapter outputs contain duplicate object keys")
    folded_keys = [object_key.casefold() for object_key in object_keys]
    if len(folded_keys) != len(set(folded_keys)):
        raise ValueError("adapter object keys collide under Unicode case folding")


def _validate_canonical_sources(sources: tuple[AdapterSourceFile, ...]) -> None:
    if not sources:
        raise ValueError("adapter evidence must contain its source inventory")
    if any(not isinstance(source, AdapterSourceFile) for source in sources):
        raise ValueError("adapter source inventory contains invalid entries")
    paths = [source.path for source in sources]
    if paths != sorted(paths, key=lambda path: path.encode("utf-8")):
        raise ValueError("adapter source inventory must use canonical UTF-8 path order")
    if len(paths) != len(set(paths)):
        raise ValueError("adapter source inventory contains duplicate paths")
    folded = [path.casefold() for path in paths]
    if len(folded) != len(set(folded)):
        raise ValueError(
            "adapter source inventory paths collide under Unicode case folding"
        )


@dataclass(frozen=True)
class AdapterEvidence:
    """Private canonical adapter evidence containing all derivation details."""

    schema_version: int
    dataset_id: str
    dataset_version: str
    acquisition_sha256: str
    directory_inventory_sha256: str
    adapter_code_bundle_sha256: str
    adapter_config: AdapterConfig
    adapter_config_sha256: str
    source_files: tuple[AdapterSourceFile, ...]
    outputs: tuple[NormalizedOutputEvidence, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported adapter-evidence schema: {self.schema_version}"
            )
        _validate_dataset_identity(self.dataset_id, self.dataset_version)
        _validate_sha256(self.acquisition_sha256, label="adapter acquisition SHA-256")
        _validate_sha256(
            self.directory_inventory_sha256,
            label="adapter directory-inventory SHA-256",
        )
        _validate_sha256(
            self.adapter_code_bundle_sha256,
            label="adapter code-bundle SHA-256",
        )
        if not isinstance(self.adapter_config, AdapterConfig):
            raise ValueError("adapter evidence config must be an AdapterConfig")
        _validate_sha256(
            self.adapter_config_sha256,
            label="adapter config SHA-256",
        )
        if not hmac.compare_digest(
            self.adapter_config_sha256,
            self.adapter_config.commitment_sha256,
        ):
            raise ValueError("adapter config content differs from its SHA-256")
        sources = tuple(self.source_files)
        outputs = tuple(self.outputs)
        _validate_canonical_sources(sources)
        _validate_canonical_outputs(outputs)
        object.__setattr__(self, "source_files", sources)
        object.__setattr__(self, "outputs", outputs)
        self._validate_source_coverage()

    def _validate_source_coverage(self) -> None:
        source_by_path = {source.path: source for source in self.source_files}
        used_paths: set[str] = set()
        for output in self.outputs:
            for source_use in output.sources:
                try:
                    source = source_by_path[source_use.path]
                except KeyError as error:
                    raise ValueError(
                        f"normalized output references an extra source: "
                        f"{source_use.path}"
                    ) from error
                if source.disposition != SourceDisposition.USED:
                    raise ValueError(
                        f"normalized output references an ignored source: "
                        f"{source_use.path}"
                    )
                if not hmac.compare_digest(source.sha256, source_use.sha256):
                    raise ValueError(
                        f"normalized output source hash differs from inventory: "
                        f"{source_use.path}"
                    )
                used_paths.add(source_use.path)
        declared_used = {
            source.path
            for source in self.source_files
            if source.disposition == SourceDisposition.USED
        }
        missing = sorted(declared_used - used_paths)
        extra = sorted(used_paths - declared_used)
        if missing or extra:
            raise ValueError(
                "normalized outputs and used source inventory differ; "
                f"missing={missing}, extra={extra}"
            )

    def to_dict(self) -> dict[str, object]:
        return {
            "acquisition_sha256": self.acquisition_sha256,
            "adapter_code_bundle_sha256": self.adapter_code_bundle_sha256,
            "adapter_config": self.adapter_config.to_dict(),
            "adapter_config_sha256": self.adapter_config_sha256,
            "dataset_id": self.dataset_id,
            "dataset_version": self.dataset_version,
            "directory_inventory_sha256": self.directory_inventory_sha256,
            "outputs": [output.to_dict() for output in self.outputs],
            "schema_version": self.schema_version,
            "source_files": [source.to_dict() for source in self.source_files],
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> AdapterEvidence:
        expected = {
            "acquisition_sha256",
            "adapter_code_bundle_sha256",
            "adapter_config",
            "adapter_config_sha256",
            "dataset_id",
            "dataset_version",
            "directory_inventory_sha256",
            "outputs",
            "schema_version",
            "source_files",
        }
        _require_keys(value, expected, label="adapter evidence")
        if type(value["schema_version"]) is not int:
            raise ValueError("adapter evidence schema_version must be an integer")
        for field in expected - {
            "adapter_config",
            "outputs",
            "schema_version",
            "source_files",
        }:
            if type(value[field]) is not str:
                raise ValueError(f"adapter evidence {field} must be a string")
        if not isinstance(value["adapter_config"], dict):
            raise ValueError("adapter evidence config must be an object")
        for field in ("outputs", "source_files"):
            if not isinstance(value[field], list) or any(
                not isinstance(item, dict) for item in value[field]
            ):
                raise ValueError(f"adapter evidence {field} must be an object array")
        return cls(
            schema_version=value["schema_version"],
            dataset_id=value["dataset_id"],
            dataset_version=value["dataset_version"],
            acquisition_sha256=value["acquisition_sha256"],
            directory_inventory_sha256=value["directory_inventory_sha256"],
            adapter_code_bundle_sha256=value["adapter_code_bundle_sha256"],
            adapter_config=AdapterConfig.from_dict(value["adapter_config"]),
            adapter_config_sha256=value["adapter_config_sha256"],
            source_files=tuple(
                AdapterSourceFile.from_dict(item) for item in value["source_files"]
            ),
            outputs=tuple(
                NormalizedOutputEvidence.from_dict(item) for item in value["outputs"]
            ),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> AdapterEvidence:
        value, raw = _strict_json_object(path, label="adapter evidence")
        evidence = cls.from_dict(value)
        if raw != evidence.canonical_bytes():
            raise ValueError("adapter evidence is not canonical UTF-8/LF JSON")
        return evidence


@dataclass(frozen=True)
class PublicAdapterCommitment:
    """Path-free public commitment to one exact private adapter manifest."""

    schema_version: int
    dataset_id: str
    dataset_version: str
    acquisition_sha256: str
    directory_inventory_sha256: str
    adapter_code_bundle_sha256: str
    adapter_config: AdapterConfig
    adapter_config_sha256: str
    output_count: int
    source_file_count: int
    used_source_file_count: int
    ignored_source_file_count: int
    private_evidence_hmac_sha256: str

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported public-adapter schema: {self.schema_version}"
            )
        _validate_dataset_identity(self.dataset_id, self.dataset_version)
        for value, label in (
            (self.acquisition_sha256, "public adapter acquisition SHA-256"),
            (
                self.directory_inventory_sha256,
                "public adapter directory-inventory SHA-256",
            ),
            (
                self.adapter_code_bundle_sha256,
                "public adapter code-bundle SHA-256",
            ),
            (self.adapter_config_sha256, "public adapter config SHA-256"),
            (
                self.private_evidence_hmac_sha256,
                "private adapter-evidence HMAC-SHA256",
            ),
        ):
            _validate_sha256(value, label=label)
        if not isinstance(self.adapter_config, AdapterConfig):
            raise ValueError("public adapter config must be an AdapterConfig")
        if not hmac.compare_digest(
            self.adapter_config_sha256,
            self.adapter_config.commitment_sha256,
        ):
            raise ValueError("public adapter config content differs from its SHA-256")
        for value, label in (
            (self.output_count, "public adapter output count"),
            (self.source_file_count, "public adapter source-file count"),
            (self.used_source_file_count, "public adapter used-source count"),
            (self.ignored_source_file_count, "public adapter ignored-source count"),
        ):
            if type(value) is not int or value < 0:
                raise ValueError(f"{label} must be a non-negative integer")
        if self.output_count == 0 or self.source_file_count == 0:
            raise ValueError("public adapter output/source counts must be nonzero")
        if (
            self.used_source_file_count + self.ignored_source_file_count
            != self.source_file_count
        ):
            raise ValueError("public adapter source counts are inconsistent")
        if self.used_source_file_count == 0:
            raise ValueError(
                "public adapter evidence must use at least one source file"
            )

    def to_dict(self) -> dict[str, object]:
        return {
            "acquisition_sha256": self.acquisition_sha256,
            "adapter_code_bundle_sha256": self.adapter_code_bundle_sha256,
            "adapter_config": self.adapter_config.to_dict(),
            "adapter_config_sha256": self.adapter_config_sha256,
            "dataset_id": self.dataset_id,
            "dataset_version": self.dataset_version,
            "directory_inventory_sha256": self.directory_inventory_sha256,
            "ignored_source_file_count": self.ignored_source_file_count,
            "output_count": self.output_count,
            "private_evidence_hmac_sha256": self.private_evidence_hmac_sha256,
            "schema_version": self.schema_version,
            "source_file_count": self.source_file_count,
            "used_source_file_count": self.used_source_file_count,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> PublicAdapterCommitment:
        expected = {
            "acquisition_sha256",
            "adapter_code_bundle_sha256",
            "adapter_config",
            "adapter_config_sha256",
            "dataset_id",
            "dataset_version",
            "directory_inventory_sha256",
            "ignored_source_file_count",
            "output_count",
            "private_evidence_hmac_sha256",
            "schema_version",
            "source_file_count",
            "used_source_file_count",
        }
        _require_keys(value, expected, label="public adapter commitment")
        integer_fields = {
            "ignored_source_file_count",
            "output_count",
            "schema_version",
            "source_file_count",
            "used_source_file_count",
        }
        if any(type(value[field]) is not int for field in integer_fields):
            raise ValueError("public adapter counts and schema must be integers")
        for field in expected - integer_fields - {"adapter_config"}:
            if type(value[field]) is not str:
                raise ValueError(f"public adapter {field} must be a string")
        if not isinstance(value["adapter_config"], dict):
            raise ValueError("public adapter config must be an object")
        return cls(
            schema_version=value["schema_version"],
            dataset_id=value["dataset_id"],
            dataset_version=value["dataset_version"],
            acquisition_sha256=value["acquisition_sha256"],
            directory_inventory_sha256=value["directory_inventory_sha256"],
            adapter_code_bundle_sha256=value["adapter_code_bundle_sha256"],
            adapter_config=AdapterConfig.from_dict(value["adapter_config"]),
            adapter_config_sha256=value["adapter_config_sha256"],
            output_count=value["output_count"],
            source_file_count=value["source_file_count"],
            used_source_file_count=value["used_source_file_count"],
            ignored_source_file_count=value["ignored_source_file_count"],
            private_evidence_hmac_sha256=value["private_evidence_hmac_sha256"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> PublicAdapterCommitment:
        value, raw = _strict_json_object(path, label="public adapter commitment")
        commitment = cls.from_dict(value)
        if raw != commitment.canonical_bytes():
            raise ValueError("public adapter commitment is not canonical UTF-8/LF JSON")
        return commitment


class NormalizedSample(Protocol):
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


@dataclass(frozen=True)
class _SampleIdentity:
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


def _sample_identity(sample: NormalizedSample) -> _SampleIdentity:
    fields: dict[str, str] = {}
    for field in (
        "sample_id",
        "dataset_id",
        "dataset_version",
        "acquisition_sha256",
        "writer_group_id",
        "object_key",
        "image_sha256",
        "reference_sha256",
    ):
        value = getattr(sample, field, None)
        if type(value) is not str:
            raise ValueError(f"normalized sample {field} must be a string")
        fields[field] = value
    _validate_opaque_id(fields["sample_id"], label="normalized sample ID")
    _validate_opaque_id(
        fields["writer_group_id"],
        label="normalized writer-group ID",
    )
    _validate_dataset_identity(fields["dataset_id"], fields["dataset_version"])
    _validate_sha256(fields["acquisition_sha256"], label="sample acquisition SHA-256")
    validate_portable_relative_path(fields["object_key"])
    _validate_sha256(fields["image_sha256"], label="sample image SHA-256")
    _validate_sha256(fields["reference_sha256"], label="sample reference SHA-256")
    integer_fields: dict[str, int] = {}
    for field in ("schema_version", "width", "height", "token_count"):
        value = getattr(sample, field, None)
        if type(value) is not int:
            raise ValueError(f"normalized sample {field} must be an integer")
        integer_fields[field] = value
    if integer_fields["schema_version"] != 1:
        raise ValueError(
            f"unsupported normalized-sample schema: {integer_fields['schema_version']}"
        )
    for field in ("width", "height", "token_count"):
        if integer_fields[field] <= 0:
            raise ValueError(f"normalized sample {field} must be positive")
    return _SampleIdentity(**integer_fields, **fields)


def _materialize_samples(
    samples: Iterable[NormalizedSample],
) -> tuple[_SampleIdentity, ...]:
    values = tuple(_sample_identity(sample) for sample in samples)
    if not values:
        raise ValueError("adapter evidence requires at least one normalized sample")
    ids = [sample.sample_id for sample in values]
    if len(ids) != len(set(ids)):
        raise ValueError("normalized samples contain duplicate sample IDs")
    folded_ids = [sample_id.casefold() for sample_id in ids]
    if len(folded_ids) != len(set(folded_ids)):
        raise ValueError("normalized sample IDs collide under Unicode case folding")
    object_keys = [sample.object_key for sample in values]
    if len(object_keys) != len(set(object_keys)):
        raise ValueError("normalized samples contain duplicate object keys")
    folded_keys = [object_key.casefold() for object_key in object_keys]
    if len(folded_keys) != len(set(folded_keys)):
        raise ValueError("normalized object keys collide under Unicode case folding")
    return tuple(sorted(values, key=lambda sample: sample.sample_id.encode("utf-8")))


def _validate_public_config_privacy(
    config: AdapterConfig,
    *,
    samples: tuple[NormalizedSample, ...],
    inventory: DirectoryInventory,
) -> None:
    private_values = {
        value
        for sample in samples
        for value in (
            getattr(sample, "sample_id", None),
            getattr(sample, "object_key", None),
            getattr(sample, "image_sha256", None),
            getattr(sample, "reference_sha256", None),
            getattr(sample, "writer_group_id", None),
        )
        if type(value) is str
    }
    private_values.update(entry.path for entry in inventory.files)
    private_values.update(entry.sha256 for entry in inventory.files)
    leaked = sorted(_json_strings(config.parameters) & private_values)
    if leaked:
        raise ValueError(
            "public adapter config contains private sample/source identifiers"
        )


def _materialize_derivations(
    derivations: Iterable[SampleDerivation],
) -> dict[str, SampleDerivation]:
    values = tuple(derivations)
    if any(not isinstance(value, SampleDerivation) for value in values):
        raise ValueError("adapter derivations must be SampleDerivation records")
    ids = [value.sample_id for value in values]
    if len(ids) != len(set(ids)):
        raise ValueError("adapter derivations contain duplicate sample IDs")
    folded_ids = [sample_id.casefold() for sample_id in ids]
    if len(folded_ids) != len(set(folded_ids)):
        raise ValueError("adapter derivation IDs collide under Unicode case folding")
    return {value.sample_id: value for value in values}


def _validate_external_identity(
    *,
    source: SourceEvidence,
    acquisition: AcquisitionRecord,
    inventory: DirectoryInventory,
) -> tuple[str, str, str]:
    if not isinstance(source, SourceEvidence):
        raise ValueError("adapter source must be SourceEvidence")
    if not isinstance(acquisition, AcquisitionRecord):
        raise ValueError("adapter acquisition must be an AcquisitionRecord")
    if not isinstance(inventory, DirectoryInventory):
        raise ValueError("adapter inventory must be a DirectoryInventory")
    acquisition.validate_source(source)
    if source.artifact_type != "dataset" or source.dataset_id is None:
        raise ValueError("adapter evidence requires dataset source evidence")
    if (
        acquisition.artifact_type != "dataset"
        or acquisition.artifact_role != "extracted_dataset"
    ):
        raise ValueError("adapter evidence requires an extracted dataset acquisition")
    if not hmac.compare_digest(
        acquisition.inventory_sha256,
        inventory.commitment_sha256,
    ):
        raise ValueError("acquisition differs from the directory inventory commitment")
    if not hmac.compare_digest(
        acquisition.artifact_sha256,
        inventory.artifact_sha256,
    ):
        raise ValueError("acquisition differs from the inventoried artifact bytes")
    return source.dataset_id, source.version, acquisition.commitment_sha256


def _private_hmac(key: bytes, private_bytes: bytes) -> str:
    if type(key) is not bytes or len(key) < 32:
        raise ValueError("adapter commitment key must contain at least 32 bytes")
    digest = hmac.new(key, digestmod=hashlib.sha256)
    digest.update(_HMAC_DOMAIN)
    digest.update(len(private_bytes).to_bytes(8, "big"))
    digest.update(private_bytes)
    return digest.hexdigest()


def adapter_commitment_key_fingerprint(key: bytes) -> str:
    """Return a domain-separated in-memory binding to an adapter HMAC key."""

    if type(key) is not bytes or len(key) < 32:
        raise ValueError("adapter commitment key must contain at least 32 bytes")
    return hashlib.sha256(_KEY_FINGERPRINT_DOMAIN + key).hexdigest()


def _public_from_private(
    private: AdapterEvidence,
    *,
    commitment_key: bytes,
) -> PublicAdapterCommitment:
    used = sum(
        source.disposition == SourceDisposition.USED for source in private.source_files
    )
    ignored = len(private.source_files) - used
    return PublicAdapterCommitment(
        schema_version=1,
        dataset_id=private.dataset_id,
        dataset_version=private.dataset_version,
        acquisition_sha256=private.acquisition_sha256,
        directory_inventory_sha256=private.directory_inventory_sha256,
        adapter_code_bundle_sha256=private.adapter_code_bundle_sha256,
        adapter_config=private.adapter_config,
        adapter_config_sha256=private.adapter_config_sha256,
        output_count=len(private.outputs),
        source_file_count=len(private.source_files),
        used_source_file_count=used,
        ignored_source_file_count=ignored,
        private_evidence_hmac_sha256=_private_hmac(
            commitment_key,
            private.canonical_bytes(),
        ),
    )


@dataclass(frozen=True)
class AdapterEvidenceArtifacts:
    private: AdapterEvidence
    public: PublicAdapterCommitment


_VERIFIED_ADAPTER_TOKEN = object()


@dataclass(frozen=True, init=False)
class VerifiedAdapterEvidence:
    """Capability returned only after exact private adapter verification."""

    public: PublicAdapterCommitment
    private_evidence_sha256: str
    key_fingerprint_sha256: str

    def __init__(
        self,
        *,
        public: PublicAdapterCommitment,
        private_evidence_sha256: str,
        key_fingerprint_sha256: str,
        _token: object,
    ) -> None:
        if _token is not _VERIFIED_ADAPTER_TOKEN:
            raise ValueError(
                "verified adapter evidence must come from adapter verification"
            )
        _validate_sha256(
            private_evidence_sha256,
            label="private adapter-evidence SHA-256",
        )
        _validate_sha256(
            key_fingerprint_sha256,
            label="adapter commitment-key fingerprint",
        )
        object.__setattr__(self, "public", public)
        object.__setattr__(
            self,
            "private_evidence_sha256",
            private_evidence_sha256,
        )
        object.__setattr__(
            self,
            "key_fingerprint_sha256",
            key_fingerprint_sha256,
        )


def create_adapter_evidence(
    *,
    source: SourceEvidence,
    acquisition: AcquisitionRecord,
    inventory: DirectoryInventory,
    adapter_code_bundle_sha256: str,
    adapter_config: AdapterConfig,
    normalized_samples: Iterable[NormalizedSample],
    derivations: Iterable[SampleDerivation],
    ignored_source_files: Mapping[str, str],
    commitment_key: bytes,
) -> AdapterEvidenceArtifacts:
    """Create exact private derivations and their path-free public commitment."""

    dataset_id, dataset_version, acquisition_sha256 = _validate_external_identity(
        source=source,
        acquisition=acquisition,
        inventory=inventory,
    )
    _validate_sha256(
        adapter_code_bundle_sha256,
        label="adapter code-bundle SHA-256",
    )
    if not isinstance(adapter_config, AdapterConfig):
        raise ValueError("adapter_config must be an AdapterConfig")
    sample_values = tuple(normalized_samples)
    samples = _materialize_samples(sample_values)
    _validate_public_config_privacy(
        adapter_config,
        samples=sample_values,
        inventory=inventory,
    )
    derivation_by_id = _materialize_derivations(derivations)
    sample_ids = {sample.sample_id for sample in samples}
    derivation_ids = set(derivation_by_id)
    missing_outputs = sorted(sample_ids - derivation_ids)
    extra_outputs = sorted(derivation_ids - sample_ids)
    if missing_outputs or extra_outputs:
        raise ValueError(
            "normalized samples and derivations differ; "
            f"missing={missing_outputs}, extra={extra_outputs}"
        )

    inventory_by_path = {entry.path: entry for entry in inventory.files}
    used_paths: set[str] = set()
    outputs: list[NormalizedOutputEvidence] = []
    for sample in samples:
        if (
            sample.dataset_id != dataset_id
            or sample.dataset_version != dataset_version
            or not hmac.compare_digest(
                sample.acquisition_sha256,
                acquisition_sha256,
            )
        ):
            raise ValueError(
                f"normalized sample identity differs from its acquisition: "
                f"{sample.sample_id}"
            )
        derivation = derivation_by_id[sample.sample_id]
        for source_use in derivation.sources:
            try:
                entry = inventory_by_path[source_use.path]
            except KeyError as error:
                raise ValueError(
                    f"adapter derivation references an extra source: {source_use.path}"
                ) from error
            if not hmac.compare_digest(entry.sha256, source_use.sha256):
                raise ValueError(
                    f"adapter derivation source hash differs from inventory: "
                    f"{source_use.path}"
                )
            used_paths.add(source_use.path)
        outputs.append(
            NormalizedOutputEvidence(
                schema_version=sample.schema_version,
                sample_id=sample.sample_id,
                writer_group_id=sample.writer_group_id,
                object_key=sample.object_key,
                image_sha256=sample.image_sha256,
                reference_sha256=sample.reference_sha256,
                width=sample.width,
                height=sample.height,
                token_count=sample.token_count,
                sources=derivation.sources,
            )
        )

    if not isinstance(ignored_source_files, Mapping):
        raise ValueError("ignored_source_files must be a path-to-reason mapping")
    ignored: dict[str, str] = {}
    for path, reason in ignored_source_files.items():
        if type(path) is not str or type(reason) is not str:
            raise ValueError("ignored source paths and reasons must be strings")
        validate_portable_relative_path(path)
        if path in ignored:
            raise ValueError(f"duplicate ignored source path: {path}")
        ignored[path] = reason
    folded_ignored = [path.casefold() for path in ignored]
    if len(folded_ignored) != len(set(folded_ignored)):
        raise ValueError("ignored source paths collide under Unicode case folding")
    ignored_paths = set(ignored)
    overlap = sorted(used_paths & ignored_paths)
    missing_sources = sorted(set(inventory_by_path) - used_paths - ignored_paths)
    extra_sources = sorted((used_paths | ignored_paths) - set(inventory_by_path))
    if overlap or missing_sources or extra_sources:
        raise ValueError(
            "adapter source coverage is not exact; "
            f"used_and_ignored={overlap}, missing={missing_sources}, "
            f"extra={extra_sources}"
        )

    source_files = tuple(
        AdapterSourceFile(
            path=entry.path,
            bytes=entry.bytes,
            sha256=entry.sha256,
            disposition=(
                SourceDisposition.USED
                if entry.path in used_paths
                else SourceDisposition.IGNORED
            ),
            ignore_reason=ignored.get(entry.path),
        )
        for entry in inventory.files
    )
    private = AdapterEvidence(
        schema_version=1,
        dataset_id=dataset_id,
        dataset_version=dataset_version,
        acquisition_sha256=acquisition_sha256,
        directory_inventory_sha256=inventory.commitment_sha256,
        adapter_code_bundle_sha256=adapter_code_bundle_sha256,
        adapter_config=adapter_config,
        adapter_config_sha256=adapter_config.commitment_sha256,
        source_files=source_files,
        outputs=tuple(outputs),
    )
    return AdapterEvidenceArtifacts(
        private=private,
        public=_public_from_private(private, commitment_key=commitment_key),
    )


def verify_adapter_evidence(
    private: AdapterEvidence,
    public: PublicAdapterCommitment,
    *,
    source: SourceEvidence,
    acquisition: AcquisitionRecord,
    inventory: DirectoryInventory,
    normalized_samples: Iterable[NormalizedSample],
    commitment_key: bytes,
    expected_code_bundle_sha256: str,
    expected_config_sha256: str,
) -> VerifiedAdapterEvidence:
    """Fail closed unless private, public, source, and outputs match exactly."""

    if not isinstance(private, AdapterEvidence):
        raise ValueError("private adapter evidence has an invalid type")
    if not isinstance(public, PublicAdapterCommitment):
        raise ValueError("public adapter commitment has an invalid type")
    dataset_id, dataset_version, acquisition_sha256 = _validate_external_identity(
        source=source,
        acquisition=acquisition,
        inventory=inventory,
    )
    _validate_sha256(
        expected_code_bundle_sha256,
        label="expected adapter code-bundle SHA-256",
    )
    _validate_sha256(
        expected_config_sha256,
        label="expected adapter config SHA-256",
    )
    if (
        private.dataset_id != dataset_id
        or private.dataset_version != dataset_version
        or not hmac.compare_digest(private.acquisition_sha256, acquisition_sha256)
        or not hmac.compare_digest(
            private.directory_inventory_sha256,
            inventory.commitment_sha256,
        )
    ):
        raise ValueError("private adapter evidence contradicts acquisition identity")
    if not hmac.compare_digest(
        private.adapter_code_bundle_sha256,
        expected_code_bundle_sha256,
    ):
        raise ValueError("adapter code bundle differs from the approved SHA-256")
    if not hmac.compare_digest(
        private.adapter_config_sha256,
        expected_config_sha256,
    ):
        raise ValueError("adapter config differs from the approved SHA-256")

    expected_sources = tuple(
        (entry.path, entry.bytes, entry.sha256) for entry in inventory.files
    )
    actual_sources = tuple(
        (entry.path, entry.bytes, entry.sha256) for entry in private.source_files
    )
    if actual_sources != expected_sources:
        raise ValueError(
            "adapter source inventory differs from exact directory inventory"
        )

    sample_values = tuple(normalized_samples)
    samples = _materialize_samples(sample_values)
    _validate_public_config_privacy(
        private.adapter_config,
        samples=sample_values,
        inventory=inventory,
    )
    expected_outputs = tuple(
        (
            sample.schema_version,
            sample.sample_id,
            sample.writer_group_id,
            sample.object_key,
            sample.image_sha256,
            sample.reference_sha256,
            sample.width,
            sample.height,
            sample.token_count,
        )
        for sample in samples
    )
    actual_outputs = tuple(
        (
            output.schema_version,
            output.sample_id,
            output.writer_group_id,
            output.object_key,
            output.image_sha256,
            output.reference_sha256,
            output.width,
            output.height,
            output.token_count,
        )
        for output in private.outputs
    )
    if actual_outputs != expected_outputs:
        expected_ids = {item[1] for item in expected_outputs}
        actual_ids = {item[1] for item in actual_outputs}
        raise ValueError(
            "adapter evidence and normalized outputs differ; "
            f"missing={sorted(expected_ids - actual_ids)}, "
            f"extra={sorted(actual_ids - expected_ids)}"
        )
    for sample in samples:
        if (
            sample.dataset_id != dataset_id
            or sample.dataset_version != dataset_version
            or not hmac.compare_digest(sample.acquisition_sha256, acquisition_sha256)
        ):
            raise ValueError(
                f"normalized sample identity differs from its acquisition: "
                f"{sample.sample_id}"
            )

    expected_public = _public_from_private(private, commitment_key=commitment_key)
    if public != expected_public:
        raise ValueError("public adapter commitment differs from private evidence")
    return VerifiedAdapterEvidence(
        public=public,
        private_evidence_sha256=hashlib.sha256(
            private.canonical_bytes()
        ).hexdigest(),
        key_fingerprint_sha256=adapter_commitment_key_fingerprint(
            commitment_key
        ),
        _token=_VERIFIED_ADAPTER_TOKEN,
    )


__all__ = [
    "AdapterConfig",
    "AdapterEvidence",
    "AdapterEvidenceArtifacts",
    "AdapterSourceFile",
    "NormalizedOutputEvidence",
    "NormalizedSample",
    "PublicAdapterCommitment",
    "SampleDerivation",
    "SourceDisposition",
    "SourceRole",
    "SourceUse",
    "VerifiedAdapterEvidence",
    "adapter_commitment_key_fingerprint",
    "create_adapter_evidence",
    "verify_adapter_evidence",
]
