"""Create canonical global-split approval bytes for external owner signing."""

from __future__ import annotations

import argparse
import hmac
import json
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.acquisition import preflight_output_paths, write_new_files
from ml.rosid_ml.adapter_evidence import AdapterConfig, PublicAdapterCommitment
from ml.rosid_ml.code_bundles import CodeBundleManifest
from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    DatasetSource,
    Eligibility,
    SourceEvidence,
)
from ml.rosid_ml.split_approvals import (
    APPROVAL_SIGNATURE_NAMESPACE,
    ApprovalPolicy,
    create_split_approval_request,
    git_head_commit,
    verify_approval_policy,
)
from ml.rosid_ml.split_manifests import (
    SplitConfig,
    assemble_split_approved_files,
    read_secret_file,
)
from ml.rosid_ml.storage import (
    paths_equal,
    require_git_worktree,
    require_private_manifest_path,
    require_public_acquisition_path,
    require_public_adapter_path,
    require_public_dataset_path,
    require_public_split_path,
    require_tracked_unchanged_path,
)


_APPROVAL_POLICY_PATH = Path("ml/APPROVAL_POLICY.json")


def _reject_output_collisions(output: Path, inputs: tuple[Path, ...]) -> None:
    if any(paths_equal(output, source) for source in inputs):
        raise ValueError("approval request output must differ from every input")


def _require_new_output(path: Path) -> None:
    preflight_output_paths((path,))
    if path.exists() or path.is_symlink():
        raise FileExistsError(f"refusing to overwrite approval request: {path}")


def _unique_by_commitment(
    values: tuple[object, ...],
    *,
    label: str,
) -> dict[str, object]:
    result: dict[str, object] = {}
    for value in values:
        commitment = getattr(value, "commitment_sha256", None)
        if type(commitment) is not str:
            raise ValueError(f"{label} lacks a canonical commitment")
        if commitment in result:
            raise ValueError(f"duplicate {label}: {commitment}")
        result[commitment] = value
    return result


