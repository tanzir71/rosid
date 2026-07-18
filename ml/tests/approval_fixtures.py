"""Test-only capabilities for split tests below the signature boundary."""

from __future__ import annotations

import base64
import hashlib

from ml.rosid_ml import split_approvals as approval_module
from ml.rosid_ml.split_approvals import (
    ApprovalFileRole,
    ApprovalScope,
    ApprovedFile,
    SplitApproval,
    SplitApprovalRequest,
    VerifiedSplitApproval,
    split_commitment_key_fingerprint,
    split_seed_key_fingerprint,
)
from ml.rosid_ml.split_manifests import SplitConfig


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def fake_verified_split_approval(
    *,
    config: SplitConfig,
    acquisition_sha256s: tuple[str, ...],
    adapter_commitment_sha256s: tuple[str, ...],
    seed_key: bytes,
    commitment_key: bytes,
    allow_nonproduction: bool = False,
) -> VerifiedSplitApproval:
    """Construct a test capability after signature behavior is tested elsewhere."""

    roles = tuple(ApprovalFileRole)
    files = tuple(
        ApprovedFile(
            path=f"ml/fixture/{index:02d}-{role.value}.json",
            role=role,
            sha256=_digest(f"approved-file:{role.value}"),
        )
        for index, role in enumerate(roles)
    )
    policy_sha256 = _digest("test-approval-policy")
    request = SplitApprovalRequest(
        schema_version=1,
        repository_id="tanzir71/rosid",
        approval_id="unit-test-split-approval",
        approved_by="unit-test-owner",
        approved_git_commit="0" * 40,
        policy_sha256=policy_sha256,
        policy_generation=1,
        scope=(
            ApprovalScope.QUARANTINED_RESEARCH
            if allow_nonproduction
            else ApprovalScope.PRODUCTION
        ),
        seed_key_fingerprint_sha256=split_seed_key_fingerprint(seed_key),
        commitment_key_fingerprint_sha256=(
            split_commitment_key_fingerprint(commitment_key)
        ),
        split_config_sha256=config.commitment_sha256,
        code_bundle_sha256=config.splitter_code_sha256,
        acquisition_sha256s=tuple(sorted(acquisition_sha256s)),
        adapter_commitment_sha256s=tuple(
            sorted(adapter_commitment_sha256s)
        ),
        adapter_config_sha256s=(_digest("test-adapter-config"),),
        approved_files=files,
    )
    signature = base64.b64encode(
        b"-----BEGIN SSH SIGNATURE-----\n"
        b"test-only\n"
        b"-----END SSH SIGNATURE-----\n"
    ).decode("ascii")
    approval = SplitApproval(
        schema_version=1,
        request=request,
        signature_sshsig_base64=signature,
    )
    return VerifiedSplitApproval(
        approval=approval,
        policy_sha256=policy_sha256,
        _token=approval_module._VERIFIED_APPROVAL_TOKEN,
    )


__all__ = ["fake_verified_split_approval"]
