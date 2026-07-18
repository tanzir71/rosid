from __future__ import annotations

import hashlib
import tempfile
import unittest
from collections.abc import Mapping
from dataclasses import replace
from pathlib import Path

from ml.rosid_ml.acquisition import DirectoryInventory, InventoryEntry
from ml.rosid_ml.adapter_evidence import (
    AdapterConfig,
    AdapterEvidence,
    AdapterSourceFile,
    PublicAdapterCommitment,
    SampleDerivation,
    SourceDisposition,
    SourceRole,
    SourceUse,
    VerifiedAdapterEvidence,
    create_adapter_evidence,
    verify_adapter_evidence,
)
from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    Eligibility,
    SourceEvidence,
)
from ml.rosid_ml.split_manifests import UnsplitSample


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


class AdapterEvidenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.source = SourceEvidence(
            schema_version=2,
            evidence_id="dataset:adapter-fixture",
            dataset_id="dataset-a",
            doi="10.0000/dataset-a",
            source_manifest_sha256=digest("dataset-source-manifest"),
            source_url="https://example.test/dataset-a.zip",
            version="1",
            license_id="CC-BY-4.0",
            content_sha256=digest("archive"),
            artifact_type="dataset",
            artifact_role="source_archive",
            eligibility=Eligibility.PRODUCTION,
            attribution="Synthetic adapter unit-test source.",
            rights_notes="No real source bytes.",
        )
        self.inventory = DirectoryInventory(
            schema_version=1,
            artifact_sha256=digest("extracted-artifact"),
            files=tuple(
                InventoryEntry(path=path, bytes=len(path), sha256=digest(path))
                for path in (
                    "README.txt",
                    "images/a.png",
                    "images/b.png",
                    "labels/a.txt",
                    "labels/b.txt",
                )
            ),
        )
        self.acquisition = AcquisitionRecord(
            schema_version=3,
            record_id="dataset-a-v1",
            source_evidence_sha256=self.source.commitment_sha256,
            content_sha256=self.source.content_sha256,
            artifact_sha256=self.inventory.artifact_sha256,
            artifact_type="dataset",
            artifact_role="extracted_dataset",
            inventory_sha256=self.inventory.commitment_sha256,
            acquired_at_utc="2026-07-18T00:00:00Z",
            accepted_by="unit-test",
            terms_accepted=True,
            extractor="unit-test/1",
            eligibility=Eligibility.PRODUCTION,
        )
        self.config = AdapterConfig(
            schema_version=2,
            adapter_id="dataset-a-lines",
            implementation_paths=(
                "ml/rosid_ml/adapters/dataset_a_lines.py",
            ),
            parameters={
                "normalization": "NFC",
                "resize": {"height": 48, "preserve_aspect": True},
            },
        )
        self.code_sha256 = digest("clean-adapter-code-bundle")
        self.key = b"K" * 32
        self.samples = tuple(self.sample(index) for index in (1, 2))
        self.derivations = tuple(self.derivation(index) for index in (1, 2))

    def sample(self, index: int) -> UnsplitSample:
        letter = "a" if index == 1 else "b"
        return UnsplitSample(
            schema_version=1,
            sample_id=f"sample-{index}",
            dataset_id="dataset-a",
            dataset_version="1",
            acquisition_sha256=self.acquisition.commitment_sha256,
            writer_group_id=f"private-writer-{index}",
            object_key=f"normalized/{letter}.png",
            image_sha256=digest(f"normalized-image-{letter}"),
            reference_sha256=digest(f"normalized-reference-{letter}"),
            width=120,
            height=48,
            token_count=4,
        )

    def derivation(self, index: int) -> SampleDerivation:
        letter = "a" if index == 1 else "b"
        return SampleDerivation(
            sample_id=f"sample-{index}",
            sources=(
                SourceUse(
                    path=f"images/{letter}.png",
                    sha256=digest(f"images/{letter}.png"),
                    roles=(SourceRole.IMAGE,),
                ),
                SourceUse(
                    path=f"labels/{letter}.txt",
                    sha256=digest(f"labels/{letter}.txt"),
                    roles=(SourceRole.REFERENCE,),
                ),
            ),
        )

    def create(self, **overrides: object):
        arguments = {
            "source": self.source,
            "acquisition": self.acquisition,
            "inventory": self.inventory,
            "adapter_code_bundle_sha256": self.code_sha256,
            "adapter_config": self.config,
            "normalized_samples": self.samples,
            "derivations": self.derivations,
            "ignored_source_files": {"README.txt": "publisher documentation"},
            "commitment_key": self.key,
        }
        arguments.update(overrides)
        return create_adapter_evidence(**arguments)

    def verify(self, private, public, **overrides: object) -> VerifiedAdapterEvidence:
        arguments = {
            "source": self.source,
            "acquisition": self.acquisition,
            "inventory": self.inventory,
            "normalized_samples": self.samples,
            "commitment_key": self.key,
            "expected_code_bundle_sha256": self.code_sha256,
            "expected_config_sha256": self.config.commitment_sha256,
        }
        arguments.update(overrides)
        return verify_adapter_evidence(private, public, **arguments)

    def test_canonical_round_trip_and_exact_reverification(self) -> None:
        artifacts = self.create()
        verified = self.verify(artifacts.private, artifacts.public)
        self.assertIs(verified.public, artifacts.public)
        with self.assertRaisesRegex(ValueError, "must come from"):
            VerifiedAdapterEvidence(
                public=artifacts.public,
                private_evidence_sha256="0" * 64,
                key_fingerprint_sha256="1" * 64,
                _token=object(),
            )
        self.assertEqual(artifacts.public.output_count, 2)
        self.assertEqual(artifacts.public.source_file_count, 5)
        self.assertEqual(artifacts.public.used_source_file_count, 4)
        self.assertEqual(artifacts.public.ignored_source_file_count, 1)

        with tempfile.TemporaryDirectory() as directory:
            private_path = Path(directory) / "private-adapter.json"
            public_path = Path(directory) / "public-adapter.json"
            private_path.write_bytes(artifacts.private.canonical_bytes())
            public_path.write_bytes(artifacts.public.canonical_bytes())
            loaded_private = AdapterEvidence.from_json_file(private_path)
            loaded_public = PublicAdapterCommitment.from_json_file(public_path)
            self.assertEqual(loaded_private, artifacts.private)
            self.assertEqual(loaded_public, artifacts.public)
            self.verify(loaded_private, loaded_public)

            public_path.write_bytes(artifacts.public.canonical_bytes() + b"\n")
            with self.assertRaisesRegex(ValueError, "not canonical"):
                PublicAdapterCommitment.from_json_file(public_path)

    def test_public_commitment_contains_no_private_paths_outputs_or_writers(
        self,
    ) -> None:
        artifacts = self.create()
        public = artifacts.public.canonical_bytes()

        for sample in self.samples:
            for private_value in (
                sample.sample_id,
                sample.object_key,
                sample.image_sha256,
                sample.reference_sha256,
                sample.writer_group_id,
            ):
                self.assertNotIn(private_value.encode(), public)
        for entry in self.inventory.files:
            self.assertNotIn(entry.path.encode(), public)
        self.assertNotIn(str(Path.cwd()).encode(), public)
        self.assertIn(self.config.adapter_id.encode(), public)
        self.assertIn(b'"normalization": "NFC"', public)

    def test_config_is_immutable_canonical_and_rejects_host_paths(self) -> None:
        with self.assertRaises(TypeError):
            self.config.parameters["normalization"] = "NFD"
        resize = self.config.parameters["resize"]
        self.assertIsInstance(resize, Mapping)
        with self.assertRaises(TypeError):
            resize["height"] = 96

        with self.assertRaisesRegex(ValueError, "host path"):
            AdapterConfig(
                schema_version=2,
                adapter_id="unsafe",
                implementation_paths=(
                    "ml/rosid_ml/adapters/unsafe.py",
                ),
                parameters={"cache": "C:\\Users\\person\\cache"},
            )
        for host_path in (
            "\\Users\\person\\secret",
            "C:Users\\person\\secret",
            "cache=C:\\Users\\person\\secret",
            "cache=/home/person/secret",
        ):
            with self.subTest(host_path=host_path):
                with self.assertRaisesRegex(ValueError, "host path"):
                    AdapterConfig(
                        schema_version=2,
                        adapter_id="unsafe",
                        implementation_paths=(
                            "ml/rosid_ml/adapters/unsafe.py",
                        ),
                        parameters={"cache": host_path},
                    )
        with self.assertRaisesRegex(ValueError, "only null"):
            AdapterConfig(
                schema_version=2,
                adapter_id="unsafe",
                implementation_paths=(
                    "ml/rosid_ml/adapters/unsafe.py",
                ),
                parameters={"threshold": 0.5},
            )

        leaky = AdapterConfig(
            schema_version=2,
            adapter_id="unsafe",
            implementation_paths=(
                "ml/rosid_ml/adapters/unsafe.py",
            ),
            parameters={"debug_writer": self.samples[0].writer_group_id},
        )
        with self.assertRaisesRegex(ValueError, "private sample/source"):
            self.create(adapter_config=leaky)

        artifacts = self.create()
        verifier_leak = replace(
            self.samples[0],
            writer_group_id="NFC",
        )
        with self.assertRaisesRegex(ValueError, "private sample/source"):
            self.verify(
                artifacts.private,
                artifacts.public,
                normalized_samples=(verifier_leak, self.samples[1]),
            )

    def test_missing_extra_duplicate_and_casefold_outputs_fail_closed(self) -> None:
        with self.assertRaisesRegex(
            ValueError, "samples and derivations differ.*missing"
        ):
            self.create(derivations=self.derivations[:1])
        extra = SampleDerivation(
            sample_id="sample-3",
            sources=self.derivations[0].sources,
        )
        with self.assertRaisesRegex(
            ValueError, "samples and derivations differ.*extra"
        ):
            self.create(derivations=(*self.derivations, extra))
        with self.assertRaisesRegex(ValueError, "duplicate sample IDs"):
            self.create(normalized_samples=(self.samples[0], self.samples[0]))

        collided = replace(
            self.samples[1],
            object_key=self.samples[0].object_key.upper(),
        )
        with self.assertRaisesRegex(ValueError, "object keys collide"):
            self.create(normalized_samples=(self.samples[0], collided))

        artifacts = self.create()
        with self.assertRaisesRegex(ValueError, "normalized outputs differ"):
            self.verify(
                artifacts.private,
                artifacts.public,
                normalized_samples=self.samples[:1],
            )

        mutated = replace(
            self.samples[0],
            writer_group_id="different-writer",
            width=121,
            height=49,
            token_count=5,
        )
        with self.assertRaisesRegex(ValueError, "normalized outputs differ"):
            self.verify(
                artifacts.private,
                artifacts.public,
                normalized_samples=(mutated, self.samples[1]),
            )

    def test_source_coverage_hash_roles_duplicates_and_casefold_fail_closed(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            ValueError, "source coverage is not exact.*missing"
        ):
            self.create(ignored_source_files={})
        with self.assertRaisesRegex(ValueError, "source coverage is not exact.*extra"):
            self.create(
                ignored_source_files={
                    "README.txt": "publisher documentation",
                    "ghost.txt": "not real",
                }
            )

        bad_hash = replace(
            self.derivations[0].sources[0],
            sha256=digest("wrong-source"),
        )
        with self.assertRaisesRegex(ValueError, "hash differs from inventory"):
            self.create(
                derivations=(
                    replace(
                        self.derivations[0],
                        sources=(bad_hash, self.derivations[0].sources[1]),
                    ),
                    self.derivations[1],
                )
            )

        with self.assertRaisesRegex(ValueError, "both image and reference"):
            SampleDerivation(
                sample_id="sample-1",
                sources=(self.derivations[0].sources[0],),
            )

        upper = SourceUse(
            path="Images/a.png",
            sha256=digest("Images/a.png"),
            roles=(SourceRole.IMAGE,),
        )
        lower = SourceUse(
            path="images/A.png",
            sha256=digest("images/A.png"),
            roles=(SourceRole.REFERENCE,),
        )
        with self.assertRaisesRegex(ValueError, "case folding"):
            SampleDerivation(sample_id="sample-1", sources=(upper, lower))

        first_entry = self.inventory.files[0]
        with self.assertRaisesRegex(ValueError, "case folding"):
            AdapterEvidence(
                schema_version=1,
                dataset_id="dataset-a",
                dataset_version="1",
                acquisition_sha256=self.acquisition.commitment_sha256,
                directory_inventory_sha256=self.inventory.commitment_sha256,
                adapter_code_bundle_sha256=self.code_sha256,
                adapter_config=self.config,
                adapter_config_sha256=self.config.commitment_sha256,
                source_files=(
                    AdapterSourceFile(
                        path="A.txt",
                        bytes=first_entry.bytes,
                        sha256=first_entry.sha256,
                        disposition=SourceDisposition.USED,
                    ),
                    AdapterSourceFile(
                        path="a.txt",
                        bytes=first_entry.bytes,
                        sha256=first_entry.sha256,
                        disposition=SourceDisposition.USED,
                    ),
                ),
                outputs=(self.create().private.outputs[0],),
            )

    def test_inconsistent_dataset_acquisition_and_inventory_fail_closed(self) -> None:
        wrong_dataset = replace(self.samples[0], dataset_id="dataset-b")
        with self.assertRaisesRegex(ValueError, "identity differs"):
            self.create(normalized_samples=(wrong_dataset, self.samples[1]))

        wrong_acquisition = replace(
            self.acquisition,
            inventory_sha256=digest("other-inventory"),
        )
        with self.assertRaisesRegex(ValueError, "directory inventory commitment"):
            self.create(acquisition=wrong_acquisition)

        wrong_artifact = replace(
            self.acquisition,
            artifact_sha256=digest("other-extracted-bytes"),
        )
        with self.assertRaisesRegex(ValueError, "inventoried artifact bytes"):
            self.create(acquisition=wrong_artifact)

    def test_public_hmac_and_independent_code_config_expectations_fail_closed(
        self,
    ) -> None:
        artifacts = self.create()
        with self.assertRaisesRegex(ValueError, "public adapter commitment differs"):
            self.verify(
                artifacts.private,
                artifacts.public,
                commitment_key=b"Q" * 32,
            )
        with self.assertRaisesRegex(ValueError, "approved SHA-256"):
            self.verify(
                artifacts.private,
                artifacts.public,
                expected_code_bundle_sha256=digest("unapproved-code"),
            )
        with self.assertRaisesRegex(ValueError, "approved SHA-256"):
            self.verify(
                artifacts.private,
                artifacts.public,
                expected_config_sha256=digest("unapproved-config"),
            )
        tampered_public = replace(
            artifacts.public,
            output_count=artifacts.public.output_count + 1,
        )
        with self.assertRaisesRegex(ValueError, "public adapter commitment differs"):
            self.verify(artifacts.private, tampered_public)


if __name__ == "__main__":
    unittest.main()
