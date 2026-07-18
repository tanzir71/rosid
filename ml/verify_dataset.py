"""Verify a manually downloaded dataset archive against its source manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ml.rosid_ml.provenance import DatasetSource, Eligibility


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--allow-nonproduction",
        dest="require_production",
        action="store_false",
        default=True,
        help="explicitly allow conditional/research-only bytes for quarantined work",
    )
    return parser


def verify(
    manifest_path: Path,
    archive_path: Path,
    *,
    require_production: bool = True,
) -> DatasetSource:
    source = DatasetSource.from_json_file(manifest_path)
    if source.eligibility == Eligibility.EXCLUDED:
        raise ValueError(f"{source.dataset_id} is excluded from acquisition")
    if require_production and source.eligibility != Eligibility.PRODUCTION:
        raise ValueError(
            f"{source.dataset_id} eligibility is {source.eligibility.value}, "
            "not production"
        )
    source.verify_archive(archive_path)
    return source


def main() -> int:
    args = _parser().parse_args()
    try:
        source = verify(
            args.manifest,
            args.archive,
            require_production=args.require_production,
        )
    except ValueError as error:
        raise SystemExit(f"dataset verification failed: {error}") from error
    print(
        json.dumps(
            {
                "bytes": source.bytes,
                "dataset_id": source.dataset_id,
                "eligibility": source.eligibility.value,
                "filename": source.filename,
                "sha256": source.sha256,
                "source_commitment_sha256": (
                    source.to_source_evidence().commitment_sha256
                ),
                "version": source.version,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
