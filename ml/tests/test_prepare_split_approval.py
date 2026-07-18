from __future__ import annotations

import contextlib
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from ml.prepare_split_approval import main as prepare_split_approval_main
from ml.rosid_ml.code_bundles import (
    REQUIRED_CORE_CODE_ROLES,
    CodeBundleManifest,
    CodeRole,
)
from ml.rosid_ml.split_manifests import SplitConfig
from ml.tests.code_bundle_fixtures import write_p1_code_fixture


class PrepareSplitApprovalTest(unittest.TestCase):
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

    def test_prepares_reviewable_config_from_clean_tracked_code(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repository"
            root.mkdir()
            self.run_git(root, "init", "--quiet")
            self.run_git(root, "config", "user.name", "Approval Test")
            self.run_git(
                root,
                "config",
                "user.email",
                "approval-test@example.invalid",
            )
            write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"def adapt():\n    return 2\n")
            unrelated = root / "ml" / "rosid_ml" / "training.py"
            unrelated.write_bytes(b"VALUE = 1\n")
            (root / ".gitattributes").write_bytes(b"* -text\n")
            self.run_git(root, "add", "--", ".gitattributes", "ml")
            self.run_git(root, "commit", "--quiet", "-m", "code")

            output_root = root / "ml" / "manifests" / "splits"
            bundle_path = output_root / "fixture.code.json"
            config_path = output_root / "fixture.config.json"
            stdout = io.StringIO()
            with (
                contextlib.chdir(root),
                contextlib.redirect_stdout(stdout),
            ):
                result = prepare_split_approval_main(
                    [
                        "--adapter-code-file",
                        str(adapter),
                        "--seed-id",
                        "seed-v1",
                        "--key-id",
                        "hmac-v1",
                        "--code-bundle-output",
                        str(bundle_path),
                        "--config-output",
                        str(config_path),
                    ]
                )

            self.assertEqual(result, 0)
            bundle = CodeBundleManifest.from_json_file(bundle_path)
            config = SplitConfig.from_json_file(config_path)
            self.assertEqual(
                {
                    entry.path: entry.role
                    for entry in bundle.files
                },
                {
                    **{
                        path: CodeRole(role)
                        for path, role in REQUIRED_CORE_CODE_ROLES.items()
                    },
                    "ml/rosid_ml/adapters/fixture.py": CodeRole.ADAPTER,
                },
            )
            self.assertNotIn(
                "ml/rosid_ml/training.py",
                {entry.path for entry in bundle.files},
            )
            self.assertEqual(
                config.splitter_code_sha256,
                bundle.commitment_sha256,
            )
            output = json.loads(stdout.getvalue())
            self.assertEqual(
                output["code_bundle_sha256"],
                bundle.commitment_sha256,
            )
            self.assertNotIn(str(root), stdout.getvalue())

            adapter.write_bytes(b"def adapt():\n    return 3\n")
            stderr = io.StringIO()
            with (
                contextlib.chdir(root),
                contextlib.redirect_stderr(stderr),
                self.assertRaises(SystemExit),
            ):
                prepare_split_approval_main(
                    [
                        "--adapter-code-file",
                        str(adapter),
                        "--seed-id",
                        "seed-v2",
                        "--key-id",
                        "hmac-v2",
                        "--code-bundle-output",
                        str(output_root / "dirty.code.json"),
                        "--config-output",
                        str(output_root / "dirty.config.json"),
                    ]
                )
            self.assertIn("unchanged at Git HEAD", stderr.getvalue())

            adapter.write_bytes(b"def adapt():\n    return 2\n")
            reviewed_core = root / "ml" / "rosid_ml" / "provenance.py"
            reviewed_core.write_bytes(reviewed_core.read_bytes() + b"# dirty\n")
            stderr = io.StringIO()
            with (
                contextlib.chdir(root),
                contextlib.redirect_stderr(stderr),
                self.assertRaises(SystemExit),
            ):
                prepare_split_approval_main(
                    [
                        "--adapter-code-file",
                        str(adapter),
                        "--seed-id",
                        "seed-v3",
                        "--key-id",
                        "hmac-v3",
                        "--code-bundle-output",
                        str(output_root / "dirty-core.code.json"),
                        "--config-output",
                        str(output_root / "dirty-core.config.json"),
                    ]
                )
            self.assertIn("unchanged at Git HEAD", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
