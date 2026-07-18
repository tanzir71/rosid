"""Canonical commitments for the exact splitter and adapter source bundle."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from types import MappingProxyType
from typing import Iterable

from .acquisition import validate_portable_relative_path
from .provenance import canonical_json_bytes
from .storage import normalize_path, path_is_within


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_MAX_CODE_FILE_BYTES = 10_000_000
_MAX_CODE_BUNDLE_BYTES = 50_000_000

REQUIRED_CORE_CODE_ROLES = MappingProxyType({
    "ml/__init__.py": "shared",
    "ml/build_split_manifest.py": "splitter",
    "ml/finalize_split_approval.py": "shared",
    "ml/prepare_split_approval.py": "shared",
    "ml/record_acquisition.py": "shared",
    "ml/request_split_approval.py": "shared",
    "ml/verify_dataset.py": "shared",
    "ml/verify_split_manifest.py": "splitter",
    "ml/rosid_ml/__init__.py": "shared",
    "ml/rosid_ml/acquisition.py": "shared",
    "ml/rosid_ml/adapter_evidence.py": "shared",
    "ml/rosid_ml/code_bundles.py": "shared",
    "ml/rosid_ml/limits.py": "shared",
    "ml/rosid_ml/lineage.py": "shared",
    "ml/rosid_ml/metrics.py": "shared",
    "ml/rosid_ml/provenance.py": "shared",
    "ml/rosid_ml/split_approvals.py": "shared",
    "ml/rosid_ml/split_manifests.py": "splitter",
    "ml/rosid_ml/splits.py": "splitter",
    "ml/rosid_ml/storage.py": "shared",
})


class CodeRole(StrEnum):
    """Why one repository file can influence normalized split inputs."""

    SPLITTER = "splitter"
    ADAPTER = "adapter"
    SHARED = "shared"


@dataclass(frozen=True)
class CodeFileEntry:
    """One exact repository-relative file in an approved code bundle."""

    path: str
    role: CodeRole
    bytes: int
    sha256: str

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        if not isinstance(self.role, CodeRole):
            raise ValueError("code-file role must be a CodeRole")
        if (
            type(self.bytes) is not int
            or self.bytes <= 0
            or self.bytes > _MAX_CODE_FILE_BYTES
        ):
            raise ValueError(
                "code-file bytes must be between 1 and 10,000,000"
            )
        if not _SHA256.fullmatch(self.sha256):
            raise ValueError(
                "code-file SHA-256 must be 64 lowercase hexadecimal digits"
            )

    def to_dict(self) -> dict[str, object]:
        return {
            "bytes": self.bytes,
            "path": self.path,
            "role": self.role.value,
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> CodeFileEntry:
        if set(value) != {"bytes", "path", "role", "sha256"}:
            raise ValueError("code-file keys differ from the schema")
        if type(value["bytes"]) is not int:
            raise ValueError("code-file bytes must be an integer")
        for field in ("path", "role", "sha256"):
            if type(value[field]) is not str:
                raise ValueError(f"code-file {field} must be a string")
        try:
            role = CodeRole(value["role"])
        except ValueError as error:
            raise ValueError("code-file role is unsupported") from error
        return cls(
            path=value["path"],
            role=role,
            bytes=value["bytes"],
            sha256=value["sha256"],
        )


@dataclass(frozen=True)
class CodeBundleManifest:
    """Canonical splitter/adapter source snapshot approved through Git."""

    schema_version: int
    files: tuple[CodeFileEntry, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported code-bundle schema: {self.schema_version}"
            )
        if not self.files:
            raise ValueError("code bundle must contain files")
        paths = tuple(entry.path for entry in self.files)
        if paths != tuple(sorted(paths, key=lambda value: value.encode("utf-8"))):
            raise ValueError("code-bundle files must be sorted by path")
        if len(paths) != len(set(paths)):
            raise ValueError("code-bundle file paths must be unique")
        folded = [path.casefold() for path in paths]
        if len(folded) != len(set(folded)):
            raise ValueError("code-bundle paths collide after case folding")
        roles = {entry.role for entry in self.files}
        if CodeRole.SPLITTER not in roles or CodeRole.ADAPTER not in roles:
            raise ValueError(
                "code bundle must contain splitter and adapter source"
            )
        if sum(entry.bytes for entry in self.files) > _MAX_CODE_BUNDLE_BYTES:
            raise ValueError("code bundle exceeds 50,000,000 bytes")

    def to_dict(self) -> dict[str, object]:
        return {
            "files": [entry.to_dict() for entry in self.files],
            "schema_version": self.schema_version,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    def verify_worktree(self, worktree_root: Path) -> None:
        """Rehash every declared file from one safe repository worktree."""

        root = normalize_path(worktree_root)
        for entry in self.files:
            candidate = normalize_path(entry.path, base=root)
            if not path_is_within(candidate, root):
                raise ValueError(
                    f"code-bundle path escapes its worktree: {entry.path}"
                )
            content = _read_stable_plain_file(candidate)
            if len(content) != entry.bytes:
                raise ValueError(
                    f"code-bundle byte count differs for {entry.path}"
                )
            if hashlib.sha256(content).hexdigest() != entry.sha256:
                raise ValueError(f"code-bundle SHA-256 differs for {entry.path}")

    def require_exact_implementation(
        self,
        *,
        adapter_paths: Iterable[str],
        worktree_root: Path,
    ) -> None:
        """Reject omitted, extra, or mislabelled executable P1 code."""

        adapter_values = tuple(
            sorted(set(adapter_paths), key=lambda value: value.encode("utf-8"))
        )
        for path in adapter_values:
            validate_portable_relative_path(path)
            if (
                not path.startswith("ml/rosid_ml/adapters/")
                or not path.endswith(".py")
            ):
                raise ValueError(
                    "adapter code must be below ml/rosid_ml/adapters"
                )
        root = normalize_path(worktree_root)
        ml_root = normalize_path("ml", base=root)
        discovered_core_paths: set[str] = set()
        if ml_root.exists():
            for raw_candidate in ml_root.rglob("*.py"):
                candidate = normalize_path(raw_candidate)
                try:
                    relative = candidate.relative_to(root).as_posix()
                except ValueError as error:
                    raise ValueError(
                        f"ML implementation escapes its worktree: {candidate}"
                    ) from error
                if relative.startswith("ml/tests/") or relative.startswith(
                    "ml/rosid_ml/adapters/"
                ):
                    continue
                _read_stable_plain_file(candidate)
                discovered_core_paths.add(relative)
        declared_core_paths = set(REQUIRED_CORE_CODE_ROLES)
        if declared_core_paths != discovered_core_paths:
            raise ValueError(
                "fixed P1 code closure differs from executable ML Python files; "
                f"missing={sorted(discovered_core_paths - declared_core_paths)}, "
                f"stale={sorted(declared_core_paths - discovered_core_paths)}"
            )
        adapter_root = normalize_path("ml/rosid_ml/adapters", base=root)
        discovered_adapter_paths: set[str] = set()
        if adapter_root.exists():
            for raw_candidate in adapter_root.rglob("*.py"):
                candidate = normalize_path(raw_candidate)
                content = _read_stable_plain_file(candidate)
                if not content:
                    raise ValueError(f"adapter code must not be empty: {candidate}")
                try:
                    relative = candidate.relative_to(root).as_posix()
                except ValueError as error:
                    raise ValueError(
                        f"adapter code escapes its worktree: {candidate}"
                    ) from error
                discovered_adapter_paths.add(relative)
        if set(adapter_values) != discovered_adapter_paths:
            raise ValueError(
                "adapter configs must name every Python file in the adapter "
                "package; "
                f"missing={sorted(discovered_adapter_paths - set(adapter_values))}, "
                f"extra={sorted(set(adapter_values) - discovered_adapter_paths)}"
            )
        expected = {
            path: CodeRole(role)
            for path, role in REQUIRED_CORE_CODE_ROLES.items()
        }
        for path in adapter_values:
            if path in expected:
                raise ValueError(f"adapter code collides with core code: {path}")
            expected[path] = CodeRole.ADAPTER
        actual = {entry.path: entry.role for entry in self.files}
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        wrong_roles = sorted(
            path
            for path in set(expected) & set(actual)
            if actual[path] != expected[path]
        )
        if missing or extra or wrong_roles:
            raise ValueError(
                "code bundle differs from the exact P1 implementation closure; "
                f"missing={missing}, extra={extra}, wrong_roles={wrong_roles}"
            )

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> CodeBundleManifest:
        if set(value) != {"files", "schema_version"}:
            raise ValueError("code-bundle keys differ from the schema")
        if type(value["schema_version"]) is not int:
            raise ValueError("code-bundle schema_version must be an integer")
        files = value["files"]
        if not isinstance(files, list) or any(
            not isinstance(item, dict) for item in files
        ):
            raise ValueError("code-bundle files must be an object list")
        return cls(
            schema_version=value["schema_version"],
            files=tuple(CodeFileEntry.from_dict(item) for item in files),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> CodeBundleManifest:
        value, raw = _read_strict_json_object(path)
        manifest = cls.from_dict(value)
        if raw != manifest.canonical_bytes():
            raise ValueError(
                f"code bundle is not canonical UTF-8/LF JSON: {path}"
            )
        return manifest


def build_code_bundle(
    worktree_root: Path,
    *,
    splitter_files: Iterable[Path],
    adapter_files: Iterable[Path],
    shared_files: Iterable[Path] = (),
) -> CodeBundleManifest:
    """Snapshot exact worktree files for review as a canonical code bundle."""

    root = normalize_path(worktree_root)
    entries: list[CodeFileEntry] = []
    for role, paths in (
        (CodeRole.SPLITTER, splitter_files),
        (CodeRole.ADAPTER, adapter_files),
        (CodeRole.SHARED, shared_files),
    ):
        for path in paths:
            candidate = normalize_path(path, base=root)
            if not path_is_within(candidate, root):
                raise ValueError(f"code file is outside its worktree: {path}")
            try:
                relative = candidate.relative_to(root).as_posix()
            except ValueError as error:
                raise ValueError(
                    f"cannot make code path repository-relative: {path}"
                ) from error
            validate_portable_relative_path(relative)
            content = _read_stable_plain_file(candidate)
            entries.append(
                CodeFileEntry(
                    path=relative,
                    role=role,
                    bytes=len(content),
                    sha256=hashlib.sha256(content).hexdigest(),
                )
            )
    entries.sort(key=lambda entry: entry.path.encode("utf-8"))
    return CodeBundleManifest(schema_version=1, files=tuple(entries))


def _read_stable_plain_file(path: Path) -> bytes:
    try:
        initial = path.stat(follow_symlinks=False)
        attributes = getattr(initial, "st_file_attributes", 0)
        reparse = attributes & getattr(
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
            raise ValueError(f"code input must be one unlinked plain file: {path}")
        if initial.st_size > _MAX_CODE_FILE_BYTES:
            raise ValueError(f"code input exceeds 10,000,000 bytes: {path}")
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_identity(initial, opened):
                raise ValueError(f"code input changed before reading: {path}")
            content = source.read(_MAX_CODE_FILE_BYTES + 1)
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
        with path.open("rb") as confirmation:
            confirmed = confirmation.read(_MAX_CODE_FILE_BYTES + 1)
            confirmed_stat = os.fstat(confirmation.fileno())
        last = path.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(f"cannot read code input {path}: {error}") from error
    if (
        len(content) > _MAX_CODE_FILE_BYTES
        or not _same_snapshot(opened, finished)
        or not _same_snapshot(initial, final)
        or not _same_identity(finished, final)
        or not _same_identity(final, confirmed_stat)
        or not _same_snapshot(final, last)
        or content != confirmed
    ):
        raise ValueError(f"code input changed while reading: {path}")
    return content


def _same_identity(first: os.stat_result, second: os.stat_result) -> bool:
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


def _same_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
    return _same_identity(first, second) and first.st_ctime_ns == second.st_ctime_ns


def _read_strict_json_object(path: Path) -> tuple[dict[str, object], bytes]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in code bundle: {key}")
            result[key] = value
        return result

    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read code-bundle manifest {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError("code-bundle manifest root must be an object")
    return value, raw
