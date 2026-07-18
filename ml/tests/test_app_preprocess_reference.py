from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Callable
from unittest import mock

from ml.rosid_ml.preprocess_reference import (
    AppPreprocessReference,
    verify_app_preprocess_reference,
)
from ml.rosid_ml.provenance import canonical_json_bytes


_ROOT = Path(__file__).resolve().parents[2]
_MANIFEST_RELATIVE = Path("test/fixtures/v2_preprocessing/app_reference_v1.json")
_DIGEST_RELATIVE = _MANIFEST_RELATIVE.with_suffix(".sha256")
_MANIFEST = _ROOT / _MANIFEST_RELATIVE
_DIGEST = _ROOT / _DIGEST_RELATIVE
_BASE_VALUE = json.loads(_MANIFEST.read_text(encoding="utf-8"))
_EXPECTED_VECTORS = (
    "english-receipt-default",
    "mixed-bangla-receipt-quarter-turn",
    "handwritten-bangla-deskew",
)
_EXPECTED_ROOT_CONSTANTS = {
    "excluded_stages": [
        "document-quad detection",
        "JPEG encode/decode for cross-language parity",
        "line segmentation",
        "model tensor resize, padding, layout, dtype, and normalization",
    ],
    "fixture_origin": "synthetic_privacy_safe",
    "hash": "sha256_lowercase_hex",
    "implementation": (
        "lib/ocr/preprocess/image_preprocessor.dart#ImagePreprocessor.processPlanes"
    ),
    "manifest_serialization": (
        "NFC UTF-8 JSON, recursively sorted keys, two-space indent, LF terminator"
    ),
    "pipeline_stages": [
        "decode and bake orientation",
        "cap input longest dimension",
        "perspective warp from the fixed quad",
        "apply requested quarter-turn rotation",
        "fit configured dimensions with linear interpolation",
        "normalize percentile contrast",
        "convert to grayscale",
        "apply adaptive threshold",
        "estimate skew when enabled",
        (
            "for absolute skew >= 0.5 degrees: rotate color, refit, and "
            "recompute grayscale and threshold"
        ),
    ],
    "plane_serialization": {
        "binarized": "Y8 restricted to 0 or 255",
        "color": "R8,G8,B8,A8 channel order",
        "grayscale": "Y8 from the opaque grayscale pixel red channel",
        "hash_scope": "plane payload bytes only",
        "jpeg_container_included": False,
        "packing": "tightly packed with no row padding",
        "pixel_order": "top-to-bottom rows, left-to-right pixels",
    },
    "python_parity_status": "not_implemented",
    "quad_serialization": (
        "normalized millionths as integers; divide each value by 1000000"
    ),
    "schema": "rosid-v2-app-preprocess-goldens-v1",
    "scope": "app_reference_only",
    "source_decode": "package:image decodeImage then bakeOrientation",
    "v1_jpeg_regression_scope": (
        "app-code regression only; excluded from cross-language plane parity"
    ),
}

_ROOT_KEYS = frozenset((*_EXPECTED_ROOT_CONSTANTS, "vectors"))
_PLANE_SERIALIZATION_KEYS = frozenset(_EXPECTED_ROOT_CONSTANTS["plane_serialization"])
_VECTOR_KEYS = frozenset(
    {
        "id",
        "options",
        "quad",
        "result",
        "source_encoded_byte_count",
        "source_encoded_sha256",
        "source_path",
        "source_plane",
    }
)
_OPTION_KEYS = frozenset(
    {
        "adaptive_window",
        "deskew",
        "maximum_dimension",
        "minimum_dimension",
        "rotation_quarter_turns",
        "threshold_bias",
    }
)
_QUAD_KEYS = frozenset({"bottom_left", "bottom_right", "top_left", "top_right"})
_RESULT_KEYS = frozenset(
    {
        "binarized_plane",
        "color_corrected_plane",
        "deskew_angle_degrees",
        "deskew_half_degree_ticks",
        "grayscale_plane",
        "height",
        "width",
    }
)
_PLANE_KEYS = frozenset(
    {
        "byte_count",
        "channel_maximums",
        "channel_minimums",
        "channels",
        "height",
        "layout",
        "sha256",
        "width",
    }
)
_COUNTED_PLANE_KEYS = frozenset((*_PLANE_KEYS, "full_scale_count", "zero_count"))
_JPEG_REGRESSION_KEYS = frozenset({"binarized", "color_corrected"})
_BLOB_KEYS = frozenset({"byte_count", "sha256"})


