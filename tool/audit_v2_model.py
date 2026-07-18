#!/usr/bin/env python3
"""Structural primitives for a future bundled V2 TFLite artifact.

This is not the P3/P5 release audit: it cannot yet inspect operators, tensor
contracts, quantization, or an interpreter. CI runs its unit tests only until a
real generated model and locked LiteRT validator exist. A future release audit
will compose these hash/size/privacy/FlatBuffer checks with those runtime gates.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
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


class ModelAuditError(ValueError):
    """A candidate cannot be accepted as a bundled V2 model."""


@dataclass(frozen=True)
class CompanionExpectation:
    """Integrity declaration for one non-model file in the HTR bundle."""

    asset_id: str
    path: Path
    expected_sha256: str
    expected_bytes: int


def audit_tflite(
    path: Path,
    *,
    asset_id: str,
    expected_sha256: str,
    expected_bytes: int,
    max_bytes: int = MAX_HTR_BUNDLE_BYTES,
    companions: tuple[CompanionExpectation, ...] = (),
) -> dict[str, object]:
    model_id = _validate_asset_id(asset_id)
    companion_ids = [
        _validate_asset_id(companion.asset_id) for companion in companions
    ]
    if (
        type(max_bytes) is not int
        or max_bytes <= 0
        or max_bytes > MAX_HTR_BUNDLE_BYTES
    ):
        raise ModelAuditError(
            "bundle byte budget must be a positive integer no greater than "
            f"{MAX_HTR_BUNDLE_BYTES}"
        )
    _validate_expected_bytes(expected_bytes, label=model_id)
    expected_bundle_bytes = expected_bytes + sum(
        _validated_companion_bytes(companion, companion_id)
        for companion, companion_id in zip(companions, companion_ids, strict=True)
    )
    if expected_bundle_bytes > max_bytes:
        raise ModelAuditError(
            f"HTR asset bundle declares {expected_bundle_bytes} bytes; "
            f"the budget is {max_bytes} bytes"
        )
    if len({model_id, *companion_ids}) != 1 + len(companion_ids):
        raise ModelAuditError("model and companion asset IDs must be unique")

    content = _read_exact_snapshot(path, model_id, expected_bytes)
    if len(content) < 8:
        raise ModelAuditError("model is too short to be a TFLite FlatBuffer")
    _audit_model_table(content)
    _audit_privacy_markers(content, label=model_id)
    actual_sha256 = _sha256_snapshot(content)
    normalized = _normalize_sha256(expected_sha256, label=model_id)
    if actual_sha256 != normalized:
        raise ModelAuditError(
            f"asset {model_id} SHA-256 is {actual_sha256}; "
            f"manifest declares {normalized}"
        )

    companion_results: list[dict[str, int | str]] = []
    bundle_size = len(content)
    for companion, companion_id in zip(companions, companion_ids, strict=True):
        companion_content = _read_exact_snapshot(
            companion.path,
            companion_id,
            companion.expected_bytes,
        )
        _audit_privacy_markers(companion_content, label=companion_id)
        companion_sha256 = _sha256_snapshot(companion_content)
        expected_companion_sha256 = _normalize_sha256(
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


def _validated_companion_bytes(
    companion: CompanionExpectation,
    companion_id: str,
) -> int:
    _validate_expected_bytes(companion.expected_bytes, label=companion_id)
    return companion.expected_bytes


def _validate_expected_bytes(value: int, *, label: str) -> None:
    if type(value) is not int or value <= 0:
        raise ModelAuditError(f"asset {label} byte count must be a positive integer")


def _validate_asset_id(value: str) -> str:
    if not isinstance(value, str):
        raise ModelAuditError(
            "asset ID must be a stable portable relative identifier"
        )
    normalized = value.strip()
    path = PurePosixPath(normalized)
    if (
        value != normalized
        or not _ASSET_ID.fullmatch(normalized)
        or path.is_absolute()
        or any(part in {"", ".", ".."} for part in normalized.split("/"))
    ):
        raise ModelAuditError(
            "asset ID must be a stable portable relative identifier"
        )
    return normalized


def _read_exact_snapshot(path: Path, asset_id: str, expected_bytes: int) -> bytes:
    if not path.is_file():
        raise ModelAuditError(f"asset is not a file: {asset_id}")
    try:
        with path.open("rb") as source:
            content = source.read(expected_bytes + 1)
    except OSError as error:
        raise ModelAuditError(f"cannot read asset: {asset_id}") from error
    if len(content) != expected_bytes:
        raise ModelAuditError(
            f"asset {asset_id} byte count is {len(content)}; "
            f"manifest declares {expected_bytes}"
        )
    return content


def _sha256_snapshot(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def _normalize_sha256(value: str, *, label: str) -> str:
    normalized = value.strip().lower()
    if len(normalized) != 64 or any(
        character not in "0123456789abcdef" for character in normalized
    ):
        raise ModelAuditError(f"declared {label} SHA-256 is not 64 hex digits")
    return normalized


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
