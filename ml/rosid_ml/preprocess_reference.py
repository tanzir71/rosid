"""Strict verification for the non-qualifying app preprocessing reference.

This module verifies the frozen Dart-side pixel-plane reference and its public
source fixtures.  It deliberately cannot issue cross-language parity or
production evidence: no Python preprocessing implementation is represented by
this schema, and parsing recorded hashes cannot prove that result planes were
computed correctly.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
import unicodedata
from dataclasses import dataclass
from pathlib import Path

from .acquisition import validate_portable_relative_path
from .provenance import canonical_json_bytes
from .storage import normalize_path, paths_equal, require_tracked_unchanged_path


_SCHEMA = "rosid-v2-app-preprocess-goldens-v1"
_SCOPE = "app_reference_only"
_PYTHON_PARITY_STATUS = "not_implemented"
_MANIFEST_REPOSITORY_PATH = Path("test/fixtures/v2_preprocessing/app_reference_v1.json")
_DIGEST_REPOSITORY_PATH = Path("test/fixtures/v2_preprocessing/app_reference_v1.sha256")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_MAX_MANIFEST_BYTES = 1_000_000
_MAX_DIGEST_BYTES = 256
_MAX_SOURCE_BYTES = 100_000_000
_WINDOWS_REPARSE_POINT = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)

_EXPECTED_PIPELINE_STAGES = (
    "decode and bake orientation",
    "cap input longest dimension",
    "perspective warp from the fixed quad",
    "apply requested quarter-turn rotation",
    "fit configured dimensions with linear interpolation",
    "normalize percentile contrast",
    "convert to grayscale",
    "apply adaptive threshold",
    "estimate skew when enabled",
    "for absolute skew >= 0.5 degrees: rotate color, refit, and recompute "
    "grayscale and threshold",
)
_EXPECTED_EXCLUDED_STAGES = (
    "document-quad detection",
    "JPEG encode/decode for cross-language parity",
    "line segmentation",
    "model tensor resize, padding, layout, dtype, and normalization",
)
_EXPECTED_PLANE_SERIALIZATION = {
    "binarized": "Y8 restricted to 0 or 255",
    "color": "R8,G8,B8,A8 channel order",
    "grayscale": "Y8 from the opaque grayscale pixel red channel",
    "hash_scope": "plane payload bytes only",
    "jpeg_container_included": False,
    "packing": "tightly packed with no row padding",
    "pixel_order": "top-to-bottom rows, left-to-right pixels",
}
_EXPECTED_VECTOR_SOURCES = (
    ("english-receipt-default", "assets/fixtures/english_receipt.png"),
    (
        "mixed-bangla-receipt-quarter-turn",
        "assets/fixtures/mixed_bangla_receipt.png",
    ),
    ("handwritten-bangla-deskew", "assets/fixtures/handwritten_bangla_note.png"),
)


@dataclass(frozen=True)
class PlaneReference:
    """Metadata for one recorded raw plane; the payload is not in the manifest."""

    layout: str
    width: int
    height: int
    channels: int
    byte_count: int
    channel_minimums: tuple[int, ...]
    channel_maximums: tuple[int, ...]
    sha256: str
    zero_count: int | None = None
    full_scale_count: int | None = None


@dataclass(frozen=True)
class BlobReference:
    byte_count: int
    sha256: str


@dataclass(frozen=True)
class PreprocessOptionsReference:
    minimum_dimension: int
    maximum_dimension: int
    adaptive_window: int
    threshold_bias: int
    deskew: bool
    rotation_quarter_turns: int


PointMillionths = tuple[int, int]


@dataclass(frozen=True)
class QuadReference:
    top_left: PointMillionths
    top_right: PointMillionths
    bottom_right: PointMillionths
    bottom_left: PointMillionths


@dataclass(frozen=True)
class PreprocessResultReference:
    width: int
    height: int
    deskew_half_degree_ticks: int
    deskew_angle_degrees: float
    color_corrected_plane: PlaneReference
    grayscale_plane: PlaneReference
    binarized_plane: PlaneReference
    color_corrected_jpeg: BlobReference | None = None
    binarized_jpeg: BlobReference | None = None


@dataclass(frozen=True)
class AppPreprocessVector:
    id: str
    source_path: str
    source_encoded_byte_count: int
    source_encoded_sha256: str
    source_plane: PlaneReference
    quad: QuadReference
    options: PreprocessOptionsReference
    result: PreprocessResultReference


@dataclass(frozen=True)
class AppPreprocessReference:
    """A verified app-only reference, never parity or production evidence."""

    manifest_sha256: str
    schema: str
    scope: str
    python_parity_status: str
    vectors: tuple[AppPreprocessVector, ...]


def verify_app_preprocess_reference(
    manifest_path: Path,
    digest_path: Path,
    *,
    worktree_root: Path,
) -> AppPreprocessReference:
    """Verify and parse the tracked app-only preprocessing reference.

    Every file read by this verifier must be an ordinary tracked file whose
    index and worktree bytes match ``HEAD``.  The returned type carries no
    eligibility or parity assertion.
    """

    root = normalize_path(worktree_root)
    manifest = normalize_path(manifest_path)
    digest = normalize_path(digest_path)
    _require_repository_location(
        manifest,
        root=root,
        expected_relative=_MANIFEST_REPOSITORY_PATH,
        label="app preprocessing manifest",
    )
    _require_repository_location(
        digest,
        root=root,
        expected_relative=_DIGEST_REPOSITORY_PATH,
        label="app preprocessing digest",
    )

    manifest_bytes = _read_tracked_bytes(
        manifest,
        root=root,
        maximum=_MAX_MANIFEST_BYTES,
        label="app preprocessing manifest",
    )
    digest_bytes = _read_tracked_bytes(
        digest,
        root=root,
        maximum=_MAX_DIGEST_BYTES,
        label="app preprocessing digest",
    )
    manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    expected_digest = f"{manifest_sha256}  {_MANIFEST_REPOSITORY_PATH.name}\n".encode(
        "ascii"
    )
    if digest_bytes != expected_digest:
        raise ValueError(
            "app preprocessing digest must be the exact lowercase SHA-256 record"
        )

    value = _parse_unique_json(manifest_bytes)
    try:
        canonical = canonical_json_bytes(value)
    except (TypeError, ValueError, UnicodeError, RecursionError) as error:
        raise ValueError("app preprocessing manifest is not canonical JSON") from error
    if manifest_bytes != canonical:
        raise ValueError("app preprocessing manifest must use canonical NFC UTF-8 JSON")
    manifest_object = _exact_object(
        value,
        label="app preprocessing manifest",
        keys={
            "excluded_stages",
            "fixture_origin",
            "hash",
            "implementation",
            "manifest_serialization",
            "pipeline_stages",
            "plane_serialization",
            "python_parity_status",
            "quad_serialization",
            "schema",
            "scope",
            "source_decode",
            "v1_jpeg_regression_scope",
            "vectors",
        },
    )
    _require_constant(manifest_object, "schema", _SCHEMA)
    _require_constant(manifest_object, "scope", _SCOPE)
    _require_constant(
        manifest_object,
        "python_parity_status",
        _PYTHON_PARITY_STATUS,
    )
    _require_constant(manifest_object, "fixture_origin", "synthetic_privacy_safe")
    _require_constant(manifest_object, "hash", "sha256_lowercase_hex")
    _require_constant(
        manifest_object,
        "implementation",
        "lib/ocr/preprocess/image_preprocessor.dart#ImagePreprocessor.processPlanes",
    )
    _require_constant(
        manifest_object,
        "manifest_serialization",
        "NFC UTF-8 JSON, recursively sorted keys, two-space indent, LF terminator",
    )
    _require_constant(
        manifest_object,
        "quad_serialization",
        "normalized millionths as integers; divide each value by 1000000",
    )
    _require_constant(
        manifest_object,
        "source_decode",
        "package:image decodeImage then bakeOrientation",
    )
    _require_constant(
        manifest_object,
        "v1_jpeg_regression_scope",
        "app-code regression only; excluded from cross-language plane parity",
    )
    _require_string_sequence(
        manifest_object["pipeline_stages"],
        expected=_EXPECTED_PIPELINE_STAGES,
        label="pipeline_stages",
    )
    _require_string_sequence(
        manifest_object["excluded_stages"],
        expected=_EXPECTED_EXCLUDED_STAGES,
        label="excluded_stages",
    )
    plane_serialization = _exact_object(
        manifest_object["plane_serialization"],
        label="plane_serialization",
        keys=set(_EXPECTED_PLANE_SERIALIZATION),
    )
    for key, expected in _EXPECTED_PLANE_SERIALIZATION.items():
        _require_constant(plane_serialization, key, expected)

    raw_vectors = _list(manifest_object["vectors"], label="vectors")
    if len(raw_vectors) != len(_EXPECTED_VECTOR_SOURCES):
        raise ValueError("vectors must contain the three fixed public fixtures")
    vectors = tuple(
        _parse_vector(
            item,
            expected_id=expected_id,
            expected_source_path=expected_source,
            root=root,
        )
        for item, (expected_id, expected_source) in zip(
            raw_vectors,
            _EXPECTED_VECTOR_SOURCES,
            strict=True,
        )
    )
    return AppPreprocessReference(
        manifest_sha256=manifest_sha256,
        schema=_SCHEMA,
        scope=_SCOPE,
        python_parity_status=_PYTHON_PARITY_STATUS,
        vectors=vectors,
    )


def _parse_vector(
    value: object,
    *,
    expected_id: str,
    expected_source_path: str,
    root: Path,
) -> AppPreprocessVector:
    label = f"vector {expected_id}"
    item = _exact_object(
        value,
        label=label,
        keys={
            "id",
            "options",
            "quad",
            "result",
            "source_encoded_byte_count",
            "source_encoded_sha256",
            "source_path",
            "source_plane",
        },
    )
    _require_constant(item, "id", expected_id)
    _require_constant(item, "source_path", expected_source_path)
    validate_portable_relative_path(expected_source_path)
    source_path = normalize_path(expected_source_path, base=root)
    source_bytes = _read_tracked_bytes(
        source_path,
        root=root,
        maximum=_MAX_SOURCE_BYTES,
        label=f"{label} source",
    )
    source_count = _positive_int(
        item["source_encoded_byte_count"],
        label=f"{label}.source_encoded_byte_count",
    )
    if source_count != len(source_bytes):
        raise ValueError(f"{label} source byte count does not match tracked source")
    source_sha256 = _sha256(
        item["source_encoded_sha256"],
        label=f"{label}.source_encoded_sha256",
    )
    if source_sha256 != hashlib.sha256(source_bytes).hexdigest():
        raise ValueError(f"{label} source SHA-256 does not match tracked source")

    source_plane = _parse_plane(
        item["source_plane"],
        label=f"{label}.source_plane",
        expected_layout="rgba8",
    )
    options = _parse_options(item["options"], label=f"{label}.options")
    quad = _parse_quad(item["quad"], label=f"{label}.quad")
    result = _parse_result(
        item["result"],
        label=f"{label}.result",
        options=options,
        expect_jpeg=expected_id == _EXPECTED_VECTOR_SOURCES[0][0],
    )
    return AppPreprocessVector(
        id=expected_id,
        source_path=expected_source_path,
        source_encoded_byte_count=source_count,
        source_encoded_sha256=source_sha256,
        source_plane=source_plane,
        quad=quad,
        options=options,
        result=result,
    )


def _parse_options(value: object, *, label: str) -> PreprocessOptionsReference:
    item = _exact_object(
        value,
        label=label,
        keys={
            "adaptive_window",
            "deskew",
            "maximum_dimension",
            "minimum_dimension",
            "rotation_quarter_turns",
            "threshold_bias",
        },
    )
    minimum = _positive_int(item["minimum_dimension"], label=f"{label}.minimum")
    maximum = _positive_int(item["maximum_dimension"], label=f"{label}.maximum")
    if maximum < 2 or minimum > maximum:
        raise ValueError(f"{label} dimensions must satisfy 1 <= minimum <= maximum")
    window = _positive_int(item["adaptive_window"], label=f"{label}.adaptive_window")
    if window < 3 or window % 2 == 0:
        raise ValueError(f"{label}.adaptive_window must be an odd integer >= 3")
    bias = _int(item["threshold_bias"], label=f"{label}.threshold_bias")
    if not 0 <= bias <= 255:
        raise ValueError(f"{label}.threshold_bias must be between 0 and 255")
    deskew = item["deskew"]
    if type(deskew) is not bool:
        raise ValueError(f"{label}.deskew must be a boolean")
    rotation = _int(
        item["rotation_quarter_turns"],
        label=f"{label}.rotation_quarter_turns",
    )
    if not 0 <= rotation <= 3:
        raise ValueError(f"{label}.rotation_quarter_turns must be between 0 and 3")
    return PreprocessOptionsReference(
        minimum_dimension=minimum,
        maximum_dimension=maximum,
        adaptive_window=window,
        threshold_bias=bias,
        deskew=deskew,
        rotation_quarter_turns=rotation,
    )


def _parse_quad(value: object, *, label: str) -> QuadReference:
    item = _exact_object(
        value,
        label=label,
        keys={"bottom_left", "bottom_right", "top_left", "top_right"},
    )
    points = {
        name: _parse_point(item[name], label=f"{label}.{name}")
        for name in ("top_left", "top_right", "bottom_right", "bottom_left")
    }
    polygon = tuple(points.values())
    turns = []
    for index, current in enumerate(polygon):
        following = polygon[(index + 1) % len(polygon)]
        after = polygon[(index + 2) % len(polygon)]
        turns.append(
            (following[0] - current[0]) * (after[1] - following[1])
            - (following[1] - current[1]) * (after[0] - following[0])
        )
    if any(turn <= 0 for turn in turns):
        raise ValueError(f"{label} must be a non-degenerate convex screen-order quad")
    twice_area = abs(
        sum(
            current[0] * polygon[(index + 1) % len(polygon)][1]
            - polygon[(index + 1) % len(polygon)][0] * current[1]
            for index, current in enumerate(polygon)
        )
    )
    if twice_area <= 160_000_000_000:
        raise ValueError(f"{label} normalized area must be greater than 0.08")
    return QuadReference(
        top_left=points["top_left"],
        top_right=points["top_right"],
        bottom_right=points["bottom_right"],
        bottom_left=points["bottom_left"],
    )


def _parse_point(value: object, *, label: str) -> PointMillionths:
    coordinates = _list(value, label=label)
    if len(coordinates) != 2:
        raise ValueError(f"{label} must contain exactly two coordinates")
    point = tuple(_int(item, label=f"{label} coordinate") for item in coordinates)
    if any(coordinate < 0 or coordinate > 1_000_000 for coordinate in point):
        raise ValueError(f"{label} coordinates must be normalized millionths")
    return point[0], point[1]


def _parse_result(
    value: object,
    *,
    label: str,
    options: PreprocessOptionsReference,
    expect_jpeg: bool,
) -> PreprocessResultReference:
    keys = {
        "binarized_plane",
        "color_corrected_plane",
        "deskew_angle_degrees",
        "deskew_half_degree_ticks",
        "grayscale_plane",
        "height",
        "width",
    }
    if expect_jpeg:
        keys.add("v1_production_jpeg_regression")
    item = _exact_object(value, label=label, keys=keys)
    width = _positive_int(item["width"], label=f"{label}.width")
    height = _positive_int(item["height"], label=f"{label}.height")
    shortest = min(width, height)
    longest = max(width, height)
    if longest > options.maximum_dimension:
        raise ValueError(f"{label} dimensions exceed the configured maximum")
    if shortest < options.minimum_dimension and longest != options.maximum_dimension:
        raise ValueError(
            f"{label} dimensions satisfy neither the configured minimum nor "
            "the maximum-dimension cap"
        )
    ticks = _int(
        item["deskew_half_degree_ticks"],
        label=f"{label}.deskew_half_degree_ticks",
    )
    if not -10 <= ticks <= 10:
        raise ValueError(f"{label}.deskew_half_degree_ticks is outside [-10, 10]")
    angle = item["deskew_angle_degrees"]
    if type(angle) is not float or not math.isfinite(angle):
        raise ValueError(f"{label}.deskew_angle_degrees must be a finite JSON decimal")
    if angle != ticks / 2:
        raise ValueError(f"{label} deskew angle does not match half-degree ticks")
    if not options.deskew and ticks != 0:
        raise ValueError(f"{label} cannot record deskew when deskew is disabled")

    color = _parse_plane(
        item["color_corrected_plane"],
        label=f"{label}.color_corrected_plane",
        expected_layout="rgba8",
    )
    grayscale = _parse_plane(
        item["grayscale_plane"],
        label=f"{label}.grayscale_plane",
        expected_layout="y8",
    )
    binarized = _parse_plane(
        item["binarized_plane"],
        label=f"{label}.binarized_plane",
        expected_layout="y8",
        binary=True,
    )
    for name, plane in (
        ("color_corrected_plane", color),
        ("grayscale_plane", grayscale),
        ("binarized_plane", binarized),
    ):
        if (plane.width, plane.height) != (width, height):
            raise ValueError(f"{label}.{name} dimensions do not match result")

    color_jpeg = None
    binary_jpeg = None
    if expect_jpeg:
        regression = _exact_object(
            item["v1_production_jpeg_regression"],
            label=f"{label}.v1_production_jpeg_regression",
            keys={"binarized", "color_corrected"},
        )
        color_jpeg = _parse_blob(
            regression["color_corrected"],
            label=f"{label}.v1_production_jpeg_regression.color_corrected",
        )
        binary_jpeg = _parse_blob(
            regression["binarized"],
            label=f"{label}.v1_production_jpeg_regression.binarized",
        )
    return PreprocessResultReference(
        width=width,
        height=height,
        deskew_half_degree_ticks=ticks,
        deskew_angle_degrees=angle,
        color_corrected_plane=color,
        grayscale_plane=grayscale,
        binarized_plane=binarized,
        color_corrected_jpeg=color_jpeg,
        binarized_jpeg=binary_jpeg,
    )


def _parse_plane(
    value: object,
    *,
    label: str,
    expected_layout: str,
    binary: bool = False,
) -> PlaneReference:
    channels = 4 if expected_layout == "rgba8" else 1
    keys = {
        "byte_count",
        "channel_maximums",
        "channel_minimums",
        "channels",
        "height",
        "layout",
        "sha256",
        "width",
    }
    if channels == 1:
        keys.update({"full_scale_count", "zero_count"})
    item = _exact_object(value, label=label, keys=keys)
    _require_constant(item, "layout", expected_layout)
    recorded_channels = _positive_int(item["channels"], label=f"{label}.channels")
    if recorded_channels != channels:
        raise ValueError(f"{label}.channels does not match {expected_layout}")
    width = _positive_int(item["width"], label=f"{label}.width")
    height = _positive_int(item["height"], label=f"{label}.height")
    byte_count = _positive_int(item["byte_count"], label=f"{label}.byte_count")
    if byte_count != width * height * channels:
        raise ValueError(f"{label}.byte_count does not match dimensions and channels")
    minimums = _channel_values(
        item["channel_minimums"],
        channels=channels,
        label=f"{label}.channel_minimums",
    )
    maximums = _channel_values(
        item["channel_maximums"],
        channels=channels,
        label=f"{label}.channel_maximums",
    )
    if any(minimum > maximum for minimum, maximum in zip(minimums, maximums)):
        raise ValueError(f"{label} channel minimum exceeds maximum")
    if channels == 4 and (minimums[3] != 255 or maximums[3] != 255):
        raise ValueError(f"{label} RGBA alpha channel must be opaque")
    sha256 = _sha256(item["sha256"], label=f"{label}.sha256")

    zero_count = None
    full_scale_count = None
    if channels == 1:
        zero_count = _nonnegative_int(item["zero_count"], label=f"{label}.zero_count")
        full_scale_count = _nonnegative_int(
            item["full_scale_count"], label=f"{label}.full_scale_count"
        )
        if zero_count + full_scale_count > byte_count:
            raise ValueError(f"{label} endpoint counts exceed the plane size")
        if (minimums[0] == 0) != (zero_count > 0):
            raise ValueError(f"{label} zero count does not match channel minimum")
        if (maximums[0] == 255) != (full_scale_count > 0):
            raise ValueError(f"{label} full-scale count does not match channel maximum")
        if binary:
            if zero_count + full_scale_count != byte_count:
                raise ValueError(f"{label} binary plane must contain only 0 and 255")
            expected_minimum = 0 if zero_count else 255
            expected_maximum = 255 if full_scale_count else 0
            if minimums != (expected_minimum,) or maximums != (expected_maximum,):
                raise ValueError(f"{label} binary endpoint statistics are inconsistent")

    return PlaneReference(
        layout=expected_layout,
        width=width,
        height=height,
        channels=channels,
        byte_count=byte_count,
        channel_minimums=minimums,
        channel_maximums=maximums,
        sha256=sha256,
        zero_count=zero_count,
        full_scale_count=full_scale_count,
    )


def _parse_blob(value: object, *, label: str) -> BlobReference:
    item = _exact_object(value, label=label, keys={"byte_count", "sha256"})
    return BlobReference(
        byte_count=_positive_int(item["byte_count"], label=f"{label}.byte_count"),
        sha256=_sha256(item["sha256"], label=f"{label}.sha256"),
    )


def _channel_values(value: object, *, channels: int, label: str) -> tuple[int, ...]:
    raw = _list(value, label=label)
    if len(raw) != channels:
        raise ValueError(f"{label} must contain one value per channel")
    result = tuple(_int(item, label=f"{label} value") for item in raw)
    if any(item < 0 or item > 255 for item in result):
        raise ValueError(f"{label} values must be between 0 and 255")
    return result


def _require_repository_location(
    path: Path,
    *,
    root: Path,
    expected_relative: Path,
    label: str,
) -> None:
    expected = normalize_path(expected_relative, base=root)
    if not paths_equal(path, expected):
        raise ValueError(f"{label} must be {expected_relative.as_posix()}")


def _read_tracked_bytes(
    path: Path,
    *,
    root: Path,
    maximum: int,
    label: str,
) -> bytes:
    try:
        initial = path.stat(follow_symlinks=False)
        _require_plain_file(initial, path=path, label=label)
        if initial.st_size < 1 or initial.st_size > maximum:
            raise ValueError(f"{label} size must be between 1 and {maximum} bytes")
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_file_identity(initial, opened):
                raise ValueError(f"{label} changed before its bounded read")
            content = source.read(maximum + 1)
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
        _require_plain_file(final, path=path, label=label)
    except ValueError:
        raise
    except OSError as error:
        raise ValueError(f"cannot read {label}: {error}") from error
    if (
        not _same_file_identity(opened, finished)
        or not _same_file_identity(initial, final)
        or not _same_file_identity(finished, final)
        or len(content) != final.st_size
    ):
        raise ValueError(f"{label} changed during its bounded read")
    if not content or len(content) > maximum:
        raise ValueError(f"{label} size must be between 1 and {maximum} bytes")
    require_tracked_unchanged_path(
        path,
        expected_worktree=root,
        expected_bytes=content,
    )
    return content


def _require_plain_file(metadata: os.stat_result, *, path: Path, label: str) -> None:
    if (
        bool(getattr(metadata, "st_file_attributes", 0) & _WINDOWS_REPARSE_POINT)
        or not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
    ):
        raise ValueError(f"{label} must be one unlinked regular file: {path}")


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


def _parse_unique_json(content: bytes) -> object:
    try:
        text = content.decode("utf-8", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=_unique_object,
            parse_constant=lambda value: _reject_json_constant(value),
        )
    except (UnicodeError, ValueError, RecursionError) as error:
        raise ValueError(
            "app preprocessing manifest must be strict UTF-8 JSON"
        ) from error


def _unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    normalized_keys: set[str] = set()
    for key, value in pairs:
        normalized = unicodedata.normalize("NFC", key)
        if normalized in normalized_keys:
            raise ValueError(
                "app preprocessing manifest contains duplicate or NFC-colliding keys"
            )
        normalized_keys.add(normalized)
        result[key] = value
    return result


def _reject_json_constant(value: str) -> object:
    raise ValueError(f"non-finite JSON number is forbidden: {value}")


def _exact_object(
    value: object,
    *,
    label: str,
    keys: set[str],
) -> dict[str, object]:
    if type(value) is not dict:
        raise ValueError(f"{label} must be an object")
    actual = set(value)
    if actual != keys:
        missing = sorted(keys - actual)
        extra = sorted(actual - keys)
        raise ValueError(f"{label} keys differ: missing={missing}, extra={extra}")
    return value


def _list(value: object, *, label: str) -> list[object]:
    if type(value) is not list:
        raise ValueError(f"{label} must be an array")
    return value


def _require_string_sequence(
    value: object,
    *,
    expected: tuple[str, ...],
    label: str,
) -> None:
    items = _list(value, label=label)
    if any(type(item) is not str for item in items) or tuple(items) != expected:
        raise ValueError(f"{label} does not match the app reference schema")


def _require_constant(item: dict[str, object], key: str, expected: object) -> None:
    value = item[key]
    if type(value) is not type(expected) or value != expected:
        raise ValueError(f"{key} must equal {expected!r}")


def _int(value: object, *, label: str) -> int:
    if type(value) is not int:
        raise ValueError(f"{label} must be an integer")
    return value


def _positive_int(value: object, *, label: str) -> int:
    result = _int(value, label=label)
    if result <= 0:
        raise ValueError(f"{label} must be positive")
    return result


def _nonnegative_int(value: object, *, label: str) -> int:
    result = _int(value, label=label)
    if result < 0:
        raise ValueError(f"{label} must be nonnegative")
    return result


def _sha256(value: object, *, label: str) -> str:
    if type(value) is not str or not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")
    return value
