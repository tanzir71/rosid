"""Create canonical acquisition evidence after an approved manual download."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.acquisition import (
    build_acquisition_artifacts,
    preflight_output_paths,
    write_new_files,
)
from ml.rosid_ml.provenance import (
    DatasetSource,
    Eligibility,
    validate_acquisition_record_id,
)
from ml.rosid_ml.storage import (
    path_is_within,
    paths_overlap,
    require_git_worktree,
    require_private_manifest_path,
    require_private_path,
    require_public_acquisition_path,
    require_public_dataset_path,
    require_tracked_unchanged_path,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Verify one reviewed dataset archive and its extracted tree, then "
            "write canonical public acquisition evidence plus a private inventory."
        )
    )
    parser.add_argument("source_manifest", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("extracted_directory", type=Path)
    parser.add_argument("--record-id", required=True)
    parser.add_argument(
        "--acquired-at-utc",
        required=True,
        help="Canonical UTC timestamp: YYYY-MM-DDTHH:MM:SSZ.",
    )
    parser.add_argument("--accepted-by", required=True)
    parser.add_argument(
        "--extractor",
        required=True,
        help="Exact extraction tool and version, for example python-zipfile/3.12.10.",
    )
    terms = parser.add_mutually_exclusive_group(required=True)
    terms.add_argument(
        "--terms-accepted",
        dest="terms_accepted",
        action="store_true",
    )
    terms.add_argument(
        "--terms-not-accepted",
        dest="terms_accepted",
        action="store_false",
    )
    parser.add_argument(
        "--eligibility",
        choices=[value.value for value in Eligibility],
        help="Optional downgrade from the reviewed source eligibility.",
    )
    parser.add_argument(
        "--quarantined-research",
        action="store_true",
        help=(
            "Required for conditional/research-only evidence; this does not "
            "authorize production lineage."
        ),
    )
    parser.add_argument(
        "--public-directory",
        type=Path,
        default=Path("ml/manifests/acquisitions"),
    )
    parser.add_argument(
        "--private-inventory",
        type=Path,
        help=(
            "Ignored canonical inventory path. Defaults under "
            "ml/manifests/private/acquisitions/."
        ),
    )
    return parser


def _contains(parent: Path, child: Path) -> bool:
    return path_is_within(child, parent)


def _overlaps(first: Path, second: Path) -> bool:
    return paths_overlap(first, second)


def _validate_path_topology(
    *,
    source_manifest: Path,
    archive: Path,
    extracted_directory: Path,
    public_directory: Path,
    private_inventory: Path,
    source_output: Path,
    acquisition_output: Path,
) -> None:
    if _contains(extracted_directory, source_manifest):
        raise ValueError("source manifest must be outside the extracted directory")
    if _contains(extracted_directory, archive):
        raise ValueError("source archive must be outside the extracted directory")
    if _overlaps(extracted_directory, public_directory):
        raise ValueError(
            "public evidence directory must not overlap the extracted directory"
        )
    if _overlaps(extracted_directory, private_inventory.parent):
        raise ValueError(
            "private inventory directory must not overlap the extracted directory"
        )
    if _contains(public_directory, private_inventory):
        raise ValueError("private inventory must be outside public evidence")
    inputs = (source_manifest, archive, extracted_directory)
    outputs = (private_inventory, source_output, acquisition_output)
    input_paths = {path.resolve(strict=False) for path in inputs}
    output_paths = {path.resolve(strict=False) for path in outputs}
    if input_paths & output_paths:
        raise ValueError("acquisition inputs and evidence outputs must be distinct")


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        validate_acquisition_record_id(args.record_id)
        worktree = require_git_worktree()
        source_manifest_path = require_public_dataset_path(
            args.source_manifest,
            expected_worktree=worktree,
        )
        source_manifest_path = require_tracked_unchanged_path(
            source_manifest_path,
            expected_worktree=worktree,
        )
        archive_path = require_private_path(
            args.archive,
            expected_worktree=worktree,
        )
        extracted_directory = require_private_path(
            args.extracted_directory,
            expected_worktree=worktree,
        )
        private_inventory = args.private_inventory or (
            Path("ml/manifests/private/acquisitions")
            / f"{args.record_id}.inventory.json"
        )
        private_inventory = require_private_manifest_path(
            private_inventory,
            expected_worktree=worktree,
        )
        source_output = require_public_acquisition_path(
            args.public_directory / f"{args.record_id}.source.json",
            expected_worktree=worktree,
        )
        acquisition_output = require_public_acquisition_path(
            args.public_directory / f"{args.record_id}.acquisition.json",
            expected_worktree=worktree,
        )
        _validate_path_topology(
            source_manifest=source_manifest_path,
            archive=archive_path,
            extracted_directory=extracted_directory,
            public_directory=args.public_directory,
            private_inventory=private_inventory,
            source_output=source_output,
            acquisition_output=acquisition_output,
        )
        preflight_output_paths(
            (private_inventory, source_output, acquisition_output)
        )
        source_manifest = DatasetSource.from_json_file(source_manifest_path)
        require_tracked_unchanged_path(
            source_manifest_path,
            expected_worktree=worktree,
            expected_bytes=source_manifest.canonical_bytes(),
        )
        artifacts = build_acquisition_artifacts(
            source_manifest=source_manifest,
            archive_path=archive_path,
            extracted_directory=extracted_directory,
            record_id=args.record_id,
            acquired_at_utc=args.acquired_at_utc,
            accepted_by=args.accepted_by,
            terms_accepted=args.terms_accepted,
            extractor=args.extractor,
            eligibility=(
                None
                if args.eligibility is None
                else Eligibility(args.eligibility)
            ),
            quarantined_research=args.quarantined_research,
        )
        write_new_files(
            (
                (private_inventory, artifacts.inventory.canonical_bytes()),
                (source_output, artifacts.source.canonical_bytes()),
                (
                    acquisition_output,
                    artifacts.acquisition.canonical_bytes(),
                ),
            )
        )
    except (OSError, ValueError) as error:
        parser.error(str(error))

    print(
        json.dumps(
            {
                "acquisition_sha256": artifacts.acquisition.commitment_sha256,
                "inventory_sha256": artifacts.inventory.commitment_sha256,
                "source_sha256": artifacts.source.commitment_sha256,
                "written": True,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
