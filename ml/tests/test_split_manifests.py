from __future__ import annotations

import contextlib
import hashlib
import io
import subprocess
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from ml.build_split_manifest import main as build_split_main
from ml.finalize_split_approval import main as finalize_split_approval_main
from ml.request_split_approval import main as request_split_approval_main
from ml.rosid_ml.acquisition import DirectoryInventory, InventoryEntry
from ml.rosid_ml.adapter_evidence import (
    AdapterConfig,
    SampleDerivation,
    SourceRole,
    SourceUse,
    create_adapter_evidence,
    verify_adapter_evidence,
)
from ml.rosid_ml.code_bundles import (
    REQUIRED_CORE_CODE_ROLES,
    CodeRole,
    build_code_bundle,
)
from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    canonical_json_line_bytes,
)
from ml.rosid_ml.split_approvals import (
    APPROVAL_SIGNATURE_NAMESPACE,
    ApprovalPolicy,
    ApprovalStatus,
    ROSID_REPOSITORY_ID,
    owner_public_key_sha256,
)
from ml.rosid_ml.split_manifests import (
    AcquisitionBinding,
    PrivateSplitRecord,
    PublicSplitCommitment,
    UnsplitSample,
    VerifiedSplitEvidence,
    canonical_unsplit_jsonl,
    create_split_artifacts,
    default_split_config,
    load_acquisition_bindings,
    read_private_jsonl,
    read_secret_file,
    read_unsplit_jsonl,
    validate_acquisition_bindings,
    verify_split_artifacts,
    verify_split_evidence,
)
from ml.rosid_ml.splits import Split
from ml.tests.approval_fixtures import fake_verified_split_approval
from ml.verify_split_manifest import main as verify_split_main


SPLITTER_CODE_SHA256 = hashlib.sha256(b"unit-test-splitter-code").hexdigest()
ADAPTER_COMMITMENT_SHA256S = tuple(
    hashlib.sha256(f"unit-test-adapter-{index}".encode()).hexdigest()
    for index in range(2)
)
SEED_KEY = b"S" * 32
COMMITMENT_KEY = b"K" * 32


