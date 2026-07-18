"""Prepare exact split config and code-bundle files for owner review."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.acquisition import preflight_output_paths, write_new_files
from ml.rosid_ml.code_bundles import (
    REQUIRED_CORE_CODE_ROLES,
    CodeRole,
    build_code_bundle,
)
from ml.rosid_ml.split_manifests import SplitConfig
from ml.rosid_ml.splits import WRITER_SPLIT_ALGORITHM, Split
from ml.rosid_ml.storage import (
    paths_equal,
    require_git_worktree,
    require_public_split_path,
    require_tracked_unchanged_path,
)


def _split_values(args: argparse.Namespace, prefix: str) -> dict[Split, int]:
    return {
        Split.TRAIN: getattr(args, f"train_{prefix}"),
        Split.VALIDATION: getattr(args, f"validation_{prefix}"),
        Split.TEST: getattr(args, f"test_{prefix}"),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--adapter-code-file",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument("--seed-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--train-weight", type=int, default=8)
    parser.add_argument("--validation-weight", type=int, default=1)
    parser.add_argument("--test-weight", type=int, default=1)
    parser.add_argument("--train-minimum-writers", type=int, default=1)
    parser.add_argument("--validation-minimum-writers", type=int, default=1)
    parser.add_argument("--test-minimum-writers", type=int, default=1)
    parser.add_argument("--train-minimum-samples", type=int, default=1)
    parser.add_argument("--validation-minimum-samples", type=int, default=1)
    parser.add_argument("--test-minimum-samples", type=int, default=1)
    parser.add_argument("--code-bundle-output", required=True, type=Path)
    parser.add_argument("--config-output", required=True, type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        worktree = require_git_worktree()
        code_bundle_output = require_public_split_path(
            args.code_bundle_output,
            expected_worktree=worktree,
        )
        config_output = require_public_split_path(
            args.config_output,
            expected_worktree=worktree,
        )
        if paths_equal(code_bundle_output, config_output):
            raise ValueError("code-bundle and split-config outputs must differ")
        preflight_output_paths((code_bundle_output, config_output))

        splitter_paths = tuple(
            worktree / path
            for path, role in REQUIRED_CORE_CODE_ROLES.items()
            if role == CodeRole.SPLITTER.value
        )
        shared_paths = tuple(
            worktree / path
            for path, role in REQUIRED_CORE_CODE_ROLES.items()
            if role == CodeRole.SHARED.value
        )
        adapter_paths = tuple(args.adapter_code_file)
        code_paths = (*splitter_paths, *adapter_paths, *shared_paths)
        tracked_paths = tuple(
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )
            for path in code_paths
        )
        for code_path in tracked_paths:
            if paths_equal(code_path, code_bundle_output) or paths_equal(
                code_path,
                config_output,
            ):
                raise ValueError("approval output cannot overwrite code input")

        splitter_count = len(splitter_paths)
        adapter_count = len(adapter_paths)
        bundle = build_code_bundle(
            worktree,
            splitter_files=tracked_paths[:splitter_count],
            adapter_files=tracked_paths[
                splitter_count : splitter_count + adapter_count
            ],
            shared_files=tracked_paths[splitter_count + adapter_count :],
        )
        bundle.require_exact_implementation(
            adapter_paths=(
                entry.path
                for entry in bundle.files
                if entry.role == CodeRole.ADAPTER
            ),
            worktree_root=worktree,
        )
        config = SplitConfig(
            schema_version=2,
            algorithm=WRITER_SPLIT_ALGORITHM,
            splitter_code_sha256=bundle.commitment_sha256,
            seed_id=args.seed_id,
            key_id=args.key_id,
            weights=_split_values(args, "weight"),
            minimum_writers=_split_values(args, "minimum_writers"),
            minimum_samples=_split_values(args, "minimum_samples"),
        )

        for code_path in tracked_paths:
            require_tracked_unchanged_path(
                code_path,
                expected_worktree=worktree,
            )
        bundle.verify_worktree(worktree)
        write_new_files(
            (
                (code_bundle_output, bundle.canonical_bytes()),
                (config_output, config.canonical_bytes()),
            )
        )
    except (OSError, ValueError) as error:
        parser.error(str(error))

    print(
        json.dumps(
            {
                "code_bundle_sha256": bundle.commitment_sha256,
                "config_sha256": config.commitment_sha256,
                "written": True,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
