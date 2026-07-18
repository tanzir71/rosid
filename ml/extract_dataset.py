"""Safely extract one reviewed dataset ZIP into a fresh private directory."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.provenance import DatasetSource
from ml.rosid_ml.safe_extract import (
    SAFE_ZIP_EXTRACTOR_ID,
    SafeExtractionError,
    ZipExtractionLimits,
    safe_extract_zip,
)
from ml.rosid_ml.storage import (
    paths_overlap,
    require_git_worktree,
    require_private_path,
    require_public_dataset_path,
    require_tracked_unchanged_path,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_manifest", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--max-members", required=True, type=int)
    parser.add_argument("--max-central-directory-bytes", required=True, type=int)
    parser.add_argument("--max-total-bytes", required=True, type=int)
    parser.add_argument("--max-member-bytes", required=True, type=int)
    parser.add_argument("--max-compression-ratio", required=True, type=int)
    parser.add_argument("--minimum-free-bytes-after", required=True, type=int)
    parser.add_argument(
        "--allow-nonproduction",
        dest="require_production",
        action="store_false",
        default=True,
        help=(
            "explicitly permit conditional/research-only bytes in an ignored "
            "quarantine; this never upgrades their eligibility"
        ),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        worktree = require_git_worktree()
        manifest_path = require_public_dataset_path(
            args.source_manifest,
            expected_worktree=worktree,
        )
        manifest_path = require_tracked_unchanged_path(
            manifest_path,
            expected_worktree=worktree,
        )
        archive_path = require_private_path(
            args.archive,
            expected_worktree=worktree,
        )
        destination = require_private_path(
            args.destination,
            expected_worktree=worktree,
        )
        if paths_overlap(archive_path, destination):
            raise ValueError(
                "source archive and extraction destination must not overlap"
            )

        source = DatasetSource.from_json_file(manifest_path)
        require_tracked_unchanged_path(
            manifest_path,
            expected_worktree=worktree,
            expected_bytes=source.canonical_bytes(),
        )
        limits = ZipExtractionLimits(
            max_members=args.max_members,
            max_central_directory_bytes=args.max_central_directory_bytes,
            max_total_uncompressed_bytes=args.max_total_bytes,
            max_member_uncompressed_bytes=args.max_member_bytes,
            max_compression_ratio=args.max_compression_ratio,
            minimum_free_bytes_after=args.minimum_free_bytes_after,
        )
        result = safe_extract_zip(
            source,
            archive_path,
            destination,
            limits=limits,
            require_production=args.require_production,
        )
    except (OSError, SafeExtractionError, ValueError) as error:
        try:
            parser.error(
                "dataset extraction was rejected by the private verification boundary"
            )
        except SystemExit as exit_error:
            raise exit_error from error

    print(
        json.dumps(
            {
                "artifact_sha256": result.inventory.artifact_sha256,
                "compressed_bytes": result.compressed_bytes,
                "dataset_id": result.dataset_id,
                "directory_count": result.directory_count,
                "extractor": SAFE_ZIP_EXTRACTOR_ID,
                "file_count": result.file_count,
                "eligibility_mode": (
                    "production_only"
                    if args.require_production
                    else "nonproduction_quarantine"
                ),
                "inventory_sha256": result.inventory.commitment_sha256,
                "limits": limits.to_dict(),
                "member_count": result.member_count,
                "source_archive_bytes": source.bytes,
                "source_archive_sha256": source.sha256,
                "source_eligibility": source.eligibility.value,
                "source_manifest_sha256": source.commitment_sha256,
                "total_uncompressed_bytes": result.inventory.total_bytes,
                "written": True,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
