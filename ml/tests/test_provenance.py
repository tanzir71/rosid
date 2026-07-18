from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    canonical_json_bytes,
)


class ProvenanceTest(unittest.TestCase):
    def test_canonical_json_normalizes_unicode_and_rejects_key_collisions(self) -> None:
        self.assertEqual(
            canonical_json_bytes({"label": "café"}),
            canonical_json_bytes({"label": "cafe\u0301"}),
        )
        with self.assertRaisesRegex(ValueError, "collide after NFC"):
            canonical_json_bytes({"é": 1, "e\u0301": 2})

    def source(self, content: bytes = b"dataset") -> DatasetSource:
        return DatasetSource(
            schema_version=1,
            dataset_id="example",
            version="1",
            doi="10.0000/example",
            source_url="https://example.test/dataset/1",
            license_id="CC-BY-4.0",
            filename="dataset.zip",
            bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            eligibility=Eligibility.PRODUCTION,
            attribution="Example Authors; CC BY 4.0.",
            rights_notes="Synthetic unit-test bytes only.",
        )

    def test_verifies_an_exact_local_archive(self) -> None:
        content = b"dataset"
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "dataset.zip"
            archive.write_bytes(content)

            self.source(content).verify_archive(archive)

    def test_rejects_size_and_hash_changes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "dataset.zip"
            archive.write_bytes(b"changed")

            with self.assertRaisesRegex(ValueError, "byte count|SHA-256"):
                self.source().verify_archive(archive)

    def test_manifest_parser_rejects_unknown_keys(self) -> None:
        value = {
            "schema_version": 1,
            "dataset_id": "example",
            "version": "1",
            "doi": "10.0000/example",
            "source_url": "https://example.test/data",
            "license_id": "CC-BY-4.0",
            "filename": "dataset.zip",
            "bytes": 1,
            "sha256": "0" * 64,
            "eligibility": "production",
            "attribution": "Example Authors; CC BY 4.0.",
            "rights_notes": "Synthetic unit-test bytes only.",
            "unreviewed": True,
        }

        with self.assertRaisesRegex(ValueError, "extra"):
            DatasetSource.from_dict(value)

    def test_conditional_is_distinct_from_production_eligibility(self) -> None:
        source = DatasetSource(
            **{**self.source().__dict__, "eligibility": Eligibility.CONDITIONAL}
        )

        self.assertEqual(source.eligibility, Eligibility.CONDITIONAL)
        self.assertNotEqual(source.eligibility, Eligibility.PRODUCTION)

    def test_rejects_non_https_source_and_path_traversal(self) -> None:
        values = self.source().__dict__
        with self.assertRaisesRegex(ValueError, "HTTPS"):
            DatasetSource(**{**values, "source_url": "http://example.test"})
        with self.assertRaisesRegex(ValueError, "leaf"):
            DatasetSource(**{**values, "filename": "../dataset.zip"})
        with self.assertRaisesRegex(ValueError, "leaf"):
            DatasetSource(**{**values, "filename": r"C:\\Users\\data.zip"})
        with self.assertRaisesRegex(ValueError, "leaf"):
            DatasetSource(**{**values, "filename": r"dir\\data.zip"})

    def test_reads_strict_utf8_json_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.json"
            path.write_bytes(self.source().canonical_bytes())

            parsed = DatasetSource.from_json_file(path)

        self.assertEqual(parsed, self.source())

    def test_rejects_noncanonical_manifest_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.json"
            path.write_text(json.dumps(self.source().to_dict()), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "not canonical"):
                DatasetSource.from_json_file(path)

    def test_acquisition_cannot_upgrade_reviewed_source_eligibility(self) -> None:
        source = DatasetSource(
            **{**self.source().__dict__, "eligibility": Eligibility.CONDITIONAL}
        ).to_source_evidence()
        acquisition = AcquisitionRecord(
            schema_version=2,
            record_id="example-v1",
            source_evidence_sha256=source.commitment_sha256,
            content_sha256=source.content_sha256,
            artifact_sha256=source.content_sha256,
            inventory_sha256="1" * 64,
            acquired_at_utc="2026-07-18T00:00:00Z",
            accepted_by="unit-test",
            terms_accepted=True,
            extractor="unit-test/1",
            eligibility=Eligibility.PRODUCTION,
        )

        with self.assertRaisesRegex(ValueError, "cannot upgrade"):
            acquisition.validate_source(source)

    def test_source_and_acquisition_commitments_round_trip_canonically(self) -> None:
        source = self.source().to_source_evidence()
        acquisition = AcquisitionRecord(
            schema_version=2,
            record_id="example-v1",
            source_evidence_sha256=source.commitment_sha256,
            content_sha256=source.content_sha256,
            artifact_sha256=source.content_sha256,
            inventory_sha256="2" * 64,
            acquired_at_utc="2026-07-18T00:00:00Z",
            accepted_by="unit-test",
            terms_accepted=True,
            extractor="unit-test/1",
            eligibility=Eligibility.PRODUCTION,
        )
        with tempfile.TemporaryDirectory() as directory:
            source_path = Path(directory) / "source-evidence.json"
            acquisition_path = Path(directory) / "acquisition.json"
            source_path.write_bytes(source.canonical_bytes())
            acquisition_path.write_bytes(acquisition.canonical_bytes())

            parsed_source = type(source).from_json_file(source_path)
            parsed_acquisition = AcquisitionRecord.from_json_file(acquisition_path)

        self.assertEqual(parsed_source.commitment_sha256, source.commitment_sha256)
        self.assertEqual(
            parsed_acquisition.commitment_sha256,
            acquisition.commitment_sha256,
        )
        parsed_acquisition.validate_source(parsed_source)
        self.assertEqual(parsed_source.dataset_id, "example")
        self.assertEqual(parsed_source.doi, "10.0000/example")
        self.assertEqual(
            parsed_source.source_manifest_sha256,
            self.source().commitment_sha256,
        )

    def test_acquisition_timestamp_has_one_canonical_utc_spelling(self) -> None:
        source = self.source().to_source_evidence()
        values = {
            "schema_version": 2,
            "record_id": "example-v1",
            "source_evidence_sha256": source.commitment_sha256,
            "content_sha256": source.content_sha256,
            "artifact_sha256": source.content_sha256,
            "inventory_sha256": "3" * 64,
            "acquired_at_utc": "2026-07-18T00:00:00Z",
            "accepted_by": "unit-test",
            "terms_accepted": True,
            "extractor": "unit-test/1",
            "eligibility": Eligibility.PRODUCTION,
        }

        AcquisitionRecord(**values)
        for timestamp in (
            "2026-07-18 00:00:00Z",
            "2026-07-18T00:00:00+00:00",
            "2026-07-18T00:00:00.000Z",
        ):
            with self.subTest(timestamp=timestamp):
                with self.assertRaisesRegex(ValueError, "canonical UTC seconds"):
                    AcquisitionRecord(**{**values, "acquired_at_utc": timestamp})

    def test_all_committed_source_manifests_parse(self) -> None:
        paths = sorted(Path("ml/manifests/datasets").glob("*.json"))

        self.assertGreaterEqual(len(paths), 4)
        for path in paths:
            with self.subTest(path=path):
                source = DatasetSource.from_json_file(path)
                self.assertEqual(source.schema_version, 1)

    def test_rejects_duplicate_keys_and_type_coercion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            duplicate = Path(directory) / "duplicate.json"
            duplicate.write_text(
                '{"eligibility":"research_only","eligibility":"production"}',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                DatasetSource.from_json_file(duplicate)

        value = self.source().__dict__.copy()
        value["eligibility"] = value["eligibility"].value
        value["bytes"] = True
        with self.assertRaisesRegex(ValueError, "bytes must be an integer"):
            DatasetSource.from_dict(value)


if __name__ == "__main__":
    unittest.main()
