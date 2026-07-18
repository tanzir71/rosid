from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import stat
import struct
import subprocess
import tempfile
import unittest
import warnings
import zipfile
from dataclasses import replace
from pathlib import Path
from unittest import mock

import ml.rosid_ml.safe_extract as safe_extract_module
from ml.extract_dataset import main as extract_main
from ml.rosid_ml.provenance import DatasetSource, Eligibility
from ml.rosid_ml.safe_extract import (
    SafeExtractionError,
    ZipExtractionLimits,
    safe_extract_zip,
)


class SafeExtractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)

    @staticmethod
    def limits(**overrides: int) -> ZipExtractionLimits:
        values = {
            "max_members": 20,
            "max_central_directory_bytes": 100_000,
            "max_total_uncompressed_bytes": 100_000,
            "max_member_uncompressed_bytes": 100_000,
            "max_compression_ratio": 1_000,
            "minimum_free_bytes_after": 1,
            **overrides,
        }
        return ZipExtractionLimits(**values)

    @staticmethod
    def source(
        archive: Path,
        *,
        filename: str | None = None,
        eligibility: Eligibility = Eligibility.PRODUCTION,
    ) -> DatasetSource:
        content = archive.read_bytes()
        return DatasetSource(
            schema_version=1,
            dataset_id="fixture-v1",
            version="1",
            doi=None,
            source_url="https://example.test/fixture.zip",
            license_id="CC0-1.0",
            filename=archive.name if filename is None else filename,
            bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            eligibility=eligibility,
            attribution="Synthetic test fixture.",
            rights_notes="Unit-test bytes only.",
        )

    def write_zip(
        self,
        name: str,
        members: list[tuple[str | zipfile.ZipInfo, bytes]],
        *,
        compression: int = zipfile.ZIP_DEFLATED,
    ) -> Path:
        archive = self.root / name
        with zipfile.ZipFile(archive, "w", compression=compression) as zipped:
            for member, content in members:
                zipped.writestr(member, content)
        return archive

    def extract(
        self,
        archive: Path,
        *,
        destination_name: str = "extracted",
        source: DatasetSource | None = None,
        limits: ZipExtractionLimits | None = None,
        require_production: bool = True,
    ):
        return safe_extract_zip(
            self.source(archive) if source is None else source,
            archive,
            self.root / destination_name,
            limits=self.limits() if limits is None else limits,
            require_production=require_production,
        )

    def test_extracts_regular_files_into_a_fresh_inventoried_tree(self) -> None:
        directory = zipfile.ZipInfo("nested/")
        directory.external_attr = (stat.S_IFDIR | 0o755) << 16 | 0x10
        archive = self.write_zip(
            "fixture.zip",
            [
                (directory, b""),
                ("nested/receipt.txt", "মোট ১২৩".encode()),
                ("empty.bin", b""),
            ],
        )

        result = self.extract(archive)

        self.assertEqual(result.dataset_id, "fixture-v1")
        self.assertEqual(result.member_count, 3)
        self.assertEqual(result.directory_count, 1)
        self.assertEqual(result.file_count, 2)
        self.assertEqual(
            [entry.path for entry in result.inventory.files],
            ["empty.bin", "nested/receipt.txt"],
        )
        self.assertEqual(
            (result.destination / "nested" / "receipt.txt").read_text("utf-8"),
            "মোট ১২৩",
        )
        for sealed in (
            result.destination,
            result.destination / "nested",
            result.destination / "nested" / "receipt.txt",
            result.destination / "empty.bin",
        ):
            self.assertEqual(
                sealed.stat().st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH),
                0,
            )
        with self.assertRaisesRegex(SafeExtractionError, "must not already exist"):
            self.extract(archive)

    def test_preflights_central_directory_before_constructing_zipfile(self) -> None:
        archive = self.write_zip(
            "bounded.zip",
            [("a.txt", b"a"), ("b.txt", b"b")],
        )
        with mock.patch.object(
            safe_extract_module.zipfile,
            "ZipFile",
            side_effect=AssertionError("ZipFile must not be constructed"),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "has 2 members"):
                self.extract(
                    archive,
                    destination_name="member-preflight",
                    limits=self.limits(max_members=1),
                )
            with self.assertRaisesRegex(SafeExtractionError, "central directory has"):
                self.extract(
                    archive,
                    destination_name="central-byte-preflight",
                    limits=self.limits(max_central_directory_bytes=1),
                )

        content = bytearray(archive.read_bytes())
        eocd = content.rfind(b"PK\x05\x06")
        struct.pack_into("<H", content, eocd + 8, 1)
        struct.pack_into("<H", content, eocd + 10, 1)
        archive.write_bytes(content)
        understated = self.source(archive)
        with mock.patch.object(
            safe_extract_module.zipfile,
            "ZipFile",
            side_effect=AssertionError("ZipFile must not be constructed"),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "more than 1 members"):
                self.extract(
                    archive,
                    destination_name="actual-member-preflight",
                    source=understated,
                    limits=self.limits(max_members=1),
                )

    def test_accepts_canonical_single_disk_zip64_and_rejects_multi_disk(self) -> None:
        archive = self.root / "zip64.zip"
        with mock.patch.object(zipfile, "ZIP_FILECOUNT_LIMIT", 0):
            with zipfile.ZipFile(
                archive, "w", compression=zipfile.ZIP_STORED
            ) as zipped:
                zipped.writestr("file.txt", b"content")
        self.assertIn(b"PK\x06\x06", archive.read_bytes())
        self.assertEqual(self.extract(archive).file_count, 1)

        content = bytearray(archive.read_bytes())
        locator = content.index(b"PK\x06\x07")
        struct.pack_into("<Q", content, locator + 8, 0xFFFFFFFFFFFFFFFF)
        archive.write_bytes(content)
        with mock.patch.object(
            safe_extract_module.zipfile,
            "ZipFile",
            side_effect=AssertionError("ZipFile must not be constructed"),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "offset is invalid"):
                self.extract(
                    archive,
                    destination_name="bad-zip64-offset",
                    source=self.source(archive),
                )

        multi_disk = self.write_zip("multi-disk.zip", [("file.txt", b"content")])
        content = bytearray(multi_disk.read_bytes())
        eocd = content.rfind(b"PK\x05\x06")
        struct.pack_into("<H", content, eocd + 4, 1)
        multi_disk.write_bytes(content)
        with self.assertRaisesRegex(SafeExtractionError, "multi-disk"):
            self.extract(
                multi_disk,
                destination_name="multi-disk-out",
                source=self.source(multi_disk),
            )

    def test_rejects_a_later_fake_end_record_before_constructing_zipfile(self) -> None:
        archive = self.root / "fake-end-record.zip"
        fake = (
            b"prefix"
            + struct.pack(
                "<4s4H2LH",
                b"PK\x05\x06",
                0,
                0,
                0,
                0,
                0xFFFFFFFF,
                0,
                7,
            )
            + b"x"
        )
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as zipped:
            zipped.writestr("file.txt", b"content")
            zipped.comment = fake

        with mock.patch.object(
            safe_extract_module.zipfile,
            "ZipFile",
            side_effect=AssertionError("ZipFile must not be constructed"),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "canonical end record"):
                self.extract(archive, destination_name="fake-end-record-out")

    def test_rejects_nonportable_or_noncanonical_member_paths(self) -> None:
        unsafe = (
            "../escape.txt",
            "/absolute.txt",
            "C:/drive.txt",
            "con.txt",
            "trailing./file.txt",
            "bad\x01name.txt",
            "e\u0301.txt",
        )
        for index, name in enumerate(unsafe):
            with self.subTest(name=name):
                archive = self.write_zip(f"unsafe-{index}.zip", [(name, b"x")])
                with self.assertRaisesRegex(SafeExtractionError, "unsafe ZIP"):
                    self.extract(archive, destination_name=f"output-{index}")
                self.assertFalse((self.root / f"output-{index}").exists())

        backslash = self.write_zip(
            "raw-backslash.zip",
            [("folder/windows.txt", b"x")],
        )
        self.replace_member_name_byte(backslash, ord("/"), ord("\\"))
        with self.assertRaisesRegex(SafeExtractionError, "unsafe ZIP"):
            self.extract(backslash, destination_name="raw-backslash-out")

    def test_rejects_duplicate_case_compatibility_and_prefix_collisions(self) -> None:
        member_sets = (
            (("same.txt", b"a"), ("same.txt", b"b")),
            (("A.txt", b"a"), ("a.txt", b"b")),
            (("1.txt", b"a"), ("①.txt", b"b")),
            (("parent", b"a"), ("parent/child.txt", b"b")),
            (("Dir/a.txt", b"a"), ("dir/b.txt", b"b")),
        )
        for index, members in enumerate(member_sets):
            with self.subTest(index=index):
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive = self.write_zip(
                        f"collision-{index}.zip",
                        list(members),
                    )
                with self.assertRaisesRegex(
                    SafeExtractionError,
                    "collide|both a file|parent directory",
                ):
                    self.extract(archive, destination_name=f"collision-{index}")

    def test_rejects_links_special_files_and_reparse_metadata(self) -> None:
        entries: list[zipfile.ZipInfo] = []
        for index, mode in enumerate((stat.S_IFLNK, stat.S_IFIFO)):
            info = zipfile.ZipInfo(f"special-{index}")
            info.create_system = 3
            info.external_attr = (mode | 0o600) << 16
            entries.append(info)
        reparse = zipfile.ZipInfo("reparse.txt")
        reparse.external_attr = ((stat.S_IFREG | 0o600) << 16) | 0x400
        entries.append(reparse)

        for index, info in enumerate(entries):
            with self.subTest(filename=info.filename):
                archive = self.write_zip(
                    f"special-{index}.zip",
                    [(info, b"target")],
                )
                with self.assertRaisesRegex(
                    SafeExtractionError,
                    "special file|reparse point",
                ):
                    self.extract(archive, destination_name=f"special-out-{index}")

    def test_rejects_encrypted_and_unsupported_compression_headers(self) -> None:
        encrypted = self.write_zip(
            "encrypted.zip",
            [("file.txt", b"content")],
            compression=zipfile.ZIP_STORED,
        )
        self.mutate_headers(encrypted, flag_or=0x1)
        with self.assertRaisesRegex(SafeExtractionError, "encrypted"):
            self.extract(encrypted, destination_name="encrypted-out")

        unsupported = self.write_zip(
            "unsupported.zip",
            [("file.txt", b"content")],
            compression=zipfile.ZIP_STORED,
        )
        self.mutate_headers(unsupported, compression_method=99)
        with self.assertRaisesRegex(SafeExtractionError, "unsupported"):
            self.extract(unsupported, destination_name="unsupported-out")

        for method in (zipfile.ZIP_BZIP2, zipfile.ZIP_LZMA):
            with self.subTest(method=method):
                archive = self.write_zip(
                    f"high-memory-method-{method}.zip",
                    [("file.txt", b"content")],
                    compression=method,
                )
                with self.assertRaisesRegex(SafeExtractionError, "unsupported"):
                    self.extract(
                        archive,
                        destination_name=f"high-memory-method-{method}-out",
                    )

    def test_enforces_member_total_ratio_and_free_space_limits(self) -> None:
        two_files = self.write_zip(
            "two.zip",
            [("a", b"1234"), ("b", b"5678")],
        )
        cases = (
            self.limits(max_members=1),
            self.limits(max_member_uncompressed_bytes=3),
            self.limits(
                max_total_uncompressed_bytes=7,
                max_member_uncompressed_bytes=7,
            ),
        )
        for index, limits in enumerate(cases):
            with self.subTest(index=index):
                with self.assertRaisesRegex(SafeExtractionError, "limit|ceiling"):
                    self.extract(
                        two_files,
                        destination_name=f"limited-{index}",
                        limits=limits,
                    )

        compressed = self.write_zip(
            "ratio.zip",
            [("zeros.bin", b"0" * 20_000)],
        )
        with self.assertRaisesRegex(SafeExtractionError, "compression-ratio"):
            self.extract(
                compressed,
                destination_name="ratio-out",
                limits=self.limits(max_compression_ratio=2),
            )

        with mock.patch.object(
            safe_extract_module.shutil,
            "disk_usage",
            return_value=mock.Mock(free=7),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "free space"):
                self.extract(
                    two_files,
                    destination_name="space-out",
                    limits=self.limits(minimum_free_bytes_after=1),
                )

        inode_capacity = mock.Mock(f_files=10_000, f_favail=1_024)
        with mock.patch.object(
            safe_extract_module.os,
            "statvfs",
            return_value=inode_capacity,
            create=True,
        ):
            with self.assertRaisesRegex(SafeExtractionError, "free inodes"):
                self.extract(two_files, destination_name="inode-out")

        enough_inodes = mock.Mock(f_files=10_000, f_favail=10_000)
        exhausted_inodes = mock.Mock(f_files=10_000, f_favail=1_023)
        with mock.patch.object(
            safe_extract_module.os,
            "statvfs",
            side_effect=(enough_inodes, exhausted_inodes),
            create=True,
        ):
            with self.assertRaisesRegex(SafeExtractionError, "free-inode reserve"):
                self.extract(two_files, destination_name="post-inode-out")
        self.assertFalse((self.root / "post-inode-out").exists())

        with mock.patch.object(
            safe_extract_module.shutil,
            "disk_usage",
            side_effect=(mock.Mock(free=10_000_000), mock.Mock(free=0)),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "free-space reserve"):
                self.extract(two_files, destination_name="post-space-out")
        self.assertFalse((self.root / "post-space-out").exists())

    def test_capacity_accounts_for_root_and_implicit_directories(self) -> None:
        archive = self.write_zip(
            "implicit-directories.zip",
            [("first/second/file.txt", b"content")],
        )
        original = safe_extract_module._require_disk_capacity
        with mock.patch.object(
            safe_extract_module,
            "_require_disk_capacity",
            wraps=original,
        ) as capacity:
            result = self.extract(archive)

        self.assertEqual(result.file_count, 1)
        self.assertEqual(result.directory_count, 2)
        self.assertEqual(capacity.call_args.args[2], 4)

    def test_limits_are_strictly_typed_and_internally_consistent(self) -> None:
        invalid = (
            {"max_members": 0},
            {"max_central_directory_bytes": 0},
            {"max_total_uncompressed_bytes": -1},
            {"max_member_uncompressed_bytes": True},
            {"max_compression_ratio": 0},
            {"minimum_free_bytes_after": 0},
            {"minimum_free_bytes_after": -1},
            {
                "max_total_uncompressed_bytes": 5,
                "max_member_uncompressed_bytes": 6,
            },
        )
        for overrides in invalid:
            with self.subTest(overrides=overrides):
                with self.assertRaises(SafeExtractionError):
                    self.limits(**overrides)

    def test_rejects_wrong_name_hash_eligibility_and_linked_archives(self) -> None:
        archive = self.write_zip("reviewed.zip", [("file", b"content")])
        with self.assertRaisesRegex(SafeExtractionError, "leaf name"):
            self.extract(
                archive,
                destination_name="wrong-name",
                source=self.source(archive, filename="publisher.zip"),
            )

        wrong_hash = replace(self.source(archive), sha256="0" * 64)
        with self.assertRaisesRegex(SafeExtractionError, "SHA-256"):
            self.extract(
                archive,
                destination_name="wrong-hash",
                source=wrong_hash,
            )

        conditional = self.source(archive, eligibility=Eligibility.CONDITIONAL)
        with self.assertRaisesRegex(SafeExtractionError, "not production"):
            self.extract(
                archive,
                destination_name="conditional-rejected",
                source=conditional,
            )
        result = self.extract(
            archive,
            destination_name="conditional-quarantine",
            source=conditional,
            require_production=False,
        )
        self.assertEqual(result.file_count, 1)

        excluded = self.source(archive, eligibility=Eligibility.EXCLUDED)
        with self.assertRaisesRegex(SafeExtractionError, "excluded"):
            self.extract(
                archive,
                destination_name="excluded",
                source=excluded,
                require_production=False,
            )

        hardlink = self.root / "linked.zip"
        try:
            os.link(archive, hardlink)
        except OSError:
            self.skipTest("hardlinks are unavailable")
        with self.assertRaisesRegex(SafeExtractionError, "unlinked regular file"):
            self.extract(
                hardlink,
                destination_name="linked-out",
                source=self.source(hardlink),
            )

    def test_crc_or_post_extraction_archive_failure_leaves_no_output(self) -> None:
        corrupt = self.write_zip(
            "corrupt.zip",
            [("file.txt", b"content")],
            compression=zipfile.ZIP_STORED,
        )
        content = bytearray(corrupt.read_bytes())
        name_length = struct.unpack_from("<H", content, 26)[0]
        extra_length = struct.unpack_from("<H", content, 28)[0]
        data_offset = 30 + name_length + extra_length
        content[data_offset] ^= 0xFF
        corrupt.write_bytes(content)
        with self.assertRaisesRegex(SafeExtractionError, "CRC|extraction failed"):
            self.extract(corrupt, destination_name="corrupt-out")
        self.assertFalse((self.root / "corrupt-out").exists())
        self.assertEqual(list(self.root.glob(".rosid-extract-*")), [])

        stable = self.write_zip("stable.zip", [("file.txt", b"content")])
        original_hash = safe_extract_module._hash_open_file
        calls = 0

        def changed_on_confirmation(source):
            nonlocal calls
            calls += 1
            digest, size = original_hash(source)
            return ("0" * 64, size) if calls == 2 else (digest, size)

        with mock.patch.object(
            safe_extract_module,
            "_hash_open_file",
            side_effect=changed_on_confirmation,
        ):
            with self.assertRaisesRegex(SafeExtractionError, "changed"):
                self.extract(stable, destination_name="changed-out")
        self.assertFalse((self.root / "changed-out").exists())
        self.assertEqual(list(self.root.glob(".rosid-extract-*")), [])

    def test_malformed_deflate_is_a_controlled_failure_with_no_output(self) -> None:
        archive = self.write_zip(
            "bad-deflate.zip",
            [("file.txt", b"content" * 100)],
            compression=zipfile.ZIP_DEFLATED,
        )
        content = bytearray(archive.read_bytes())
        name_length = struct.unpack_from("<H", content, 26)[0]
        extra_length = struct.unpack_from("<H", content, 28)[0]
        data_offset = 30 + name_length + extra_length
        content[data_offset] = (content[data_offset] & ~0x06) | 0x06
        archive.write_bytes(content)

        with self.assertRaisesRegex(SafeExtractionError, "extraction failed"):
            self.extract(archive, destination_name="bad-deflate-out")
        self.assertFalse((self.root / "bad-deflate-out").exists())

    def test_post_seal_failure_restores_permissions_and_removes_output(self) -> None:
        archive = self.write_zip("post-seal.zip", [("file.txt", b"content")])
        original = safe_extract_module.DirectoryInventory.verify_directory
        calls = 0

        def fail_second_verification(inventory, root):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError("post-seal verification rejected")
            return original(inventory, root)

        with mock.patch.object(
            safe_extract_module.DirectoryInventory,
            "verify_directory",
            new=fail_second_verification,
        ):
            with self.assertRaisesRegex(SafeExtractionError, "safe ZIP extraction"):
                self.extract(archive, destination_name="post-seal-out")
        self.assertFalse((self.root / "post-seal-out").exists())

    def test_target_identity_mismatch_refuses_success_and_cleans_output(self) -> None:
        archive = self.write_zip("identity.zip", [("file.txt", b"content")])
        original = safe_extract_module._same_directory_object
        calls = 0

        def mismatch_target_once(first, second):
            nonlocal calls
            calls += 1
            if calls == 2:
                return False
            return original(first, second)

        with mock.patch.object(
            safe_extract_module,
            "_same_directory_object",
            side_effect=mismatch_target_once,
        ):
            with self.assertRaisesRegex(SafeExtractionError, "target or its parent"):
                self.extract(archive, destination_name="identity-out")
        self.assertFalse((self.root / "identity-out").exists())

    def test_cleanup_failure_is_surfaced_and_does_not_claim_success(self) -> None:
        archive = self.write_zip("cleanup.zip", [("file.txt", b"content")])
        original_hash = safe_extract_module._hash_open_file
        calls = 0

        def changed_on_confirmation(source):
            nonlocal calls
            calls += 1
            digest, size = original_hash(source)
            return ("0" * 64, size) if calls == 2 else (digest, size)

        target = self.root / "cleanup-out"
        with (
            mock.patch.object(
                safe_extract_module,
                "_hash_open_file",
                side_effect=changed_on_confirmation,
            ),
            mock.patch.object(
                safe_extract_module.shutil,
                "rmtree",
                side_effect=OSError("cleanup denied"),
            ),
        ):
            with self.assertRaisesRegex(SafeExtractionError, "residue remains"):
                self.extract(archive, destination_name=target.name)
        self.assertTrue(target.exists())
        safe_extract_module.shutil.rmtree(target)

    def test_cli_requires_tracked_manifest_and_ignored_private_paths(self) -> None:
        repository = self.root / "repository"
        repository.mkdir()
        self.run_git(repository, "init")
        self.run_git(repository, "config", "user.email", "tests@example.test")
        self.run_git(repository, "config", "user.name", "Tests")
        (repository / ".gitignore").write_bytes(b"/ml/data/\n/ml/manifests/private/\n")
        archive = repository / "ml/data/raw/fixture/1/fixture.zip"
        archive.parent.mkdir(parents=True)
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr("receipt.txt", "মোট".encode())
        source = self.source(archive)
        manifest = repository / "ml/manifests/datasets/fixture.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_bytes(source.canonical_bytes())
        self.run_git(repository, "add", ".gitignore", str(manifest))
        self.run_git(repository, "commit", "-m", "fixture")

        arguments = [
            str(manifest),
            str(archive),
            "ml/data/external/fixture/1",
            "--max-members",
            "10",
            "--max-central-directory-bytes",
            "10000",
            "--max-total-bytes",
            "1000",
            "--max-member-bytes",
            "1000",
            "--max-compression-ratio",
            "100",
            "--minimum-free-bytes-after",
            "1",
        ]
        previous = Path.cwd()
        output = io.StringIO()
        try:
            os.chdir(repository)
            with contextlib.redirect_stdout(output):
                code = extract_main(arguments)
        finally:
            os.chdir(previous)

        self.assertEqual(code, 0)
        result = json.loads(output.getvalue())
        self.assertTrue(result["written"])
        self.assertEqual(result["extractor"], "rosid-safe-zip/1")
        self.assertEqual(result["eligibility_mode"], "production_only")
        self.assertEqual(result["source_eligibility"], "production")
        self.assertEqual(result["limits"]["max_members"], 10)
        self.assertEqual(result["source_manifest_sha256"], source.commitment_sha256)
        self.assertEqual(result["file_count"], 1)
        self.assertNotIn(str(repository), output.getvalue())
        self.assertEqual(
            (repository / "ml/data/external/fixture/1/receipt.txt").read_text("utf-8"),
            "মোট",
        )

    def test_cli_failure_does_not_disclose_private_paths(self) -> None:
        private_member = "private/member-name.txt"
        private_root = self.root / "private-workstation"
        private_detail = f"{private_root}/{private_member}"
        diagnostic_output = io.StringIO()
        arguments = [
            "source.json",
            "archive.zip",
            "destination",
            "--max-members",
            "10",
            "--max-central-directory-bytes",
            "10000",
            "--max-total-bytes",
            "1000",
            "--max-member-bytes",
            "1000",
            "--max-compression-ratio",
            "100",
            "--minimum-free-bytes-after",
            "1",
        ]
        with (
            mock.patch(
                "ml.extract_dataset.require_git_worktree",
                side_effect=SafeExtractionError(private_detail),
            ),
            contextlib.redirect_stderr(diagnostic_output),
        ):
            with self.assertRaises(SystemExit) as raised:
                extract_main(arguments)

        self.assertEqual(raised.exception.code, 2)
        self.assertIsInstance(raised.exception.__cause__, SafeExtractionError)
        diagnostic = diagnostic_output.getvalue()
        self.assertIn("private verification boundary", diagnostic)
        self.assertNotIn(str(private_root), diagnostic)
        self.assertNotIn(private_member, diagnostic)

    def test_repository_private_artifact_roots_are_actually_ignored(self) -> None:
        repository = Path(__file__).resolve().parents[2]
        paths = (
            "ml/data/raw/dataset/archive.zip",
            "ml/checkpoints/run/model.keras",
            "ml/artifacts/run/model.tflite",
            "ml/manifests/private/key.bin",
        )
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "--", *paths],
            cwd=repository,
            capture_output=True,
            check=False,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(result.stdout.splitlines()), set(paths))

    @staticmethod
    def mutate_headers(
        archive: Path,
        *,
        flag_or: int = 0,
        compression_method: int | None = None,
    ) -> None:
        content = bytearray(archive.read_bytes())
        local = content.index(b"PK\x03\x04")
        central = content.index(b"PK\x01\x02")
        if flag_or:
            struct.pack_into(
                "<H",
                content,
                local + 6,
                struct.unpack_from("<H", content, local + 6)[0] | flag_or,
            )
            struct.pack_into(
                "<H",
                content,
                central + 8,
                struct.unpack_from("<H", content, central + 8)[0] | flag_or,
            )
        if compression_method is not None:
            struct.pack_into("<H", content, local + 8, compression_method)
            struct.pack_into("<H", content, central + 10, compression_method)
        archive.write_bytes(content)

    @staticmethod
    def replace_member_name_byte(archive: Path, old: int, new: int) -> None:
        content = bytearray(archive.read_bytes())
        local = content.index(b"PK\x03\x04")
        central = content.index(b"PK\x01\x02")
        local_name_length = struct.unpack_from("<H", content, local + 26)[0]
        central_name_length = struct.unpack_from("<H", content, central + 28)[0]
        local_name = slice(local + 30, local + 30 + local_name_length)
        central_name = slice(central + 46, central + 46 + central_name_length)
        for area in (local_name, central_name):
            name = bytes(content[area])
            replaced = name.replace(bytes((old,)), bytes((new,)), 1)
            if replaced == name:
                raise AssertionError("requested member-name byte was absent")
            content[area] = replaced
        archive.write_bytes(content)

    @staticmethod
    def run_git(repository: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["git", *arguments],
            cwd=repository,
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout)
        return result


if __name__ == "__main__":
    unittest.main()