def _node(value: object, path: tuple[str | int, ...]) -> object:
    current = value
    for component in path:
        if isinstance(component, int):
            assert isinstance(current, list)
            current = current[component]
        else:
            assert isinstance(current, dict)
            current = current[component]
    return current


def _replace(value: object, path: tuple[str | int, ...], replacement: object) -> None:
    parent = _node(value, path[:-1])
    component = path[-1]
    if isinstance(component, int):
        assert isinstance(parent, list)
        parent[component] = replacement
    else:
        assert isinstance(parent, dict)
        parent[component] = replacement


class _CommittedReferenceFixture:
    def __init__(self, directory: str) -> None:
        self.root = Path(directory) / "repository"
        self.root.mkdir()
        self.manifest = self.root / _MANIFEST_RELATIVE
        self.digest = self.root / _DIGEST_RELATIVE
        self.manifest.parent.mkdir(parents=True)
        (self.root / ".gitattributes").write_bytes(b"* -text\n")
        for vector in _BASE_VALUE["vectors"]:
            source = self.root / vector["source_path"]
            source.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(_ROOT / vector["source_path"], source)
        self._git("init", "--quiet")
        self._git("config", "user.name", "Preprocess Reference Test")
        self._git(
            "config",
            "user.email",
            "preprocess-reference@example.invalid",
        )
        self.write_and_commit(_BASE_VALUE)

    def _git(self, *arguments: str) -> None:
        subprocess.run(
            ("git", *arguments),
            cwd=self.root,
            check=True,
            capture_output=True,
            shell=False,
        )

    def write_and_commit(
        self,
        value: object,
        *,
        manifest_bytes: bytes | None = None,
        digest_bytes: bytes | None = None,
        include_untracked: bool = True,
    ) -> None:
        self.write(
            value,
            manifest_bytes=manifest_bytes,
            digest_bytes=digest_bytes,
        )
        paths = [
            self.manifest.relative_to(self.root).as_posix(),
            self.digest.relative_to(self.root).as_posix(),
        ]
        if include_untracked:
            paths = ["."]
        self._git("add", "--", *paths)
        self._git("commit", "--quiet", "--allow-empty", "-m", "fixture")

    def write(
        self,
        value: object,
        *,
        manifest_bytes: bytes | None = None,
        digest_bytes: bytes | None = None,
    ) -> None:
        raw = canonical_json_bytes(value) if manifest_bytes is None else manifest_bytes
        self.manifest.write_bytes(raw)
        if digest_bytes is None:
            digest_bytes = (
                f"{hashlib.sha256(raw).hexdigest()}  {self.manifest.name}\n".encode()
            )
        self.digest.write_bytes(digest_bytes)

    def verify(self) -> AppPreprocessReference:
        return verify_app_preprocess_reference(
            self.manifest,
            self.digest,
            worktree_root=self.root,
        )

    def verify_schema_only(self) -> AppPreprocessReference:
        with mock.patch(
            "ml.rosid_ml.preprocess_reference.require_tracked_unchanged_path"
        ):
            return self.verify()


