from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ml.record_acquisition import main as record_acquisition_main
from ml.rosid_ml import acquisition as acquisition_module
from ml.rosid_ml.acquisition import (
    DirectoryInventory,
    InventoryEntry,
    build_acquisition_artifacts,
    inventory_directory,
    write_new_files,
)
from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    SourceEvidence,
)


class AcquisitionTest(unittest.TestCase):
    def source(
        self,
        content: bytes,
        *,
        eligibility: Eligibility = Eligibility.PRODUCTION,
    ) -> DatasetSource:
        return DatasetSource(
            schema_version=1,
            dataset_id="fixture",
            version="1",
            doi="10.0000/fixture",
            source_url="https://example.test/fixture/1",
            license_id="CC-BY-4.0",
            filename="fixture.zip",
            bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            eligibility=eligibility,
            attribution="Synthetic test fixture; CC BY 4.0.",
            rights_notes="Unit-test bytes only.",
        )

    def populate(self, root: Path, *, reverse: bool = False) -> None:
        entries = [
            ("a.txt", b"alpha\n"),
            ("nested/b.bin", b"\x00\xff"),
        ]
        if reverse:
            entries.reverse()
        for relative, content in entries:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    @staticmethod
    def run_git(directory: Path, *arguments: str) -> None:
        subprocess.run(
            ("git", *arguments),
            cwd=directory,
            check=True,
            capture_output=True,
            shell=False,
        )

    def prepare_cli_repository(
        self,
        root: Path,
        archive_content: bytes,
    ) -> tuple[Path, Path, Path, Path, Path, Path]:
        repository = root / "repository"
        repository.mkdir()
        self.run_git(repository, "init", "--quiet")
        self.run_git(repository, "config", "user.name", "Acquisition Test")
        self.run_git(
            repository,
            "config",
            "user.email",
            "acquisition-test@example.invalid",
        )
        (repository / ".gitignore").write_bytes(
            b"/ml/data/\n/ml/manifests/private/\n"
        )
        (repository / ".gitattributes").write_bytes(b"* -text\n")
        source_manifest = (
            repository
            / "ml"
            / "manifests"
            / "datasets"
            / "fixture.json"
        )
        source_manifest.parent.mkdir(parents=True)
        source_manifest.write_bytes(self.source(archive_content).canonical_bytes())
        self.run_git(
            repository,
            "add",
            "--",
            ".gitattributes",
            ".gitignore",
            "ml/manifests/datasets/fixture.json",
        )
        self.run_git(repository, "commit", "--quiet", "-m", "source allowlist")

        archive = repository / "ml" / "data" / "raw" / "fixture.zip"
        archive.parent.mkdir(parents=True)
        archive.write_bytes(archive_content)
        extracted = repository / "ml" / "data" / "external" / "fixture"
        extracted.mkdir(parents=True)
        self.populate(extracted)
        public = repository / "ml" / "manifests" / "acquisitions"
        private_inventory = (
            repository
            / "ml"
            / "manifests"
            / "private"
            / "acquisitions"
            / "fixture.inventory.json"
        )
        return (
            repository,
            source_manifest,
            archive,
            extracted,
            public,
            private_inventory,
        )

    def test_inventory_has_fixed_golden_bytes_and_ignores_creation_order(self) -> None:
        with (
            tempfile.TemporaryDirectory() as first_directory,
            tempfile.TemporaryDirectory() as second_directory,
        ):
            first = Path(first_directory)
            second = Path(second_directory)
            self.populate(first)
            self.populate(second, reverse=True)
            os.utime(first / "a.txt", (1_000_000_000, 1_000_000_000))
            os.utime(second / "a.txt", (1_100_000_000, 1_100_000_000))

            first_inventory = inventory_directory(first)
            second_inventory = inventory_directory(second)

        self.assertEqual(first_inventory, second_inventory)
        self.assertEqual(
            first_inventory.artifact_sha256,
            "7f042d4fc8fb766e077cdf94a5ffe18976b25039cce349ca8d773047b4cc74fb",
        )
        self.assertEqual(
            first_inventory.commitment_sha256,
            "738168a901b5ce310b8f853279cc159cf7567e0c93d0dc57ebcda3faa272847b",
        )
        self.assertEqual(
            first_inventory.canonical_bytes(),
            (
                b'{\n'
                b'  "artifact_sha256": '
                b'"7f042d4fc8fb766e077cdf94a5ffe18976b25039cce349ca8d773047b4cc74fb",\n'
                b'  "file_count": 2,\n'
                b'  "files": [\n'
                b'    {\n'
                b'      "bytes": 6,\n'
                b'      "path": "a.txt",\n'
                b'      "sha256": '
                b'"b6a98d9ce9a2d9149288fa3df42d377c3e42737afdcdaf714e33c0a100b51060"\n'
                b'    },\n'
                b'    {\n'
                b'      "bytes": 2,\n'
                b'      "path": "nested/b.bin",\n'
                b'      "sha256": '
                b'"06eb7d6a69ee19e5fbdf749018d3d2abfa04bcbd1365db312eb86dc7169389b8"\n'
                b'    }\n'
                b'  ],\n'
                b'  "schema_version": 1,\n'
                b'  "total_bytes": 8\n'
                b'}\n'
            ),
        )

    def test_inventory_round_trip_and_detects_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "extract"
            root.mkdir()
            self.populate(root)
            inventory = inventory_directory(root)
            manifest = Path(directory) / "inventory.json"
            manifest.write_bytes(inventory.canonical_bytes())

            parsed = DirectoryInventory.from_json_file(manifest)
            parsed.verify_directory(root)
            (root / "a.txt").write_bytes(b"changed")

            with self.assertRaisesRegex(ValueError, "differs"):
                parsed.verify_directory(root)

    def test_inventory_detects_same_size_restored_mtime_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "sample.txt"
            target.write_bytes(b"alpha\n")
            initial = target.stat()
            timestamps = (initial.st_atime_ns, initial.st_mtime_ns)
            original_scan = acquisition_module._scan_regular_files
            calls = 0

            def mutate_after_rescan(
                scan_root: Path,
            ) -> list[tuple[str, Path, os.stat_result]]:
                nonlocal calls
                result = original_scan(scan_root)
                calls += 1
                if calls == 2:
                    target.write_bytes(b"bravo\n")
                    os.utime(target, ns=timestamps)
                return result

            with (
                mock.patch(
                    "ml.rosid_ml.acquisition._scan_regular_files",
                    mutate_after_rescan,
                ),
                self.assertRaisesRegex(ValueError, "confirmation"),
            ):
                inventory_directory(root)

    def test_inventory_entry_rejects_nonportable_paths(self) -> None:
        sha256 = "0" * 64
        invalid = (
            "../escape",
            "/absolute",
            r"dir\file",
            "C:/drive",
            "con.txt",
            "trailing.",
            "trailing ",
            "wild?.txt",
            "cafe\u0301.txt",
            "control\x01.txt",
        )
        for path in invalid:
            with self.subTest(path=path):
                with self.assertRaisesRegex(ValueError, "portable|NFC"):
                    InventoryEntry(path=path, bytes=1, sha256=sha256)

    def test_inventory_rejects_linked_roots_and_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            real = base / "real"
            real.mkdir()
            (real / "file.txt").write_text("fixture", encoding="utf-8")
            linked_root = base / "linked-root"
            try:
                linked_root.symlink_to(real, target_is_directory=True)
            except OSError as error:
                self.skipTest(f"symbolic links unavailable: {error}")

            with self.assertRaisesRegex(ValueError, "linked directory"):
                inventory_directory(linked_root)

            linked_file = real / "linked-file"
            linked_file.symlink_to(real / "file.txt")
            with self.assertRaisesRegex(ValueError, "non-regular"):
                inventory_directory(real)

    def test_inventory_rejects_hardlinks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            extracted = base / "extracted"
            extracted.mkdir()
            outside = base / "outside.txt"
            outside.write_bytes(b"private")
            try:
                os.link(outside, extracted / "hardlink.txt")
            except OSError as error:
                self.skipTest(f"hard links unavailable: {error}")

            with self.assertRaisesRegex(ValueError, "linked"):
                inventory_directory(extracted)

    def test_build_acquisition_binds_archive_and_extracted_snapshots(self) -> None:
        archive_content = b"publisher archive"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "fixture.zip"
            archive.write_bytes(archive_content)
            extracted = root / "extracted"
            extracted.mkdir()
            self.populate(extracted)

            artifacts = build_acquisition_artifacts(
                source_manifest=self.source(archive_content),
                archive_path=archive,
                extracted_directory=extracted,
                record_id="fixture-v1",
                acquired_at_utc="2026-07-18T00:00:00Z",
                accepted_by="unit-test",
                terms_accepted=True,
                extractor="unit-test/1",
            )

        self.assertEqual(
            artifacts.acquisition.content_sha256,
            hashlib.sha256(archive_content).hexdigest(),
        )
        self.assertEqual(
            artifacts.acquisition.artifact_sha256,
            artifacts.inventory.artifact_sha256,
        )
        self.assertEqual(
            artifacts.acquisition.inventory_sha256,
            artifacts.inventory.commitment_sha256,
        )
        artifacts.acquisition.validate_source(artifacts.source)

    def test_nonproduction_requires_explicit_quarantine_and_cannot_upgrade(
        self,
    ) -> None:
        archive_content = b"publisher archive"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "fixture.zip"
            archive.write_bytes(archive_content)
            extracted = root / "extracted"
            extracted.mkdir()
            (extracted / "file").write_bytes(b"content")
            conditional = self.source(
                archive_content,
                eligibility=Eligibility.CONDITIONAL,
            )

            with self.assertRaisesRegex(ValueError, "quarantined"):
                build_acquisition_artifacts(
                    source_manifest=conditional,
                    archive_path=archive,
                    extracted_directory=extracted,
                    record_id="fixture-v1",
                    acquired_at_utc="2026-07-18T00:00:00Z",
                    accepted_by="unit-test",
                    terms_accepted=True,
                    extractor="unit-test/1",
                )

            artifacts = build_acquisition_artifacts(
                source_manifest=conditional,
                archive_path=archive,
                extracted_directory=extracted,
                record_id="fixture-v1",
                acquired_at_utc="2026-07-18T00:00:00Z",
                accepted_by="unit-test",
                terms_accepted=True,
                extractor="unit-test/1",
                quarantined_research=True,
            )
            self.assertEqual(
                artifacts.acquisition.eligibility,
                Eligibility.CONDITIONAL,
            )

            with self.assertRaisesRegex(ValueError, "cannot upgrade"):
                build_acquisition_artifacts(
                    source_manifest=conditional,
                    archive_path=archive,
                    extracted_directory=extracted,
                    record_id="fixture-production",
                    acquired_at_utc="2026-07-18T00:00:00Z",
                    accepted_by="unit-test",
                    terms_accepted=True,
                    extractor="unit-test/1",
                    eligibility=Eligibility.PRODUCTION,
                    quarantined_research=True,
                )

    def test_record_acquisition_cli_writes_canonical_public_and_private_evidence(
        self,
    ) -> None:
        archive_content = b"publisher archive"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (
                repository,
                source_manifest,
                archive,
                extracted,
                public,
                private_inventory,
            ) = self.prepare_cli_repository(root, archive_content)

            stdout = io.StringIO()
            with contextlib.chdir(repository), contextlib.redirect_stdout(stdout):
                result = record_acquisition_main(
                    [
                        str(source_manifest),
                        str(archive),
                        str(extracted),
                        "--record-id",
                        "fixture-v1",
                        "--acquired-at-utc",
                        "2026-07-18T00:00:00Z",
                        "--accepted-by",
                        "unit-test",
                        "--terms-accepted",
                        "--extractor",
                        "unit-test/1",
                        "--public-directory",
                        str(public),
                        "--private-inventory",
                        str(private_inventory),
                    ]
                )

            self.assertEqual(result, 0)
            source = SourceEvidence.from_json_file(
                public / "fixture-v1.source.json"
            )
            acquisition = AcquisitionRecord.from_json_file(
                public / "fixture-v1.acquisition.json"
            )
            inventory = DirectoryInventory.from_json_file(private_inventory)
            acquisition.validate_source(source)
            self.assertEqual(acquisition.schema_version, 3)
            self.assertEqual(acquisition.artifact_role, "extracted_dataset")
            self.assertEqual(acquisition.artifact_sha256, inventory.artifact_sha256)
            output = json.loads(stdout.getvalue())
            self.assertEqual(
                output["inventory_sha256"],
                inventory.commitment_sha256,
            )
            self.assertTrue(output["written"])
            self.assertNotIn(str(root), stdout.getvalue())

    def test_record_cli_requires_committed_source_before_hashing_or_writes(
        self,
    ) -> None:
        archive_content = b"publisher archive"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (
                repository,
                source_manifest,
                archive,
                extracted,
                public,
                private_inventory,
            ) = self.prepare_cli_repository(root, archive_content)
            outside = root / "outside.json"
            outside.write_bytes(self.source(archive_content).canonical_bytes())
            untracked = source_manifest.with_name("untracked.json")
            untracked.write_bytes(self.source(archive_content).canonical_bytes())
            committed = source_manifest.read_bytes()
            common = [
                str(archive),
                str(extracted),
                "--record-id",
                "fixture-v1",
                "--acquired-at-utc",
                "2026-07-18T00:00:00Z",
                "--accepted-by",
                "unit-test",
                "--terms-accepted",
                "--extractor",
                "unit-test/1",
                "--public-directory",
                str(public),
                "--private-inventory",
                str(private_inventory),
            ]
            cases = (
                ("outside", outside, "expected Git worktree"),
                ("untracked", untracked, "tracked by Git"),
                ("dirty", source_manifest, "unchanged at Git HEAD"),
            )
            for label, candidate, expected_error in cases:
                with self.subTest(label=label):
                    if label == "dirty":
                        source_manifest.write_bytes(b"dirty\n")
                    stderr = io.StringIO()
                    with (
                        contextlib.chdir(repository),
                        mock.patch(
                            "ml.record_acquisition.DatasetSource.from_json_file"
                        ) as parse,
                        mock.patch(
                            "ml.record_acquisition.build_acquisition_artifacts"
                        ) as build,
                        mock.patch("ml.record_acquisition.write_new_files") as write,
                        contextlib.redirect_stderr(stderr),
                        self.assertRaises(SystemExit),
                    ):
                        record_acquisition_main(
                            [str(candidate), *common]
                        )
                    parse.assert_not_called()
                    build.assert_not_called()
                    write.assert_not_called()
                    self.assertIn(expected_error, stderr.getvalue())
                    source_manifest.write_bytes(committed)

            self.assertFalse(public.exists())
            self.assertFalse(private_inventory.exists())

    def test_record_cli_rejects_unsafe_outputs_before_hashing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (
                repository,
                source_manifest,
                archive,
                extracted,
                public,
                _,
            ) = self.prepare_cli_repository(root, b"publisher archive")
            common = [
                str(source_manifest),
                str(archive),
                str(extracted),
                "--record-id",
                "fixture-v1",
                "--acquired-at-utc",
                "2026-07-18T00:00:00Z",
                "--accepted-by",
                "unit-test",
                "--terms-accepted",
                "--extractor",
                "unit-test/1",
            ]
            cases = (
                (
                    "public outside worktree",
                    ["--public-directory", str(root / "outside-public")],
                    "expected Git worktree",
                ),
                (
                    "public tree overlap",
                    ["--public-directory", str(extracted / "evidence")],
                    "acquisitions",
                ),
                (
                    "private under public",
                    [
                        "--public-directory", str(public),
                        "--private-inventory",
                        str(public / "private.json"),
                    ],
                    "ml/manifests/private",
                ),
            )
            for label, extra, expected_error in cases:
                with self.subTest(label=label):
                    stderr = io.StringIO()
                    with (
                        contextlib.chdir(repository),
                        mock.patch(
                            "ml.record_acquisition.build_acquisition_artifacts"
                        ) as build,
                        contextlib.redirect_stderr(stderr),
                        self.assertRaises(SystemExit),
                    ):
                        record_acquisition_main([*common, *extra])
                    build.assert_not_called()
                    self.assertIn(expected_error, stderr.getvalue())

    def test_write_new_files_never_overwrites_or_partially_writes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = root / "existing.json"
            missing = root / "missing.json"
            existing.write_bytes(b"original")

            with self.assertRaises(FileExistsError):
                write_new_files(
                    (
                        (existing, b"replacement"),
                        (missing, b"new"),
                    )
                )

            self.assertEqual(existing.read_bytes(), b"original")
            self.assertFalse(missing.exists())

            write_new_files(
                (
                    (existing, b"original"),
                    (missing, b"new"),
                )
            )
            with self.assertRaisesRegex(ValueError, "distinct"):
                write_new_files(
                    (
                        (existing, b"original"),
                        (existing, b"original"),
                    )
                )
            self.assertEqual(missing.read_bytes(), b"new")
            write_new_files(
                (
                    (existing, b"original"),
                    (missing, b"new"),
                )
            )

    def test_write_new_files_rejects_symlink_and_rolls_back_link_failure(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.json"
            target.write_bytes(b"same")
            linked = root / "linked.json"
            try:
                linked.symlink_to(target)
            except OSError as error:
                self.skipTest(f"symbolic links unavailable: {error}")
            with self.assertRaisesRegex(ValueError, "linked"):
                write_new_files(((linked, b"same"),))

            first = root / "first.json"
            second = root / "second.json"
            real_link = os.link
            calls = 0

            def fail_second(source: Path, destination: Path) -> None:
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("injected second-link failure")
                real_link(source, destination)

            with (
                mock.patch("ml.rosid_ml.acquisition.os.link", fail_second),
                self.assertRaisesRegex(OSError, "injected"),
            ):
                write_new_files(((first, b"one"), (second, b"two")))
            self.assertFalse(first.exists())
            self.assertFalse(second.exists())


if __name__ == "__main__":
    unittest.main()
