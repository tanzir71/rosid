from __future__ import annotations

from pathlib import Path
from typing import Iterable

from ml.rosid_ml.code_bundles import (
    REQUIRED_CORE_CODE_ROLES,
    CodeBundleManifest,
    CodeRole,
    build_code_bundle,
)


def write_p1_code_fixture(root: Path) -> dict[str, Path]:
    """Create a minimal fixed P1 tree whose static imports close exactly."""

    core: dict[str, Path] = {}
    for relative in REQUIRED_CORE_CODE_ROLES:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(f"# {relative}\n".encode())
        core[relative] = path

    bridge_path = "ml/build_split_manifest.py"
    imports = ["import json"]
    for relative in REQUIRED_CORE_CODE_ROLES:
        if relative == bridge_path or relative.endswith("/__init__.py"):
            continue
        imports.append(f"import {relative[:-3].replace('/', '.')}")
    core[bridge_path].write_bytes(("\n".join(imports) + "\n").encode())

    # Exercise cycle handling in every graph-aware fixture.
    core["ml/rosid_ml/acquisition.py"].write_bytes(b"from . import provenance\n")
    core["ml/rosid_ml/provenance.py"].write_bytes(b"from . import acquisition\n")
    return core


def build_p1_code_fixture_bundle(
    root: Path,
    *,
    core_files: dict[str, Path],
    adapter_files: Iterable[Path],
) -> CodeBundleManifest:
    adapters = tuple(adapter_files)
    return build_code_bundle(
        root,
        splitter_files=tuple(
            core_files[path]
            for path, role in REQUIRED_CORE_CODE_ROLES.items()
            if role == CodeRole.SPLITTER.value
        ),
        adapter_files=adapters,
        shared_files=tuple(
            core_files[path]
            for path, role in REQUIRED_CORE_CODE_ROLES.items()
            if role == CodeRole.SHARED.value
        ),
    )
