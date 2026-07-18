from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from ml.rosid_ml.code_bundles import (
    P1_ENTRYPOINT_CODE_ROLES,
    REQUIRED_CORE_CODE_ROLES,
    CodeBundleManifest,
    CodeFileEntry,
    CodeRole,
    build_code_bundle,
    discover_p1_implementation_paths,
)
from ml.tests.code_bundle_fixtures import (
    build_p1_code_fixture_bundle,
    write_p1_code_fixture,
)


class CodeBundleTest(unittest.TestCase):
    def test_exact_closure_ignores_unrelated_and_rejects_reachable_code(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"def adapt():\n    return 1\n")

            def bundle_for(*adapters: Path) -> CodeBundleManifest:
                return build_p1_code_fixture_bundle(
                    root,
                    core_files=core,
                    adapter_files=adapters,
                )

            bundle = bundle_for(adapter)
            bundle.require_exact_implementation(
                adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                worktree_root=root,
            )

            future_training = root / "ml" / "rosid_ml" / "training.py"
            future_training.write_bytes(b"VALUE = 1\n")
            bundle.require_exact_implementation(
                adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                worktree_root=root,
            )

            bridge = core["ml/build_split_manifest.py"]
            original_bridge = bridge.read_bytes()
            metrics_import = b"import ml.rosid_ml.metrics\n"
            self.assertIn(metrics_import, original_bridge)
            bridge.write_bytes(original_bridge.replace(metrics_import, b""))
            with self.assertRaisesRegex(ValueError, "stale=.*metrics.py"):
                bundle.require_exact_implementation(
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                    worktree_root=root,
                )

            bridge.write_bytes(original_bridge + b"import ml.rosid_ml.training\n")
            with self.assertRaisesRegex(ValueError, "transitive local-import graph"):
                bundle.require_exact_implementation(
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                    worktree_root=root,
                )
            bridge.write_bytes(original_bridge)

            adapter.write_bytes(
                b"import ml.rosid_ml.training\n\ndef adapt():\n    return 1\n"
            )
            with self.assertRaisesRegex(ValueError, "transitive local-import graph"):
                bundle.require_exact_implementation(
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                    worktree_root=root,
                )
            adapter.write_bytes(b"def adapt():\n    return 1\n")

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

            missing_bundle = CodeBundleManifest(
                schema_version=1,
                files=tuple(
                    entry
                    for entry in complete.files
                    if entry.path != "ml/rosid_ml/metrics.py"
                ),
            )
            with self.assertRaisesRegex(ValueError, "missing=.*metrics.py"):
                missing_bundle.require_exact_implementation(
                    adapter_paths=(
                        "ml/rosid_ml/adapters/fixture.py",
                        "ml/rosid_ml/adapters/helper.py",
                    ),
                    worktree_root=root,
                )

            wrong_role_bundle = CodeBundleManifest(
                schema_version=1,
                files=tuple(
                    replace(entry, role=CodeRole.SHARED)
                    if entry.path == "ml/rosid_ml/splits.py"
                    else entry
                    for entry in complete.files
                ),
            )
            with self.assertRaisesRegex(ValueError, "wrong_roles=.*splits.py"):
                wrong_role_bundle.require_exact_implementation(
                    adapter_paths=(
                        "ml/rosid_ml/adapters/fixture.py",
                        "ml/rosid_ml/adapters/helper.py",
                    ),
                    worktree_root=root,
                )

            with self.assertRaisesRegex(ValueError, "must be unique"):
                complete.require_exact_implementation(
                    adapter_paths=(
                        "ml/rosid_ml/adapters/fixture.py",
                        "ml/rosid_ml/adapters/fixture.py",
                    ),
                    worktree_root=root,
                )

            extra_bundle = build_code_bundle(
                root,
                splitter_files=tuple(
                    core[path]
                    for path, role in REQUIRED_CORE_CODE_ROLES.items()
                    if role == CodeRole.SPLITTER.value
                ),
                adapter_files=(adapter, helper),
                shared_files=(
                    *(
                        core[path]
                        for path, role in REQUIRED_CORE_CODE_ROLES.items()
                        if role == CodeRole.SHARED.value
                    ),
                    future_training,
                ),
            )
            with self.assertRaisesRegex(ValueError, "exact P1 implementation"):
                extra_bundle.require_exact_implementation(
                    adapter_paths=(
                        "ml/rosid_ml/adapters/fixture.py",
                        "ml/rosid_ml/adapters/helper.py",
                    ),
                    worktree_root=root,
                )

    def test_discovery_follows_relative_namespace_imports_and_cycles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            support = root / "support"
            support.mkdir()
            (support / "__init__.py").write_bytes(b"VALUE = 0\n")
            (support / "helpers.py").write_bytes(b"from . import leaf\n")
            (support / "leaf.py").write_bytes(b"from . import helpers\nVALUE = 2\n")
            unrelated = root / "future.py"
            unrelated.write_bytes(b"this is not valid Python !\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"from support import helpers\n")

            found = discover_p1_implementation_paths(
                root,
                adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
            )

            self.assertIn("support/helpers.py", found)
            self.assertIn("support/leaf.py", found)
            self.assertIn("support/__init__.py", found)
            self.assertNotIn("future.py", found)
            self.assertEqual(len(found), len(set(found)))
            self.assertEqual(found, tuple(sorted(found, key=lambda x: x.encode())))

            bridge.write_bytes(bridge.read_bytes() + b"import future\n")
            with self.assertRaisesRegex(ValueError, "cannot parse P1 Python code"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_unresolved_and_case_mismatched_local_imports(
        self,
    ) -> None:
        cases = (
            (b"import ml.rosid_ml.missing\n", "cannot resolve local Python import"),
            (b"import ml.rosid_ml.training\n", "differs only by case"),
            (b"import ML.rosid_ml.metrics\n", "differs only by case"),
        )
        for import_line, message in cases:
            with self.subTest(import_line=import_line):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    core = write_p1_code_fixture(root)
                    adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
                    adapter.parent.mkdir(parents=True)
                    adapter.write_bytes(b"VALUE = 1\n")
                    (root / "ml" / "rosid_ml" / "Training.py").write_bytes(
                        b"VALUE = 2\n"
                    )
                    bridge = core["ml/build_split_manifest.py"]
                    bridge.write_bytes(bridge.read_bytes() + import_line)
                    with self.assertRaisesRegex(ValueError, message):
                        discover_p1_implementation_paths(
                            root,
                            adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                        )

    def test_discovery_rejects_ambiguous_module_and_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            ambiguous_module = root / "ambiguous.py"
            ambiguous_package = root / "ambiguous" / "__init__.py"
            ambiguous_module.write_bytes(b"VALUE = 1\n")
            ambiguous_package.parent.mkdir()
            ambiguous_package.write_bytes(b"VALUE = 2\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"import ambiguous\n")

            with self.assertRaisesRegex(ValueError, "module is ambiguous"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            (root / "plain.py").write_bytes(b"VALUE = 1\n")
            plain_directory = root / "plain"
            plain_directory.mkdir()
            (plain_directory / "child.py").write_bytes(b"VALUE = 2\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"import plain.child\n")

            with self.assertRaisesRegex(ValueError, "non-package module"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_unprovable_local_import_sources(self) -> None:
        sources = (
            ("build/hidden.py", b"import build.hidden\n", "generated"),
            ("bytecode_only.pyc", b"import bytecode_only\n", "bytecode-only"),
            ("windows_source.pyw", b"import windows_source\n", "source bundle"),
            (
                "ml/upperpkg/__INIT__.PY",
                b"import ml.upperpkg\n",
                "source bundle",
            ),
            (
                "ml/upperpkg_lower_ext/__INIT__.py",
                b"import ml.upperpkg_lower_ext\n",
                "source bundle",
            ),
        )
        for relative, import_line, message in sources:
            with self.subTest(relative=relative):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    core = write_p1_code_fixture(root)
                    adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
                    adapter.parent.mkdir(parents=True)
                    adapter.write_bytes(b"VALUE = 1\n")
                    unprovable = root / relative
                    unprovable.parent.mkdir(parents=True, exist_ok=True)
                    unprovable.write_bytes(b"not approved source\n")
                    bridge = core["ml/build_split_manifest.py"]
                    bridge.write_bytes(bridge.read_bytes() + import_line)

                    with self.assertRaisesRegex(ValueError, message):
                        discover_p1_implementation_paths(
                            root,
                            adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                        )

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            generated = root / "ml" / "rosid_ml" / "build" / "__init__.py"
            generated.parent.mkdir()
            generated.write_bytes(b"VALUE = 99\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"from ml.rosid_ml import build\n")

            with self.assertRaisesRegex(ValueError, "source bundle"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    @unittest.skipIf(os.name == "nt", "Windows cannot create reserved con.py")
    def test_discovery_rejects_importable_nonportable_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            (root / "con.py").write_bytes(b"VALUE = 2\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"import con\n")

            with self.assertRaisesRegex(ValueError, "nonportable"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_normalization_equivalent_nonportable_source(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            (root / "e\N{COMBINING ACUTE ACCENT}.py").write_bytes(b"VALUE = 2\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + "import é\n".encode())

            with self.assertRaisesRegex(ValueError, "Unicode normalization"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_linked_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            target = root / "target_payload"
            target.mkdir()
            (target / "__init__.py").write_bytes(b"VALUE = 1\n")
            (target / "helper.py").write_bytes(b"VALUE = 2\n")
            linked = root / "linked_payload"
            try:
                linked.symlink_to(target, target_is_directory=True)
            except OSError as error:
                self.skipTest(f"directory symbolic links unavailable: {error}")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"import linked_payload.helper\n")

            with self.assertRaisesRegex(ValueError, "linked"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_dynamic_import_and_execution_mechanisms(self) -> None:
        dynamic_sources = (
            b"import importlib as loader\n",
            b"from runpy import run_module\n",
            b"import builtins as runtime\n",
            b"from ml.rosid_ml import *\n",
            b"def hidden():\n    return __import__('ml.rosid_ml.training')\n",
            b"if False:\n    compile('pass', '<test>', 'exec')\n",
            b"if False:\n    eval('1')\n",
            b"if False:\n    exec('pass')\n",
            b"if False:\n    print(__builtins__)\n",
            b"__path__ = ['/outside']\n",
            b"import sys\nsys.modules['builtins'].__import__('ml.hidden')\n",
            b"globals()['eval']('1')\n",
            b"getattr(object(), '__import__')('ml.hidden')\n",
        )
        for source in dynamic_sources:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    core = write_p1_code_fixture(root)
                    adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
                    adapter.parent.mkdir(parents=True)
                    adapter.write_bytes(b"VALUE = 1\n")
                    bridge = core["ml/build_split_manifest.py"]
                    bridge.write_bytes(bridge.read_bytes() + source)
                    with self.assertRaisesRegex(ValueError, "dynamic Python"):
                        discover_p1_implementation_paths(
                            root,
                            adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                        )

    def test_discovery_rejects_non_utf8_source_cookie(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(b"# coding: latin-1\n" + bridge.read_bytes())

            with self.assertRaisesRegex(ValueError, "plain UTF-8"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_discovery_rejects_git_hidden_local_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = write_p1_code_fixture(root)
            adapter = root / "ml" / "rosid_ml" / "adapters" / "fixture.py"
            adapter.parent.mkdir(parents=True)
            adapter.write_bytes(b"VALUE = 1\n")
            hidden = root / "hidden.py"
            hidden.write_bytes(b"VALUE = 2\n")
            bridge = core["ml/build_split_manifest.py"]
            bridge.write_bytes(bridge.read_bytes() + b"import hidden\n")

            def git(*arguments: str) -> None:
                subprocess.run(
                    ("git", *arguments),
                    cwd=root,
                    check=True,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    shell=False,
                )

            git("init", "--quiet")
            git("config", "user.name", "Code Bundle Test")
            git("config", "user.email", "code-bundle@example.invalid")
            git("add", "--all")
            git("commit", "--quiet", "-m", "fixture")
            git("update-index", "--skip-worktree", "hidden.py")
            hidden.unlink()

            with self.assertRaisesRegex(ValueError, "ordinary stage-0"):
                discover_p1_implementation_paths(
                    root,
                    adapter_paths=("ml/rosid_ml/adapters/fixture.py",),
                )

    def test_checked_in_p1_closure_matches_reviewed_role_table(self) -> None:
        root = Path(__file__).resolve().parents[2]
        found = discover_p1_implementation_paths(root, adapter_paths=())
        self.assertEqual(set(found), set(REQUIRED_CORE_CODE_ROLES))
        self.assertNotIn("ml/rosid_ml/limits.py", found)
        self.assertNotIn("ml/rosid_ml/preprocess_reference.py", found)
        self.assertNotIn(
            "ml/rosid_ml/preprocess_reference.py",
            REQUIRED_CORE_CODE_ROLES,
        )

    def test_entrypoint_roles_are_consistent_with_reviewed_role_table(self) -> None:
        self.assertTrue(set(P1_ENTRYPOINT_CODE_ROLES) < set(REQUIRED_CORE_CODE_ROLES))
        self.assertEqual(
            dict(P1_ENTRYPOINT_CODE_ROLES),
            {path: REQUIRED_CORE_CODE_ROLES[path] for path in P1_ENTRYPOINT_CODE_ROLES},
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
