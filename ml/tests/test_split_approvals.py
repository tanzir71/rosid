from __future__ import annotations

import inspect
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import uuid
from dataclasses import replace
from pathlib import Path

from ml.rosid_ml.provenance import canonical_json_bytes
from ml.rosid_ml.split_approvals import (
    APPROVAL_SIGNATURE_NAMESPACE,
    ROSID_REPOSITORY_ID,
    ApprovalFileRole,
    ApprovalPolicy,
    ApprovalScope,
    ApprovalStatus,
    ApprovedFile,
    SplitApproval,
    SplitApprovalRequest,
    VerifiedSplitApproval,
    approved_file,
    canonical_approved_files,
    create_split_approval_request,
    finalize_split_approval,
    git_head_commit,
    owner_public_key_sha256,
    split_commitment_key_fingerprint,
    split_seed_key_fingerprint,
    verify_approval_policy,
    verify_split_approval,
    verify_split_approval_public,
)


def _sha(label: str) -> str:
    import hashlib

    return hashlib.sha256(label.encode("utf-8")).hexdigest()


class SplitApprovalsTest(unittest.TestCase):
    """Exercise the owner signature boundary against a real Git tree."""

    def setUp(self) -> None:
        fixture_type = type(self)
        if not hasattr(fixture_type, "_fixture_repo"):
            self._build_shared_fixture()

        temporary = tempfile.TemporaryDirectory(prefix="rosid-approval-test-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.repo = self.base / "repo"
        shutil.copytree(fixture_type._fixture_repo, self.repo)
        for attribute in (
            "private_key",
            "policy",
            "seed_key",
            "commitment_key",
            "split_config_sha256",
            "code_bundle_sha256",
            "acquisition_sha256s",
            "adapter_commitment_sha256s",
            "adapter_config_sha256s",
            "approved_files",
            "approved_head",
            "request",
            "signature",
            "approval",
        ):
            setattr(self, attribute, getattr(fixture_type, f"_fixture_{attribute}"))

    def _build_shared_fixture(self) -> None:
        fixture_type = type(self)
        temporary = tempfile.TemporaryDirectory(
            prefix="rosid-approval-shared-fixture-"
        )
        fixture_type.addClassCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        self._git("init", ".")
        self._git("config", "user.name", "Rosid Approval Test")
        self._git("config", "user.email", "approval-test@example.invalid")
        self._git("config", "core.autocrlf", "false")
        self._git(
            "remote",
            "add",
            "origin",
            "https://github.com/tanzir71/rosid.git",
        )

        self.private_key, public_key = self._generate_key("owner")
        self.policy = ApprovalPolicy(
            schema_version=1,
            repository_id=ROSID_REPOSITORY_ID,
            generation=7,
            status=ApprovalStatus.ACTIVE,
            signer_identity="rosid-owner",
            owner_public_key=public_key,
            owner_public_key_sha256=owner_public_key_sha256(public_key),
        )
        self.seed_key = b"s" * 32
        self.commitment_key = b"c" * 32
        self.split_config_sha256 = _sha("split-config")
        self.code_bundle_sha256 = _sha("code-bundle")
        self.acquisition_sha256s = tuple(
            sorted((_sha("acquisition-a"), _sha("acquisition-b")))
        )
        self.adapter_commitment_sha256s = tuple(
            sorted((_sha("adapter-commitment-a"), _sha("adapter-commitment-b")))
        )
        self.adapter_config_sha256s = tuple(
            sorted((_sha("adapter-config-a"), _sha("adapter-config-b")))
        )

        paths = {
            ApprovalFileRole.POLICY: Path("ml/APPROVAL_POLICY.json"),
            ApprovalFileRole.SPLIT_CONFIG: Path("ml/splits/config.json"),
            ApprovalFileRole.CODE_BUNDLE: Path("ml/splits/code-bundle.json"),
            ApprovalFileRole.ACQUISITION: Path("ml/acquisitions/source.json"),
            ApprovalFileRole.SOURCE_EVIDENCE: Path(
                "ml/sources/source-evidence.json"
            ),
            ApprovalFileRole.SOURCE_MANIFEST: Path(
                "ml/sources/source-manifest.json"
            ),
            ApprovalFileRole.ADAPTER_COMMITMENT: Path(
                "ml/adapters/source-commitment.json"
            ),
            ApprovalFileRole.ADAPTER_CONFIG: Path(
                "ml/adapters/source-config.json"
            ),
            ApprovalFileRole.IMPLEMENTATION_CODE: Path(
                "ml/rosid_ml/adapters/source.py"
            ),
        }
        contents: dict[ApprovalFileRole, bytes] = {
            role: canonical_json_bytes({"fixture_role": role.value})
            for role in ApprovalFileRole
        }
        contents[ApprovalFileRole.POLICY] = self.policy.canonical_bytes()
        contents[ApprovalFileRole.IMPLEMENTATION_CODE] = (
            b'def adapt(value: str) -> str:\n    return value\n'
        )
        entries: list[ApprovedFile] = []
        for role in ApprovalFileRole:
            path = self.repo / paths[role]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents[role])
            entries.append(
                approved_file(
                    self.repo,
                    path,
                    role=role,
                    canonical_bytes=contents[role],
                )
            )
        self.approved_files = canonical_approved_files(entries)
        self._git("add", "--all")
        self._git("commit", "-m", "approval inputs")
        self.approved_head = git_head_commit(self.repo)

        self.request = create_split_approval_request(
            **self._create_arguments()
        )
        self.signature = self._sign(
            self.request.canonical_bytes(),
            self.private_key,
        )
        self.approval = finalize_split_approval(
            self.request,
            self.signature,
            policy=self.policy,
            trusted_policy_sha256=self.policy.commitment_sha256,
        )
        fixture_type._fixture_repo = self.repo
        for attribute in (
            "private_key",
            "policy",
            "seed_key",
            "commitment_key",
            "split_config_sha256",
            "code_bundle_sha256",
            "acquisition_sha256s",
            "adapter_commitment_sha256s",
            "adapter_config_sha256s",
            "approved_files",
            "approved_head",
            "request",
            "signature",
            "approval",
        ):
            setattr(
                fixture_type,
                f"_fixture_{attribute}",
                getattr(self, attribute),
            )

    def _git(
        self,
        *arguments: str,
        input_bytes: bytes | None = None,
    ) -> subprocess.CompletedProcess[bytes]:
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repo,
            input=input_bytes,
            stdin=(subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            shell=False,
        )
        if result.returncode != 0:
            self.fail(
                f"git {' '.join(arguments)} failed: "
                f"{os.fsdecode(result.stderr).strip()}"
            )
        return result

    def _generate_key(self, stem: str) -> tuple[Path, str]:
        private_key = self.base / f"{stem}-{uuid.uuid4().hex}"
        result = subprocess.run(
            (
                "ssh-keygen",
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-f",
                os.fspath(private_key),
            ),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            shell=False,
        )
        if result.returncode != 0:
            self.fail(
                "ssh-keygen key generation failed: "
                f"{os.fsdecode(result.stderr).strip()}"
            )
        parts = private_key.with_suffix(".pub").read_text(
            encoding="ascii"
        ).split()
        self.assertGreaterEqual(len(parts), 2)
        public_key = f"{parts[0]} {parts[1]}"
        return private_key, public_key

    def _sign(self, payload: bytes, private_key: Path) -> bytes:
        payload_path = self.base / f"payload-{uuid.uuid4().hex}"
        signature_path = Path(f"{payload_path}.sig")
        payload_path.write_bytes(payload)
        try:
            result = subprocess.run(
                (
                    "ssh-keygen",
                    "-Y",
                    "sign",
                    "-f",
                    os.fspath(private_key),
                    "-n",
                    APPROVAL_SIGNATURE_NAMESPACE,
                    os.fspath(payload_path),
                ),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                shell=False,
            )
            if result.returncode != 0:
                self.fail(
                    "ssh-keygen signing failed: "
                    f"{os.fsdecode(result.stderr).strip()}"
                )
            self.assertTrue(signature_path.is_file())
            return signature_path.read_bytes()
        finally:
            signature_path.unlink(missing_ok=True)
            payload_path.unlink(missing_ok=True)

    def _create_arguments(self, **overrides: object) -> dict[str, object]:
        values: dict[str, object] = {
            "policy": self.policy,
            "trusted_policy_sha256": self.policy.commitment_sha256,
            "worktree": self.repo,
            "approval_id": "v2-global-split-001",
            "approved_by": self.policy.signer_identity,
            "allow_nonproduction": False,
            "seed_key": self.seed_key,
            "commitment_key": self.commitment_key,
            "split_config_sha256": self.split_config_sha256,
            "code_bundle_sha256": self.code_bundle_sha256,
            "acquisition_sha256s": self.acquisition_sha256s,
            "adapter_commitment_sha256s": (
                self.adapter_commitment_sha256s
            ),
            "adapter_config_sha256s": self.adapter_config_sha256s,
            "approved_files": self.approved_files,
        }
        values.update(overrides)
        return values

    def _verify_arguments(self, **overrides: object) -> dict[str, object]:
        values = self._create_arguments()
        for key in ("approval_id", "approved_by"):
            del values[key]
        values.update(overrides)
        return values

    def _verify_public_arguments(
        self,
        **overrides: object,
    ) -> dict[str, object]:
        values = self._verify_arguments()
        del values["seed_key"]
        del values["commitment_key"]
        values.update(overrides)
        return values

    def test_canonical_round_trip_and_real_signature_verification(self) -> None:
        policy_path = self.base / "policy.json"
        request_path = self.base / "request.json"
        approval_path = self.base / "approval.json"
        policy_path.write_bytes(self.policy.canonical_bytes())
        request_path.write_bytes(self.request.canonical_bytes())
        approval_path.write_bytes(self.approval.canonical_bytes())

        self.assertEqual(ApprovalPolicy.from_json_file(policy_path), self.policy)
        self.assertEqual(
            SplitApprovalRequest.from_json_file(request_path),
            self.request,
        )
        self.assertEqual(
            SplitApproval.from_json_file(approval_path),
            self.approval,
        )
        self.assertEqual(self.request.approved_git_commit, self.approved_head)
        self.assertEqual(git_head_commit(self.repo), self.approved_head)
        self.assertEqual(
            {entry.role for entry in self.request.approved_files},
            set(ApprovalFileRole),
        )
        self.assertEqual(len(self.request.approved_files), len(ApprovalFileRole))

        verified = verify_split_approval(
            self.approval,
            **self._verify_arguments(),
        )
        self.assertIsInstance(verified, VerifiedSplitApproval)
        self.assertEqual(
            verified.approval_sha256,
            self.approval.commitment_sha256,
        )
        self.assertEqual(verified.scope, ApprovalScope.PRODUCTION)
        self.assertEqual(
            verified.seed_key_fingerprint_sha256,
            split_seed_key_fingerprint(self.seed_key),
        )
        self.assertEqual(
            verified.commitment_key_fingerprint_sha256,
            split_commitment_key_fingerprint(self.commitment_key),
        )
        self.assertFalse(any(self.base.glob("payload-*.sig")))

    def test_verification_material_cannot_sign_through_public_api(self) -> None:
        public_functions = (
            create_split_approval_request,
            finalize_split_approval,
            verify_split_approval,
            verify_split_approval_public,
        )
        for function in public_functions:
            with self.subTest(function=function.__name__):
                names = inspect.signature(function).parameters
                self.assertFalse(
                    any("private" in name or "signing_key" in name for name in names)
                )

        fake_signature = (
            b"-----BEGIN SSH SIGNATURE-----\n"
            b"verification-material-is-not-a-signature\n"
            b"-----END SSH SIGNATURE-----\n"
        )
        with self.assertRaisesRegex(ValueError, "signature is invalid"):
            finalize_split_approval(
                self.request,
                fake_signature,
                policy=self.policy,
                trusted_policy_sha256=self.policy.commitment_sha256,
            )

    def test_wrong_out_of_band_policy_hash_fails_closed(self) -> None:
        wrong_hash = _sha("untrusted-policy")
        with self.assertRaisesRegex(ValueError, "out-of-band trust root"):
            verify_approval_policy(self.policy, wrong_hash)
        with self.assertRaisesRegex(ValueError, "out-of-band trust root"):
            create_split_approval_request(
                **self._create_arguments(trusted_policy_sha256=wrong_hash)
            )
        with self.assertRaisesRegex(ValueError, "out-of-band trust root"):
            verify_split_approval_public(
                self.approval,
                **self._verify_public_arguments(
                    trusted_policy_sha256=wrong_hash
                ),
            )

    def test_pending_and_revoked_policies_fail_closed(self) -> None:
        pending = replace(
            self.policy,
            status=ApprovalStatus.PENDING,
            signer_identity=None,
            owner_public_key=None,
            owner_public_key_sha256=None,
        )
        revoked = replace(self.policy, status=ApprovalStatus.REVOKED)
        cases = (
            (pending, "pending"),
            (revoked, "revoked"),
        )
        for policy, message in cases:
            with self.subTest(status=policy.status):
                with self.assertRaisesRegex(ValueError, message):
                    verify_approval_policy(policy, policy.commitment_sha256)
                with self.assertRaisesRegex(ValueError, message):
                    create_split_approval_request(
                        **self._create_arguments(
                            policy=policy,
                            trusted_policy_sha256=policy.commitment_sha256,
                        )
                    )

    def test_signature_over_different_bytes_is_rejected(self) -> None:
        wrong_signature = self._sign(
            b"not the canonical split approval request\n",
            self.private_key,
        )
        with self.assertRaisesRegex(ValueError, "signature is invalid"):
            finalize_split_approval(
                self.request,
                wrong_signature,
                policy=self.policy,
                trusted_policy_sha256=self.policy.commitment_sha256,
            )

    def test_signature_from_wrong_public_key_is_rejected(self) -> None:
        _, other_public_key = self._generate_key("other-owner")
        other_policy = replace(
            self.policy,
            owner_public_key=other_public_key,
            owner_public_key_sha256=owner_public_key_sha256(other_public_key),
        )
        request_for_other_policy = replace(
            self.request,
            policy_sha256=other_policy.commitment_sha256,
        )
        signature_from_original_key = self._sign(
            request_for_other_policy.canonical_bytes(),
            self.private_key,
        )
        with self.assertRaisesRegex(ValueError, "signature is invalid"):
            finalize_split_approval(
                request_for_other_policy,
                signature_from_original_key,
                policy=other_policy,
                trusted_policy_sha256=other_policy.commitment_sha256,
            )

    def test_tampered_signed_fields_are_rejected(self) -> None:
        replacements: tuple[dict[str, object], ...] = (
            {"approval_id": "v2-global-split-tampered"},
            {"split_config_sha256": _sha("tampered-config")},
            {"code_bundle_sha256": _sha("tampered-code")},
            {"approved_by": "attacker"},
        )
        for fields in replacements:
            with self.subTest(fields=tuple(fields)):
                tampered = replace(self.request, **fields)
                packaged = SplitApproval(
                    schema_version=1,
                    request=tampered,
                    signature_sshsig_base64=(
                        self.approval.signature_sshsig_base64
                    ),
                )
                with self.assertRaisesRegex(
                    ValueError,
                    "owner policy|signature is invalid",
                ):
                    verify_split_approval_public(
                        packaged,
                        **self._verify_public_arguments(),
                    )

    def test_wrong_seed_and_commitment_keys_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "seed key differs"):
            verify_split_approval(
                self.approval,
                **self._verify_arguments(seed_key=b"x" * 32),
            )
        with self.assertRaisesRegex(ValueError, "commitment key differs"):
            verify_split_approval(
                self.approval,
                **self._verify_arguments(commitment_key=b"x" * 32),
            )
        with self.assertRaisesRegex(ValueError, "exactly 32 bytes"):
            split_seed_key_fingerprint(b"too short")
        with self.assertRaisesRegex(ValueError, "exactly 32 bytes"):
            split_commitment_key_fingerprint(b"too short")

    def test_production_scope_mismatch_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "wrong production scope"):
            verify_split_approval_public(
                self.approval,
                **self._verify_public_arguments(allow_nonproduction=True),
            )

    def test_missing_extra_and_duplicate_input_sets_are_rejected(self) -> None:
        cases: tuple[dict[str, object], ...] = (
            {"acquisition_sha256s": self.acquisition_sha256s[:-1]},
            {
                "adapter_commitment_sha256s": tuple(
                    sorted(
                        (*self.adapter_commitment_sha256s, _sha("extra-adapter"))
                    )
                )
            },
            {
                "adapter_config_sha256s": (
                    self.adapter_config_sha256s[0],
                    self.adapter_config_sha256s[0],
                )
            },
        )
        for fields in cases:
            with self.subTest(fields=tuple(fields)):
                with self.assertRaisesRegex(
                    ValueError,
                    "differs from the qualifying inputs",
                ):
                    verify_split_approval_public(
                        self.approval,
                        **self._verify_public_arguments(**fields),
                    )

        with self.assertRaisesRegex(ValueError, "nonempty"):
            replace(self.request, acquisition_sha256s=())
        duplicate = self.adapter_commitment_sha256s[0]
        with self.assertRaisesRegex(ValueError, "unique"):
            replace(
                self.request,
                adapter_commitment_sha256s=(duplicate, duplicate),
            )
        with self.assertRaisesRegex(ValueError, "paths must be unique"):
            replace(
                self.request,
                approved_files=canonical_approved_files(
                    (*self.approved_files, self.approved_files[-1])
                ),
            )

    def test_nonancestor_approved_commit_is_rejected(self) -> None:
        self._git("checkout", "--orphan", "unrelated-history")
        self._git("rm", "--cached", "-r", ".")
        alien = self.repo / "alien.txt"
        alien.write_bytes(b"unrelated history\n")
        self._git("add", "alien.txt")
        self._git("commit", "-m", "unrelated root")

        with self.assertRaisesRegex(ValueError, "not an ancestor"):
            verify_split_approval_public(
                self.approval,
                **self._verify_public_arguments(),
            )

    def test_file_introduced_after_approved_commit_is_rejected(self) -> None:
        extra_path = self.repo / "ml" / "rosid_ml" / "adapters" / "later.py"
        extra_bytes = b"def later() -> bool:\n    return True\n"
        extra_path.write_bytes(extra_bytes)
        self._git("add", "ml/rosid_ml/adapters/later.py")
        self._git("commit", "-m", "later implementation")
        later_file = approved_file(
            self.repo,
            extra_path,
            role=ApprovalFileRole.IMPLEMENTATION_CODE,
            canonical_bytes=extra_bytes,
        )
        later_files = canonical_approved_files(
            (*self.approved_files, later_file)
        )
        request = replace(self.request, approved_files=later_files)
        signature = self._sign(request.canonical_bytes(), self.private_key)
        approval = finalize_split_approval(
            request,
            signature,
            policy=self.policy,
            trusted_policy_sha256=self.policy.commitment_sha256,
        )

        with self.assertRaisesRegex(ValueError, "did not exist"):
            verify_split_approval_public(
                approval,
                **self._verify_public_arguments(approved_files=later_files),
            )

    def test_approved_commit_rejects_symlink_mode_materialized_as_text(self) -> None:
        implementation = next(
            item
            for item in self.approved_files
            if item.role == ApprovalFileRole.IMPLEMENTATION_CODE
        )
        self._git("config", "core.symlinks", "false")
        object_id = self._git(
            "hash-object",
            "--",
            implementation.path,
        ).stdout.decode("ascii").strip()
        self._git(
            "update-index",
            "--cacheinfo",
            f"120000,{object_id},{implementation.path}",
        )
        self._git("commit", "-m", "materialized symlink mode")
        linked_commit = git_head_commit(self.repo)
        self.assertTrue((self.repo / implementation.path).is_file())

        request = replace(self.request, approved_git_commit=linked_commit)
        signature = self._sign(request.canonical_bytes(), self.private_key)
        approval = finalize_split_approval(
            request,
            signature,
            policy=self.policy,
            trusted_policy_sha256=self.policy.commitment_sha256,
        )
        with self.assertRaisesRegex(ValueError, "regular Git file mode"):
            verify_split_approval_public(
                approval,
                **self._verify_public_arguments(),
            )

    def test_approved_commit_rejects_submodule_mode_materialized_as_text(
        self,
    ) -> None:
        implementation = next(
            item
            for item in self.approved_files
            if item.role == ApprovalFileRole.IMPLEMENTATION_CODE
        )
        self._git(
            "update-index",
            "--cacheinfo",
            f"160000,{self.approved_head},{implementation.path}",
        )
        self._git("commit", "-m", "materialized submodule mode")
        linked_commit = git_head_commit(self.repo)
        self.assertTrue((self.repo / implementation.path).is_file())

        request = replace(self.request, approved_git_commit=linked_commit)
        signature = self._sign(request.canonical_bytes(), self.private_key)
        approval = finalize_split_approval(
            request,
            signature,
            policy=self.policy,
            trusted_policy_sha256=self.policy.commitment_sha256,
        )
        with self.assertRaisesRegex(ValueError, "regular Git file mode"):
            verify_split_approval_public(
                approval,
                **self._verify_public_arguments(),
            )

    def test_wrong_repository_origin_is_rejected(self) -> None:
        self._git(
            "remote",
            "set-url",
            "origin",
            "https://github.com/attacker/rosid.git",
        )
        with self.assertRaisesRegex(ValueError, "canonical Rosid repository"):
            verify_split_approval_public(
                self.approval,
                **self._verify_public_arguments(),
            )

    def test_json_readers_require_canonical_bytes_and_unique_keys(self) -> None:
        cases = (
            (
                "policy",
                ApprovalPolicy.from_json_file,
                self.policy.to_dict(),
            ),
            (
                "request",
                SplitApprovalRequest.from_json_file,
                self.request.to_dict(),
            ),
            (
                "approval",
                SplitApproval.from_json_file,
                self.approval.to_dict(),
            ),
        )
        for label, loader, value in cases:
            with self.subTest(label=label, kind="noncanonical"):
                path = self.base / f"{label}-noncanonical.json"
                path.write_bytes(
                    json.dumps(value, sort_keys=True).encode("utf-8")
                )
                with self.assertRaisesRegex(ValueError, "not canonical"):
                    loader(path)
            with self.subTest(label=label, kind="duplicate"):
                path = self.base / f"{label}-duplicate.json"
                path.write_bytes(
                    b'{"schema_version":1,"schema_version":1}\n'
                )
                with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                    loader(path)

    def test_direct_verified_capability_forgery_is_rejected(self) -> None:
        with self.assertRaisesRegex(
            ValueError,
            "must come from approval verification",
        ):
            VerifiedSplitApproval(
                approval=self.approval,
                policy_sha256=self.policy.commitment_sha256,
                _token=object(),
            )


if __name__ == "__main__":
    unittest.main()
