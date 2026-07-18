"""Repository-aware storage boundaries for public and private ML artifacts."""

from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path
from typing import TypeAlias


PathLike: TypeAlias = str | os.PathLike[str]

_PUBLIC_ACQUISITION_DIRECTORY = Path("ml/manifests/acquisitions")
_PUBLIC_ADAPTER_DIRECTORY = Path("ml/manifests/adapters")
_PUBLIC_DATASET_DIRECTORY = Path("ml/manifests/datasets")
_PUBLIC_SPLIT_DIRECTORY = Path("ml/manifests/splits")
_PRIVATE_MANIFEST_DIRECTORY = Path("ml/manifests/private")


def normalize_path(path: PathLike, *, base: PathLike | None = None) -> Path:
    """Return an absolute path without requiring the final path to exist.

    Existing symbolic-link and Windows reparse-point components are rejected
    before resolution. This keeps a checked repository boundary from being
    redirected through an existing filesystem alias.
    """

    raw = os.fspath(path)
    if not raw:
        raise ValueError("storage path must not be empty")
    try:
        candidate = Path(raw)
        if not candidate.is_absolute():
            origin = Path.cwd() if base is None else Path(os.fspath(base))
            if not origin.is_absolute():
                origin = Path(os.path.abspath(os.fspath(origin)))
            candidate = origin / candidate
        lexical = Path(os.path.abspath(os.fspath(candidate)))
    except (OSError, TypeError, ValueError) as error:
        raise ValueError(f"cannot normalize storage path {raw!r}: {error}") from error

    _reject_reparse_components(lexical)
    try:
        resolved = lexical.resolve(strict=False)
    except (OSError, RuntimeError) as error:
        raise ValueError(f"cannot resolve storage path {lexical}: {error}") from error
    _reject_reparse_components(resolved)
    return resolved


def paths_equal(first: PathLike, second: PathLike) -> bool:
    """Return whether two safe normalized paths identify the same location."""

    return _path_key(normalize_path(first)) == _path_key(normalize_path(second))


def path_is_within(path: PathLike, directory: PathLike) -> bool:
    """Return whether ``path`` is equal to or below ``directory``."""

    normalized_path = normalize_path(path)
    normalized_directory = normalize_path(directory)
    try:
        common = os.path.commonpath(
            (os.fspath(normalized_path), os.fspath(normalized_directory))
        )
    except ValueError:
        return False
    return _path_key(Path(common)) == _path_key(normalized_directory)


def paths_overlap(first: PathLike, second: PathLike) -> bool:
    """Return whether either safe normalized path contains the other."""

    return path_is_within(first, second) or path_is_within(second, first)


def find_git_worktree(start: PathLike | None = None) -> Path | None:
    """Find and validate the enclosing non-bare Git worktree, if one exists.

    Both a normal ``.git`` directory and the ``.git`` indirection file used by
    linked worktrees and submodules are supported.
    """

    normalized = normalize_path(Path.cwd() if start is None else start)
    try:
        start_stat = normalized.lstat()
    except FileNotFoundError:
        search_start = normalized
    except OSError as error:
        raise ValueError(
            f"cannot inspect Git search path {normalized}: {error}"
        ) from error
    else:
        search_start = (
            normalized
            if stat.S_ISDIR(start_stat.st_mode)
            else normalized.parent
        )
    candidates = (search_start, *search_start.parents)
    for candidate in candidates:
        marker = candidate / ".git"
        try:
            marker_stat = marker.lstat()
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ValueError(f"cannot inspect Git marker {marker}: {error}") from error
        if _is_reparse(marker, marker_stat):
            raise ValueError(
                f"Git marker must not be a link or reparse point: {marker}"
            )
        if not (stat.S_ISDIR(marker_stat.st_mode) or stat.S_ISREG(marker_stat.st_mode)):
            raise ValueError(f"Git marker is not a directory or file: {marker}")

        result = _run_git(candidate, "rev-parse", "--show-toplevel")
        if result.returncode != 0:
            detail = os.fsdecode(result.stderr).strip() or "git rev-parse failed"
            raise ValueError(f"invalid Git worktree marker at {marker}: {detail}")
        output = os.fsdecode(result.stdout).strip()
        if not output or "\n" in output or "\r" in output:
            raise ValueError(f"Git returned an invalid worktree root for {candidate}")
        root = normalize_path(output)
        if not paths_equal(root, candidate):
            raise ValueError(
                f"Git worktree root {root} differs from marker location {candidate}"
            )
        return root
    return None


def require_git_worktree(start: PathLike | None = None) -> Path:
    """Return the enclosing validated Git worktree or fail closed."""

    root = find_git_worktree(Path.cwd() if start is None else start)
    if root is None:
        raise ValueError("public evidence command must run inside a Git worktree")
    return root


