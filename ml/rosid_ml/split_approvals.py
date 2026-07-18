"""Externally signed owner approvals for qualifying global split inputs.

The owner signing key is deliberately never accepted by this module.  Approval
requests are signed out of process with OpenSSH ``ssh-keygen -Y sign`` and this
module receives only the detached SSHSIG and the pinned public policy.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Iterable

from .acquisition import validate_portable_relative_path
from .provenance import canonical_json_bytes
from .storage import (
    normalize_path,
    path_is_within,
    paths_equal,
    require_git_worktree,
)


ROSID_REPOSITORY_ID = "tanzir71/rosid"
APPROVAL_SIGNATURE_NAMESPACE = "rosid-v2-split-approval"
_EXPECTED_ORIGINS = frozenset(
    {
        "git@github.com:tanzir71/rosid.git",
        "ssh://git@github.com/tanzir71/rosid.git",
        "https://github.com/tanzir71/rosid.git",
        "https://github.com/tanzir71/rosid",
    }
)
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_GIT_COMMIT = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
_OPAQUE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:@/-]{0,127}\Z")
_SEED_KEY_DOMAIN = b"rosid-v2-split-seed-key-fingerprint-v1\0"
_COMMITMENT_KEY_DOMAIN = b"rosid-v2-split-hmac-key-fingerprint-v1\0"
_REGULAR_GIT_FILE_MODES = frozenset({b"100644", b"100755"})


class ApprovalStatus(StrEnum):
    """Lifecycle of one immutable owner-verification policy."""

    PENDING = "pending"
    ACTIVE = "active"
    REVOKED = "revoked"


class ApprovalScope(StrEnum):
    """Whether an approval may authorize nonproduction source evidence."""

    PRODUCTION = "production"
    QUARANTINED_RESEARCH = "quarantined_research"


class ApprovalFileRole(StrEnum):
    """Why a committed public file is part of an approval request."""

    POLICY = "approval_policy"
    SPLIT_CONFIG = "split_config"
    CODE_BUNDLE = "code_bundle"
    ACQUISITION = "acquisition_record"
    SOURCE_EVIDENCE = "source_evidence"
    SOURCE_MANIFEST = "source_manifest"
    ADAPTER_COMMITMENT = "adapter_commitment"
    ADAPTER_CONFIG = "adapter_config"
    IMPLEMENTATION_CODE = "implementation_code"


@dataclass(frozen=True)
class ApprovalPolicy:
    """Public owner key whose exact policy hash is supplied out of band."""

    schema_version: int
    repository_id: str
    generation: int
    status: ApprovalStatus
    signer_identity: str | None
    owner_public_key: str | None
    owner_public_key_sha256: str | None

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported approval-policy schema: {self.schema_version}"
            )
        if self.repository_id != ROSID_REPOSITORY_ID:
            raise ValueError("approval policy has the wrong repository identity")
        if type(self.generation) is not int or self.generation <= 0:
            raise ValueError("approval-policy generation must be positive")
        if not isinstance(self.status, ApprovalStatus):
            raise ValueError("approval-policy status is invalid")
        if self.status == ApprovalStatus.PENDING:
            if any(
                value is not None
                for value in (
                    self.signer_identity,
                    self.owner_public_key,
                    self.owner_public_key_sha256,
                )
            ):
                raise ValueError("pending approval policy must not contain a key")
            return
        if (
            type(self.signer_identity) is not str
            or not _OPAQUE_ID.fullmatch(self.signer_identity)
        ):
            raise ValueError("approval-policy signer identity is invalid")
        if type(self.owner_public_key) is not str:
            raise ValueError("approval policy must contain an owner public key")
        key_blob = _parse_ed25519_public_key(self.owner_public_key)
        expected_fingerprint = hashlib.sha256(key_blob).hexdigest()
        if (
            type(self.owner_public_key_sha256) is not str
            or not _SHA256.fullmatch(self.owner_public_key_sha256)
            or self.owner_public_key_sha256 != expected_fingerprint
        ):
            raise ValueError("approval-policy public-key fingerprint is invalid")

    def to_dict(self) -> dict[str, object]:
        return {
            "generation": self.generation,
            "owner_public_key": self.owner_public_key,
            "owner_public_key_sha256": self.owner_public_key_sha256,
            "repository_id": self.repository_id,
            "schema_version": self.schema_version,
            "signer_identity": self.signer_identity,
            "status": self.status.value,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> ApprovalPolicy:
        expected = {
            "generation",
            "owner_public_key",
            "owner_public_key_sha256",
            "repository_id",
            "schema_version",
            "signer_identity",
            "status",
        }
        if set(value) != expected:
            raise ValueError("approval-policy keys differ from the schema")
        for field in ("generation", "schema_version"):
            if type(value[field]) is not int:
                raise ValueError(f"approval-policy {field} must be an integer")
        if type(value["repository_id"]) is not str:
            raise ValueError("approval-policy repository_id must be a string")
        if type(value["status"]) is not str:
            raise ValueError("approval-policy status must be a string")
        for field in (
            "owner_public_key",
            "owner_public_key_sha256",
            "signer_identity",
        ):
            if value[field] is not None and type(value[field]) is not str:
                raise ValueError(
                    f"approval-policy {field} must be null or a string"
                )
        try:
            status = ApprovalStatus(value["status"])
        except ValueError as error:
            raise ValueError("approval-policy status is unsupported") from error
        return cls(
            schema_version=value["schema_version"],
            repository_id=value["repository_id"],
            generation=value["generation"],
            status=status,
            signer_identity=value["signer_identity"],
            owner_public_key=value["owner_public_key"],
            owner_public_key_sha256=value["owner_public_key_sha256"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> ApprovalPolicy:
        value, raw = _read_strict_json_object(path, label="approval policy")
        policy = cls.from_dict(value)
        if raw != policy.canonical_bytes():
            raise ValueError("approval policy is not canonical UTF-8/LF JSON")
        return policy


@dataclass(frozen=True)
class ApprovedFile:
    """One exact public path/blob that existed in the approved Git tree."""

    path: str
    role: ApprovalFileRole
    sha256: str

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        if not isinstance(self.role, ApprovalFileRole):
            raise ValueError("approved-file role is invalid")
        _validate_sha256(self.sha256, label="approved-file SHA-256")

    def to_dict(self) -> dict[str, str]:
        return {
            "path": self.path,
            "role": self.role.value,
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> ApprovedFile:
        if set(value) != {"path", "role", "sha256"}:
            raise ValueError("approved-file keys differ from the schema")
        if any(type(value[field]) is not str for field in value):
            raise ValueError("approved-file fields must be strings")
        try:
            role = ApprovalFileRole(value["role"])
        except ValueError as error:
            raise ValueError("approved-file role is unsupported") from error
        return cls(path=value["path"], role=role, sha256=value["sha256"])


@dataclass(frozen=True)
class SplitApprovalRequest:
    """Canonical bytes the owner signs outside the candidate worktree."""

    schema_version: int
    repository_id: str
    approval_id: str
    approved_by: str
    approved_git_commit: str
    policy_sha256: str
    policy_generation: int
    scope: ApprovalScope
    seed_key_fingerprint_sha256: str
    commitment_key_fingerprint_sha256: str
    split_config_sha256: str
    code_bundle_sha256: str
    acquisition_sha256s: tuple[str, ...]
    adapter_commitment_sha256s: tuple[str, ...]
    adapter_config_sha256s: tuple[str, ...]
    approved_files: tuple[ApprovedFile, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported split-approval request schema: "
                f"{self.schema_version}"
            )
        if self.repository_id != ROSID_REPOSITORY_ID:
            raise ValueError("split approval has the wrong repository identity")
        for value, label in (
            (self.approval_id, "approval ID"),
            (self.approved_by, "split approver"),
        ):
            if type(value) is not str or not _OPAQUE_ID.fullmatch(value):
                raise ValueError(f"{label} must be a portable identity")
        if not _GIT_COMMIT.fullmatch(self.approved_git_commit):
            raise ValueError("approved Git commit must be a full object ID")
        if type(self.policy_generation) is not int or self.policy_generation <= 0:
            raise ValueError("approval policy generation must be positive")
        if not isinstance(self.scope, ApprovalScope):
            raise ValueError("split approval scope is invalid")
        for value, label in (
            (self.policy_sha256, "approval policy SHA-256"),
            (
                self.seed_key_fingerprint_sha256,
                "split seed-key fingerprint",
            ),
            (
                self.commitment_key_fingerprint_sha256,
                "split commitment-key fingerprint",
            ),
            (self.split_config_sha256, "approved split-config SHA-256"),
            (self.code_bundle_sha256, "approved code-bundle SHA-256"),
        ):
            _validate_sha256(value, label=label)
        for values, label in (
            (self.acquisition_sha256s, "approved acquisitions"),
            (self.adapter_commitment_sha256s, "approved adapter commitments"),
            (self.adapter_config_sha256s, "approved adapter configs"),
        ):
            _validate_sorted_hashes(values, label=label)
        if not self.approved_files:
            raise ValueError("split approval must bind public files")
        file_keys = tuple(
            (item.path.encode("utf-8"), item.role.value.encode("ascii"))
            for item in self.approved_files
        )
        if file_keys != tuple(sorted(file_keys)):
            raise ValueError("approved files must be sorted by path and role")
        paths = tuple(item.path for item in self.approved_files)
        if len(paths) != len(set(paths)):
            raise ValueError("approved-file paths must be unique")
        if len({path.casefold() for path in paths}) != len(paths):
            raise ValueError("approved-file paths collide after case folding")
        required_roles = {
            ApprovalFileRole.POLICY,
            ApprovalFileRole.SPLIT_CONFIG,
            ApprovalFileRole.CODE_BUNDLE,
            ApprovalFileRole.ACQUISITION,
            ApprovalFileRole.SOURCE_EVIDENCE,
            ApprovalFileRole.SOURCE_MANIFEST,
            ApprovalFileRole.ADAPTER_COMMITMENT,
            ApprovalFileRole.ADAPTER_CONFIG,
            ApprovalFileRole.IMPLEMENTATION_CODE,
        }
        roles = {item.role for item in self.approved_files}
        if roles != required_roles:
            raise ValueError("split approval does not cover every public-file role")
        for singleton in (
            ApprovalFileRole.POLICY,
            ApprovalFileRole.SPLIT_CONFIG,
            ApprovalFileRole.CODE_BUNDLE,
        ):
            if sum(item.role == singleton for item in self.approved_files) != 1:
                raise ValueError(
                    f"split approval must contain one {singleton.value} file"
                )

    def to_dict(self) -> dict[str, object]:
        return {
            "acquisition_sha256s": list(self.acquisition_sha256s),
            "adapter_commitment_sha256s": list(
                self.adapter_commitment_sha256s
            ),
            "adapter_config_sha256s": list(self.adapter_config_sha256s),
            "approval_id": self.approval_id,
            "approved_by": self.approved_by,
            "approved_files": [item.to_dict() for item in self.approved_files],
            "approved_git_commit": self.approved_git_commit,
            "code_bundle_sha256": self.code_bundle_sha256,
            "commitment_key_fingerprint_sha256": (
                self.commitment_key_fingerprint_sha256
            ),
            "policy_generation": self.policy_generation,
            "policy_sha256": self.policy_sha256,
            "repository_id": self.repository_id,
            "schema_version": self.schema_version,
            "scope": self.scope.value,
            "seed_key_fingerprint_sha256": (
                self.seed_key_fingerprint_sha256
            ),
            "split_config_sha256": self.split_config_sha256,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> SplitApprovalRequest:
        expected = {
            "acquisition_sha256s",
            "adapter_commitment_sha256s",
            "adapter_config_sha256s",
            "approval_id",
            "approved_by",
            "approved_files",
            "approved_git_commit",
            "code_bundle_sha256",
            "commitment_key_fingerprint_sha256",
            "policy_generation",
            "policy_sha256",
            "repository_id",
            "schema_version",
            "scope",
            "seed_key_fingerprint_sha256",
            "split_config_sha256",
        }
        if set(value) != expected:
            raise ValueError("split-approval request keys differ from the schema")
        for field in ("policy_generation", "schema_version"):
            if type(value[field]) is not int:
                raise ValueError(f"split-approval {field} must be an integer")
        list_fields = {
            "acquisition_sha256s",
            "adapter_commitment_sha256s",
            "adapter_config_sha256s",
        }
        for field in list_fields:
            if not isinstance(value[field], list) or any(
                type(item) is not str for item in value[field]
            ):
                raise ValueError(f"split-approval {field} must be a string list")
        files = value["approved_files"]
        if not isinstance(files, list) or any(
            not isinstance(item, dict) for item in files
        ):
            raise ValueError("split-approval approved_files must be objects")
        scalar_fields = expected - list_fields - {
            "approved_files",
            "policy_generation",
            "schema_version",
        }
        for field in scalar_fields:
            if type(value[field]) is not str:
                raise ValueError(f"split-approval {field} must be a string")
        try:
            scope = ApprovalScope(value["scope"])
        except ValueError as error:
            raise ValueError("split-approval scope is unsupported") from error
        return cls(
            schema_version=value["schema_version"],
            repository_id=value["repository_id"],
            approval_id=value["approval_id"],
            approved_by=value["approved_by"],
            approved_git_commit=value["approved_git_commit"],
            policy_sha256=value["policy_sha256"],
            policy_generation=value["policy_generation"],
            scope=scope,
            seed_key_fingerprint_sha256=value[
                "seed_key_fingerprint_sha256"
            ],
            commitment_key_fingerprint_sha256=value[
                "commitment_key_fingerprint_sha256"
            ],
            split_config_sha256=value["split_config_sha256"],
            code_bundle_sha256=value["code_bundle_sha256"],
            acquisition_sha256s=tuple(value["acquisition_sha256s"]),
            adapter_commitment_sha256s=tuple(
                value["adapter_commitment_sha256s"]
            ),
            adapter_config_sha256s=tuple(value["adapter_config_sha256s"]),
            approved_files=tuple(ApprovedFile.from_dict(item) for item in files),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> SplitApprovalRequest:
        value, raw = _read_strict_json_object(
            path,
            label="split approval request",
        )
        request = cls.from_dict(value)
        if raw != request.canonical_bytes():
            raise ValueError(
                "split approval request is not canonical UTF-8/LF JSON"
            )
        return request


@dataclass(frozen=True)
class SplitApproval:
    """Canonical owner approval containing an external OpenSSH signature."""

    schema_version: int
    request: SplitApprovalRequest
    signature_sshsig_base64: str

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(
                f"unsupported split-approval schema: {self.schema_version}"
            )
        if type(self.signature_sshsig_base64) is not str:
            raise ValueError("split approval signature must be base64")
        _decode_sshsig(self.signature_sshsig_base64)

    def to_dict(self) -> dict[str, object]:
        return {
            "request": self.request.to_dict(),
            "schema_version": self.schema_version,
            "signature_sshsig_base64": self.signature_sshsig_base64,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> SplitApproval:
        if set(value) != {
            "request",
            "schema_version",
            "signature_sshsig_base64",
        }:
            raise ValueError("split-approval keys differ from the schema")
        if type(value["schema_version"]) is not int:
            raise ValueError("split-approval schema_version must be an integer")
        if not isinstance(value["request"], dict):
            raise ValueError("split-approval request must be an object")
        if type(value["signature_sshsig_base64"]) is not str:
            raise ValueError("split-approval signature must be a string")
        return cls(
            schema_version=value["schema_version"],
            request=SplitApprovalRequest.from_dict(value["request"]),
            signature_sshsig_base64=value["signature_sshsig_base64"],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> SplitApproval:
        value, raw = _read_strict_json_object(path, label="split approval")
        approval = cls.from_dict(value)
        if raw != approval.canonical_bytes():
            raise ValueError("split approval is not canonical UTF-8/LF JSON")
        return approval


_VERIFIED_APPROVAL_TOKEN = object()


@dataclass(frozen=True, init=False)
class VerifiedSplitApproval:
    """Trusted-process marker returned after signature/tree verification.

    The fixed CLI is the adversarial security boundary. As with every Python
    object, arbitrary code already executing in this interpreter is trusted.
    """

    approval: SplitApproval
    policy_sha256: str

    def __init__(
        self,
        *,
        approval: SplitApproval,
        policy_sha256: str,
        _token: object,
    ) -> None:
        if _token is not _VERIFIED_APPROVAL_TOKEN:
            raise ValueError(
                "verified split approval must come from approval verification"
            )
        if approval.request.policy_sha256 != policy_sha256:
            raise ValueError("verified approval policy commitment differs")
        object.__setattr__(self, "approval", approval)
        object.__setattr__(self, "policy_sha256", policy_sha256)

    @property
    def approval_sha256(self) -> str:
        return self.approval.commitment_sha256

    @property
    def scope(self) -> ApprovalScope:
        return self.approval.request.scope

    @property
    def seed_key_fingerprint_sha256(self) -> str:
        return self.approval.request.seed_key_fingerprint_sha256

    @property
    def commitment_key_fingerprint_sha256(self) -> str:
        return self.approval.request.commitment_key_fingerprint_sha256


def approved_file(
    worktree: Path,
    path: Path,
    *,
    role: ApprovalFileRole,
    canonical_bytes: bytes,
) -> ApprovedFile:
    """Create a repository-relative approval entry for already parsed bytes."""

    if type(canonical_bytes) is not bytes:
        raise ValueError("approved canonical file bytes must be bytes")
    root = _validated_worktree(worktree)
    candidate = normalize_path(path, base=root)
    if not path_is_within(candidate, root):
        raise ValueError("approved public file must be inside its worktree")
    try:
        relative = candidate.relative_to(root).as_posix()
    except ValueError as error:
        raise ValueError("cannot make approved path repository-relative") from error
    return ApprovedFile(
        path=relative,
        role=role,
        sha256=hashlib.sha256(canonical_bytes).hexdigest(),
    )


def canonical_approved_files(
    values: Iterable[ApprovedFile],
) -> tuple[ApprovedFile, ...]:
    """Return the one canonical order used by requests and exact-set checks."""

    return tuple(
        sorted(
            values,
            key=lambda item: (
                item.path.encode("utf-8"),
                item.role.value.encode("ascii"),
            ),
        )
    )


def approved_file_set(
    worktree: Path,
    entries: Iterable[tuple[Path, ApprovalFileRole, bytes]],
    *,
    implementation_files: Iterable[ApprovedFile] = (),
) -> tuple[ApprovedFile, ...]:
    """Build one canonical exact set from parsed public files and code entries."""

    values = [
        approved_file(
            worktree,
            path,
            role=role,
            canonical_bytes=canonical_bytes,
        )
        for path, role, canonical_bytes in entries
    ]
    values.extend(implementation_files)
    return canonical_approved_files(values)


def create_split_approval_request(
    *,
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
    worktree: Path,
    approval_id: str,
    approved_by: str,
    allow_nonproduction: bool,
    seed_key: bytes,
    commitment_key: bytes,
    split_config_sha256: str,
    code_bundle_sha256: str,
    acquisition_sha256s: tuple[str, ...],
    adapter_commitment_sha256s: tuple[str, ...],
    adapter_config_sha256s: tuple[str, ...],
    approved_files: tuple[ApprovedFile, ...],
) -> SplitApprovalRequest:
    """Build an exact request at a stable current HEAD for external signing."""

    _verify_policy(policy, trusted_policy_sha256)
    if seed_key == commitment_key:
        raise ValueError("split seed and commitment keys must be different")
    root = _validated_worktree(worktree)
    head_before = git_head_commit(root)
    ordered_files = canonical_approved_files(approved_files)
    _require_files_at_commit(root, head_before, ordered_files)
    request = SplitApprovalRequest(
        schema_version=1,
        repository_id=ROSID_REPOSITORY_ID,
        approval_id=approval_id,
        approved_by=approved_by,
        approved_git_commit=head_before,
        policy_sha256=policy.commitment_sha256,
        policy_generation=policy.generation,
        scope=(
            ApprovalScope.QUARANTINED_RESEARCH
            if allow_nonproduction
            else ApprovalScope.PRODUCTION
        ),
        seed_key_fingerprint_sha256=split_seed_key_fingerprint(seed_key),
        commitment_key_fingerprint_sha256=(
            split_commitment_key_fingerprint(commitment_key)
        ),
        split_config_sha256=split_config_sha256,
        code_bundle_sha256=code_bundle_sha256,
        acquisition_sha256s=tuple(sorted(acquisition_sha256s)),
        adapter_commitment_sha256s=tuple(
            sorted(adapter_commitment_sha256s)
        ),
        adapter_config_sha256s=tuple(sorted(adapter_config_sha256s)),
        approved_files=ordered_files,
    )
    _verify_request_policy(request, policy)
    if head_before != git_head_commit(root):
        raise ValueError("Git HEAD changed while preparing split approval")
    _require_files_at_commit(root, head_before, ordered_files)
    return request


def finalize_split_approval(
    request: SplitApprovalRequest,
    signature: bytes,
    *,
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
) -> SplitApproval:
    """Verify a detached SSHSIG and package it as canonical public evidence."""

    _verify_policy(policy, trusted_policy_sha256)
    _verify_request_policy(request, policy)
    signature_base64 = base64.b64encode(signature).decode("ascii")
    approval = SplitApproval(
        schema_version=1,
        request=request,
        signature_sshsig_base64=signature_base64,
    )
    _verify_sshsig(approval, policy)
    return approval


def verify_split_approval(
    approval: SplitApproval,
    *,
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
    worktree: Path,
    allow_nonproduction: bool,
    seed_key: bytes,
    commitment_key: bytes,
    split_config_sha256: str,
    code_bundle_sha256: str,
    acquisition_sha256s: tuple[str, ...],
    adapter_commitment_sha256s: tuple[str, ...],
    adapter_config_sha256s: tuple[str, ...],
    approved_files: tuple[ApprovedFile, ...],
) -> VerifiedSplitApproval:
    """Verify trust anchor, signature, scope, keys, inputs, and Git tree."""

    verify_split_approval_public(
        approval,
        policy=policy,
        trusted_policy_sha256=trusted_policy_sha256,
        worktree=worktree,
        allow_nonproduction=allow_nonproduction,
        split_config_sha256=split_config_sha256,
        code_bundle_sha256=code_bundle_sha256,
        acquisition_sha256s=acquisition_sha256s,
        adapter_commitment_sha256s=adapter_commitment_sha256s,
        adapter_config_sha256s=adapter_config_sha256s,
        approved_files=approved_files,
    )
    request = approval.request
    if seed_key == commitment_key:
        raise ValueError("split seed and commitment keys must be different")
    if request.seed_key_fingerprint_sha256 != split_seed_key_fingerprint(
        seed_key
    ):
        raise ValueError("split seed key differs from the owner approval")
    if (
        request.commitment_key_fingerprint_sha256
        != split_commitment_key_fingerprint(commitment_key)
    ):
        raise ValueError("split commitment key differs from the owner approval")
    return VerifiedSplitApproval(
        approval=approval,
        policy_sha256=policy.commitment_sha256,
        _token=_VERIFIED_APPROVAL_TOKEN,
    )


def verify_approval_policy(
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
) -> None:
    """Fail closed on a pending, revoked, or self-authored policy."""

    _verify_policy(policy, trusted_policy_sha256)


def verify_split_approval_public(
    approval: SplitApproval,
    *,
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
    worktree: Path,
    allow_nonproduction: bool,
    split_config_sha256: str,
    code_bundle_sha256: str,
    acquisition_sha256s: tuple[str, ...],
    adapter_commitment_sha256s: tuple[str, ...],
    adapter_config_sha256s: tuple[str, ...],
    approved_files: tuple[ApprovedFile, ...],
) -> None:
    """Verify all public approval material before private evidence is read."""

    _verify_policy(policy, trusted_policy_sha256)
    _verify_request_policy(approval.request, policy)
    _verify_sshsig(approval, policy)
    expected_scope = (
        ApprovalScope.QUARANTINED_RESEARCH
        if allow_nonproduction
        else ApprovalScope.PRODUCTION
    )
    request = approval.request
    if request.scope != expected_scope:
        raise ValueError("split approval has the wrong production scope")
    expected_values = (
        split_config_sha256,
        code_bundle_sha256,
        tuple(sorted(acquisition_sha256s)),
        tuple(sorted(adapter_commitment_sha256s)),
        tuple(sorted(adapter_config_sha256s)),
        canonical_approved_files(approved_files),
    )
    actual_values = (
        request.split_config_sha256,
        request.code_bundle_sha256,
        request.acquisition_sha256s,
        request.adapter_commitment_sha256s,
        request.adapter_config_sha256s,
        request.approved_files,
    )
    if actual_values != expected_values:
        raise ValueError("split approval differs from the qualifying inputs")
    root = _validated_worktree(worktree)
    _require_repository_origin(root)
    _require_commit_ancestor(root, request.approved_git_commit)
    _require_files_at_commit(root, request.approved_git_commit, approved_files)


def split_seed_key_fingerprint(key: bytes) -> str:
    return _secret_fingerprint(key, domain=_SEED_KEY_DOMAIN, label="seed")


def owner_public_key_sha256(public_key: str) -> str:
    """Return the hex fingerprint format stored in an approval policy."""

    return hashlib.sha256(_parse_ed25519_public_key(public_key)).hexdigest()


def split_commitment_key_fingerprint(key: bytes) -> str:
    return _secret_fingerprint(
        key,
        domain=_COMMITMENT_KEY_DOMAIN,
        label="commitment",
    )


def git_head_commit(worktree: Path) -> str:
    root = _validated_worktree(worktree)
    _require_repository_origin(root)
    result = _run_git(root, "rev-parse", "--verify", "HEAD^{commit}")
    if result.returncode != 0:
        raise ValueError("Git worktree has no committed HEAD")
    commit = result.stdout.decode("ascii", errors="strict").strip()
    if not _GIT_COMMIT.fullmatch(commit):
        raise ValueError("Git returned an invalid HEAD object ID")
    return commit


def _verify_policy(
    policy: ApprovalPolicy,
    trusted_policy_sha256: str,
) -> None:
    _validate_sha256(
        trusted_policy_sha256,
        label="out-of-band approval-policy SHA-256",
    )
    if policy.commitment_sha256 != trusted_policy_sha256:
        raise ValueError("approval policy differs from the out-of-band trust root")
    if policy.status == ApprovalStatus.PENDING:
        raise ValueError(
            "owner approval policy is pending; qualifying splits are disabled"
        )
    if policy.status == ApprovalStatus.REVOKED:
        raise ValueError("owner approval policy has been revoked")


def _verify_request_policy(
    request: SplitApprovalRequest,
    policy: ApprovalPolicy,
) -> None:
    if (
        request.policy_sha256 != policy.commitment_sha256
        or request.policy_generation != policy.generation
        or request.approved_by != policy.signer_identity
    ):
        raise ValueError("split approval differs from its owner policy")


def _verify_sshsig(approval: SplitApproval, policy: ApprovalPolicy) -> None:
    if policy.owner_public_key is None or policy.signer_identity is None:
        raise ValueError("active approval policy lacks verification material")
    signature = _decode_sshsig(approval.signature_sshsig_base64)
    allowed_line = (
        f"{policy.signer_identity} {policy.owner_public_key}\n"
    ).encode("ascii")
    try:
        with tempfile.TemporaryDirectory(prefix="rosid-approval-") as raw:
            temporary = Path(raw)
            allowed = temporary / "allowed_signers"
            signature_path = temporary / "approval.sig"
            allowed.write_bytes(allowed_line)
            signature_path.write_bytes(signature)
            result = subprocess.run(
                (
                    "ssh-keygen",
                    "-Y",
                    "verify",
                    "-f",
                    os.fspath(allowed),
                    "-I",
                    policy.signer_identity,
                    "-n",
                    APPROVAL_SIGNATURE_NAMESPACE,
                    "-s",
                    os.fspath(signature_path),
                ),
                check=False,
                input=approval.request.canonical_bytes(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
    except OSError as error:
        raise ValueError(f"cannot run OpenSSH approval verifier: {error}") from error
    if result.returncode != 0:
        detail = os.fsdecode(result.stderr).strip() or "invalid SSH signature"
        raise ValueError(f"owner split-approval signature is invalid: {detail}")


def _parse_ed25519_public_key(value: str) -> bytes:
    if "\n" in value or "\r" in value or value.strip() != value:
        raise ValueError("owner public key must be one canonical line")
    parts = value.split(" ")
    if len(parts) != 2 or parts[0] != "ssh-ed25519" or not parts[1]:
        raise ValueError("owner public key must be a comment-free Ed25519 key")
    try:
        blob = base64.b64decode(parts[1], validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError("owner public key has invalid base64") from error

    def field(offset: int) -> tuple[bytes, int]:
        if offset + 4 > len(blob):
            raise ValueError("owner public key blob is truncated")
        length = int.from_bytes(blob[offset : offset + 4], "big")
        start = offset + 4
        end = start + length
        if end > len(blob):
            raise ValueError("owner public key blob is truncated")
        return blob[start:end], end

    algorithm, offset = field(0)
    key, offset = field(offset)
    if algorithm != b"ssh-ed25519" or len(key) != 32 or offset != len(blob):
        raise ValueError("owner public key is not canonical Ed25519")
    return blob


def _decode_sshsig(value: str) -> bytes:
    try:
        raw = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError("split approval signature has invalid base64") from error
    if (
        not raw.startswith(b"-----BEGIN SSH SIGNATURE-----\n")
        or not raw.endswith(b"-----END SSH SIGNATURE-----\n")
        or b"\r" in raw
        or len(raw) > 100_000
    ):
        raise ValueError("split approval does not contain a canonical SSHSIG")
    return raw


def _secret_fingerprint(key: bytes, *, domain: bytes, label: str) -> str:
    if type(key) is not bytes or len(key) != 32:
        raise ValueError(f"split {label} key must contain exactly 32 bytes")
    return hashlib.sha256(domain + key).hexdigest()


def _require_files_at_commit(
    root: Path,
    approved_commit: str,
    files: Iterable[ApprovedFile],
) -> None:
    for item in files:
        tree_result = _run_git(
            root,
            "--literal-pathspecs",
            "ls-tree",
            "-z",
            "--full-tree",
            approved_commit,
            "--",
            item.path,
        )
        if tree_result.returncode != 0:
            raise ValueError(
                f"cannot inspect approved file mode at the approved commit: "
                f"{item.path}"
            )
        records = (
            tuple(tree_result.stdout[:-1].split(b"\0"))
            if tree_result.stdout.endswith(b"\0")
            else ()
        )
        expected_path = item.path.encode("utf-8")
        if len(records) != 1 or b"\t" not in records[0]:
            raise ValueError(
                f"approved file did not exist at the approved commit: {item.path}"
            )
        metadata, actual_path = records[0].split(b"\t", 1)
        try:
            mode, object_type, object_id = metadata.split(b" ")
        except ValueError as error:
            raise ValueError(
                f"approved file has a malformed Git tree entry: {item.path}"
            ) from error
        if (
            actual_path != expected_path
            or object_type != b"blob"
            or mode not in _REGULAR_GIT_FILE_MODES
            or len(object_id) not in {40, 64}
            or any(
                character not in b"0123456789abcdef"
                for character in object_id
            )
        ):
            raise ValueError(
                "approved file must use regular Git file mode 100644/100755 "
                f"at the approved commit: {item.path}"
            )
        result = _run_git(
            root,
            "--literal-pathspecs",
            "cat-file",
            "blob",
            f"{approved_commit}:{item.path}",
        )
        if result.returncode != 0:
            raise ValueError(
                f"approved file did not exist at the approved commit: {item.path}"
            )
        if hashlib.sha256(result.stdout).hexdigest() != item.sha256:
            raise ValueError(
                f"approved file bytes differ at the approved commit: {item.path}"
            )


def _require_commit_ancestor(root: Path, approved_commit: str) -> None:
    result = _run_git(
        root,
        "merge-base",
        "--is-ancestor",
        approved_commit,
        "HEAD",
    )
    if result.returncode == 1:
        raise ValueError("owner-approved Git commit is not an ancestor of HEAD")
    if result.returncode != 0:
        raise ValueError("cannot verify the owner-approved Git commit")


def _require_repository_origin(root: Path) -> None:
    result = _run_git(root, "config", "--get", "remote.origin.url")
    if result.returncode != 0:
        raise ValueError("Git worktree lacks the canonical Rosid origin")
    try:
        origin = result.stdout.decode("utf-8", errors="strict").strip()
    except UnicodeError as error:
        raise ValueError("Git origin is not valid UTF-8") from error
    if origin.casefold() not in {value.casefold() for value in _EXPECTED_ORIGINS}:
        raise ValueError("Git origin is not the canonical Rosid repository")


def _validated_worktree(path: Path) -> Path:
    expected = normalize_path(path)
    discovered = require_git_worktree(expected)
    if not paths_equal(expected, discovered):
        raise ValueError("approval worktree must be the Git repository root")
    return expected


def _run_git(root: Path, *arguments: str) -> subprocess.CompletedProcess[bytes]:
    try:
        return subprocess.run(
            ("git", *arguments),
            cwd=root,
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
        )
    except OSError as error:
        raise ValueError(f"cannot run Git approval check: {error}") from error


def _validate_sha256(value: str, *, label: str) -> None:
    if type(value) is not str or not _SHA256.fullmatch(value):
        raise ValueError(f"{label} must be 64 lowercase hexadecimal digits")


def _validate_sorted_hashes(values: tuple[str, ...], *, label: str) -> None:
    if not values or values != tuple(sorted(values)):
        raise ValueError(f"{label} must be nonempty and sorted")
    if len(values) != len(set(values)):
        raise ValueError(f"{label} must be unique")
    for value in values:
        _validate_sha256(value, label=label)


def _read_strict_json_object(
    path: Path,
    *,
    label: str,
) -> tuple[dict[str, object], bytes]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in {label}: {key}")
            result[key] = value
        return result

    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{label} root must be an object")
    return value, raw


__all__ = [
    "APPROVAL_SIGNATURE_NAMESPACE",
    "ApprovalFileRole",
    "ApprovalPolicy",
    "ApprovalScope",
    "ApprovalStatus",
    "ApprovedFile",
    "ROSID_REPOSITORY_ID",
    "SplitApproval",
    "SplitApprovalRequest",
    "VerifiedSplitApproval",
    "approved_file",
    "approved_file_set",
    "canonical_approved_files",
    "create_split_approval_request",
    "finalize_split_approval",
    "git_head_commit",
    "owner_public_key_sha256",
    "split_commitment_key_fingerprint",
    "split_seed_key_fingerprint",
    "verify_split_approval",
    "verify_approval_policy",
    "verify_split_approval_public",
]