class AppPreprocessReferenceTest(unittest.TestCase):
    def test_checked_in_reference_is_typed_and_explicitly_nonqualifying(self) -> None:
        reference = verify_app_preprocess_reference(
            _MANIFEST,
            _DIGEST,
            worktree_root=_ROOT,
        )

        self.assertIs(type(reference), AppPreprocessReference)
        self.assertEqual(
            reference.manifest_sha256,
            hashlib.sha256(_MANIFEST.read_bytes()).hexdigest(),
        )
        self.assertEqual(reference.scope, "app_reference_only")
        self.assertEqual(reference.python_parity_status, "not_implemented")
        self.assertIs(type(reference.vectors), tuple)
        self.assertEqual(
            tuple(vector.id for vector in reference.vectors), _EXPECTED_VECTORS
        )
        self.assertTrue(
            all(not isinstance(vector, dict) for vector in reference.vectors)
        )

        # This verifier is intentionally not an eligibility, parity, artifact, or
        # lineage API. Adding any such surface would make this app-only precursor
        # dangerously easy to consume as production evidence.
        for attribute in (
            "artifact_role",
            "artifact_type",
            "eligibility",
            "lineage_node",
            "parity_evidence",
            "production_evidence",
            "production_eligible",
            "require_production_eligible",
            "to_lineage_node",
        ):
            with self.subTest(attribute=attribute):
                self.assertFalse(hasattr(reference, attribute))
                self.assertFalse(hasattr(AppPreprocessReference, attribute))

    def test_rejects_missing_or_extra_keys_at_every_schema_level(self) -> None:
        key_specs: tuple[tuple[tuple[str | int, ...], frozenset[str], str], ...] = (
            ((), _ROOT_KEYS, "vectors"),
            (("plane_serialization",), _PLANE_SERIALIZATION_KEYS, "packing"),
            (("vectors", 0), _VECTOR_KEYS, "source_path"),
            (("vectors", 0, "options"), _OPTION_KEYS, "deskew"),
            (("vectors", 0, "quad"), _QUAD_KEYS, "top_left"),
            (
                ("vectors", 0, "result"),
                frozenset((*_RESULT_KEYS, "v1_production_jpeg_regression")),
                "v1_production_jpeg_regression",
            ),
            (("vectors", 1, "result"), _RESULT_KEYS, "width"),
            (("vectors", 0, "source_plane"), _PLANE_KEYS, "sha256"),
            (
                ("vectors", 0, "result", "color_corrected_plane"),
                _PLANE_KEYS,
                "layout",
            ),
            (
                ("vectors", 0, "result", "grayscale_plane"),
                _COUNTED_PLANE_KEYS,
                "full_scale_count",
            ),
            (
                ("vectors", 0, "result", "binarized_plane"),
                _COUNTED_PLANE_KEYS,
                "zero_count",
            ),
            (
                ("vectors", 0, "result", "v1_production_jpeg_regression"),
                _JPEG_REGRESSION_KEYS,
                "binarized",
            ),
            (
                (
                    "vectors",
                    0,
                    "result",
                    "v1_production_jpeg_regression",
                    "color_corrected",
                ),
                _BLOB_KEYS,
                "byte_count",
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)
            for path, expected_keys, missing in key_specs:
                self.assertIn(missing, expected_keys)
                with self.subTest(path=path, missing=missing):
                    value = copy.deepcopy(_BASE_VALUE)
                    target = _node(value, path)
                    self.assertIsInstance(target, dict)
                    del target[missing]
                    fixture.write(value)
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

                with self.subTest(path=path, extra="unexpected"):
                    value = copy.deepcopy(_BASE_VALUE)
                    target = _node(value, path)
                    self.assertIsInstance(target, dict)
                    target["unexpected"] = None
                    fixture.write(value)
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

    def test_rejects_wrong_types_and_changed_fixed_constants(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)
            for field, expected in _EXPECTED_ROOT_CONSTANTS.items():
                with self.subTest(constant=field):
                    value = copy.deepcopy(_BASE_VALUE)
                    if isinstance(expected, str):
                        value[field] = f"{expected}-changed"
                    elif isinstance(expected, list):
                        value[field] = [*expected, "changed"]
                    else:
                        changed = copy.deepcopy(expected)
                        changed[next(iter(changed))] = "changed"
                        value[field] = changed
                    fixture.write(value)
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

            type_cases: tuple[tuple[tuple[str | int, ...], object], ...] = (
                (("vectors",), {}),
                (("plane_serialization", "jpeg_container_included"), 0),
                (("vectors", 0, "id"), 1),
                (("vectors", 0, "source_path"), []),
                (("vectors", 0, "source_encoded_byte_count"), True),
                (("vectors", 0, "source_encoded_sha256"), 1),
                (("vectors", 0, "options"), []),
                (("vectors", 0, "options", "adaptive_window"), True),
                (("vectors", 0, "options", "deskew"), 1),
                (("vectors", 0, "quad"), []),
                (("vectors", 0, "quad", "top_left"), {}),
                (("vectors", 0, "quad", "top_left", 0), 0.08),
                (("vectors", 0, "result"), []),
                (("vectors", 0, "result", "width"), True),
                (("vectors", 0, "result", "deskew_angle_degrees"), "-5.0"),
                (("vectors", 0, "result", "deskew_half_degree_ticks"), -10.0),
                (("vectors", 0, "source_plane", "sha256"), 1),
                (("vectors", 0, "source_plane", "channel_minimums"), {}),
                (
                    (
                        "vectors",
                        0,
                        "result",
                        "v1_production_jpeg_regression",
                        "color_corrected",
                        "byte_count",
                    ),
                    True,
                ),
            )
            for path, replacement in type_cases:
                with self.subTest(path=path, replacement=replacement):
                    value = copy.deepcopy(_BASE_VALUE)
                    _replace(value, path, replacement)
                    fixture.write(value)
                    with self.assertRaises((TypeError, ValueError)):
                        fixture.verify_schema_only()

    def test_rejects_changed_vector_contract_and_invalid_numeric_invariants(
        self,
    ) -> None:
        cases: tuple[tuple[str, Callable[[dict[str, object]], None]], ...] = (
            ("vector_order", lambda value: value["vectors"].reverse()),
            (
                "duplicate_vector",
                lambda value: value["vectors"].__setitem__(
                    1, copy.deepcopy(value["vectors"][0])
                ),
            ),
            (
                "encoded_bytes",
                lambda value: value["vectors"][0].__setitem__(
                    "source_encoded_byte_count",
                    value["vectors"][0]["source_encoded_byte_count"] + 1,
                ),
            ),
            (
                "encoded_hash",
                lambda value: value["vectors"][0].__setitem__(
                    "source_encoded_sha256", "0" * 64
                ),
            ),
            (
                "even_adaptive_window",
                lambda value: value["vectors"][0]["options"].__setitem__(
                    "adaptive_window", 30
                ),
            ),
            (
                "dimension_order",
                lambda value: value["vectors"][0]["options"].__setitem__(
                    "maximum_dimension", 999
                ),
            ),
            (
                "rotation_range",
                lambda value: value["vectors"][0]["options"].__setitem__(
                    "rotation_quarter_turns", 4
                ),
            ),
            (
                "quad_length",
                lambda value: value["vectors"][0]["quad"].__setitem__(
                    "top_left", [80000]
                ),
            ),
            (
                "quad_range",
                lambda value: value["vectors"][0]["quad"].__setitem__(
                    "top_left", [-1, 70000]
                ),
            ),
            (
                "quad_too_small_for_app_contract",
                lambda value: value["vectors"][0].__setitem__(
                    "quad",
                    {
                        "top_left": [100000, 100000],
                        "top_right": [200000, 100000],
                        "bottom_right": [200000, 200000],
                        "bottom_left": [100000, 200000],
                    },
                ),
            ),
            (
                "plane_width",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "width", 0
                ),
            ),
            (
                "plane_byte_count",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "byte_count", 1
                ),
            ),
            (
                "plane_channels",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "channels", 3
                ),
            ),
            (
                "plane_layout",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "layout", "argb8"
                ),
            ),
            (
                "plane_hash",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "sha256", "A" * 64
                ),
            ),
            (
                "channel_count",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "channel_minimums", [0]
                ),
            ),
            (
                "channel_range",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "channel_maximums", [256, 255, 255, 255]
                ),
            ),
            (
                "channel_order",
                lambda value: value["vectors"][0]["source_plane"].update(
                    {
                        "channel_minimums": [200, 0, 0, 255],
                        "channel_maximums": [100, 255, 255, 255],
                    }
                ),
            ),
            (
                "opaque_alpha",
                lambda value: value["vectors"][0]["source_plane"].__setitem__(
                    "channel_minimums", [0, 0, 0, 254]
                ),
            ),
            (
                "result_dimensions",
                lambda value: value["vectors"][0]["result"].__setitem__("width", 1129),
            ),
            (
                "result_exceeds_configured_maximum",
                lambda value: value["vectors"][0]["options"].__setitem__(
                    "maximum_dimension", 1600
                ),
            ),
            (
                "result_misses_minimum_without_maximum_cap",
                lambda value: value["vectors"][0]["options"].__setitem__(
                    "minimum_dimension", 1200
                ),
            ),
            (
                "deskew_ticks",
                lambda value: value["vectors"][0]["result"].__setitem__(
                    "deskew_half_degree_ticks", -9
                ),
            ),
            (
                "grayscale_count",
                lambda value: value["vectors"][0]["result"][
                    "grayscale_plane"
                ].__setitem__("zero_count", 1836251),
            ),
            (
                "binary_partition",
                lambda value: value["vectors"][0]["result"][
                    "binarized_plane"
                ].__setitem__("zero_count", 102680),
            ),
            (
                "binary_extrema",
                lambda value: value["vectors"][0]["result"][
                    "binarized_plane"
                ].__setitem__("channel_maximums", [254]),
            ),
            (
                "jpeg_blob_bytes",
                lambda value: value["vectors"][0]["result"][
                    "v1_production_jpeg_regression"
                ]["color_corrected"].__setitem__("byte_count", 0),
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)
            for name, mutate in cases:
                with self.subTest(case=name):
                    value = copy.deepcopy(_BASE_VALUE)
                    mutate(value)
                    fixture.write(value)
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

    def test_requires_strict_canonical_json_and_exact_digest_sidecar(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)
            canonical = canonical_json_bytes(_BASE_VALUE)
            malformed_cases = (
                (b" " + canonical, None),
                (canonical.rstrip(b"\n"), None),
                (
                    canonical.replace(
                        b"{\n",
                        b'{\n  "scope": "app_reference_only",\n',
                        1,
                    ),
                    None,
                ),
                (b"\xff", None),
                (b"[" * 2_000 + b"0" + b"]" * 2_000, None),
                (b" " * 1_000_001, None),
            )
            for raw, digest in malformed_cases:
                with self.subTest(manifest_bytes=raw[:24]):
                    fixture.write(
                        _BASE_VALUE,
                        manifest_bytes=raw,
                        digest_bytes=digest,
                    )
                    with self.assertRaises((UnicodeError, ValueError)):
                        fixture.verify_schema_only()

            actual = hashlib.sha256(canonical).hexdigest()
            sidecar_cases = (
                f"{'0' * 64}  {fixture.manifest.name}\n".encode(),
                f"{actual.upper()}  {fixture.manifest.name}\n".encode(),
                f"{actual} {fixture.manifest.name}\n".encode(),
                f"{actual}  other.json\n".encode(),
                f"{actual}  {fixture.manifest.name}".encode(),
                f"{actual}  {fixture.manifest.name}\n\n".encode(),
            )
            for sidecar in sidecar_cases:
                with self.subTest(sidecar=sidecar):
                    fixture.write(
                        _BASE_VALUE,
                        manifest_bytes=canonical,
                        digest_bytes=sidecar,
                    )
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

    def test_source_paths_are_portable_and_bind_regular_tracked_head_bytes(
        self,
    ) -> None:
        invalid_paths = (
            "../outside.png",
            "/absolute.png",
            "assets\\fixtures\\receipt.png",
            "assets/fixtures/../receipt.png",
            "assets/fixtures/CON.png",
            "assets/fixtures/trailing. ",
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)
            for source_path in invalid_paths:
                with self.subTest(source_path=source_path):
                    value = copy.deepcopy(_BASE_VALUE)
                    value["vectors"][0]["source_path"] = source_path
                    fixture.write(value)
                    with self.assertRaises(ValueError):
                        fixture.verify_schema_only()

            # A valid-looking path is still rejected unless its exact bytes are
            # a stable, ordinary file tracked unchanged at HEAD.
            value = copy.deepcopy(_BASE_VALUE)
            source_relative = Path(value["vectors"][0]["source_path"])
            source = fixture.root / source_relative

            fixture.write_and_commit(value)
            source.write_bytes(source.read_bytes() + b"changed")
            with self.assertRaises(ValueError):
                fixture.verify()
            shutil.copyfile(_ROOT / source_relative, source)

            fixture._git("rm", "--cached", "--", source_relative.as_posix())
            fixture._git(
                "commit",
                "--quiet",
                "-m",
                "leave exact source untracked",
            )
            with self.assertRaises(ValueError):
                fixture.verify()
            fixture._git("add", "--", source_relative.as_posix())
            fixture._git("commit", "--quiet", "-m", "restore exact source")

            fixture.write_and_commit(_BASE_VALUE)
            hardlink = fixture.root / "source-hardlink"
            try:
                os.link(source, hardlink)
            except OSError as error:
                self.skipTest(f"hard links unavailable: {error}")
            try:
                with self.assertRaises(ValueError):
                    fixture.verify()
            finally:
                hardlink.unlink()

    def test_manifest_and_digest_must_also_be_tracked_unchanged_at_head(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = _CommittedReferenceFixture(directory)

            fixture.manifest.write_bytes(fixture.manifest.read_bytes() + b" ")
            with self.assertRaises(ValueError):
                fixture.verify()

            fixture.write_and_commit(_BASE_VALUE)
            fixture.digest.write_bytes(fixture.digest.read_bytes() + b"\n")
            with self.assertRaises(ValueError):
                fixture.verify()

            outside_manifest = fixture.root.parent / fixture.manifest.name
            outside_digest = fixture.root.parent / fixture.digest.name
            outside_manifest.write_bytes(_MANIFEST.read_bytes())
            outside_digest.write_bytes(_DIGEST.read_bytes())
            with self.assertRaises(ValueError):
                verify_app_preprocess_reference(
                    outside_manifest,
                    outside_digest,
                    worktree_root=fixture.root,
                )


if __name__ == "__main__":
    unittest.main()