def require_private_path(
    path: PathLike,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    """Require an in-repository private/key path to be ignored and untracked.

    A path outside any Git worktree is allowed. The returned path is normalized
    and can be used by callers after this check.
    """

    normalized = normalize_path(path)
    root = find_git_worktree(normalized)
    if root is None:
        return normalized
    if expected_worktree is not None:
        expected = _validated_expected_worktree(expected_worktree)
        if not paths_equal(root, expected):
            raise ValueError(
                "private path must be outside Git or in the expected worktree"
            )
        require_tracked_unchanged_path(
            expected / ".gitignore",
            expected_worktree=expected,
        )
    relative = _repository_relative_path(normalized, root)

    tracked = _run_git(
        root,
        "--literal-pathspecs",
        "ls-files",
        "--error-unmatch",
        "--",
        relative,
    )
    if tracked.returncode == 0:
        raise ValueError(
            f"private path inside a repository must be untracked: {normalized}"
        )
    if tracked.returncode not in {0, 1}:
        detail = os.fsdecode(tracked.stderr).strip() or "git ls-files failed"
        raise ValueError(f"cannot determine whether private path is tracked: {detail}")

    ignored = _git_check_ignore(root, relative)
    if not ignored:
        raise ValueError(
            f"private path inside a repository must be Git-ignored: {normalized}"
        )
    return normalized


def require_private_manifest_path(
    path: PathLike,
    *,
    expected_worktree: PathLike,
) -> Path:
    """Require private evidence outside Git or in its fixed ignored subtree."""

    normalized = normalize_path(path)
    root = _validated_expected_worktree(expected_worktree)
    discovered = find_git_worktree(normalized)
    if discovered is None:
        return normalized
    if not paths_equal(discovered, root):
        raise ValueError(
            "private evidence must be outside Git or in the expected worktree"
        )
    allowed_root = normalize_path(root / _PRIVATE_MANIFEST_DIRECTORY)
    if paths_equal(normalized, allowed_root) or not path_is_within(
        normalized,
        allowed_root,
    ):
        raise ValueError(
            "private evidence inside the project must be below "
            "ml/manifests/private"
        )
    ignore_policy = normalize_path(root / ".gitignore")
    require_tracked_unchanged_path(
        ignore_policy,
        expected_worktree=root,
    )
    return require_private_path(
        normalized,
        expected_worktree=root,
    )


def require_public_acquisition_path(
    path: PathLike,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    """Validate a public acquisition-evidence destination."""

    return _require_public_path(
        path,
        _PUBLIC_ACQUISITION_DIRECTORY,
        expected_worktree=expected_worktree,
    )


def require_public_adapter_path(
    path: PathLike,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    """Validate a public normalized-adapter commitment or config path."""

    return _require_public_path(
        path,
        _PUBLIC_ADAPTER_DIRECTORY,
        expected_worktree=expected_worktree,
    )


def require_public_dataset_path(
    path: PathLike,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    """Validate a reviewed public dataset-manifest path."""

    return _require_public_path(
        path,
        _PUBLIC_DATASET_DIRECTORY,
        expected_worktree=expected_worktree,
    )


def require_public_split_path(
    path: PathLike,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    """Validate a public split-commitment destination."""

    return _require_public_path(
        path,
        _PUBLIC_SPLIT_DIRECTORY,
        expected_worktree=expected_worktree,
    )


def require_tracked_unchanged_path(
    path: PathLike,
    *,
    expected_worktree: PathLike,
    expected_bytes: bytes | None = None,
) -> Path:
    """Require one regular file to be tracked and byte-identical to ``HEAD``.

    ``expected_bytes`` can bind bytes already parsed by a caller to the same
    ``HEAD`` blob, closing a path-swap window between validation and parsing.
    """

    if expected_bytes is not None and type(expected_bytes) is not bytes:
        raise ValueError("expected public input bytes must be bytes")

    normalized = normalize_path(path)
    root = _validated_expected_worktree(expected_worktree)
    discovered = find_git_worktree(normalized)
    if discovered is None or not paths_equal(discovered, root):
        raise ValueError(
            f"public input must belong to the expected Git worktree {root}: "
            f"{normalized}"
        )
    relative = _repository_relative_path(normalized, root)

    tracked = _run_git(
        root,
        "--literal-pathspecs",
        "ls-files",
        "--error-unmatch",
        "--",
        relative,
    )
    if tracked.returncode == 1:
        raise ValueError(f"public input must be tracked by Git: {normalized}")
    if tracked.returncode != 0:
        detail = os.fsdecode(tracked.stderr).strip() or "git ls-files failed"
        raise ValueError(f"cannot determine whether public input is tracked: {detail}")

    head = _run_git(root, "cat-file", "blob", f"HEAD:{relative}")
    if head.returncode != 0:
        raise ValueError(f"public input must exist in Git HEAD: {normalized}")
    index = _run_git(root, "cat-file", "blob", f":{relative}")
    if index.returncode != 0 or index.stdout != head.stdout:
        raise ValueError(
            f"public input index entry must be unchanged from Git HEAD: {normalized}"
        )
    _require_clean_git_diff(root, relative, cached=True)
    _require_clean_git_diff(root, relative, cached=False)

    actual = _read_stable_regular_file(normalized)
    if actual != head.stdout:
        raise ValueError(
            f"public input bytes must be unchanged from Git HEAD: {normalized}"
        )
    if expected_bytes is not None and expected_bytes != head.stdout:
        raise ValueError(
            f"parsed public input bytes differ from Git HEAD: {normalized}"
        )
    return normalized


def _require_public_path(
    path: PathLike,
    repository_directory: Path,
    *,
    expected_worktree: PathLike | None = None,
) -> Path:
    normalized = normalize_path(path)
    discovered = find_git_worktree(normalized)
    if expected_worktree is None:
        if discovered is None:
            return normalized
        root = discovered
    else:
        root = _validated_expected_worktree(expected_worktree)
        if discovered is None or not paths_equal(discovered, root):
            raise ValueError(
                f"public path must belong to the expected Git worktree {root}: "
                f"{normalized}"
            )

    allowed_root = normalize_path(root / repository_directory)
    if paths_equal(normalized, allowed_root) or not path_is_within(
        normalized, allowed_root
    ):
        raise ValueError(
            "public path inside a repository must be below "
            f"{repository_directory.as_posix()}: {normalized}"
        )
    relative = _repository_relative_path(normalized, root)
    if _git_check_ignore(root, relative):
        raise ValueError(
            f"public path inside a repository must not be Git-ignored: {normalized}"
        )
    return normalized


def _validated_expected_worktree(path: PathLike) -> Path:
    expected = normalize_path(path)
    discovered = find_git_worktree(expected)
    if discovered is None or not paths_equal(discovered, expected):
        raise ValueError(f"expected Git worktree root is invalid: {expected}")
    return expected


def _require_clean_git_diff(root: Path, relative: str, *, cached: bool) -> None:
    arguments = [
        "--literal-pathspecs",
        "diff",
        "--quiet",
        "--no-ext-diff",
        "--no-textconv",
    ]
    if cached:
        arguments.extend(("--cached", "HEAD"))
    arguments.extend(("--", relative))
    result = _run_git(root, *arguments)
    if result.returncode == 1:
        raise ValueError(
            "public input must be tracked and unchanged at Git HEAD: "
            f"{root / relative}"
        )
    if result.returncode != 0:
        detail = os.fsdecode(result.stderr).strip() or "git diff failed"
        raise ValueError(f"cannot verify public input against Git HEAD: {detail}")


def _read_stable_regular_file(path: Path) -> bytes:
    try:
        initial = path.stat(follow_symlinks=False)
        if (
            _is_reparse(path, initial)
            or not stat.S_ISREG(initial.st_mode)
            or initial.st_nlink != 1
        ):
            raise ValueError(f"public input must be one unlinked regular file: {path}")
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_file_identity(initial, opened):
                raise ValueError(f"public input changed before validation: {path}")
            content = source.read()
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(f"cannot read public input {path}: {error}") from error
    if (
        not _same_file_identity(opened, finished)
        or not _same_file_identity(initial, final)
        or not _same_file_identity(finished, final)
    ):
        raise ValueError(f"public input changed during validation: {path}")
    return content


def _same_file_identity(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        first.st_dev == second.st_dev
        and (first.st_ino == 0 or second.st_ino == 0 or first.st_ino == second.st_ino)
        and first.st_mode == second.st_mode
        and first.st_size == second.st_size
        and first.st_mtime_ns == second.st_mtime_ns
        and first.st_nlink == second.st_nlink
        and getattr(first, "st_file_attributes", 0)
        == getattr(second, "st_file_attributes", 0)
    )


def _git_check_ignore(root: Path, relative: str) -> bool:
    result = _run_git(
        root,
        "check-ignore",
        "--quiet",
        "--no-index",
        "--",
        relative,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 1:
        return False
    detail = os.fsdecode(result.stderr).strip() or "git check-ignore failed"
    raise ValueError(f"cannot determine Git ignore status: {detail}")


def _repository_relative_path(path: Path, root: Path) -> str:
    if not path_is_within(path, root):
        raise ValueError(f"path is not inside the discovered Git worktree: {path}")
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError as error:
        raise ValueError(f"cannot make repository-relative path for {path}") from error
    if not relative or relative == ".":
        raise ValueError("repository root is not a valid artifact path")
    return relative


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
        raise ValueError(f"cannot run Git storage-policy check: {error}") from error


def _reject_reparse_components(path: Path) -> None:
    anchor = Path(path.anchor)
    current = anchor
    parts = path.parts[1:] if path.anchor else path.parts
    for part in parts:
        current /= part
        try:
            current_stat = current.lstat()
        except FileNotFoundError:
            break
        except OSError as error:
            raise ValueError(
                f"cannot inspect storage path component {current}: {error}"
            ) from error
        if _is_reparse(current, current_stat):
            raise ValueError(
                f"storage path contains a link or reparse point: {current}"
            )


def _is_reparse(path: Path, value: os.stat_result) -> bool:
    attributes = getattr(value, "st_file_attributes", 0)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return path.is_symlink() or bool(attributes & reparse_flag)


def _path_key(path: Path) -> str:
    return os.path.normcase(os.fspath(path))
