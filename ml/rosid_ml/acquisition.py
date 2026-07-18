"""Deterministic post-download evidence for reviewed external datasets."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    SourceEvidence,
    canonical_json_bytes,
)


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_ARTIFACT_DOMAIN = b"rosid-v2-extracted-artifact-v1\0"
_WINDOWS_REPARSE_POINT = 0x400
_WINDOWS_RESERVED_NAMES = {
    "aux",
    "con",
    "nul",
    "prn",
    *(f"com{index}" for index in range(1, 10)),
    *(f"lpt{index}" for index in range(1, 10)),
}


def _validate_sha256(value: str, *, label: str) -> None:
    if not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")


def validate_portable_relative_path(value: str) -> str:
    normalized = unicodedata.normalize("NFC", value)
    if value != normalized:
        raise ValueError(f"inventory path is not NFC-normalized: {value!r}")
    if not value or value.startswith("/") or "\\" in value:
        raise ValueError(f"inventory path is not portable: {value!r}")
    components = value.split("/")
    if any(
        component in {"", ".", ".."}
        or component.endswith((" ", "."))
        or ":" in component
        or any(character in '<>"|?*' for character in component)
        or any(
            unicodedata.category(character) in {"Cc", "Cf"}
            for character in component
        )
        or component.split(".", 1)[0].casefold() in _WINDOWS_RESERVED_NAMES
        for component in components
    ):
        raise ValueError(f"inventory path is not portable: {value!r}")
    return value


def _portable_relative_path(root: Path, path: Path) -> str:
    return validate_portable_relative_path(path.relative_to(root).as_posix())


def _same_file_identity(first: os.stat_result, second: os.stat_result) -> bool:
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


def _same_file_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        _same_file_identity(first, second)
        and first.st_ctime_ns == second.st_ctime_ns
    )


def _is_reparse_point(metadata: os.stat_result) -> bool:
    return bool(
        getattr(metadata, "st_file_attributes", 0) & _WINDOWS_REPARSE_POINT
    )


def _validate_regular_snapshot(
    path: Path,
    metadata: os.stat_result,
    *,
    label: str,
) -> None:
    if (
        path.is_symlink()
        or _is_reparse_point(metadata)
        or not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
    ):
        raise ValueError(f"{label} is a linked or non-regular file: {path}")


def _reject_linked_path(path: Path, *, label: str) -> None:
    """Reject a link/reparse point in any existing component of ``path``."""

    is_junction = getattr(os.path, "isjunction", lambda _: False)
    absolute = path.absolute()
    components = (absolute, *absolute.parents)
    for index, component in enumerate(components):
        if component.is_symlink() or is_junction(component):
            raise ValueError(f"{label} traverses a linked path: {component}")
        try:
            metadata = component.stat(follow_symlinks=False)
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ValueError(
                f"cannot inspect {label} path {component}: {error}"
            ) from error
        if _is_reparse_point(metadata):
            raise ValueError(f"{label} traverses a reparse point: {component}")
        if index > 0 and not stat.S_ISDIR(metadata.st_mode):
            raise ValueError(
                f"{label} has a non-directory parent component: {component}"
            )


def _scan_regular_files(root: Path) -> list[tuple[str, Path, os.stat_result]]:
    is_junction = getattr(os.path, "isjunction", lambda _: False)
    candidates: list[tuple[str, Path, os.stat_result]] = []

    def raise_walk_error(error: OSError) -> None:
        raise error

    for current, directories, filenames in os.walk(
        root,
        followlinks=False,
        onerror=raise_walk_error,
    ):
        current_path = Path(current)
        current_metadata = current_path.stat(follow_symlinks=False)
        if (
            current_path.is_symlink()
            or is_junction(current_path)
            or _is_reparse_point(current_metadata)
            or not stat.S_ISDIR(current_metadata.st_mode)
        ):
            raise ValueError(
                f"extracted artifact contains a linked or special directory: "
                f"{current_path}"
            )
        for name in directories:
            directory = current_path / name
            metadata = directory.stat(follow_symlinks=False)
            if (
                directory.is_symlink()
                or is_junction(directory)
                or _is_reparse_point(metadata)
                or not stat.S_ISDIR(metadata.st_mode)
            ):
                raise ValueError(
                    f"extracted artifact contains a linked or special directory: {name}"
                )
        for name in filenames:
            path = current_path / name
            metadata = path.stat(follow_symlinks=False)
            _validate_regular_snapshot(
                path,
                metadata,
                label="extracted artifact entry",
            )
            candidates.append((_portable_relative_path(root, path), path, metadata))
    candidates.sort(key=lambda item: item[0].encode("utf-8"))
    return candidates


@dataclass(frozen=True)
class InventoryEntry:
    path: str
    bytes: int
    sha256: str

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        if type(self.bytes) is not int or self.bytes < 0:
            raise ValueError(
                "inventory entry byte count must be a non-negative integer"
            )
        _validate_sha256(self.sha256, label="inventory entry SHA-256")

    def to_dict(self) -> dict[str, object]:
        return {
            "bytes": self.bytes,
            "path": self.path,
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> InventoryEntry:
        if set(value) != {"bytes", "path", "sha256"}:
            raise ValueError("inventory entry keys differ from the schema")
        if type(value["bytes"]) is not int:
            raise ValueError("inventory entry bytes must be an integer")
        if type(value["path"]) is not str or type(value["sha256"]) is not str:
            raise ValueError("inventory entry path and SHA-256 must be strings")
        return cls(
            path=value["path"],
            bytes=value["bytes"],
            sha256=value["sha256"],
        )


@dataclass(frozen=True)
class DirectoryInventory:
    schema_version: int
    artifact_sha256: str
    files: tuple[InventoryEntry, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported directory-inventory schema: {self.schema_version}"
            )
        _validate_sha256(self.artifact_sha256, label="extracted artifact SHA-256")
        files = tuple(self.files)
        if any(not isinstance(entry, InventoryEntry) for entry in files):
            raise ValueError("directory inventory files must be inventory entries")
        if not files:
            raise ValueError(
                "extracted artifact inventory must contain at least one file"
            )
        paths = [entry.path for entry in files]
        if paths != sorted(paths, key=lambda value: value.encode("utf-8")):
            raise ValueError("inventory entries must use canonical UTF-8 path order")
        if len(paths) != len(set(paths)):
            raise ValueError("inventory entry paths must be unique")
        folded = [path.casefold() for path in paths]
        if len(folded) != len(set(folded)):
            raise ValueError("inventory paths collide under Unicode case folding")
        object.__setattr__(self, "files", files)

    @property
    def total_bytes(self) -> int:
        return sum(entry.bytes for entry in self.files)

    def to_dict(self) -> dict[str, object]:
        return {
            "artifact_sha256": self.artifact_sha256,
            "file_count": len(self.files),
            "files": [entry.to_dict() for entry in self.files],
            "schema_version": self.schema_version,
            "total_bytes": self.total_bytes,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_json_file(cls, path: Path) -> DirectoryInventory:
        def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
            result: dict[str, object] = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError(f"duplicate JSON key: {key}")
                result[key] = value
            return result

        try:
            raw = path.read_bytes()
            value = json.loads(
                raw.decode("utf-8"),
                object_pairs_hook=unique_object,
            )
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise ValueError(
                f"cannot read directory inventory {path}: {error}"
            ) from error
        if not isinstance(value, dict):
            raise ValueError("directory inventory root must be an object")
        inventory = cls.from_dict(value)
        if raw != inventory.canonical_bytes():
            raise ValueError(
                f"directory inventory is not canonical UTF-8/LF JSON: {path}"
            )
        return inventory

    def verify_directory(self, root: Path) -> None:
        actual = inventory_directory(root)
        if actual != self:
            raise ValueError("extracted directory differs from its recorded inventory")

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> DirectoryInventory:
        expected = {
            "artifact_sha256",
            "file_count",
            "files",
            "schema_version",
            "total_bytes",
        }
        if set(value) != expected:
            raise ValueError("directory inventory keys differ from the schema")
        if any(
            type(value[field]) is not int
            for field in ("file_count", "schema_version", "total_bytes")
        ):
            raise ValueError("directory inventory counts and version must be integers")
        if type(value["artifact_sha256"]) is not str:
            raise ValueError("directory inventory artifact SHA-256 must be a string")
        if not isinstance(value["files"], list):
            raise ValueError("directory inventory files must be a list")
        entries: list[InventoryEntry] = []
        for item in value["files"]:
            if not isinstance(item, dict):
                raise ValueError("directory inventory entries must be objects")
            entries.append(InventoryEntry.from_dict(item))
        inventory = cls(
            schema_version=value["schema_version"],
            artifact_sha256=value["artifact_sha256"],
            files=tuple(entries),
        )
        if value["file_count"] != len(inventory.files):
            raise ValueError(
                "directory inventory file count does not match its entries"
            )
        if value["total_bytes"] != inventory.total_bytes:
            raise ValueError(
                "directory inventory byte count does not match its entries"
            )
        return inventory


def inventory_directory(root: Path) -> DirectoryInventory:
    """Hash one extracted regular-file set without recording host paths."""

    supplied_root = root
    is_junction = getattr(os.path, "isjunction", lambda _: False)
    try:
        supplied_metadata = supplied_root.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(
            f"cannot inspect extracted artifact directory {supplied_root}: {error}"
        ) from error
    if (
        supplied_root.is_symlink()
        or is_junction(supplied_root)
        or _is_reparse_point(supplied_metadata)
    ):
        raise ValueError(
            f"extracted artifact must not be a linked directory: {supplied_root}"
        )
    try:
        root = supplied_root.resolve(strict=True)
    except OSError as error:
        raise ValueError(
            f"cannot resolve extracted artifact directory {supplied_root}: {error}"
        ) from error
    if not root.is_dir():
        raise ValueError(f"extracted artifact is not a plain directory: {root}")

    candidates = _scan_regular_files(root)
    normalized_paths = [relative for relative, _, _ in candidates]
    if len(normalized_paths) != len(set(normalized_paths)):
        raise ValueError("extracted paths collide after NFC normalization")
    folded_paths = [relative.casefold() for relative in normalized_paths]
    if len(folded_paths) != len(set(folded_paths)):
        raise ValueError("extracted paths collide under Unicode case folding")

    artifact_digest = hashlib.sha256()
    artifact_digest.update(_ARTIFACT_DOMAIN)
    entries: list[InventoryEntry] = []
    final_snapshots: dict[str, os.stat_result] = {}
    for relative, path, initial in candidates:
        path_bytes = relative.encode("utf-8")
        artifact_digest.update(len(path_bytes).to_bytes(8, "big"))
        artifact_digest.update(path_bytes)
        artifact_digest.update(initial.st_size.to_bytes(8, "big"))

        content_digest = hashlib.sha256()
        observed_bytes = 0
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_file_identity(initial, opened):
                raise ValueError(f"extracted file changed before hashing: {relative}")
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                observed_bytes += len(chunk)
                content_digest.update(chunk)
                artifact_digest.update(chunk)
            finished = os.fstat(source.fileno())
        final_path = path.stat(follow_symlinks=False)
        if (
            observed_bytes != initial.st_size
            or not _same_file_snapshot(opened, finished)
            or not _same_file_snapshot(initial, final_path)
            or not _same_file_identity(finished, final_path)
        ):
            raise ValueError(f"extracted file changed while hashing: {relative}")
        final_snapshots[relative] = final_path
        entries.append(
            InventoryEntry(
                path=relative,
                bytes=observed_bytes,
                sha256=content_digest.hexdigest(),
            )
        )

    rescanned = _scan_regular_files(root)
    if [relative for relative, _, _ in rescanned] != normalized_paths:
        raise ValueError("extracted directory membership changed while hashing")
    entries_by_path = {entry.path: entry for entry in entries}
    for relative, path, metadata in rescanned:
        if not _same_file_snapshot(final_snapshots[relative], metadata):
            raise ValueError(f"extracted file changed after hashing: {relative}")
        confirmation_digest = hashlib.sha256()
        confirmed_bytes = 0
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_file_identity(metadata, opened):
                raise ValueError(
                    f"extracted file changed before confirmation: {relative}"
                )
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                confirmed_bytes += len(chunk)
                confirmation_digest.update(chunk)
            finished = os.fstat(source.fileno())
        final_path = path.stat(follow_symlinks=False)
        expected = entries_by_path[relative]
        if (
            confirmed_bytes != expected.bytes
            or confirmation_digest.hexdigest() != expected.sha256
            or not _same_file_snapshot(opened, finished)
            or not _same_file_snapshot(metadata, final_path)
            or not _same_file_identity(finished, final_path)
        ):
            raise ValueError(f"extracted file changed during confirmation: {relative}")

    return DirectoryInventory(
        schema_version=1,
        artifact_sha256=artifact_digest.hexdigest(),
        files=tuple(entries),
    )


@dataclass(frozen=True)
class AcquisitionArtifacts:
    source: SourceEvidence
    acquisition: AcquisitionRecord
    inventory: DirectoryInventory


def build_acquisition_artifacts(
    *,
    source_manifest: DatasetSource,
    archive_path: Path,
    extracted_directory: Path,
    record_id: str,
    acquired_at_utc: str,
    accepted_by: str,
    terms_accepted: bool,
    extractor: str,
    eligibility: Eligibility | None = None,
    quarantined_research: bool = False,
) -> AcquisitionArtifacts:
    """Bind reviewed bytes to an asserted, separately extracted tree snapshot.

    This independently verifies both snapshots but cannot attest which exact
    extractor/code produced the directory. Generic safe extraction and the
    dataset-specific structure/writer-map audit remain separate gates.
    """

    source = source_manifest.to_source_evidence()
    chosen_eligibility = (
        source.eligibility if eligibility is None else eligibility
    )
    if chosen_eligibility == Eligibility.EXCLUDED:
        raise ValueError("excluded sources cannot produce acquisition records")
    if (
        chosen_eligibility
        in {Eligibility.CONDITIONAL, Eligibility.RESEARCH_ONLY}
        and not quarantined_research
    ):
        raise ValueError(
            "nonproduction acquisition requires explicit quarantined research mode"
        )
    preflight = AcquisitionRecord(
        schema_version=3,
        record_id=record_id,
        source_evidence_sha256=source.commitment_sha256,
        content_sha256=source.content_sha256,
        artifact_sha256="0" * 64,
        artifact_type="dataset",
        artifact_role="extracted_dataset",
        inventory_sha256="0" * 64,
        acquired_at_utc=acquired_at_utc,
        accepted_by=accepted_by,
        terms_accepted=terms_accepted,
        extractor=extractor,
        eligibility=chosen_eligibility,
    )
    preflight.validate_source(source)

    source_manifest.verify_archive(archive_path)
    inventory = inventory_directory(extracted_directory)
    acquisition = AcquisitionRecord(
        schema_version=3,
        record_id=record_id,
        source_evidence_sha256=source.commitment_sha256,
        content_sha256=source.content_sha256,
        artifact_sha256=inventory.artifact_sha256,
        artifact_type="dataset",
        artifact_role="extracted_dataset",
        inventory_sha256=inventory.commitment_sha256,
        acquired_at_utc=acquired_at_utc,
        accepted_by=accepted_by,
        terms_accepted=terms_accepted,
        extractor=extractor,
        eligibility=chosen_eligibility,
    )
    acquisition.validate_source(source)
    return AcquisitionArtifacts(
        source=source,
        acquisition=acquisition,
        inventory=inventory,
    )


def preflight_output_paths(paths: Iterable[Path]) -> tuple[Path, ...]:
    """Validate publication destinations before expensive evidence hashing."""

    entries = tuple(paths)
    if not entries or any(not isinstance(path, Path) for path in entries):
        raise ValueError("output paths must be a nonempty Path sequence")
    for path in entries:
        _reject_linked_path(path, label="evidence output")
    resolved = tuple(path.resolve(strict=False) for path in entries)
    if len(resolved) != len(set(resolved)):
        raise ValueError("output paths must be distinct")
    for path in entries:
        if not (path.exists() or path.is_symlink()):
            continue
        try:
            metadata = path.stat(follow_symlinks=False)
        except OSError as error:
            raise ValueError(
                f"cannot inspect evidence output {path}: {error}"
            ) from error
        _validate_regular_snapshot(
            path,
            metadata,
            label="existing evidence output",
        )
    return resolved


def write_new_files(files: Iterable[tuple[Path, bytes]]) -> None:
    """Idempotently publish an ordered evidence set without overwriting bytes."""

    entries = tuple(files)
    if not entries:
        raise ValueError("at least one output file is required")
    if any(
        not isinstance(path, Path) or type(content) is not bytes
        for path, content in entries
    ):
        raise ValueError("output entries must contain Path and bytes values")
    preflight_output_paths(path for path, _ in entries)
    pending: list[tuple[Path, bytes]] = []
    for path, content in entries:
        if path.exists() or path.is_symlink():
            try:
                initial = path.stat(follow_symlinks=False)
                _validate_regular_snapshot(
                    path,
                    initial,
                    label="existing evidence output",
                )
                with path.open("rb") as source:
                    opened = os.fstat(source.fileno())
                    if not _same_file_identity(initial, opened):
                        raise ValueError(
                            f"evidence output changed before reading: {path}"
                        )
                    existing = source.read()
                    finished = os.fstat(source.fileno())
                final = path.stat(follow_symlinks=False)
                if (
                    not _same_file_snapshot(opened, finished)
                    or not _same_file_snapshot(initial, final)
                    or not _same_file_identity(finished, final)
                ):
                    raise ValueError(
                        f"evidence output changed while reading: {path}"
                    )
            except OSError as error:
                raise ValueError(
                    f"cannot inspect evidence output {path}: {error}"
                ) from error
            if existing != content:
                raise FileExistsError(
                    f"refusing to overwrite evidence file: {path}"
                )
        else:
            pending.append((path, content))

    staged: list[tuple[Path, Path]] = []
    created: list[Path] = []
    try:
        for path, content in pending:
            path.parent.mkdir(parents=True, exist_ok=True)
            descriptor, temporary_name = tempfile.mkstemp(
                prefix=f".{path.name}.",
                suffix=".tmp",
                dir=path.parent,
            )
            temporary = Path(temporary_name)
            staged.append((temporary, path))
            with os.fdopen(descriptor, "wb") as output:
                output.write(content)
                output.flush()
                os.fsync(output.fileno())
        for temporary, path in staged:
            _reject_linked_path(path, label="evidence output")
            os.link(temporary, path)
            created.append(path)
    except BaseException:
        for path in reversed(created):
            path.unlink(missing_ok=True)
        raise
    finally:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)
