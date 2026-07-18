"""Strict source/acquisition evidence with canonical cross-platform bytes."""

from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from pathlib import Path
from urllib.parse import urlparse


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_ARTIFACT_TOKEN = re.compile(r"[a-z0-9][a-z0-9_.-]*\Z")
_CANONICAL_UTC = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\Z")


class Eligibility(StrEnum):
    PRODUCTION = "production"
    CONDITIONAL = "conditional"
    RESEARCH_ONLY = "research_only"
    EXCLUDED = "excluded"


_ELIGIBILITY_RESTRICTIVENESS = {
    Eligibility.PRODUCTION: 0,
    Eligibility.CONDITIONAL: 1,
    Eligibility.RESEARCH_ONLY: 2,
    Eligibility.EXCLUDED: 3,
}


def eligibility_restrictiveness(value: Eligibility) -> int:
    return _ELIGIBILITY_RESTRICTIVENESS[value]


def canonical_json_bytes(value: object) -> bytes:
    """Return the only JSON serialization whose SHA may enter lineage."""

    normalized = _normalize_json_unicode(value)
    return (
        json.dumps(
            normalized,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def _normalize_json_unicode(value: object) -> object:
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)
    if isinstance(value, dict):
        normalized: dict[str, object] = {}
        for key, item in value.items():
            if type(key) is not str:
                raise ValueError("canonical JSON object keys must be strings")
            normalized_key = unicodedata.normalize("NFC", key)
            if normalized_key in normalized:
                raise ValueError(
                    "canonical JSON object keys collide after NFC normalization"
                )
            normalized[normalized_key] = _normalize_json_unicode(item)
        return normalized
    if isinstance(value, (list, tuple)):
        return [_normalize_json_unicode(item) for item in value]
    return value


def _sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _validate_sha256(value: str, *, label: str) -> None:
    if not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")


def _strict_json_object(path: Path) -> tuple[dict[str, object], bytes]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read JSON manifest {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError("manifest root must be an object")
    return value, raw


def _require_exact_keys(value: dict[str, object], expected: set[str]) -> None:
    if set(value) != expected:
        missing = sorted(expected - set(value))
        extra = sorted(set(value) - expected)
        raise ValueError(f"manifest keys differ; missing={missing}, extra={extra}")


def _validate_source_fields(
    *,
    source_url: str,
    version: str,
    license_id: str,
    attribution: str,
    rights_notes: str,
) -> None:
    parsed = urlparse(source_url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise ValueError("source must be an absolute HTTPS URL")
    if not version.strip() or not license_id.strip():
        raise ValueError("source version and license are required")
    if not attribution.strip() or not rights_notes.strip():
        raise ValueError("attribution and rights notes are required")


@dataclass(frozen=True)
class SourceEvidence:
    """Reviewed publisher/license evidence for any external input bytes."""

    schema_version: int
    evidence_id: str
    dataset_id: str | None
    doi: str | None
    source_manifest_sha256: str | None
    source_url: str
    version: str
    license_id: str
    content_sha256: str
    artifact_type: str
    artifact_role: str
    eligibility: Eligibility
    attribution: str
    rights_notes: str

    def __post_init__(self) -> None:
        if self.schema_version != 2:
            raise ValueError(
                f"unsupported source-evidence schema: {self.schema_version}"
            )
        if not self.evidence_id or any(
            character.isspace() for character in self.evidence_id
        ):
            raise ValueError("evidence ID must be nonempty and contain no whitespace")
        _validate_source_fields(
            source_url=self.source_url,
            version=self.version,
            license_id=self.license_id,
            attribution=self.attribution,
            rights_notes=self.rights_notes,
        )
        _validate_sha256(self.content_sha256, label="source content SHA-256")
        for value, label in (
            (self.artifact_type, "source artifact type"),
            (self.artifact_role, "source artifact role"),
        ):
            if not _ARTIFACT_TOKEN.fullmatch(value):
                raise ValueError(f"{label} must be a portable lowercase token")
        if self.dataset_id is None:
            if self.doi is not None or self.source_manifest_sha256 is not None:
                raise ValueError(
                    "dataset DOI/manifest commitment require a dataset ID"
                )
        else:
            if not self.dataset_id.strip():
                raise ValueError("source-evidence dataset ID must be nonempty")
            if self.doi is not None and not self.doi.startswith("10."):
                raise ValueError("source-evidence DOI must start with '10.' or be null")
            if self.source_manifest_sha256 is None:
                raise ValueError(
                    "dataset source evidence requires its source-manifest commitment"
                )
            _validate_sha256(
                self.source_manifest_sha256,
                label="source-manifest SHA-256",
            )
        if self.artifact_type == "dataset" and self.dataset_id is None:
            raise ValueError("dataset source evidence requires structured dataset metadata")

    def to_dict(self) -> dict[str, object]:
        return {
            "artifact_role": self.artifact_role,
            "artifact_type": self.artifact_type,
            "attribution": self.attribution,
            "content_sha256": self.content_sha256,
            "dataset_id": self.dataset_id,
            "doi": self.doi,
            "eligibility": self.eligibility.value,
            "evidence_id": self.evidence_id,
            "license_id": self.license_id,
            "rights_notes": self.rights_notes,
            "schema_version": self.schema_version,
            "source_url": self.source_url,
            "source_manifest_sha256": self.source_manifest_sha256,
            "version": self.version,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return _sha256_bytes(self.canonical_bytes())

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> SourceEvidence:
        expected = {
            "artifact_role",
            "artifact_type",
            "attribution",
            "content_sha256",
            "dataset_id",
            "doi",
            "eligibility",
            "evidence_id",
            "license_id",
            "rights_notes",
            "schema_version",
            "source_url",
            "source_manifest_sha256",
            "version",
        }
        _require_exact_keys(value, expected)
        if type(value["schema_version"]) is not int:
            raise ValueError("schema_version must be an integer")
        string_fields = expected - {
            "schema_version",
            "dataset_id",
            "doi",
            "source_manifest_sha256",
        }
        if any(type(value[field]) is not str for field in string_fields):
            raise ValueError("source-evidence scalar fields must be strings")
        for field in ("dataset_id", "doi", "source_manifest_sha256"):
            if value[field] is not None and type(value[field]) is not str:
                raise ValueError(f"source-evidence {field} must be a string or null")
        return cls(
            schema_version=value["schema_version"],
            evidence_id=value["evidence_id"],
            dataset_id=value["dataset_id"],
            doi=value["doi"],
            source_manifest_sha256=value["source_manifest_sha256"],
            source_url=value["source_url"],
            version=value["version"],
            license_id=value["license_id"],
            content_sha256=value["content_sha256"],
            artifact_type=value["artifact_type"],
            artifact_role=value["artifact_role"],
            eligibility=Eligibility(value["eligibility"]),
            attribution=value["attribution"],
            rights_notes=value["rights_notes"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> SourceEvidence:
        value, raw = _strict_json_object(path)
        evidence = cls.from_dict(value)
        if raw != evidence.canonical_bytes():
            raise ValueError(f"source evidence is not canonical UTF-8/LF JSON: {path}")
        return evidence


@dataclass(frozen=True)
class AcquisitionRecord:
    """Proof that reviewed external bytes were acquired and inventoried."""

    schema_version: int
    record_id: str
    source_evidence_sha256: str
    content_sha256: str
    artifact_sha256: str
    inventory_sha256: str
    acquired_at_utc: str
    accepted_by: str
    terms_accepted: bool
    extractor: str
    eligibility: Eligibility

    def __post_init__(self) -> None:
        if self.schema_version != 2:
            raise ValueError(
                f"unsupported acquisition schema: {self.schema_version}"
            )
        if not self.record_id or any(
            character.isspace() for character in self.record_id
        ):
            raise ValueError("record ID must be nonempty and contain no whitespace")
        for value, label in (
            (self.source_evidence_sha256, "source-evidence SHA-256"),
            (self.content_sha256, "acquired content SHA-256"),
            (self.artifact_sha256, "acquired artifact SHA-256"),
            (self.inventory_sha256, "inventory SHA-256"),
        ):
            _validate_sha256(value, label=label)
        if not self.accepted_by.strip() or not self.extractor.strip():
            raise ValueError("acquisition actor and extractor are required")
        if type(self.terms_accepted) is not bool:
            raise ValueError("terms_accepted must be a boolean")
        if not _CANONICAL_UTC.fullmatch(self.acquired_at_utc):
            raise ValueError(
                "acquisition timestamp must use canonical UTC seconds "
                "(YYYY-MM-DDTHH:MM:SSZ)"
            )
        try:
            parsed = datetime.strptime(self.acquired_at_utc, "%Y-%m-%dT%H:%M:%SZ")
        except ValueError as error:
            raise ValueError("acquisition timestamp is not a valid UTC date") from error
        if parsed.tzinfo is not None or parsed.utcoffset() is not None:
            raise AssertionError("strptime unexpectedly returned an aware datetime")

    def to_dict(self) -> dict[str, object]:
        return {
            "accepted_by": self.accepted_by,
            "acquired_at_utc": self.acquired_at_utc,
            "artifact_sha256": self.artifact_sha256,
            "content_sha256": self.content_sha256,
            "eligibility": self.eligibility.value,
            "extractor": self.extractor,
            "inventory_sha256": self.inventory_sha256,
            "record_id": self.record_id,
            "schema_version": self.schema_version,
            "source_evidence_sha256": self.source_evidence_sha256,
            "terms_accepted": self.terms_accepted,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return _sha256_bytes(self.canonical_bytes())

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> AcquisitionRecord:
        expected = {
            "accepted_by",
            "acquired_at_utc",
            "artifact_sha256",
            "content_sha256",
            "eligibility",
            "extractor",
            "inventory_sha256",
            "record_id",
            "schema_version",
            "source_evidence_sha256",
            "terms_accepted",
        }
        _require_exact_keys(value, expected)
        if type(value["schema_version"]) is not int:
            raise ValueError("schema_version must be an integer")
        if type(value["terms_accepted"]) is not bool:
            raise ValueError("terms_accepted must be a boolean")
        string_fields = expected - {"schema_version", "terms_accepted"}
        if any(type(value[field]) is not str for field in string_fields):
            raise ValueError("acquisition scalar fields must be strings")
        return cls(
            schema_version=value["schema_version"],
            record_id=value["record_id"],
            source_evidence_sha256=value["source_evidence_sha256"],
            content_sha256=value["content_sha256"],
            artifact_sha256=value["artifact_sha256"],
            inventory_sha256=value["inventory_sha256"],
            acquired_at_utc=value["acquired_at_utc"],
            accepted_by=value["accepted_by"],
            terms_accepted=value["terms_accepted"],
            extractor=value["extractor"],
            eligibility=Eligibility(value["eligibility"]),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> AcquisitionRecord:
        value, raw = _strict_json_object(path)
        record = cls.from_dict(value)
        if raw != record.canonical_bytes():
            raise ValueError(f"acquisition is not canonical UTF-8/LF JSON: {path}")
        return record

    def validate_source(self, source: SourceEvidence) -> None:
        if self.source_evidence_sha256 != source.commitment_sha256:
            raise ValueError("acquisition references different source evidence")
        if self.content_sha256 != source.content_sha256:
            raise ValueError("acquisition content differs from reviewed source")
        if (
            _ELIGIBILITY_RESTRICTIVENESS[self.eligibility]
            < _ELIGIBILITY_RESTRICTIVENESS[source.eligibility]
        ):
            raise ValueError("acquisition cannot upgrade source eligibility")
        if self.eligibility == Eligibility.PRODUCTION and not self.terms_accepted:
            raise ValueError("production acquisition requires accepted terms")


@dataclass(frozen=True)
class DatasetSource:
    schema_version: int
    dataset_id: str
    version: str
    doi: str | None
    source_url: str
    license_id: str
    filename: str
    bytes: int
    sha256: str
    eligibility: Eligibility
    attribution: str
    rights_notes: str

    def __post_init__(self) -> None:
        if self.schema_version != 1:
            raise ValueError(f"unsupported dataset manifest schema: {self.schema_version}")
        if not self.dataset_id:
            raise ValueError("dataset ID is required")
        _validate_source_fields(
            source_url=self.source_url,
            version=self.version,
            license_id=self.license_id,
            attribution=self.attribution,
            rights_notes=self.rights_notes,
        )
        if self.doi is not None and not self.doi.startswith("10."):
            raise ValueError("DOI must start with '10.' or be null")
        filename = Path(self.filename)
        if (
            filename.name != self.filename
            or filename.is_absolute()
            or "/" in self.filename
            or "\\" in self.filename
            or re.match(r"^[A-Za-z]:", self.filename)
        ):
            raise ValueError("filename must be one portable leaf name")
        if self.bytes <= 0:
            raise ValueError("byte count must be positive")
        _validate_sha256(self.sha256, label="SHA-256")

    def to_dict(self) -> dict[str, object]:
        return {
            "attribution": self.attribution,
            "bytes": self.bytes,
            "dataset_id": self.dataset_id,
            "doi": self.doi,
            "eligibility": self.eligibility.value,
            "filename": self.filename,
            "license_id": self.license_id,
            "rights_notes": self.rights_notes,
            "schema_version": self.schema_version,
            "sha256": self.sha256,
            "source_url": self.source_url,
            "version": self.version,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return _sha256_bytes(self.canonical_bytes())

    def to_source_evidence(self) -> SourceEvidence:
        return SourceEvidence(
            schema_version=2,
            evidence_id=f"dataset:{self.dataset_id}:{self.version}:{self.filename}",
            dataset_id=self.dataset_id,
            doi=self.doi,
            source_manifest_sha256=self.commitment_sha256,
            source_url=self.source_url,
            version=self.version,
            license_id=self.license_id,
            content_sha256=self.sha256,
            artifact_type="dataset",
            artifact_role="source_archive",
            eligibility=self.eligibility,
            attribution=self.attribution,
            rights_notes=self.rights_notes,
        )

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> DatasetSource:
        expected = {
            "schema_version",
            "dataset_id",
            "version",
            "doi",
            "source_url",
            "license_id",
            "filename",
            "bytes",
            "sha256",
            "eligibility",
            "attribution",
            "rights_notes",
        }
        _require_exact_keys(value, expected)
        string_fields = (
            "dataset_id",
            "version",
            "source_url",
            "license_id",
            "filename",
            "sha256",
            "eligibility",
            "attribution",
            "rights_notes",
        )
        if type(value["schema_version"]) is not int:
            raise ValueError("schema_version must be an integer")
        if type(value["bytes"]) is not int:
            raise ValueError("bytes must be an integer")
        if any(type(value[field]) is not str for field in string_fields):
            raise ValueError("dataset manifest string fields must be strings")
        if value["doi"] is not None and type(value["doi"]) is not str:
            raise ValueError("doi must be a string or null")
        return cls(
            schema_version=value["schema_version"],
            dataset_id=value["dataset_id"],
            version=value["version"],
            doi=value["doi"],
            source_url=value["source_url"],
            license_id=value["license_id"],
            filename=value["filename"],
            bytes=value["bytes"],
            sha256=value["sha256"],
            eligibility=Eligibility(value["eligibility"]),
            attribution=value["attribution"],
            rights_notes=value["rights_notes"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> DatasetSource:
        value, raw = _strict_json_object(path)
        source = cls.from_dict(value)
        if raw != source.canonical_bytes():
            raise ValueError(f"dataset manifest is not canonical UTF-8/LF JSON: {path}")
        return source

    def verify_archive(self, path: Path) -> None:
        if not path.is_file():
            raise ValueError(f"dataset archive is not a file: {path}")
        actual_bytes = path.stat().st_size
        if actual_bytes != self.bytes:
            raise ValueError(
                f"dataset byte count is {actual_bytes}; expected {self.bytes}"
            )
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        actual_sha256 = digest.hexdigest()
        if actual_sha256 != self.sha256:
            raise ValueError(
                f"dataset SHA-256 is {actual_sha256}; expected {self.sha256}"
            )