class SplitManifestTest(unittest.TestCase):
    @staticmethod
    def approval(
        records: tuple[UnsplitSample, ...],
        *,
        config,
        adapter_commitment_sha256s: tuple[str, ...],
        seed_key: bytes = SEED_KEY,
        commitment_key: bytes = COMMITMENT_KEY,
        allow_nonproduction: bool = False,
    ):
        return fake_verified_split_approval(
            config=config,
            acquisition_sha256s=tuple(
                sorted({record.acquisition_sha256 for record in records})
            ),
            adapter_commitment_sha256s=adapter_commitment_sha256s,
            seed_key=seed_key,
            commitment_key=commitment_key,
            allow_nonproduction=allow_nonproduction,
        )

    @staticmethod
    def run_git(root: Path, *arguments: str) -> None:
        subprocess.run(
            ("git", *arguments),
            cwd=root,
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
        )

    def sample(
        self,
        index: int,
        *,
        dataset_id: str = "dataset-a",
        acquisition_sha256: str = "a" * 64,
    ) -> UnsplitSample:
        return UnsplitSample(
            schema_version=1,
            sample_id=f"sample-{index}",
            dataset_id=dataset_id,
            dataset_version="1",
            acquisition_sha256=acquisition_sha256,
            writer_group_id=f"writer-{index}",
            object_key=f"{dataset_id}/sample-{index}.png",
            image_sha256=hashlib.sha256(f"image-{index}".encode()).hexdigest(),
            reference_sha256=hashlib.sha256(
                f"reference-{index}".encode()
            ).hexdigest(),
            width=100 + index,
            height=48,
            token_count=10 + index,
        )

    def samples(
        self,
        *,
        acquisition_sha256: str = "a" * 64,
    ) -> tuple[UnsplitSample, ...]:
        return tuple(
            self.sample(
                index,
                dataset_id="dataset-a" if index < 3 else "dataset-b",
                acquisition_sha256=(
                    acquisition_sha256 if index < 3 else "b" * 64
                ),
            )
            for index in range(6)
        )

    def test_split_has_fixed_golden_assignment_and_commitments(self) -> None:
        records = self.samples()
        config = default_split_config(
            seed_id="seed-v1",
            key_id="hmac-v1",
            splitter_code_sha256=SPLITTER_CODE_SHA256,
        )
        approval = self.approval(
            records,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
        )

        artifacts = create_split_artifacts(
            records,
            seed_key=SEED_KEY,
            commitment_key=COMMITMENT_KEY,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
            approval=approval,
            allow_nonproduction=False,
        )

        self.assertEqual(
            {
                record.sample.sample_id: record.split.value
                for record in artifacts.private_records
            },
            {
                "sample-0": "train",
                "sample-1": "train",
                "sample-2": "test",
                "sample-3": "validation",
                "sample-4": "train",
                "sample-5": "train",
            },
        )
        self.assertEqual(
            artifacts.public.private_manifest_hmac_sha256,
            "9acecfe0982f2511fc6a481668f09873121cab3d98a8f32052717961d475daad",
        )
        self.assertEqual(
            artifacts.public.config.commitment_sha256,
            "e272dbb1fad07e7c69e8b68d317e8bd45185b879d5baef482543fd2747a592ef",
        )
        self.assertEqual(
            artifacts.public.commitment_sha256,
            "fdae18edb3a564ade8772713f52c29f8db0f4a325bf31a4e90cd4a6d36a0f878",
        )
        with self.assertRaises(TypeError):
            artifacts.public.sample_counts[Split.TRAIN] = 99
        with self.assertRaises(TypeError):
            artifacts.public.config.weights[Split.TRAIN] = 99

        shuffled = create_split_artifacts(
            tuple(reversed(records)),
            seed_key=SEED_KEY,
            commitment_key=COMMITMENT_KEY,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
            approval=approval,
            allow_nonproduction=False,
        )
        self.assertEqual(shuffled, artifacts)

    def test_public_commitment_contains_no_private_sample_material(self) -> None:
        records = self.samples()
        config = default_split_config(
            seed_id="seed-v1",
            key_id="hmac-v1",
            splitter_code_sha256=SPLITTER_CODE_SHA256,
        )
        approval = self.approval(
            records,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
        )
        artifacts = create_split_artifacts(
            records,
            seed_key=SEED_KEY,
            commitment_key=COMMITMENT_KEY,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
            approval=approval,
            allow_nonproduction=False,
        )
        public = artifacts.public.canonical_bytes()

        for sample in records:
            for private_value in (
                sample.sample_id,
                sample.writer_group_id,
                sample.object_key,
                sample.image_sha256,
                sample.reference_sha256,
            ):
                self.assertNotIn(private_value.encode(), public)
        self.assertNotIn(b"K" * 32, public)

    def test_secret_reader_rejects_tracked_or_wrong_sized_files(self) -> None:
        with self.assertRaisesRegex(ValueError, "untracked"):
            read_secret_file(Path(".gitattributes"), label="test key")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "key.bin"
            path.write_bytes(b"K" * 33)
            with self.assertRaisesRegex(ValueError, "exactly 32"):
                read_secret_file(path, label="test key")

    def test_wrong_seed_key_assignment_or_public_count_is_rejected(self) -> None:
        records = self.samples()
        config = default_split_config(
            seed_id="seed-v1",
            key_id="hmac-v1",
            splitter_code_sha256=SPLITTER_CODE_SHA256,
        )
        approval = self.approval(
            records,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
        )
        artifacts = create_split_artifacts(
            records,
            seed_key=SEED_KEY,
            commitment_key=COMMITMENT_KEY,
            config=config,
            adapter_commitment_sha256s=ADAPTER_COMMITMENT_SHA256S,
            approval=approval,
            allow_nonproduction=False,
        )
        with self.assertRaisesRegex(ValueError, "keys differ|assignments|commitment"):
            verify_split_artifacts(
                artifacts.private_records,
                artifacts.public,
                seed_key=b"Q" * 32,
                commitment_key=COMMITMENT_KEY,
                approval=approval,
                allow_nonproduction=False,
            )
        with self.assertRaisesRegex(ValueError, "keys differ|commitment"):
            verify_split_artifacts(
                artifacts.private_records,
                artifacts.public,
                seed_key=SEED_KEY,
                commitment_key=b"Q" * 32,
                approval=approval,
                allow_nonproduction=False,
            )

        tampered_counts = dict(artifacts.public.sample_counts)
        tampered_counts[Split.TRAIN] += 1
        tampered_public = replace(
            artifacts.public,
            sample_counts=tampered_counts,
        )
        with self.assertRaisesRegex(ValueError, "commitment"):
            verify_split_artifacts(
                artifacts.private_records,
                tampered_public,
                seed_key=SEED_KEY,
                commitment_key=COMMITMENT_KEY,
                approval=approval,
                allow_nonproduction=False,
            )

        first = artifacts.private_records[0]
        replacement_split = (
            Split.TEST if first.split != Split.TEST else Split.TRAIN
        )
        tampered_private = (
            replace(first, split=replacement_split),
            *artifacts.private_records[1:],
        )
        with self.assertRaises(ValueError):
            verify_split_artifacts(
                tampered_private,
                artifacts.public,
                seed_key=SEED_KEY,
                commitment_key=COMMITMENT_KEY,
                approval=approval,
                allow_nonproduction=False,
            )

    def test_jsonl_is_strict_canonical_and_rejects_unsafe_objects(self) -> None:
        records = self.samples()
        canonical = canonical_unsplit_jsonl(records)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "samples.jsonl"
            path.write_bytes(canonical)
            self.assertEqual(read_unsplit_jsonl(path), records)

            path.write_bytes(canonical.replace(b"\n", b"\r\n"))
            with self.assertRaisesRegex(ValueError, "one LF"):
                read_unsplit_jsonl(path)

            unknown = records[0].to_dict()
            unknown["extra"] = 1
            path.write_bytes(
                canonical_json_line_bytes(unknown)
                + b"".join(
                    canonical_json_line_bytes(record.to_dict())
                    for record in records[1:]
                )
            )
            with self.assertRaisesRegex(ValueError, "schema"):
                read_unsplit_jsonl(path)

        with self.assertRaisesRegex(ValueError, "portable"):
            replace(records[0], object_key="../outside.png")
        with self.assertRaisesRegex(ValueError, "positive"):
            replace(records[0], width=True)
        with self.assertRaisesRegex(ValueError, "case folding"):
            canonical_unsplit_jsonl(
                (
                    replace(records[0], object_key="A.png"),
                    replace(records[1], object_key="a.png"),
                )
            )

    def binding(
        self,
        *,
        dataset_id: str = "dataset-a",
        eligibility: Eligibility = Eligibility.PRODUCTION,
        terms_accepted: bool = True,
    ) -> AcquisitionBinding:
        content = f"archive-{dataset_id}".encode()
        source_manifest = DatasetSource(
            schema_version=1,
            dataset_id=dataset_id,
            version="1",
            doi=f"10.0000/{dataset_id}",
            source_url=f"https://example.test/{dataset_id}/1",
            license_id="CC-BY-4.0",
            filename=f"{dataset_id}.zip",
            bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            eligibility=eligibility,
            attribution="Synthetic unit-test source.",
            rights_notes="Unit-test bytes only.",
        )
        source = source_manifest.to_source_evidence()
        inventory = DirectoryInventory(
            schema_version=1,
            artifact_sha256=hashlib.sha256(
                f"artifact-{dataset_id}".encode()
            ).hexdigest(),
            files=(
                InventoryEntry(
                    path=f"{dataset_id}.bin",
                    bytes=1,
                    sha256=hashlib.sha256(
                        f"sample-{dataset_id}".encode()
                    ).hexdigest(),
                ),
            ),
        )
        acquisition = AcquisitionRecord(
            schema_version=3,
            record_id=f"{dataset_id}-v1",
            source_evidence_sha256=source.commitment_sha256,
            content_sha256=source.content_sha256,
            artifact_sha256=inventory.artifact_sha256,
            artifact_type="dataset",
            artifact_role="extracted_dataset",
            inventory_sha256=inventory.commitment_sha256,
            acquired_at_utc="2026-07-18T00:00:00Z",
            accepted_by="unit-test",
            terms_accepted=terms_accepted,
            extractor="unit-test/1",
            eligibility=eligibility,
        )
        return AcquisitionBinding(
            acquisition=acquisition,
            source=source,
            source_manifest=source_manifest,
            inventory=inventory,
        )

    def adapter_artifacts(
        self,
        binding: AcquisitionBinding,
        records: tuple[UnsplitSample, ...],
        *,
        commitment_key: bytes,
        code_bundle_sha256: str = SPLITTER_CODE_SHA256,
    ):
        config = AdapterConfig(
            schema_version=2,
            adapter_id=f"{binding.source.dataset_id}-lines",
            implementation_paths=(
                "ml/rosid_ml/adapters/dataset_a_lines.py",
            ),
            parameters={"normalization": "NFC", "height": 48},
        )
        source_entry = binding.inventory.files[0]
        derivations = tuple(
            SampleDerivation(
                sample_id=record.sample_id,
                sources=(
                    SourceUse(
                        path=source_entry.path,
                        sha256=source_entry.sha256,
                        roles=(SourceRole.IMAGE, SourceRole.REFERENCE),
                    ),
                ),
            )
            for record in records
        )
        artifacts = create_adapter_evidence(
            source=binding.source,
            acquisition=binding.acquisition,
            inventory=binding.inventory,
            adapter_code_bundle_sha256=code_bundle_sha256,
            adapter_config=config,
            normalized_samples=records,
            derivations=derivations,
            ignored_source_files={},
            commitment_key=commitment_key,
        )
        verified = verify_adapter_evidence(
            artifacts.private,
            artifacts.public,
            source=binding.source,
            acquisition=binding.acquisition,
            inventory=binding.inventory,
            normalized_samples=records,
            commitment_key=commitment_key,
            expected_code_bundle_sha256=code_bundle_sha256,
            expected_config_sha256=config.commitment_sha256,
        )
        return config, artifacts, verified

    def test_acquisition_bindings_are_exact_and_production_gated(self) -> None:
        first = self.binding(dataset_id="dataset-a")
        second = self.binding(dataset_id="dataset-b")
        records = self.samples(
            acquisition_sha256=first.commitment_sha256,
        )
        records = tuple(
            sample
            if sample.dataset_id == "dataset-a"
            else replace(
                sample,
                acquisition_sha256=second.commitment_sha256,
            )
            for sample in records
        )
        validate_acquisition_bindings(
            records,
            (first, second),
            allow_nonproduction=False,
        )

        with self.assertRaisesRegex(ValueError, "unbound"):
            validate_acquisition_bindings(
                (replace(records[0], acquisition_sha256="f" * 64), *records[1:]),
                (first, second),
                allow_nonproduction=False,
            )
        with self.assertRaisesRegex(ValueError, "differs"):
            validate_acquisition_bindings(
                (replace(records[0], dataset_id="dataset-b"), *records[1:]),
                (first, second),
                allow_nonproduction=False,
            )

        conditional = self.binding(
            dataset_id="dataset-a",
            eligibility=Eligibility.CONDITIONAL,
        )
        conditional_records = tuple(
            replace(sample, acquisition_sha256=conditional.commitment_sha256)
            for sample in records[:3]
        )
        with self.assertRaisesRegex(ValueError, "quarantined"):
            validate_acquisition_bindings(
                conditional_records,
                (conditional,),
                allow_nonproduction=False,
            )
        validate_acquisition_bindings(
            conditional_records,
            (conditional,),
            allow_nonproduction=True,
        )
        unaccepted = self.binding(
            dataset_id="dataset-a",
            eligibility=Eligibility.CONDITIONAL,
            terms_accepted=False,
        )
        with self.assertRaisesRegex(ValueError, "accepted source terms"):
            validate_acquisition_bindings(
                tuple(
                    replace(
                        sample,
                        acquisition_sha256=unaccepted.commitment_sha256,
                    )
                    for sample in records[:3]
                ),
                (unaccepted,),
                allow_nonproduction=True,
            )

    def test_verified_split_evidence_requires_full_keyed_verification(self) -> None:
        binding = self.binding(dataset_id="dataset-a")
        records = tuple(
            replace(
                self.sample(index),
                acquisition_sha256=binding.commitment_sha256,
            )
            for index in range(6)
        )
        seed_key = b"S" * 32
        commitment_key = b"K" * 32
        _, adapter_artifacts, verified_adapter = self.adapter_artifacts(
            binding,
            records,
            commitment_key=commitment_key,
        )
        config = default_split_config(
            seed_id="seed-v1",
            key_id="hmac-v1",
            splitter_code_sha256=SPLITTER_CODE_SHA256,
        )
        adapter_commitments = (adapter_artifacts.public.commitment_sha256,)
        approval = self.approval(
            records,
            config=config,
            adapter_commitment_sha256s=adapter_commitments,
            seed_key=seed_key,
            commitment_key=commitment_key,
        )
        artifacts = create_split_artifacts(
            records,
            seed_key=seed_key,
            commitment_key=commitment_key,
            config=config,
            adapter_commitment_sha256s=adapter_commitments,
            approval=approval,
            allow_nonproduction=False,
        )

        verified = verify_split_evidence(
            artifacts.private_records,
            artifacts.public,
            seed_key=seed_key,
            commitment_key=commitment_key,
            bindings=(binding,),
            adapter_evidence=(verified_adapter,),
            approval=approval,
            allow_nonproduction=False,
        )
        self.assertIs(verified.public, artifacts.public)
        self.assertEqual(
            verified.public_commitment_sha256,
            artifacts.public.commitment_sha256,
        )
        with self.assertRaisesRegex(ValueError, "must come from"):
            VerifiedSplitEvidence(
                public=artifacts.public,
                private_manifest_sha256="0" * 64,
                acquisition_sha256s=(binding.commitment_sha256,),
                _token=object(),
            )
        with self.assertRaisesRegex(ValueError, "must be different"):
            verify_split_evidence(
                artifacts.private_records,
                artifacts.public,
                seed_key=commitment_key,
                commitment_key=commitment_key,
                bindings=(binding,),
                adapter_evidence=(verified_adapter,),
                approval=approval,
                allow_nonproduction=False,
            )

    def test_loader_rejects_forged_source_or_inventory_binding(self) -> None:
        first = self.binding(dataset_id="dataset-a")
        second = self.binding(dataset_id="dataset-b")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            acquisition = root / "acquisition.json"
            source = root / "source.json"
            source_manifest = root / "source-manifest.json"
            inventory = root / "inventory.json"
            acquisition.write_bytes(first.acquisition.canonical_bytes())
            source.write_bytes(first.source.canonical_bytes())
            inventory.write_bytes(first.inventory.canonical_bytes())

            source_manifest.write_bytes(second.source_manifest.canonical_bytes())
            with self.assertRaisesRegex(ValueError, "reviewed dataset manifest"):
                load_acquisition_bindings(
                    (acquisition,),
                    (source,),
                    (source_manifest,),
                    (inventory,),
                )

            source_manifest.write_bytes(first.source_manifest.canonical_bytes())
            inventory.write_bytes(second.inventory.canonical_bytes())
            with self.assertRaisesRegex(ValueError, "private directory inventory"):
                load_acquisition_bindings(
                    (acquisition,),
                    (source,),
                    (source_manifest,),
                    (inventory,),
                )

    def test_build_and_verify_cli_round_trip_without_private_stdout(self) -> None:
        binding = self.binding(dataset_id="dataset-a")
        records = tuple(
            replace(
                self.sample(index),
                acquisition_sha256=binding.commitment_sha256,
            )
            for index in range(6)
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repository = root / "repository"
            private_root = root / "private"
            repository.mkdir()
            private_root.mkdir()
            self.run_git(repository, "init", "--quiet")
            self.run_git(repository, "config", "user.name", "Split Test")
            self.run_git(
                repository,
                "config",
                "user.email",
                "split-test@example.invalid",
            )
            self.run_git(
                repository,
                "remote",
                "add",
                "origin",
                "https://github.com/tanzir-lameh/rosid.git",
            )
            (repository / ".gitattributes").write_bytes(b"* -text\n")

            owner_key = private_root / "owner-ed25519"
            subprocess.run(
                (
                    "ssh-keygen",
                    "-q",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    str(owner_key),
                ),
                check=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
            public_key_parts = owner_key.with_suffix(".pub").read_text(
                encoding="ascii"
            ).strip().split()
            owner_public_key = " ".join(public_key_parts[:2])
            policy = ApprovalPolicy(
                schema_version=1,
                repository_id=ROSID_REPOSITORY_ID,
                generation=1,
                status=ApprovalStatus.ACTIVE,
                signer_identity="unit-test-owner",
                owner_public_key=owner_public_key,
                owner_public_key_sha256=owner_public_key_sha256(
                    owner_public_key
                ),
            )

            core_files: dict[str, Path] = {}
            for relative in REQUIRED_CORE_CODE_ROLES:
                core_file = repository / relative
                core_file.parent.mkdir(parents=True, exist_ok=True)
                core_file.write_bytes(f"# {relative}\n".encode())
                core_files[relative] = core_file
            adapter_code = (
                repository
                / "ml"
                / "rosid_ml"
                / "adapters"
                / "dataset_a_lines.py"
            )
            adapter_code.parent.mkdir(parents=True)
            adapter_code.write_bytes(b"def adapt():\n    return 2\n")
            code_bundle = build_code_bundle(
                repository,
                splitter_files=tuple(
                    core_files[path]
                    for path, role in REQUIRED_CORE_CODE_ROLES.items()
                    if role == CodeRole.SPLITTER.value
                ),
                adapter_files=(adapter_code,),
                shared_files=tuple(
                    core_files[path]
                    for path, role in REQUIRED_CORE_CODE_ROLES.items()
                    if role == CodeRole.SHARED.value
                ),
            )
            config = default_split_config(
                seed_id="seed-v1",
                key_id="hmac-v1",
                splitter_code_sha256=code_bundle.commitment_sha256,
            )
            adapter_config, adapter_artifacts, _ = self.adapter_artifacts(
                binding,
                records,
                commitment_key=b"K" * 32,
                code_bundle_sha256=code_bundle.commitment_sha256,
            )

            acquisition_root = (
                repository / "ml" / "manifests" / "acquisitions"
            )
            dataset_root = repository / "ml" / "manifests" / "datasets"
            adapter_root = repository / "ml" / "manifests" / "adapters"
            split_root = repository / "ml" / "manifests" / "splits"
            for path in (
                acquisition_root,
                dataset_root,
                adapter_root,
                split_root,
            ):
                path.mkdir(parents=True)
            acquisition_path = acquisition_root / "fixture.acquisition.json"
            source_path = acquisition_root / "fixture.source.json"
            source_manifest_path = dataset_root / "fixture.json"
            adapter_commitment_path = adapter_root / "fixture.commitment.json"
            adapter_config_path = adapter_root / "fixture.config.json"
            code_bundle_path = split_root / "fixture.code.json"
            config_path = split_root / "fixture.config.json"
            request_path = split_root / "fixture.approval-request.json"
            approval_path = split_root / "fixture.approval.json"
            public_path = split_root / "fixture.commitment.json"

            inventory_path = private_root / "samples.jsonl"
            directory_inventory_path = private_root / "directory-inventory.json"
            adapter_evidence_path = private_root / "adapter-evidence.json"
            seed_key_path = private_root / "seed.key"
            commitment_key_path = private_root / "commitment.key"
            private_path = private_root / "private.jsonl"
            inventory_path.write_bytes(canonical_unsplit_jsonl(records))
            acquisition_path.write_bytes(
                binding.acquisition.canonical_bytes()
            )
            source_path.write_bytes(binding.source.canonical_bytes())
            source_manifest_path.write_bytes(
                binding.source_manifest.canonical_bytes()
            )
            directory_inventory_path.write_bytes(
                binding.inventory.canonical_bytes()
            )
            adapter_evidence_path.write_bytes(
                adapter_artifacts.private.canonical_bytes()
            )
            adapter_commitment_path.write_bytes(
                adapter_artifacts.public.canonical_bytes()
            )
            adapter_config_path.write_bytes(adapter_config.canonical_bytes())
            code_bundle_path.write_bytes(code_bundle.canonical_bytes())
            config_path.write_bytes(config.canonical_bytes())
            policy_path = repository / "ml" / "APPROVAL_POLICY.json"
            policy_path.write_bytes(policy.canonical_bytes())
            seed_key_path.write_bytes(b"S" * 32)
            commitment_key_path.write_bytes(b"K" * 32)
            self.run_git(repository, "add", "--", ".")
            self.run_git(repository, "commit", "--quiet", "-m", "approvals")

            trusted_policy_sha256 = policy.commitment_sha256
            request_args = [
                "--approval-id",
                "fixture-global-split-v1",
                "--approved-by",
                "unit-test-owner",
                "--trusted-approval-policy-sha256",
                trusted_policy_sha256,
                "--approved-config",
                str(config_path),
                "--approved-code-bundle",
                str(code_bundle_path),
                "--acquisition-record",
                str(acquisition_path),
                "--source-evidence",
                str(source_path),
                "--source-manifest",
                str(source_manifest_path),
                "--adapter-commitment",
                str(adapter_commitment_path),
                "--approved-adapter-config",
                str(adapter_config_path),
                "--seed-key-file",
                str(seed_key_path),
                "--commitment-key-file",
                str(commitment_key_path),
                "--request-output",
                str(request_path),
            ]
            with contextlib.chdir(repository):
                self.assertEqual(request_split_approval_main(request_args), 0)
            self.run_git(
                repository,
                "add",
                "--",
                request_path.relative_to(repository).as_posix(),
            )
            self.run_git(repository, "commit", "--quiet", "-m", "request")

            signing_copy = private_root / "approval-request.json"
            signing_copy.write_bytes(request_path.read_bytes())
            subprocess.run(
                (
                    "ssh-keygen",
                    "-Y",
                    "sign",
                    "-f",
                    str(owner_key),
                    "-n",
                    APPROVAL_SIGNATURE_NAMESPACE,
                    str(signing_copy),
                ),
                check=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
            signature_path = Path(f"{signing_copy}.sig")
            with contextlib.chdir(repository):
                self.assertEqual(
                    finalize_split_approval_main(
                        [
                            "--trusted-approval-policy-sha256",
                            trusted_policy_sha256,
                            "--approval-request",
                            str(request_path),
                            "--detached-signature",
                            str(signature_path),
                            "--approval-output",
                            str(approval_path),
                        ]
                    ),
                    0,
                )
            self.run_git(
                repository,
                "add",
                "--",
                approval_path.relative_to(repository).as_posix(),
            )
            self.run_git(repository, "commit", "--quiet", "-m", "approval")

            common = [
                str(inventory_path),
                "--acquisition-record",
                str(acquisition_path),
                "--source-evidence",
                str(source_path),
                "--source-manifest",
                str(source_manifest_path),
                "--directory-inventory",
                str(directory_inventory_path),
                "--adapter-evidence",
                str(adapter_evidence_path),
                "--adapter-commitment",
                str(adapter_commitment_path),
                "--approved-adapter-config",
                str(adapter_config_path),
                "--seed-key-file",
                str(seed_key_path),
                "--commitment-key-file",
                str(commitment_key_path),
                "--approved-config",
                str(config_path),
                "--approved-code-bundle",
                str(code_bundle_path),
                "--split-approval",
                str(approval_path),
                "--trusted-approval-policy-sha256",
                trusted_policy_sha256,
                "--private-output",
                str(private_path),
                "--public-output",
                str(public_path),
            ]
            stdout = io.StringIO()
            with (
                contextlib.chdir(repository),
                contextlib.redirect_stdout(stdout),
            ):
                self.assertEqual(build_split_main(common), 0)
            build_output = stdout.getvalue()

            for record in records:
                self.assertNotIn(record.writer_group_id, build_output)
                self.assertNotIn(record.object_key, build_output)
            private_records = read_private_jsonl(private_path)
            public = PublicSplitCommitment.from_json_file(public_path)
            self.assertEqual(len(private_records), 6)
            self.assertEqual(sum(public.sample_counts.values()), 6)
            self.assertEqual(
                public.adapter_commitment_sha256s,
                (adapter_artifacts.public.commitment_sha256,),
            )
            self.run_git(
                repository,
                "add",
                "--",
                public_path.relative_to(repository).as_posix(),
            )
            self.run_git(repository, "commit", "--quiet", "-m", "split")

            verify_args = [
                str(private_path),
                str(public_path),
                "--acquisition-record",
                str(acquisition_path),
                "--source-evidence",
                str(source_path),
                "--source-manifest",
                str(source_manifest_path),
                "--directory-inventory",
                str(directory_inventory_path),
                "--adapter-evidence",
                str(adapter_evidence_path),
                "--adapter-commitment",
                str(adapter_commitment_path),
                "--approved-adapter-config",
                str(adapter_config_path),
                "--seed-key-file",
                str(seed_key_path),
                "--commitment-key-file",
                str(commitment_key_path),
                "--approved-config",
                str(config_path),
                "--approved-code-bundle",
                str(code_bundle_path),
                "--split-approval",
                str(approval_path),
                "--trusted-approval-policy-sha256",
                trusted_policy_sha256,
            ]
            stdout = io.StringIO()
            with (
                contextlib.chdir(repository),
                contextlib.redirect_stdout(stdout),
            ):
                self.assertEqual(verify_split_main(verify_args), 0)
            self.assertIn('"verified":true', stdout.getvalue())

            adapter_config_path.write_bytes(
                adapter_config.canonical_bytes() + b" "
            )
            rejected_stderr = io.StringIO()
            with (
                contextlib.chdir(repository),
                contextlib.redirect_stderr(rejected_stderr),
                self.assertRaises(SystemExit),
            ):
                verify_split_main(verify_args)
            self.assertIn("unchanged", rejected_stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
