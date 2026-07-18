"""Verify an external SSHSIG and publish canonical split-approval evidence."""

from __future__ import annotations

import argparse
import json
import os
import stat
from pathlib import Path
from typing import Sequence

from ml.rosid_ml.acquisition import preflight_output_paths, write_new_files
from ml.rosid_ml.split_approvals import (
    ApprovalScope,
    ApprovalPolicy,
    SplitApprovalRequest,
    finalize_split_approval,
    git_head_commit,
    verify_approval_policy,
    verify_split_approval_public,
)
from ml.rosid_ml.storage import (
    paths_equal,
    require_git_worktree,
    require_private_manifest_path,
    require_public_split_path,
    require_tracked_unchanged_path,
)


_APPROVAL_POLICY_PATH = Path("ml/APPROVAL_POLICY.json")
_MAX_SSHSIG_BYTES = 100_000


def _same_identity(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        first.st_dev == second.st_dev
        and (
            first.st_ino == 0
            or second.st_ino == 0
            or first.st_ino == second.st_ino
        )
        and first.st_mode == second.st_mode
        and first.st_size == second.st_size
        and first.st_mtime_ns == second.st_mtime_ns
        and first.st_nlink == second.st_nlink
        and getattr(first, "st_file_attributes", 0)
        == getattr(second, "st_file_attributes", 0)
    )


def _same_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
    return _same_identity(first, second) and first.st_ctime_ns == second.st_ctime_ns


def _read_detached_signature(path: Path) -> bytes:
    try:
        initial = path.stat(follow_symlinks=False)
        reparse = getattr(initial, "st_file_attributes", 0) & getattr(
            stat,
            "FILE_ATTRIBUTE_REPARSE_POINT",
            0,
        )
        if (
            path.is_symlink()
            or reparse
            or not stat.S_ISREG(initial.st_mode)
            or initial.st_nlink != 1
            or initial.st_size <= 0
            or initial.st_size > _MAX_SSHSIG_BYTES
        ):
            raise ValueError(
                "detached SSH signature must be one nonempty unlinked plain file"
            )
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_identity(initial, opened):
                raise ValueError("detached SSH signature changed before reading")
            content = source.read(_MAX_SSHSIG_BYTES + 1)
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
        with path.open("rb") as confirmation:
            confirmed = confirmation.read(_MAX_SSHSIG_BYTES + 1)
            confirmed_stat = os.fstat(confirmation.fileno())
        last = path.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(f"cannot read detached SSH signature: {error}") from error
    if (
        not content
        or len(content) > _MAX_SSHSIG_BYTES
        or content != confirmed
        or not _same_snapshot(opened, finished)
        or not _same_snapshot(initial, final)
        or not _same_identity(finished, final)
        or not _same_identity(final, confirmed_stat)
        or not _same_snapshot(final, last)
    ):
        raise ValueError("detached SSH signature changed while reading")
    return content


def _require_new_output(path: Path) -> None:
    preflight_output_paths((path,))
    if path.exists() or path.is_symlink():
        raise FileExistsError(f"refusing to overwrite split approval: {path}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--trusted-approval-policy-sha256",
        required=True,
    )
    parser.add_argument("--approval-request", required=True, type=Path)
    parser.add_argument("--detached-signature", required=True, type=Path)
    parser.add_argument("--approval-output", required=True, type=Path)
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

        request_path = require_public_split_path(
            args.approval_request,
            expected_worktree=worktree,
        )
        require_tracked_unchanged_path(
            request_path,
            expected_worktree=worktree,
        )
        signature_path = require_private_manifest_path(
            args.detached_signature,
            expected_worktree=worktree,
        )
        output_path = require_public_split_path(
            args.approval_output,
            expected_worktree=worktree,
        )
        if any(
            paths_equal(output_path, source)
            for source in (policy_path, request_path, signature_path)
        ):
            raise ValueError("split approval output must differ from every input")
        _require_new_output(output_path)

        request = SplitApprovalRequest.from_json_file(request_path)
        require_tracked_unchanged_path(
            request_path,
            expected_worktree=worktree,
            expected_bytes=request.canonical_bytes(),
        )
        signature = _read_detached_signature(signature_path)
        approval = finalize_split_approval(
            request,
            signature,
            policy=policy,
            trusted_policy_sha256=args.trusted_approval_policy_sha256,
        )
        verify_split_approval_public(
            approval,
            policy=policy,
            trusted_policy_sha256=args.trusted_approval_policy_sha256,
            worktree=worktree,
            allow_nonproduction=(
                request.scope == ApprovalScope.QUARANTINED_RESEARCH
            ),
            split_config_sha256=request.split_config_sha256,
            code_bundle_sha256=request.code_bundle_sha256,
            acquisition_sha256s=request.acquisition_sha256s,
            adapter_commitment_sha256s=(
                request.adapter_commitment_sha256s
            ),
            adapter_config_sha256s=request.adapter_config_sha256s,
            approved_files=request.approved_files,
        )

        require_tracked_unchanged_path(
            policy_path,
            expected_worktree=worktree,
            expected_bytes=policy.canonical_bytes(),
        )
        require_tracked_unchanged_path(
            request_path,
            expected_worktree=worktree,
            expected_bytes=request.canonical_bytes(),
        )
        if git_head_commit(worktree) != initial_head:
            raise ValueError("Git HEAD changed while finalizing split approval")
        _require_new_output(output_path)
        write_new_files(((output_path, approval.canonical_bytes()),))
    except (OSError, ValueError) as error:
        parser.error(str(error))

    print(
        json.dumps(
            {
                "approval_sha256": approval.commitment_sha256,
                "approved_git_commit": request.approved_git_commit,
                "policy_sha256": request.policy_sha256,
                "request_sha256": request.commitment_sha256,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
