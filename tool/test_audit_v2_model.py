from __future__ import annotations

import hashlib
import json
import subprocess
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ml.rosid_ml.limits import MAX_HTR_BUNDLE_BYTES
from tool.audit_v2_model import (
    CompanionExpectation,
    ModelAuditError,
    audit_tflite,
)


class AuditV2ModelTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.model = Path(self.temporary_directory.name) / "model.tflite"

    def write_model(self, payload: bytes = b"offline-model") -> bytes:
        content = bytearray(68 + len(payload))
        struct.pack_into("<I", content, 0, 24)
        content[4:8] = b"TFL3"
        struct.pack_into("<HHHHHHH", content, 8, 14, 20, 4, 8, 12, 0, 16)
        struct.pack_into("<i", content, 24, 16)
        struct.pack_into("<I", content, 28, 3)
        struct.pack_into("<I", content, 32, 12)
        struct.pack_into("<I", content, 36, 16)
        struct.pack_into("<I", content, 40, 20)
        for vector in (44, 52, 60):
            struct.pack_into("<II", content, vector, 1, 4)
        content[68:] = payload
        content = bytes(content)
        self.model.write_bytes(content)
        return content

    def audit(self, **overrides: object) -> dict[str, object]:
        content = self.model.read_bytes()
        arguments = {
            "asset_id": "models/bangla-htr.tflite",
            "expected_sha256": hashlib.sha256(content).hexdigest(),
            "expected_bytes": len(content),
            **overrides,
        }
        return audit_tflite(self.model, **arguments)

    def test_accepts_matching_small_flatbuffer_primitive(self) -> None:
        content = self.write_model()
        digest = hashlib.sha256(content).hexdigest()

        result = self.audit(expected_sha256=digest, expected_bytes=len(content))

        self.assertEqual(result["sha256"], digest)
        self.assertEqual(result["bytes"], len(content))
        self.assertEqual(result["asset_id"], "models/bangla-htr.tflite")

    def test_rejects_wrong_identifier(self) -> None:
        self.model.write_bytes(b"\x10\x00\x00\x00NOPEpayload")

        with self.assertRaisesRegex(ModelAuditError, "TFL3"):
            self.audit()

    def test_rejects_size_over_budget(self) -> None:
        self.write_model(b"12345678")

        with self.assertRaisesRegex(ModelAuditError, "budget"):
            self.audit(max_bytes=12)
        with self.assertRaisesRegex(ModelAuditError, "no greater"):
            self.audit(max_bytes=MAX_HTR_BUNDLE_BYTES + 1)

    def test_rejects_manifest_size_or_hash_mismatch(self) -> None:
        content = self.write_model()

        with self.assertRaisesRegex(ModelAuditError, "byte count"):
            self.audit(expected_bytes=len(content) + 1)
        with self.assertRaisesRegex(ModelAuditError, "SHA-256"):
            self.audit(expected_sha256="0" * 64)

    def test_rejects_endpoint_and_workstation_path_markers(self) -> None:
        for marker in (
            b"https://example.test/model",
            b"ws://example.test/model",
            b"C:\\Users\\owner\\data",
            b"D:\\Users\\owner\\data",
        ):
            with self.subTest(marker=marker):
                self.write_model(marker)
                with self.assertRaisesRegex(ModelAuditError, "forbidden"):
                    self.audit()

    def test_rejects_header_only_fabrication(self) -> None:
        self.model.write_bytes(b"\x10\x00\x00\x00TFL3not-a-flatbuffer")

        with self.assertRaisesRegex(ModelAuditError, "root table|vtable|Model table"):
            self.audit()

    def test_counts_companion_assets_in_the_shared_budget(self) -> None:
        content = self.write_model()
        companion = Path(self.temporary_directory.name) / "vocabulary.json"
        companion.write_bytes(b"v" * 20)
        expectation = self.expectation(companion)

        with self.assertRaisesRegex(ModelAuditError, "asset bundle"):
            self.audit(max_bytes=len(content) + 19, companions=(expectation,))

    def test_integrity_binds_every_companion_asset(self) -> None:
        self.write_model()
        companion = Path(self.temporary_directory.name) / "vocabulary.json"
        companion.write_bytes('[["<blank>", 0], ["অ", 1]]'.encode("utf-8"))
        expectation = self.expectation(companion)

        result = self.audit(companions=(expectation,))

        self.assertEqual(
            result["companions"],
            [
                {
                    "asset_id": expectation.asset_id,
                    "bytes": companion.stat().st_size,
                    "sha256": expectation.expected_sha256,
                }
            ],
        )
        companion.write_bytes(b"changed")
        with self.assertRaisesRegex(ModelAuditError, "byte count|SHA-256"):
            self.audit(companions=(expectation,))

    def test_rejects_privacy_markers_in_companion_assets(self) -> None:
        self.write_model()
        companion = Path(self.temporary_directory.name) / "contract.json"
        companion.write_bytes(b'{"source":"/home/owner/train.py"}')

        with self.assertRaisesRegex(ModelAuditError, "companion.*forbidden"):
            self.audit(companions=(self.expectation(companion),))

    def test_rejects_json_escaped_privacy_markers(self) -> None:
        self.write_model()
        companion = Path(self.temporary_directory.name) / "contract.json"
        for payload in (
            br'{"source":"C:\\Users\\owner\\train.py"}',
            br'{"source":"https:\/\/example.test\/model"}',
            br'{"source":"\u002fhome\u002fowner\u002ftrain.py"}',
        ):
            with self.subTest(payload=payload):
                companion.write_bytes(payload)
                with self.assertRaisesRegex(ModelAuditError, "forbidden"):
                    self.audit(companions=(self.expectation(companion),))

    def test_reads_each_asset_once_and_never_serializes_workstation_paths(self) -> None:
        content = self.write_model()
        companion = Path(self.temporary_directory.name) / "vocabulary.json"
        companion.write_bytes(b"vocabulary")
        expectation = self.expectation(companion)
        counts: dict[Path, int] = {}
        original_open = Path.open

        def counted_open(path: Path, *args: object, **kwargs: object):
            counts[path] = counts.get(path, 0) + 1
            return original_open(path, *args, **kwargs)

        with mock.patch.object(Path, "open", counted_open):
            result = audit_tflite(
                self.model,
                asset_id="models/bangla-htr.tflite",
                expected_sha256=hashlib.sha256(content).hexdigest(),
                expected_bytes=len(content),
                companions=(expectation,),
            )

        self.assertEqual(counts, {self.model: 1, companion: 1})
        serialized = json.dumps(result)
        self.assertNotIn(self.temporary_directory.name, serialized)

        missing = Path(self.temporary_directory.name) / "private" / "missing.json"
        with self.assertRaises(ModelAuditError) as caught:
            self.audit(
                companions=(
                    CompanionExpectation(
                        "contracts/model.json",
                        missing,
                        "0" * 64,
                        1,
                    ),
                )
            )
        self.assertNotIn(self.temporary_directory.name, str(caught.exception))

    def test_freezes_decimal_twenty_megabyte_ceiling_and_portable_ids(self) -> None:
        self.assertEqual(MAX_HTR_BUNDLE_BYTES, 20_000_000)
        self.write_model()
        with self.assertRaisesRegex(ModelAuditError, "portable relative"):
            self.audit(asset_id="C:/Users/owner/model.tflite")

    def test_rejects_raw_dot_segments_in_every_logical_asset_id(self) -> None:
        self.write_model()
        invalid_id = "models/./bangla-htr.tflite"

        with self.assertRaisesRegex(ModelAuditError, "portable relative"):
            self.audit(asset_id=invalid_id)
        with self.assertRaisesRegex(ModelAuditError, "portable relative"):
            self.audit(asset_id=" models/bangla-htr.tflite ")
        with self.assertRaisesRegex(ModelAuditError, "portable relative"):
            self.audit(
                companions=(
                    CompanionExpectation(
                        invalid_id,
                        Path(self.temporary_directory.name) / "missing.json",
                        "0" * 64,
                        1,
                    ),
                )
            )

    def test_validates_companion_ids_before_any_labeled_diagnostic(self) -> None:
        self.write_model()
        private_id = "C:/Users/owner/private.json"
        invalid_companion = CompanionExpectation(
            private_id,
            Path(self.temporary_directory.name) / "private.json",
            "0" * 64,
            0,
        )

        for overrides in ({}, {"max_bytes": 0}):
            with self.subTest(overrides=overrides):
                with self.assertRaisesRegex(
                    ModelAuditError,
                    "portable relative",
                ) as caught:
                    self.audit(companions=(invalid_companion,), **overrides)
                self.assertNotIn(private_id, str(caught.exception))

    def test_direct_script_entrypoint_supports_help(self) -> None:
        script = Path(__file__).with_name("audit_v2_model.py").resolve()
        result = subprocess.run(
            [sys.executable, str(script), "--help"],
            cwd=self.temporary_directory.name,
            capture_output=True,
            check=False,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("usage:", result.stdout)

    @staticmethod
    def expectation(path: Path) -> CompanionExpectation:
        content = path.read_bytes()
        return CompanionExpectation(
            asset_id=f"companions/{path.name}",
            path=path,
            expected_sha256=hashlib.sha256(content).hexdigest(),
            expected_bytes=len(content),
        )


if __name__ == "__main__":
    unittest.main()
