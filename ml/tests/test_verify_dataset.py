from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from ml.rosid_ml.provenance import DatasetSource
from ml.verify_dataset import verify


class VerifyDatasetTest(unittest.TestCase):
    def test_module_cli_entrypoint_is_supported(self) -> None:
        repository = Path(__file__).resolve().parents[2]

        result = subprocess.run(
            [sys.executable, "-m", "ml.verify_dataset", "--help"],
            cwd=repository,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verify a manually downloaded dataset archive", result.stdout)
        self.assertIn("--allow-nonproduction", result.stdout)

    def test_verifies_exact_archive_and_enforces_eligibility(self) -> None:
        content = b"local-dataset"
        value = {
            "attribution": "Example Author; CC BY 4.0.",
            "bytes": len(content),
            "dataset_id": "example",
            "doi": "10.0000/example",
            "eligibility": "conditional",
            "filename": "dataset.zip",
            "license_id": "CC-BY-4.0",
            "rights_notes": "Requires a writer-map audit.",
            "schema_version": 1,
            "sha256": hashlib.sha256(content).hexdigest(),
            "source_url": "https://example.test/dataset",
            "version": "1",
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "source.json"
            archive = root / "dataset.zip"
            manifest.write_bytes(DatasetSource.from_dict(value).canonical_bytes())
            archive.write_bytes(content)

            result = verify(manifest, archive, require_production=False)
            self.assertEqual(result.dataset_id, "example")
            with self.assertRaisesRegex(ValueError, "not production"):
                verify(manifest, archive, require_production=True)
            with self.assertRaisesRegex(ValueError, "not production"):
                verify(manifest, archive)

            excluded_value = {**value, "eligibility": "excluded"}
            manifest.write_bytes(
                DatasetSource.from_dict(excluded_value).canonical_bytes()
            )
            with self.assertRaisesRegex(ValueError, "excluded"):
                verify(manifest, archive, require_production=False)


if __name__ == "__main__":
    unittest.main()
