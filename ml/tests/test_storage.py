from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from ml.rosid_ml.storage import (
    find_git_worktree,
    normalize_path,
    path_is_within,
    paths_equal,
    paths_overlap,
    require_complete_git_checkout,
    require_git_worktree,
    require_private_manifest_path,
    require_private_path,
    require_public_acquisition_path,
    require_public_adapter_path,
    require_public_dataset_path,
    require_public_split_path,
    require_tracked_unchanged_path,
)


class StoragePolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        self.run_git(self.repository, "init", "--quiet")
        (self.repository / ".gitignore").write_bytes(
            b"private/\n"
            b"ml/manifests/private/\n"
            b"ml/manifests/acquisitions/ignored.json\n"
        )
        (self.repository / ".gitattributes").write_bytes(b"* -text\n")
        self.run_git(
            self.repository,
            "add",
            "--",
            ".gitattributes",
            ".gitignore",
        )

    @staticmethod
    def run_git(directory: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ("git", *arguments),
            cwd=directory,
            check=True,
            capture_output=True,
            text=True,
            shell=False,
        )

    def test_private_path_must_be_ignored_and_untracked_inside_repository(
        self,
    ) -> None:
        attributes = self.repository / ".gitattributes"
        with self.assertRaisesRegex(ValueError, "untracked"):
            require_private_path(attributes)

        ignored = self.repository / "private" / "seed.key"
        self.assertEqual(require_private_path(ignored), normalize_path(ignored))

        tracked_ignored = self.repository / "private" / "tracked.key"
        tracked_ignored.parent.mkdir()
        tracked_ignored.write_bytes(b"secret")
        self.run_git(self.repository, "add", "--force", "--", "private/tracked.key")
        with self.assertRaisesRegex(ValueError, "untracked"):
            require_private_path(tracked_ignored)

        with self.assertRaisesRegex(ValueError, "Git-ignored"):
            require_private_path(self.repository / "not-private.key")

    def test_private_path_outside_repository_is_allowed(self) -> None:
        outside = self.root / "outside" / "commitment.key"
        self.assertEqual(require_private_path(outside), normalize_path(outside))

    def test_private_manifest_path_uses_fixed_committed_ignore_policy(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        self.run_git(self.repository, "commit", "--quiet", "-m", "policy")
        worktree = require_git_worktree(self.repository)
        private = (
            self.repository
            / "ml"
            / "manifests"
            / "private"
            / "split"
            / "seed.key"
        )
        self.assertEqual(
            require_private_manifest_path(
                private,
                expected_worktree=worktree,
            ),
            normalize_path(private),
        )
        with self.assertRaisesRegex(ValueError, "ml/manifests/private"):
            require_private_manifest_path(
                self.repository / "private" / "seed.key",
                expected_worktree=worktree,
            )
        with self.assertRaisesRegex(ValueError, "ml/manifests/private"):
            require_private_manifest_path(
                self.repository
                / "ml"
                / "manifests"
                / "splits"
                / "hidden.key",
                expected_worktree=worktree,
            )
        outside = self.root / "outside" / "seed.key"
        self.assertEqual(
            require_private_manifest_path(
                outside,
                expected_worktree=worktree,
            ),
            normalize_path(outside),
        )
        (self.repository / ".gitignore").write_bytes(b"private/\n")
        with self.assertRaisesRegex(ValueError, "unchanged at Git HEAD"):
            require_private_manifest_path(
                private,
                expected_worktree=worktree,
            )

    def test_public_paths_use_exact_repository_subtrees_and_are_not_ignored(
        self,
    ) -> None:
        acquisition = (
            self.repository / "ml" / "manifests" / "acquisitions" / "record.json"
        )
        dataset = self.repository / "ml" / "manifests" / "datasets" / "source.json"
        adapter = self.repository / "ml" / "manifests" / "adapters" / "record.json"
        split = self.repository / "ml" / "manifests" / "splits" / "v2.json"
        self.assertEqual(
            require_public_acquisition_path(acquisition),
            normalize_path(acquisition),
        )
        self.assertEqual(require_public_dataset_path(dataset), normalize_path(dataset))
        self.assertEqual(require_public_adapter_path(adapter), normalize_path(adapter))
        self.assertEqual(require_public_split_path(split), normalize_path(split))

        wrong = self.repository / "ml" / "manifests" / "splits" / "record.json"
        with self.assertRaisesRegex(ValueError, "acquisitions"):
            require_public_acquisition_path(wrong)
        with self.assertRaisesRegex(ValueError, "splits"):
            require_public_split_path(acquisition)
        with self.assertRaisesRegex(ValueError, "datasets"):
            require_public_dataset_path(acquisition)
        with self.assertRaisesRegex(ValueError, "adapters"):
            require_public_adapter_path(acquisition)
        with self.assertRaisesRegex(ValueError, "must not be Git-ignored"):
            require_public_acquisition_path(
                self.repository
                / "ml"
                / "manifests"
                / "acquisitions"
                / "ignored.json"
            )

    def test_public_paths_outside_repository_are_allowed(self) -> None:
        outside = self.root / "outside" / "public.json"
        self.assertEqual(
            require_public_acquisition_path(outside),
            normalize_path(outside),
        )
        self.assertEqual(require_public_dataset_path(outside), normalize_path(outside))
        self.assertEqual(require_public_adapter_path(outside), normalize_path(outside))
        self.assertEqual(require_public_split_path(outside), normalize_path(outside))

    def test_expected_worktree_and_tracked_head_are_enforced(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        source = (
            self.repository / "ml" / "manifests" / "datasets" / "source.json"
        )
        source.parent.mkdir(parents=True)
        committed = b'{"fixture":true}\n'
        source.write_bytes(committed)
        self.run_git(
            self.repository,
            "add",
            "--",
            ".gitattributes",
            ".gitignore",
            "ml/manifests/datasets/source.json",
        )
        self.run_git(self.repository, "commit", "--quiet", "-m", "initial")

        worktree = require_git_worktree(self.repository / "future.json")
        self.assertEqual(worktree, normalize_path(self.repository))
        self.assertEqual(
            require_public_dataset_path(source, expected_worktree=worktree),
            normalize_path(source),
        )
        self.assertEqual(
            require_tracked_unchanged_path(source, expected_worktree=worktree),
            normalize_path(source),
        )
        with self.assertRaisesRegex(ValueError, "parsed public input bytes"):
            require_tracked_unchanged_path(
                source,
                expected_worktree=worktree,
                expected_bytes=b'{"fixture":false}\n',
            )
        output = (
            self.repository
            / "ml"
            / "manifests"
            / "acquisitions"
            / "future.json"
        )
        self.assertEqual(
            require_public_acquisition_path(
                output,
                expected_worktree=worktree,
            ),
            normalize_path(output),
        )

        outside = self.root / "outside" / "source.json"
        with self.assertRaisesRegex(ValueError, "expected Git worktree"):
            require_public_dataset_path(outside, expected_worktree=worktree)

        source.write_bytes(b'{"fixture":false}\n')
        with self.assertRaisesRegex(ValueError, "unchanged at Git HEAD"):
            require_tracked_unchanged_path(source, expected_worktree=worktree)
        source.write_bytes(committed)

        untracked = source.with_name("untracked.json")
        untracked.write_bytes(committed)
        require_public_dataset_path(untracked, expected_worktree=worktree)
        with self.assertRaisesRegex(ValueError, "tracked by Git"):
            require_tracked_unchanged_path(untracked, expected_worktree=worktree)

        source.write_bytes(b'{"fixture":false}\n')
        self.run_git(
            self.repository,
            "add",
            "--",
            "ml/manifests/datasets/source.json",
        )
        source.write_bytes(committed)
        with self.assertRaisesRegex(ValueError, "unchanged from Git HEAD"):
            require_tracked_unchanged_path(source, expected_worktree=worktree)

    def test_tracked_inputs_require_regular_head_and_index_modes(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        self.run_git(self.repository, "config", "core.symlinks", "false")
        head_link = self.repository / "head-link.json"
        index_link = self.repository / "index-link.json"
        submodule = self.repository / "submodule-entry"
        head_link.write_bytes(b"target.json\n")
        index_link.write_bytes(b"target.json\n")
        submodule.write_bytes(b"materialized submodule text\n")
        self.run_git(self.repository, "add", "--all")
        self.run_git(self.repository, "commit", "--quiet", "-m", "regular files")
        regular_commit = self.run_git(
            self.repository,
            "rev-parse",
            "HEAD",
        ).stdout.strip()
        head_oid = self.run_git(
            self.repository,
            "hash-object",
            "--",
            "head-link.json",
        ).stdout.strip()
        self.run_git(
            self.repository,
            "update-index",
            "--cacheinfo",
            f"120000,{head_oid},head-link.json",
        )
        self.run_git(
            self.repository,
            "update-index",
            "--cacheinfo",
            f"160000,{regular_commit},submodule-entry",
        )
        self.run_git(
            self.repository,
            "commit",
            "--quiet",
            "-m",
            "nonregular modes",
        )

        worktree = require_git_worktree(self.repository)
        self.assertTrue(head_link.is_file())
        with self.assertRaisesRegex(ValueError, "regular Git file mode.*HEAD"):
            require_tracked_unchanged_path(
                head_link,
                expected_worktree=worktree,
            )
        self.assertTrue(submodule.is_file())
        with self.assertRaisesRegex(ValueError, "regular Git file mode.*HEAD"):
            require_tracked_unchanged_path(
                submodule,
                expected_worktree=worktree,
            )

        index_oid = self.run_git(
            self.repository,
            "hash-object",
            "--",
            "index-link.json",
        ).stdout.strip()
        self.run_git(
            self.repository,
            "update-index",
            "--cacheinfo",
            f"120000,{index_oid},index-link.json",
        )
        with self.assertRaisesRegex(ValueError, "regular Git file mode.*index"):
            require_tracked_unchanged_path(
                index_link,
                expected_worktree=worktree,
            )

    def test_complete_checkout_rejects_hidden_and_nonordinary_entries(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        source = self.repository / "tracked.py"
        executable = self.repository / "tool.sh"
        source.write_bytes(b"VALUE = 1\n")
        executable.write_bytes(b"#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        self.run_git(self.repository, "add", "--all")
        self.run_git(self.repository, "update-index", "--chmod=+x", "tool.sh")
        self.run_git(self.repository, "commit", "--quiet", "-m", "complete")
        worktree = require_git_worktree(self.repository)
        self.assertEqual(require_complete_git_checkout(worktree), worktree)
        self.assertEqual(
            require_tracked_unchanged_path(
                executable,
                expected_worktree=worktree,
            ),
            normalize_path(executable),
        )

        self.run_git(
            self.repository,
            "update-index",
            "--assume-unchanged",
            "tracked.py",
        )
        with self.assertRaisesRegex(ValueError, "ordinary stage-0"):
            require_complete_git_checkout(worktree)
        self.run_git(
            self.repository,
            "update-index",
            "--no-assume-unchanged",
            "tracked.py",
        )

        self.run_git(
            self.repository,
            "update-index",
            "--skip-worktree",
            "tracked.py",
        )
        with self.assertRaisesRegex(ValueError, "ordinary stage-0"):
            require_tracked_unchanged_path(
                source,
                expected_worktree=worktree,
            )
        source.unlink()
        with self.assertRaisesRegex(ValueError, "ordinary stage-0"):
            require_complete_git_checkout(worktree)

    def test_complete_checkout_rejects_real_sparse_exclusion(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        included = self.repository / "included" / "keep.py"
        excluded = self.repository / "excluded" / "hidden.py"
        included.parent.mkdir()
        excluded.parent.mkdir()
        included.write_bytes(b"KEEP = True\n")
        excluded.write_bytes(b"HIDDEN = True\n")
        self.run_git(self.repository, "add", "--all")
        self.run_git(self.repository, "commit", "--quiet", "-m", "sparse tree")
        self.run_git(self.repository, "sparse-checkout", "init", "--cone")
        self.run_git(self.repository, "sparse-checkout", "set", "included")
        self.assertFalse(excluded.exists())
        worktree = require_git_worktree(self.repository)
        with self.assertRaises(ValueError):
            require_tracked_unchanged_path(
                excluded,
                expected_worktree=worktree,
            )
        with self.assertRaisesRegex(ValueError, "ordinary stage-0"):
            require_complete_git_checkout(worktree)

    def test_complete_checkout_rejects_unmerged_index_stages(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        source = self.repository / "conflict.py"
        source.write_bytes(b"VALUE = 1\n")
        self.run_git(self.repository, "add", "--all")
        self.run_git(self.repository, "commit", "--quiet", "-m", "conflict base")
        base_branch = self.run_git(
            self.repository,
            "branch",
            "--show-current",
        ).stdout.strip()
        self.run_git(self.repository, "switch", "--quiet", "-c", "other")
        source.write_bytes(b"VALUE = 2\n")
        self.run_git(self.repository, "add", "conflict.py")
        self.run_git(self.repository, "commit", "--quiet", "-m", "other")
        self.run_git(self.repository, "switch", "--quiet", base_branch)
        source.write_bytes(b"VALUE = 3\n")
        self.run_git(self.repository, "add", "conflict.py")
        self.run_git(self.repository, "commit", "--quiet", "-m", "ours")
        merge = subprocess.run(
            ("git", "merge", "--no-edit", "other"),
            cwd=self.repository,
            check=False,
            capture_output=True,
            text=True,
            shell=False,
        )
        self.assertNotEqual(merge.returncode, 0)
        worktree = require_git_worktree(self.repository)
        self.assertIn(
            "conflict.py",
            self.run_git(
                self.repository,
                "ls-files",
                "--unmerged",
            ).stdout,
        )
        with self.assertRaises(ValueError):
            require_complete_git_checkout(worktree)
        with self.assertRaises(ValueError):
            require_tracked_unchanged_path(
                source,
                expected_worktree=worktree,
            )

    def test_complete_checkout_rejects_casefolded_directory_aliases(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        upper = self.repository / "Pkg"
        lower = self.repository / "pkg"
        upper.mkdir()
        lower.mkdir(exist_ok=True)
        initializer = upper / "__init__.py"
        child = lower / "sub.py"
        initializer.write_bytes(b"VALUE = 1\n")
        child.write_bytes(b"VALUE = 2\n")
        initializer_oid = self.run_git(
            self.repository,
            "hash-object",
            "-w",
            "--",
            "Pkg/__init__.py",
        ).stdout.strip()
        child_oid = self.run_git(
            self.repository,
            "hash-object",
            "-w",
            "--",
            "pkg/sub.py",
        ).stdout.strip()
        self.run_git(
            self.repository,
            "update-index",
            "--add",
            "--cacheinfo",
            f"100644,{initializer_oid},Pkg/__init__.py",
        )
        self.run_git(
            self.repository,
            "update-index",
            "--add",
            "--cacheinfo",
            f"100644,{child_oid},pkg/sub.py",
        )
        self.run_git(self.repository, "add", ".gitattributes", ".gitignore")
        self.run_git(self.repository, "commit", "--quiet", "-m", "case aliases")
        with self.assertRaisesRegex(ValueError, "collide"):
            require_complete_git_checkout(self.repository)

    def test_path_relationship_helpers_cover_nonexisting_paths(self) -> None:
        parent = self.repository / "does-not-exist"
        child = parent / "nested" / "artifact.json"
        peer = self.repository / "elsewhere" / "artifact.json"
        self.assertTrue(paths_equal(child, parent / "nested" / "artifact.json"))
        self.assertTrue(path_is_within(child, parent))
        self.assertTrue(paths_overlap(parent, child))
        self.assertFalse(paths_overlap(child, peer))
        self.assertFalse(path_is_within(parent, child))

    def test_existing_symbolic_link_component_is_rejected_when_supported(
        self,
    ) -> None:
        target = self.root / "target"
        target.mkdir()
        link = self.root / "link"
        try:
            link.symlink_to(target, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"symbolic links are unavailable: {error}")
        with self.assertRaisesRegex(ValueError, "link or reparse point"):
            normalize_path(link / "private.key")

    def test_linked_worktree_git_file_is_discovered(self) -> None:
        self.run_git(self.repository, "config", "user.name", "Storage Test")
        self.run_git(
            self.repository,
            "config",
            "user.email",
            "storage-test@example.invalid",
        )
        self.run_git(self.repository, "commit", "--quiet", "-m", "initial")
        linked = self.root / "linked"
        self.run_git(
            self.repository,
            "worktree",
            "add",
            "--quiet",
            "--detach",
            str(linked),
            "HEAD",
        )
        self.addCleanup(
            lambda: self.run_git(
                self.repository,
                "worktree",
                "remove",
                "--force",
                str(linked),
            )
            if linked.exists()
            else None
        )

        self.assertTrue((linked / ".git").is_file())
        self.assertEqual(
            find_git_worktree(linked / "future.bin"),
            normalize_path(linked),
        )


if __name__ == "__main__":
    unittest.main()