def _validate_public_relationships(
    *,
    acquisitions: tuple[AcquisitionRecord, ...],
    sources: tuple[SourceEvidence, ...],
    source_manifests: tuple[DatasetSource, ...],
    adapter_commitments: tuple[PublicAdapterCommitment, ...],
    adapter_configs: tuple[AdapterConfig, ...],
    code_bundle: CodeBundleManifest,
    allow_nonproduction: bool,
) -> None:
    acquisition_by_sha256 = _unique_by_commitment(
        acquisitions,
        label="acquisition record",
    )
    source_by_sha256 = _unique_by_commitment(
        sources,
        label="source evidence",
    )
    manifest_by_sha256 = _unique_by_commitment(
        source_manifests,
        label="source manifest",
    )
    config_by_sha256 = _unique_by_commitment(
        adapter_configs,
        label="approved adapter config",
    )

    acquisition_sources: dict[str, SourceEvidence] = {}
    used_sources: set[str] = set()
    used_manifests: set[str] = set()
    for acquisition_sha256, value in acquisition_by_sha256.items():
        if not isinstance(value, AcquisitionRecord):
            raise AssertionError("acquisition mapping lost its concrete type")
        try:
            source = source_by_sha256[value.source_evidence_sha256]
        except KeyError as error:
            raise ValueError(
                "acquisition has no matching source evidence"
            ) from error
        if not isinstance(source, SourceEvidence):
            raise AssertionError("source mapping lost its concrete type")
        if source.source_manifest_sha256 is None:
            raise ValueError("dataset source evidence lacks its manifest commitment")
        try:
            source_manifest = manifest_by_sha256[
                source.source_manifest_sha256
            ]
        except KeyError as error:
            raise ValueError(
                "source evidence has no matching reviewed dataset manifest"
            ) from error
        if not isinstance(source_manifest, DatasetSource):
            raise AssertionError("manifest mapping lost its concrete type")
        if source != source_manifest.to_source_evidence():
            raise ValueError(
                "source evidence differs from its reviewed dataset manifest"
            )
        value.validate_source(source)
        if (
            source.artifact_type != "dataset"
            or source.artifact_role != "source_archive"
            or source.dataset_id is None
            or value.artifact_type != "dataset"
            or value.artifact_role != "extracted_dataset"
        ):
            raise ValueError(
                "split acquisition must bind a source archive to an extracted dataset"
            )
        if value.eligibility == Eligibility.EXCLUDED:
            raise ValueError("excluded acquisition cannot be owner-approved")
        if not value.terms_accepted:
            raise ValueError("owner-approved acquisition requires accepted terms")
        if not allow_nonproduction and value.eligibility != Eligibility.PRODUCTION:
            raise ValueError(
                "nonproduction acquisition requires quarantined approval scope"
            )
        acquisition_sources[acquisition_sha256] = source
        used_sources.add(source.commitment_sha256)
        used_manifests.add(source_manifest.commitment_sha256)
    if used_sources != set(source_by_sha256):
        raise ValueError("source evidence does not exactly cover acquisitions")
    if used_manifests != set(manifest_by_sha256):
        raise ValueError("source manifests do not exactly cover acquisitions")

    commitment_by_acquisition: dict[str, PublicAdapterCommitment] = {}
    used_config_sha256s: set[str] = set()
    for commitment in adapter_commitments:
        if commitment.acquisition_sha256 in commitment_by_acquisition:
            raise ValueError(
                "duplicate public adapter commitment for one acquisition"
            )
        commitment_by_acquisition[commitment.acquisition_sha256] = commitment
        if (
            commitment.adapter_code_bundle_sha256
            != code_bundle.commitment_sha256
        ):
            raise ValueError(
                "public adapter commitment differs from the approved code bundle"
            )
        try:
            approved_config = config_by_sha256[
                commitment.adapter_config_sha256
            ]
        except KeyError as error:
            raise ValueError(
                "public adapter commitment lacks its approved adapter config"
            ) from error
        if not isinstance(approved_config, AdapterConfig):
            raise AssertionError("config mapping lost its concrete type")
        if commitment.adapter_config != approved_config:
            raise ValueError(
                "public adapter commitment embeds a different adapter config"
            )
        source = acquisition_sources.get(commitment.acquisition_sha256)
        if source is None:
            raise ValueError(
                "public adapter commitment references an unapproved acquisition"
            )
        acquisition = acquisition_by_sha256[commitment.acquisition_sha256]
        if not isinstance(acquisition, AcquisitionRecord):
            raise AssertionError("acquisition mapping lost its concrete type")
        if (
            commitment.dataset_id != source.dataset_id
            or commitment.dataset_version != source.version
            or commitment.directory_inventory_sha256
            != acquisition.inventory_sha256
        ):
            raise ValueError(
                "public adapter commitment differs from its acquisition identity"
            )
        used_config_sha256s.add(commitment.adapter_config_sha256)
    if set(commitment_by_acquisition) != set(acquisition_by_sha256):
        raise ValueError(
            "public adapter commitments do not exactly cover acquisitions"
        )
    if used_config_sha256s != set(config_by_sha256):
        raise ValueError(
            "approved adapter configs do not exactly cover commitments"
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approval-id", required=True)
    parser.add_argument("--approved-by", required=True)
    parser.add_argument(
        "--trusted-approval-policy-sha256",
        required=True,
    )
    parser.add_argument("--approved-config", required=True, type=Path)
    parser.add_argument("--approved-code-bundle", required=True, type=Path)
    parser.add_argument(
        "--acquisition-record",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--source-evidence",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--source-manifest",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--adapter-commitment",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--approved-adapter-config",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument("--seed-key-file", required=True, type=Path)
    parser.add_argument("--commitment-key-file", required=True, type=Path)
    parser.add_argument("--request-output", required=True, type=Path)
    parser.add_argument(
        "--quarantined-research",
        action="store_true",
        help="Request approval for conditional/research evidence without promotion.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        worktree = require_git_worktree()
        initial_head = git_head_commit(worktree)
        policy_path = require_tracked_unchanged_path(
            worktree / _APPROVAL_POLICY_PATH,
            expected_worktree=worktree,
        )
        policy = ApprovalPolicy.from_json_file(policy_path)
        require_tracked_unchanged_path(
            policy_path,
            expected_worktree=worktree,
            expected_bytes=policy.canonical_bytes(),
        )
        verify_approval_policy(
            policy,
            args.trusted_approval_policy_sha256,
        )
        if policy.signer_identity != args.approved_by:
            raise ValueError("split approver differs from the active owner policy")

        config_path = require_public_split_path(
            args.approved_config,
            expected_worktree=worktree,
        )
        code_bundle_path = require_public_split_path(
            args.approved_code_bundle,
            expected_worktree=worktree,
        )
        acquisition_paths = tuple(
            require_public_acquisition_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.acquisition_record
        )
        source_paths = tuple(
            require_public_acquisition_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.source_evidence
        )
        source_manifest_paths = tuple(
            require_public_dataset_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.source_manifest
        )
        adapter_commitment_paths = tuple(
            require_public_adapter_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.adapter_commitment
        )
        adapter_config_paths = tuple(
            require_public_adapter_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.approved_adapter_config
        )
        seed_key_path = require_private_manifest_path(
            args.seed_key_file,
            expected_worktree=worktree,
        )
        commitment_key_path = require_private_manifest_path(
            args.commitment_key_file,
            expected_worktree=worktree,
        )
        request_output = require_public_split_path(
            args.request_output,
            expected_worktree=worktree,
        )
        public_paths = (
            policy_path,
            config_path,
            code_bundle_path,
            *acquisition_paths,
            *source_paths,
            *source_manifest_paths,
            *adapter_commitment_paths,
            *adapter_config_paths,
        )
        _reject_output_collisions(
            request_output,
            (*public_paths, seed_key_path, commitment_key_path),
        )
        _require_new_output(request_output)
        for path in public_paths:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )

        config = SplitConfig.from_json_file(config_path)
        code_bundle = CodeBundleManifest.from_json_file(code_bundle_path)
        acquisitions = tuple(
            AcquisitionRecord.from_json_file(path) for path in acquisition_paths
        )
        sources = tuple(
            SourceEvidence.from_json_file(path) for path in source_paths
        )
        source_manifests = tuple(
            DatasetSource.from_json_file(path) for path in source_manifest_paths
        )
        adapter_commitments = tuple(
            PublicAdapterCommitment.from_json_file(path)
            for path in adapter_commitment_paths
        )
        adapter_configs = tuple(
            AdapterConfig.from_json_file(path) for path in adapter_config_paths
        )
        parsed_public_inputs = (
            (policy_path, policy.canonical_bytes()),
            (config_path, config.canonical_bytes()),
            (code_bundle_path, code_bundle.canonical_bytes()),
            *(
                (path, value.canonical_bytes())
                for path, value in zip(acquisition_paths, acquisitions, strict=True)
            ),
            *(
                (path, value.canonical_bytes())
                for path, value in zip(source_paths, sources, strict=True)
            ),
            *(
                (path, value.canonical_bytes())
                for path, value in zip(
                    source_manifest_paths,
                    source_manifests,
                    strict=True,
                )
            ),
            *(
                (path, value.canonical_bytes())
                for path, value in zip(
                    adapter_commitment_paths,
                    adapter_commitments,
                    strict=True,
                )
            ),
            *(
                (path, value.canonical_bytes())
                for path, value in zip(
                    adapter_config_paths,
                    adapter_configs,
                    strict=True,
                )
            ),
        )
        for path, canonical_bytes in parsed_public_inputs:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
                expected_bytes=canonical_bytes,
            )

        if config.splitter_code_sha256 != code_bundle.commitment_sha256:
            raise ValueError(
                "approved split config differs from its approved code bundle"
            )
        _validate_public_relationships(
            acquisitions=acquisitions,
            sources=sources,
            source_manifests=source_manifests,
            adapter_commitments=adapter_commitments,
            adapter_configs=adapter_configs,
            code_bundle=code_bundle,
            allow_nonproduction=args.quarantined_research,
        )
        adapter_paths = tuple(
            implementation_path
            for adapter_config in adapter_configs
            for implementation_path in adapter_config.implementation_paths
        )
        code_bundle.require_exact_implementation(
            adapter_paths=adapter_paths,
            worktree_root=worktree,
        )
        code_paths = tuple(worktree / entry.path for entry in code_bundle.files)
        _reject_output_collisions(request_output, code_paths)
        for path in code_paths:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )
        code_bundle.verify_worktree(worktree)

        approved_files = assemble_split_approved_files(
            worktree=worktree,
            policy_path=policy_path,
            policy=policy,
            config_path=config_path,
            config=config,
            code_bundle_path=code_bundle_path,
            code_bundle=code_bundle,
            acquisition_paths=acquisition_paths,
            source_paths=source_paths,
            source_manifest_paths=source_manifest_paths,
            adapter_commitment_paths=adapter_commitment_paths,
            adapter_commitments=adapter_commitments,
            adapter_config_paths=adapter_config_paths,
            adapter_configs=adapter_configs,
        )
        seed_key = read_secret_file(seed_key_path, label="split seed key")
        commitment_key = read_secret_file(
            commitment_key_path,
            label="split commitment key",
        )
        if hmac.compare_digest(seed_key, commitment_key):
            raise ValueError("split seed and commitment keys must be different")
        if git_head_commit(worktree) != initial_head:
            raise ValueError("Git HEAD changed while preparing split approval")

        request = create_split_approval_request(
            policy=policy,
            trusted_policy_sha256=args.trusted_approval_policy_sha256,
            worktree=worktree,
            approval_id=args.approval_id,
            approved_by=args.approved_by,
            allow_nonproduction=args.quarantined_research,
            seed_key=seed_key,
            commitment_key=commitment_key,
            split_config_sha256=config.commitment_sha256,
            code_bundle_sha256=code_bundle.commitment_sha256,
            acquisition_sha256s=tuple(
                value.commitment_sha256 for value in acquisitions
            ),
            adapter_commitment_sha256s=tuple(
                value.commitment_sha256 for value in adapter_commitments
            ),
            adapter_config_sha256s=tuple(
                value.commitment_sha256 for value in adapter_configs
            ),
            approved_files=approved_files,
        )
        if request.approved_git_commit != initial_head:
            raise ValueError("Git HEAD changed while preparing split approval")

        for path, canonical_bytes in parsed_public_inputs:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
                expected_bytes=canonical_bytes,
            )
        for path in code_paths:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )
        code_bundle.require_exact_implementation(
            adapter_paths=adapter_paths,
            worktree_root=worktree,
        )
        code_bundle.verify_worktree(worktree)
        if git_head_commit(worktree) != request.approved_git_commit:
            raise ValueError("Git HEAD changed while preparing split approval")
        _require_new_output(request_output)
        write_new_files(((request_output, request.canonical_bytes()),))
    except (OSError, ValueError) as error:
        parser.error(str(error))

    sign_command = (
        "ssh-keygen -Y sign -f <owner-private-key-outside-repo> "
        f"-n {APPROVAL_SIGNATURE_NAMESPACE} <request-path>"
    )
    print(
        json.dumps(
            {
                "approved_git_commit": request.approved_git_commit,
                "policy_sha256": request.policy_sha256,
                "request_sha256": request.commitment_sha256,
                "sign_command": sign_command,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
