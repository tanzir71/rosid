from __future__ import annotations

import os
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from ml.rosid_ml.code_bundles import (
    REQUIRED_CORE_CODE_ROLES,
    CodeBundleManifest,
    CodeFileEntry,
    CodeRole,
    build_code_bundle,
)


class CodeBundleTest(unittest.TestCase):
    def test_exact_closure_rejects_unlisted_core_and_adapter_helpers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core: dict[str, Path] = {}
            for relative in REQUIRED_CORE_CODE_ROLES:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(f"# {relative}\n".encode())
                core[relative] = path
            adapter = (
                root
                / "ml"
                / "rosid_ml"
                / "adapters"
                / "fixture.py"
            )
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"def adapt():\n    return 1\n")

            def bundle_for(*adapters: Path) -> CodeBundleManifest:
                return build_code_bundle(
                    root,
                    splitter_files=tuple(
                        core[path]
                        for path, role in REQUIRED_CORE_CODE_ROLES.items()
                        if role == CodeRole.SPLITTER.value
                    ),
                    adapter_files=adapters,
                    shared_files=tuple(
                        core[path]
                        for path, role in REQUIRED_CORE_CODE_ROLES.items()
                        if role == CodeRole.SHARED.value
                    ),
                )

            bundle = bundle_for(adapter)
            bundle.require_exact_implementation(
                adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                worktree_root=root,
            )

            unlisted_core = root / "ml" / "rosid_ml" / "hidden_helper.py"
            unlisted_core.write_bytes(b"VALUE = 1\n")
            with self.assertRaisesRegex(ValueError, "fixed P1 code closure"):
                bundle.require_exact_implementation(
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                    worktree_root=root,
                )
            unlisted_core.unlink()

            helper = adapter.with_name("helper.py")
            helper.write_bytes(b"VALUE = 2\n")
            with self.assertRaisesRegex(ValueError, "every Python file"):
                bundle.require_exact_implementation(
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                    worktree_root=root,
                )
            complete = bundle_for(adapter, helper)
            complete.require_exact_implementation(
                adapter_paths=(
                    "ml/rosid_ml/adapters/fixture.py",
                    "ml/rosid_ml/adapters/helper.py",
                ),
                worktree_root=root,
            )

    def test_round_trip_binds_splitter_and_adapter_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            splitter = root / "ml" / "splitter.py"
            adapter = root / "ml" / "adapters" / "fixture.py"
            splitter.parent.mkdir(parents=True)
            adapter.parent.mkdir(parents=True)
            splitter.write_bytes(b"def split():\n    return 1\n")
            adapter.write_bytes(b"def adapt():\n    return 2\n")

            bundle = build_code_bundle(
                root,
                splitter_files=(splitter,),
                adapter_files=(adapter,),
            )
            manifest = root / "bundle.json"
            manifest.write_bytes(bundle.canonical_bytes())
            parsed = CodeBundleManifest.from_json_file(manifest)
            parsed.verify_worktree(root)

            self.assertEqual(parsed, bundle)
            self.assertEqual(
                {entry.role for entry in parsed.files},
                {CodeRole.SPLITTER, CodeRole.ADAPTER},
            )
            self.assertNotIn(str(root), bundle.canonical_bytes().decode("utf-8"))

            adapter.write_bytes(b"def adapt():\n    return 3\n")
            with self.assertRaisesRegex(ValueError, "SHA-256 differs"):
                parsed.verify_worktree(root)

    def test_rejects_missing_roles_and_path_collisions(self) -> None:
        splitter = CodeFileEntry(
            path="ml/splitter.py",
            role=CodeRole.SPLITTER,
            bytes=1,
            sha256="0" * 64,
        )
        adapter = CodeFileEntry(
            path="ml/ADAPTER.py",
            role=CodeRole.ADAPTER,
            bytes=1,
            sha256="1" * 64,
        )
        with self.assertRaisesRegex(ValueError, "splitter and adapter"):
            CodeBundleManifest(schema_version=1, files=(splitter,))
        with self.assertRaisesRegex(ValueError, "case folding"):
            CodeBundleManifest(
                schema_version=1,
                files=(
                    replace(splitter, path="ml/ADAPTER.py"),
                    replace(adapter, path="ml/adapter.py"),
                ),
            )

    def test_rejects_linked_code_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            splitter = root / "splitter.py"
            adapter = root / "adapter.py"
            outside = root / "outside.py"
            splitter.write_bytes(b"x")
            outside.write_bytes(b"y")
            try:
                adapter.symlink_to(outside)
            except OSError as error:
                self.skipTest(f"symbolic links unavailable: {error}")
            with self.assertRaisesRegex(ValueError, "link|reparse"):
                build_code_bundle(
                    root,
                    splitter_files=(splitter,),
                    adapter_files=(adapter,),
                )

    def test_rejects_hardlinked_code_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            splitter = root / "splitter.py"
            adapter = root / "adapter.py"
            outside = root / "outside.py"
            splitter.write_bytes(b"x")
            outside.write_bytes(b"y")
            try:
                os.link(outside, adapter)
            except OSError as error:
                self.skipTest(f"hard links unavailable: {error}")
            with self.assertRaisesRegex(ValueError, "unlinked"):
                build_code_bundle(
                    root,
                    splitter_files=(splitter,),
                    adapter_files=(adapter,),
                )


if __name__ == "__main__":
    unittest.main()
