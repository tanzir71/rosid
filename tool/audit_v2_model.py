#!/usr/bin/env python3
"""Structural primitives for a future bundled V2 TFLite artifact.

This is not the P3/P5 release audit: it cannot yet inspect operators, tensor
contracts, quantization, or an interpreter. CI runs its unit tests only until a
real generated model and locked LiteRT validator exist. A future release audit
will compose these hash/size/privacy/FlatBuffer checks with those runtime gates.

Path traversal assumes a trusted clean filesystem with no hostile concurrent
namespace mutation. Stable leaf snapshots detect ordinary drift; this is not a
descriptor-relative hostile-filesystem sandbox.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import struct
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Final

# Direct script execution puts ``tool/`` rather than the repository root on
# sys.path. Keep the shebang entry point equivalent to ``python -m tool...``.
if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ml.rosid_ml.limits import MAX_HTR_BUNDLE_BYTES


_TFLITE_IDENTIFIER: Final = b"TFL3"
_FORBIDDEN_BINARY_MARKERS: Final = (
    b"http://",
    b"https://",
    b"ws://",
    b"wss://",
    b"/users/",
    b"/home/",
    b"\\users\\",
)
_ASSET_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*\Z")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_WINDOWS_REPARSE_POINT: Final = 0x400
_WINDOWS_RESERVED_NAMES: Final = frozenset(
    {
        "aux",
        "con",
        "nul",
        "prn",
        *(f"com{index}" for index in range(1, 10)),
        *(f"lpt{index}" for index in range(1, 10)),
    }
)


class ModelAuditError(ValueError):
    """A candidate cannot be accepted as a bundled V2 model."""


@dataclass(frozen=True)
class CompanionExpectation:
    """Integrity declaration for one non-model file in the HTR bundle."""

    asset_id: str
    path: Path
    expected_sha256: str
    expected_bytes: int


@dataclass(frozen=True)
class _AssetSnapshot:
    content: bytes
    identity_key: tuple[object, ...]
    path: Path


def audit_tflite(
    path: Path,
    *,
    asset_id: str,
    expected_sha256: str,
    expected_bytes: int,
    max_bytes: int = MAX_HTR_BUNDLE_BYTES,
    companions: tuple[CompanionExpectation, ...] = (),
) -> dict[str, object]:
    if type(companions) is not tuple:
        raise ModelAuditError("companions must be a tuple of integrity declarations")
    if any(type(companion) is not CompanionExpectation for companion in companions):
        raise ModelAuditError(
            "companions must contain only CompanionExpectation values"
        )
    model_id = _validate_asset_id(asset_id)
    companion_ids = [_validate_asset_id(companion.asset_id) for companion in companions]
    logical_ids = (model_id, *companion_ids)
    collision_keys = tuple(_asset_id_collision_key(value) for value in logical_ids)
    if len(set(collision_keys)) != len(collision_keys):
        raise ModelAuditError(
            "model and companion asset IDs must be unique under portable "
            "Unicode case folding"
        )
    model_path = _validate_asset_path(path, label=model_id)
    normalized_model_sha256 = _validate_sha256(expected_sha256, label=model_id)
    _validate_expected_bytes(expected_bytes, label=model_id)
    for companion, companion_id in zip(companions, companion_ids, strict=True):
        _validate_asset_path(companion.path, label=companion_id)
        _validate_sha256(companion.expected_sha256, label=companion_id)
        _validate_expected_bytes(companion.expected_bytes, label=companion_id)
    if type(max_bytes) is not int or max_bytes <= 0 or max_bytes > MAX_HTR_BUNDLE_BYTES:
        raise ModelAuditError(
            "bundle byte budget must be a positive integer no greater than "
            f"{MAX_HTR_BUNDLE_BYTES}"
        )
    expected_bundle_bytes = expected_bytes + sum(
        companion.expected_bytes for companion in companions
    )
    if expected_bundle_bytes > max_bytes:
        raise ModelAuditError(
            f"HTR asset bundle declares {expected_bundle_bytes} bytes; "
            f"the budget is {max_bytes} bytes"
        )
    model_snapshot = _read_exact_snapshot(model_path, model_id, expected_bytes)
    content = model_snapshot.content
    if len(content) < 8:
        raise ModelAuditError("model is too short to be a TFLite FlatBuffer")
    _audit_model_table(content)
    _audit_privacy_markers(content, label=model_id)
    actual_sha256 = _sha256_snapshot(content)
    if actual_sha256 != normalized_model_sha256:
        raise ModelAuditError(
            f"asset {model_id} SHA-256 is {actual_sha256}; "
            f"manifest declares {normalized_model_sha256}"
        )

    companion_results: list[dict[str, int | str]] = []
    bundle_size = len(content)
    physical_assets = [model_snapshot]
    for companion, companion_id in zip(companions, companion_ids, strict=True):
        companion_snapshot = _read_exact_snapshot(
            companion.path,
            companion_id,
            companion.expected_bytes,
        )
        if any(
            _snapshots_alias(companion_snapshot, existing)
            for existing in physical_assets
        ):
            raise ModelAuditError(
                f"asset {companion_id} aliases another HTR bundle asset"
            )
        physical_assets.append(companion_snapshot)
        companion_content = companion_snapshot.content
        _audit_privacy_markers(companion_content, label=companion_id)
        companion_sha256 = _sha256_snapshot(companion_content)
        expected_companion_sha256 = _validate_sha256(
            companion.expected_sha256,
            label=companion_id,
        )
        if companion_sha256 != expected_companion_sha256:
            raise ModelAuditError(
                f"asset {companion_id} SHA-256 is {companion_sha256}; "
                f"manifest declares {expected_companion_sha256}"
            )
        bundle_size += len(companion_content)
        companion_results.append(
            {
                "asset_id": companion_id,
                "bytes": len(companion_content),
                "sha256": companion_sha256,
            }
        )

    return {
        "asset_id": model_id,
        "bundle_bytes": bundle_size,
        "bytes": len(content),
        "companions": companion_results,
        "sha256": actual_sha256,
        "structural_only": True,
    }


def _validate_expected_bytes(value: int, *, label: str) -> None:
    if type(value) is not int or value <= 0:
        raise ModelAuditError(f"asset {label} byte count must be a positive integer")


def _validate_asset_id(value: str) -> str:
    if type(value) is not str:
        raise ModelAuditError("asset ID must be a stable portable relative identifier")
    components = value.split("/")
    if not _ASSET_ID.fullmatch(value) or any(
        component in {"", ".", ".."}
        or component.endswith((" ", "."))
        or component.split(".", 1)[0].casefold() in _WINDOWS_RESERVED_NAMES
        for component in components
    ):
        raise ModelAuditError("asset ID must be a stable portable relative identifier")
    return value


def _asset_id_collision_key(value: str) -> str:
    return unicodedata.normalize("NFKC", value).casefold()


def _validate_asset_path(value: Path, *, label: str) -> Path:
    if not isinstance(value, Path):
        raise ModelAuditError(f"asset {label} path must be a pathlib.Path")
    return value


def _read_exact_snapshot(
    path: Path,
    asset_id: str,
    expected_bytes: int,
) -> _AssetSnapshot:
    try:
        absolute, initial = _inspect_regular_asset_path(path, asset_id=asset_id)
        if initial.st_size != expected_bytes:
            raise ModelAuditError(
                f"asset {asset_id} byte count is {initial.st_size}; "
                f"manifest declares {expected_bytes}"
            )
        with absolute.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_file_snapshot(initial, opened):
                raise ModelAuditError(f"asset {asset_id} changed before validation")
            content = source.read(expected_bytes + 1)
            finished = os.fstat(source.fileno())
        final_absolute, final = _inspect_regular_asset_path(
            absolute,
            asset_id=asset_id,
        )
    except OSError as error:
        raise ModelAuditError(f"cannot read asset: {asset_id}") from error
    if final_absolute != absolute or (
        not _same_file_snapshot(opened, finished)
        or not _same_file_snapshot(initial, final)
        or not _same_file_snapshot(finished, final)
    ):
        raise ModelAuditError(f"asset {asset_id} changed during validation")
    if len(content) != expected_bytes:
        raise ModelAuditError(
            f"asset {asset_id} byte count is {len(content)}; "
            f"manifest declares {expected_bytes}"
        )
    identity_key: tuple[object, ...]
    if finished.st_ino:
        identity_key = ("inode", finished.st_dev, finished.st_ino)
    else:
        identity_key = (
            "path",
            os.path.normcase(os.path.normpath(os.fspath(absolute))),
        )
    return _AssetSnapshot(
        content=content,
        identity_key=identity_key,
        path=absolute,
    )


def _snapshots_alias(first: _AssetSnapshot, second: _AssetSnapshot) -> bool:
    if first.identity_key == second.identity_key:
        return True
    try:
        return os.path.samefile(first.path, second.path)
    except OSError as error:
        raise ModelAuditError(
            "cannot verify physical HTR bundle asset uniqueness"
        ) from error


def _inspect_regular_asset_path(
    path: Path,
    *,
    asset_id: str,
) -> tuple[Path, os.stat_result]:
    try:
        raw = Path(os.fspath(path))
        if ".." in raw.parts:
            raise ModelAuditError(f"asset {asset_id} path is not portable")
        absolute = Path(os.path.abspath(os.fspath(raw)))
    except ModelAuditError:
        raise
    except (OSError, TypeError, ValueError) as error:
        raise ModelAuditError(f"cannot inspect asset: {asset_id}") from error
    if os.name == "nt" and any(":" in component for component in absolute.parts[1:]):
        raise ModelAuditError(f"asset {asset_id} path is not portable")
    is_junction = getattr(os.path, "isjunction", lambda _: False)
    metadata: os.stat_result | None = None
    components = tuple(reversed((absolute, *absolute.parents)))
    try:
        for component in components:
            current = component.stat(follow_symlinks=False)
            if _is_reparse_point(current) or is_junction(component):
                raise ModelAuditError(
                    f"asset {asset_id} traverses a link or reparse point"
                )
            if component != absolute and not stat.S_ISDIR(current.st_mode):
                raise ModelAuditError(
                    f"asset {asset_id} has a non-directory path component"
                )
            metadata = current
    except ModelAuditError:
        raise
    except (OSError, ValueError) as error:
        raise ModelAuditError(f"cannot inspect asset: {asset_id}") from error
    if metadata is None or not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise ModelAuditError(f"asset {asset_id} must be one unlinked regular file")
    return absolute, metadata


def _is_reparse_point(metadata: os.stat_result) -> bool:
    return stat.S_ISLNK(metadata.st_mode) or bool(
        getattr(metadata, "st_file_attributes", 0) & _WINDOWS_REPARSE_POINT
    )


def _same_file_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
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


def _sha256_snapshot(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _validate_sha256(value: str, *, label: str) -> str:
    if type(value) is not str or not _SHA256.fullmatch(value):
        raise ModelAuditError(
            f"declared {label} SHA-256 must be 64 lowercase hex digits"
        )
    return value


def _audit_privacy_markers(content: bytes, *, label: str) -> None:
    searchable = _normalize_json_escapes(content.lower())
    marker = next(
        (value for value in _FORBIDDEN_BINARY_MARKERS if value in searchable),
        None,
    )
    if marker is not None:
        raise ModelAuditError(
            f"asset {label} contains a forbidden endpoint or workstation-path "
            f"marker: {marker.decode('ascii', errors='replace')}"
        )


def _normalize_json_escapes(content: bytes) -> bytes:
    """Expose common/nested JSON escapes before privacy-marker scanning."""

    searchable = content
    unicode_escape = re.compile(rb"\\u00([0-7][0-9a-f])")

    def decode_ascii(match: re.Match[bytes]) -> bytes:
        return bytes((int(match.group(1), 16),))

    for _ in range(8):
        normalized = unicode_escape.sub(decode_ascii, searchable)
        normalized = normalized.replace(b"\\/", b"/").replace(b"\\\\", b"\\")
        if normalized == searchable:
            return normalized
        searchable = normalized
    return searchable


def _audit_model_table(content: bytes) -> None:
    if len(content) < 8 or content[4:8] != _TFLITE_IDENTIFIER:
        raise ModelAuditError("model does not have the TFL3 FlatBuffer identifier")
    root = struct.unpack_from("<I", content, 0)[0]
    if root < 8 or root % 4 != 0 or root + 4 > len(content):
        raise ModelAuditError("model has an invalid FlatBuffer root table offset")
    vtable_distance = struct.unpack_from("<i", content, root)[0]
    vtable = root - vtable_distance
    if vtable_distance <= 0 or vtable < 8 or vtable + 4 > root:
        raise ModelAuditError("model has an invalid FlatBuffer vtable offset")
    vtable_size, object_size = struct.unpack_from("<HH", content, vtable)
    if (
        vtable_size < 14
        or vtable_size % 2 != 0
        or vtable + vtable_size > root
        or object_size < 20
        or root + object_size > len(content)
    ):
        raise ModelAuditError("model has an invalid TFLite Model table")

    def field_offset(index: int) -> int:
        entry = vtable + 4 + index * 2
        if entry + 2 > vtable + vtable_size:
            return 0
        offset = struct.unpack_from("<H", content, entry)[0]
        if offset and (offset < 4 or offset + 4 > object_size):
            raise ModelAuditError("model table has an invalid field offset")
        return offset

    version_offset = field_offset(0)
    if (
        not version_offset
        or struct.unpack_from("<I", content, root + version_offset)[0] != 3
    ):
        raise ModelAuditError("model does not declare TFLite schema version 3")

    for index, name in ((1, "operator codes"), (2, "subgraphs"), (4, "buffers")):
        offset = field_offset(index)
        if not offset:
            raise ModelAuditError(f"model has no {name} vector")
        field = root + offset
        relative = struct.unpack_from("<I", content, field)[0]
        vector = field + relative
        if relative == 0 or vector + 4 > len(content):
            raise ModelAuditError(f"model has an invalid {name} vector")
        count = struct.unpack_from("<I", content, vector)[0]
        if count == 0 or vector + 4 + count * 4 > len(content):
            raise ModelAuditError(f"model has an empty or truncated {name} vector")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path)
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--sha256", dest="expected_sha256", required=True)
    parser.add_argument("--bytes", dest="expected_bytes", type=int, required=True)
    parser.add_argument("--max-bytes", type=int, default=MAX_HTR_BUNDLE_BYTES)
    parser.add_argument("--companion", action="append", default=[], type=Path)
    parser.add_argument("--companion-id", action="append", default=[])
    parser.add_argument("--companion-sha256", action="append", default=[])
    parser.add_argument("--companion-bytes", action="append", default=[], type=int)
    return parser


def main() -> int:
    parser = _parser()
    args = parser.parse_args()
    companion_count = len(args.companion)
    if (
        len(args.companion_id) != companion_count
        or len(args.companion_sha256) != companion_count
        or len(args.companion_bytes) != companion_count
    ):
        parser.error(
            "each --companion requires one aligned --companion-id, "
            "--companion-sha256, and --companion-bytes"
        )
    companions = tuple(
        CompanionExpectation(asset_id, path, sha256, byte_count)
        for path, asset_id, sha256, byte_count in zip(
            args.companion,
            args.companion_id,
            args.companion_sha256,
            args.companion_bytes,
            strict=True,
        )
    )
    try:
        result = audit_tflite(
            args.model,
            asset_id=args.asset_id,
            expected_sha256=args.expected_sha256,
            expected_bytes=args.expected_bytes,
            max_bytes=args.max_bytes,
            companions=companions,
        )
    except ModelAuditError as error:
        raise SystemExit(f"V2 model audit failed: {error}") from error
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
