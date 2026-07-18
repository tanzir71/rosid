"""Recompute and verify a private/public writer-split evidence pair."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.adapter_evidence import (
    AdapterConfig,
    AdapterEvidence,
    PublicAdapterCommitment,
)
from ml.rosid_ml.code_bundles import CodeBundleManifest
from ml.rosid_ml.provenance import AcquisitionRecord
from ml.rosid_ml.split_approvals import (
    ApprovalPolicy,
    SplitApproval,
    verify_approval_policy,
    verify_split_approval,
    verify_split_approval_public,
)
from ml.rosid_ml.split_manifests import (
    PublicSplitCommitment,
    SplitConfig,
    assemble_split_approved_files,
    load_acquisition_bindings,
    read_private_jsonl,
    read_secret_file,
    rebind_acquisition_inputs_to_head,
    verify_adapter_bindings,
    verify_split_evidence,
)
from ml.rosid_ml.splits import Split
from ml.rosid_ml.storage import (
    require_git_worktree,
    require_private_manifest_path,
    require_public_acquisition_path,
    require_public_adapter_path,
    require_public_dataset_path,
    require_public_split_path,
    require_tracked_unchanged_path,
)


_APPROVAL_POLICY_PATH = Path("ml/APPROVAL_POLICY.json")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_manifest", type=Path)
    parser.add_argument("public_commitment", type=Path)
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
        "--directory-inventory",
        action="append",
        required=True,
        type=Path,
    )
    parser.add_argument(
        "--adapter-evidence",
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
    parser.add_argument("--approved-config", required=True, type=Path)
    parser.add_argument("--approved-code-bundle", required=True, type=Path)
    parser.add_argument("--split-approval", required=True, type=Path)
    parser.add_argument("--trusted-approval-policy-sha256", required=True)
    parser.add_argument(
        "--quarantined-research",
        action="store_true",
        help="Allow conditional/research-only acquisitions without promoting them.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        worktree = require_git_worktree()
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
        approval_path = require_public_split_path(
            args.split_approval,
            expected_worktree=worktree,
        )
        require_tracked_unchanged_path(
            approval_path,
            expected_worktree=worktree,
        )
        approval = SplitApproval.from_json_file(approval_path)
        require_tracked_unchanged_path(
            approval_path,
            expected_worktree=worktree,
            expected_bytes=approval.canonical_bytes(),
        )
        private_manifest = require_private_manifest_path(
            args.private_manifest,
            expected_worktree=worktree,
        )
        public_commitment = require_public_split_path(
            args.public_commitment,
            expected_worktree=worktree,
        )
        approved_config_path = require_public_split_path(
            args.approved_config,
            expected_worktree=worktree,
        )
        approved_bundle_path = require_public_split_path(
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
        tracked_inputs = (
            policy_path,
            approval_path,
            public_commitment,
            approved_config_path,
            approved_bundle_path,
            *acquisition_paths,
            *source_paths,
            *source_manifest_paths,
            *adapter_commitment_paths,
            *adapter_config_paths,
        )
        for path in tracked_inputs:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )
        inventory_paths = tuple(
            require_private_manifest_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.directory_inventory
        )
        adapter_evidence_paths = tuple(
            require_private_manifest_path(
                path,
                expected_worktree=worktree,
            )
            for path in args.adapter_evidence
        )
        seed_key_path = require_private_manifest_path(
            args.seed_key_file,
            expected_worktree=worktree,
        )
        commitment_key_path = require_private_manifest_path(
            args.commitment_key_file,
            expected_worktree=worktree,
        )
        public = PublicSplitCommitment.from_json_file(public_commitment)
        config = SplitConfig.from_json_file(approved_config_path)
        code_bundle = CodeBundleManifest.from_json_file(approved_bundle_path)
        require_tracked_unchanged_path(
            public_commitment,
            expected_worktree=worktree,
            expected_bytes=public.canonical_bytes(),
        )
        require_tracked_unchanged_path(
            approved_config_path,
            expected_worktree=worktree,
            expected_bytes=config.canonical_bytes(),
        )
        require_tracked_unchanged_path(
            approved_bundle_path,
            expected_worktree=worktree,
            expected_bytes=code_bundle.canonical_bytes(),
        )
        if public.config != config:
            raise ValueError("public split config differs from the approved config")
        if config.splitter_code_sha256 != code_bundle.commitment_sha256:
            raise ValueError(
                "approved split config differs from its approved code bundle"
            )
        for entry in code_bundle.files:
            require_tracked_unchanged_path(
                worktree / entry.path,
                expected_worktree=worktree,
            )
        code_bundle.verify_worktree(worktree)
        public_adapter_commitments = tuple(
            PublicAdapterCommitment.from_json_file(path)
            for path in adapter_commitment_paths
        )
        approved_adapter_configs = tuple(
            AdapterConfig.from_json_file(path)
            for path in adapter_config_paths
        )
        code_bundle.require_exact_implementation(
            adapter_paths=(
                implementation_path
                for adapter_config in approved_adapter_configs
                for implementation_path in adapter_config.implementation_paths
            ),
            worktree_root=worktree,
        )
        for path, value in (
            *zip(adapter_commitment_paths, public_adapter_commitments),
            *zip(adapter_config_paths, approved_adapter_configs),
        ):
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
                expected_bytes=value.canonical_bytes(),
            )
        acquisition_records = tuple(
            AcquisitionRecord.from_json_file(path)
            for path in acquisition_paths
        )
        approved_files = assemble_split_approved_files(
            worktree=worktree,
            policy_path=policy_path,
            policy=policy,
            config_path=approved_config_path,
            config=config,
            code_bundle_path=approved_bundle_path,
            code_bundle=code_bundle,
            acquisition_paths=acquisition_paths,
            source_paths=source_paths,
            source_manifest_paths=source_manifest_paths,
            adapter_commitment_paths=adapter_commitment_paths,
            adapter_commitments=public_adapter_commitments,
            adapter_config_paths=adapter_config_paths,
            adapter_configs=approved_adapter_configs,
        )
        approval_arguments = {
            "policy": policy,
            "trusted_policy_sha256": (
                args.trusted_approval_policy_sha256
            ),
            "worktree": worktree,
            "allow_nonproduction": args.quarantined_research,
            "split_config_sha256": config.commitment_sha256,
            "code_bundle_sha256": code_bundle.commitment_sha256,
            "acquisition_sha256s": tuple(
                value.commitment_sha256 for value in acquisition_records
            ),
            "adapter_commitment_sha256s": tuple(
                value.commitment_sha256
                for value in public_adapter_commitments
            ),
            "adapter_config_sha256s": tuple(
                value.commitment_sha256 for value in approved_adapter_configs
            ),
            "approved_files": approved_files,
        }
        verify_split_approval_public(
            approval,
            **approval_arguments,
        )
        seed_key = read_secret_file(seed_key_path, label="split seed key")
        commitment_key = read_secret_file(
            commitment_key_path,
            label="split commitment key",
        )
        verified_approval = verify_split_approval(
            approval,
            seed_key=seed_key,
            commitment_key=commitment_key,
            **approval_arguments,
        )
        private_records = read_private_jsonl(private_manifest)
        private_adapter_evidence = tuple(
            AdapterEvidence.from_json_file(path)
            for path in adapter_evidence_paths
        )
        bindings = load_acquisition_bindings(
            acquisition_paths,
            source_paths,
            source_manifest_paths,
            inventory_paths,
        )
        rebind_acquisition_inputs_to_head(
            acquisition_paths,
            source_paths,
            source_manifest_paths,
            bindings,
            worktree=worktree,
        )
        records = tuple(record.sample for record in private_records)
        verified_adapters = verify_adapter_bindings(
            records,
            bindings,
            private_adapter_evidence,
            public_adapter_commitments,
            approved_adapter_configs,
            commitment_key=commitment_key,
            code_bundle=code_bundle,
            worktree=worktree,
        )
        verified = verify_split_evidence(
            private_records,
            public,
            seed_key=seed_key,
            commitment_key=commitment_key,
            bindings=bindings,
            adapter_evidence=verified_adapters,
            approval=verified_approval,
            allow_nonproduction=args.quarantined_research,
        )
        for path in tracked_inputs:
            require_tracked_unchanged_path(
                path,
                expected_worktree=worktree,
            )
        code_bundle.verify_worktree(worktree)
    except (OSError, ValueError) as error:
        parser.error(str(error))

    print(
        json.dumps(
            {
                "approval_policy_sha256": verified.approval_policy_sha256,
                "private_manifest_sha256": verified.private_manifest_sha256,
                "public_commitment_sha256": verified.public_commitment_sha256,
                "split_approval_sha256": verified.split_approval_sha256,
                "sample_counts": {
                    split.value: public.sample_counts[split]
                    for split in Split
                },
                "verified": True,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
