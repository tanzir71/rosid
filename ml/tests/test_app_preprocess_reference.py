from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path

from ml.rosid_ml.provenance import canonical_json_bytes


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_ROOT = Path(__file__).resolve().parents[2]
_MANIFEST = _ROOT / "test/fixtures/v2_preprocessing/app_reference_v1.json"
_DIGEST = _ROOT / "test/fixtures/v2_preprocessing/app_reference_v1.sha256"
_EXPECTED_VECTORS = (
    "english-receipt-default",
    "mixed-bangla-receipt-quarter-turn",
    "handwritten-bangla-deskew",
)


class AppPreprocessReferenceTest(unittest.TestCase):
    def test_manifest_is_canonical_and_binds_public_sources(self) -> None:
        raw = _MANIFEST.read_bytes()
        value = json.loads(raw.decode("utf-8"))

        self.assertEqual(raw, canonical_json_bytes(value))
        self.assertEqual(
            _DIGEST.read_bytes(),
            f"{hashlib.sha256(raw).hexdigest()}  app_reference_v1.json\n".encode(),
        )
        self.assertEqual(value["schema"], "rosid-v2-app-preprocess-goldens-v1")
        self.assertEqual(value["scope"], "app_reference_only")
        self.assertEqual(value["python_parity_status"], "not_implemented")

        vectors = value["vectors"]
        self.assertEqual(tuple(vector["id"] for vector in vectors), _EXPECTED_VECTORS)
        for vector in vectors:
            source = _ROOT / vector["source_path"]
            self.assertTrue(source.is_file())
            source_bytes = source.read_bytes()
            self.assertEqual(len(source_bytes), vector["source_encoded_byte_count"])
            self.assertEqual(
                hashlib.sha256(source_bytes).hexdigest(),
                vector["source_encoded_sha256"],
            )
            self._assert_plane(vector["source_plane"])
            result = vector["result"]
            self.assertEqual(
                result["deskew_angle_degrees"],
                result["deskew_half_degree_ticks"] / 2,
            )
            self._assert_plane(result["color_corrected_plane"])
            self._assert_plane(result["grayscale_plane"])
            self._assert_plane(result["binarized_plane"])
            jpeg_regression = result.get("v1_production_jpeg_regression")
            if vector["id"] == "english-receipt-default":
                self.assertIsInstance(jpeg_regression, dict)
                self._assert_blob(jpeg_regression["color_corrected"])
                self._assert_blob(jpeg_regression["binarized"])
            else:
                self.assertIsNone(jpeg_regression)

    def _assert_plane(self, plane: dict[str, object]) -> None:
        width = plane["width"]
        height = plane["height"]
        channels = plane["channels"]
        self.assertIs(type(width), int)
        self.assertIs(type(height), int)
        self.assertIs(type(channels), int)
        self.assertGreater(width, 0)
        self.assertGreater(height, 0)
        self.assertIn(channels, (1, 4))
        self.assertEqual(plane["byte_count"], width * height * channels)
        self.assertEqual(len(plane["channel_minimums"]), channels)
        self.assertEqual(len(plane["channel_maximums"]), channels)
        self.assertRegex(plane["sha256"], _SHA256)

    def _assert_blob(self, blob: dict[str, object]) -> None:
        self.assertIs(type(blob["byte_count"]), int)
        self.assertGreater(blob["byte_count"], 0)
        self.assertRegex(blob["sha256"], _SHA256)


if __name__ == "__main__":
    unittest.main()
