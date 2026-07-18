"""Canonical commitments for the exact splitter and adapter source bundle."""

from __future__ import annotations

import ast
import hashlib
import io
import json
import keyword
import os
import re
import stat
import tokenize
import unicodedata
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from types import MappingProxyType
from typing import Iterable

from .acquisition import validate_portable_relative_path
from .provenance import canonical_json_bytes
from .storage import (
    find_git_worktree,
    normalize_path,
    path_is_within,
    paths_equal,
    require_complete_git_checkout,
)


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_MAX_CODE_FILE_BYTES = 10_000_000
_MAX_CODE_BUNDLE_BYTES = 50_000_000
_DISCOVERY_EXCLUDED_PARTS = frozenset(
    {
        ".dart_tool",
        ".git",
        ".mypy_cache",
        ".pub-cache",
        ".pytest_cache",
        ".ruff_cache",
        ".tox",
        ".venv",
        "__pycache__",
        "build",
        "node_modules",
        "venv",
    }
)
_DISCOVERY_EXCLUDED_CASEFOLDS = frozenset(
    part.casefold() for part in _DISCOVERY_EXCLUDED_PARTS
)
_FORBIDDEN_IMPORT_ROOTS = frozenset(
    part
    for part in _DISCOVERY_EXCLUDED_PARTS
    if part.isidentifier() and not keyword.iskeyword(part)
)
_FORBIDDEN_IMPORT_ROOT_KEYS = frozenset(
    unicodedata.normalize("NFKC", root).casefold() for root in _FORBIDDEN_IMPORT_ROOTS
)
_DYNAMIC_IMPORT_MODULES = frozenset(
    {
        "builtins",
        "importlib",
        "pkgutil",
        "runpy",
        "site",
        "sys",
        "zipimport",
    }
)
_DYNAMIC_CODE_CALLS = frozenset(
    {
        "__import__",
        "compile",
        "eval",
        "exec",
    }
)
_DYNAMIC_NAMESPACE_NAMES = frozenset(
    {
        "__builtins__",
        "__loader__",
        "__package__",
        "__path__",
        "__spec__",
        "globals",
        "locals",
        "vars",
    }
)
_DYNAMIC_LOOKUP_NAMES = frozenset(
    {
        *_DYNAMIC_CODE_CALLS,
        *_DYNAMIC_IMPORT_MODULES,
        *_DYNAMIC_NAMESPACE_NAMES,
    }
)

P1_ENTRYPOINT_CODE_ROLES = MappingProxyType(
    {
        "ml/build_split_manifest.py": "splitter",
        "ml/finalize_split_approval.py": "shared",
        "ml/prepare_split_approval.py": "shared",
        "ml/record_acquisition.py": "shared",
        "ml/request_split_approval.py": "shared",
        "ml/verify_dataset.py": "shared",
        "ml/verify_split_manifest.py": "splitter",
    }
)

REQUIRED_CORE_CODE_ROLES = MappingProxyType(
    {
        "ml/__init__.py": "shared",
        "ml/build_split_manifest.py": "splitter",
        "ml/finalize_split_approval.py": "shared",
        "ml/prepare_split_approval.py": "shared",
        "ml/record_acquisition.py": "shared",
        "ml/request_split_approval.py": "shared",
        "ml/verify_dataset.py": "shared",
        "ml/verify_split_manifest.py": "splitter",
        "ml/rosid_ml/__init__.py": "shared",
        "ml/rosid_ml/acquisition.py": "shared",
        "ml/rosid_ml/adapter_evidence.py": "shared",
        "ml/rosid_ml/code_bundles.py": "shared",
        "ml/rosid_ml/lineage.py": "shared",
        "ml/rosid_ml/metrics.py": "shared",
        "ml/rosid_ml/provenance.py": "shared",
        "ml/rosid_ml/split_approvals.py": "shared",
        "ml/rosid_ml/split_manifests.py": "splitter",
        "ml/rosid_ml/splits.py": "splitter",
        "ml/rosid_ml/storage.py": "shared",
    }
)


@dataclass(frozen=True)
class _LocalPythonIndex:
    """Importable repository modules without assuming they are unambiguous."""

    paths_by_module: dict[str, tuple[str, ...]]
    namespaces: frozenset[str]
    blocked_modules: frozenset[str]
    names_by_import_key: dict[str, tuple[str, ...]]


def _import_name_key(value: str) -> str:
    """Match Python's identifier normalization plus portable case folding."""

    return unicodedata.normalize("NFKC", value).casefold()


def discover_p1_implementation_paths(
    worktree_root: Path,
    *,
    adapter_paths: Iterable[str],
) -> tuple[str, ...]:
    """Return the closed local-import graph for P1 entrypoints/adapters.

    Unrelated future training, synthesis, or export modules are deliberately
    outside this graph. Any local module imported by P1 is included, package
    initializers are included because Python executes them, and recognized
    dynamic import/execution mechanisms are rejected because their source
    closure cannot be proven. This binds reviewed repository source; it is not
    a sandbox for hostile approved code or a substitute for a trusted runtime.
    """

    root = normalize_path(worktree_root)
    git_root = find_git_worktree(root)
    if git_root is not None:
        if not paths_equal(git_root, root):
            raise ValueError("P1 code discovery root must be the Git worktree root")
        require_complete_git_checkout(root)
    module_index = _local_python_module_index(root)
    entry_paths = (*P1_ENTRYPOINT_CODE_ROLES, *tuple(adapter_paths))
    pending: list[str] = []
    discovered: set[str] = set()

    def schedule_module(module: str, *, required: bool) -> bool:
        resolved, path = _resolve_local_module(
            module_index,
            module,
            required=required,
        )
        if not resolved:
            return False
        parts = module.split(".")
        for count in range(1, len(parts)):
            initializer = ".".join(parts[:count])
            _, initializer_path = _resolve_local_module(
                module_index,
                initializer,
                required=False,
            )
            if initializer_path is not None and not initializer_path.endswith(
                "/__init__.py"
            ):
                raise ValueError(
                    "local Python import traverses a non-package module: "
                    f"module={module}, parent={initializer}, "
                    f"path={initializer_path}"
                )
            if initializer_path is not None and initializer_path not in discovered:
                pending.append(initializer)
        if path is not None and path not in discovered:
            pending.append(module)
        return True

    for path in entry_paths:
        validate_portable_relative_path(path)
        module = _module_name_for_path(path)
        candidates = module_index.paths_by_module.get(module, ())
        if candidates != (path,):
            raise ValueError(f"P1 code path is not one local Python module: {path}")
        schedule_module(module, required=True)

    local_roots = {
        module.partition(".")[0]
        for module in (
            *module_index.paths_by_module,
            *module_index.namespaces,
            *module_index.blocked_modules,
        )
    }
    while pending:
        module = pending.pop()
        _, path = _resolve_local_module(module_index, module, required=True)
        if path is None:
            continue
        if path in discovered:
            continue
        discovered.add(path)
        content = _read_stable_plain_file(normalize_path(path, base=root))
        tree = _parse_static_python(content, path=path)
        package = module if path.endswith("/__init__.py") else module.rpartition(".")[0]
        for imported, required in _local_import_targets(
            tree,
            package=package,
            local_roots=local_roots,
            module_index=module_index,
        ):
            schedule_module(imported, required=required)

    return tuple(sorted(discovered, key=lambda value: value.encode("utf-8")))


def _local_python_module_index(root: Path) -> _LocalPythonIndex:
    """Index importable repository Python files without reading unrelated code."""

    collected: dict[str, list[str]] = {}
    blocked_modules: set[str] = set()

    def walk_error(error: OSError) -> None:
        raise ValueError(f"cannot inspect Python source tree: {error}") from error

    for raw_directory, directory_names, file_names in os.walk(
        root,
        topdown=True,
        onerror=walk_error,
        followlinks=False,
    ):
        directory = Path(raw_directory)
        try:
            relative_directory = directory.relative_to(root)
        except ValueError as error:
            raise ValueError(
                f"Python source directory escapes its worktree: {directory}"
            ) from error

        retained_directories: list[str] = []
        for name in directory_names:
            if name.casefold() in _DISCOVERY_EXCLUDED_CASEFOLDS:
                module = _module_name_for_parts((*relative_directory.parts, name))
                if module is not None:
                    blocked_modules.add(module)
                continue
            candidate = directory / name
            try:
                metadata = candidate.lstat()
            except OSError as error:
                raise ValueError(
                    f"cannot inspect Python package directory {candidate}: {error}"
                ) from error
            if _is_link_or_reparse(metadata) or not stat.S_ISDIR(metadata.st_mode):
                module = _module_name_for_parts((*relative_directory.parts, name))
                if module is not None:
                    blocked_modules.add(module)
                continue
            retained_directories.append(name)
        directory_names[:] = retained_directories

        for name in file_names:
            relative = (relative_directory / name).as_posix()
            candidate = directory / name
            if name.endswith(".py"):
                if name.casefold() == "__init__.py" and name != "__init__.py":
                    module = _module_name_for_parts(relative_directory.parts)
                    if module is not None:
                        blocked_modules.add(module)
                    continue
                module = _module_name_for_source_path(relative)
                if module is None:
                    # Such a file cannot be reached by a static Python import.
                    # An explicitly configured adapter path is checked separately.
                    continue
                try:
                    validate_portable_relative_path(relative)
                except ValueError:
                    blocked_modules.add(module)
                    continue
                try:
                    metadata = candidate.lstat()
                except OSError as error:
                    raise ValueError(
                        f"cannot inspect Python source {candidate}: {error}"
                    ) from error
                if _is_link_or_reparse(metadata) or not stat.S_ISREG(metadata.st_mode):
                    blocked_modules.add(module)
                    continue
                collected.setdefault(module, []).append(relative)
                continue
            module = _blocked_import_artifact_module(relative)
            if module is not None:
                blocked_modules.add(module)

    paths_by_module = {
        module: tuple(sorted(paths, key=lambda value: value.encode("utf-8")))
        for module, paths in collected.items()
    }
    namespaces: set[str] = set()
    for module in (*paths_by_module, *blocked_modules):
        parts = module.split(".")
        for count in range(1, len(parts)):
            parent = ".".join(parts[:count])
            if parent not in paths_by_module and parent not in blocked_modules:
                namespaces.add(parent)

    folded: dict[str, list[str]] = {}
    for name in (*paths_by_module, *namespaces, *blocked_modules):
        folded.setdefault(_import_name_key(name), []).append(name)
    names_by_import_key = {
        folded_name: tuple(sorted(set(names), key=lambda value: value.encode("utf-8")))
        for folded_name, names in folded.items()
    }
    return _LocalPythonIndex(
        paths_by_module=paths_by_module,
        namespaces=frozenset(namespaces),
        blocked_modules=frozenset(blocked_modules),
        names_by_import_key=names_by_import_key,
    )


def _module_name_for_parts(parts: tuple[str, ...]) -> str | None:
    if not parts or any(
        not part.isidentifier() or keyword.iskeyword(part) for part in parts
    ):
        return None
    return ".".join(parts)


def _blocked_import_artifact_module(path: str) -> str | None:
    """Identify bytecode/native/case-variant files that static source cannot bind."""

    parts = path.split("/")
    filename = parts[-1]
    folded = filename.casefold()
    if folded.endswith((".py", ".pyw")):
        if filename.endswith(".py"):
            return None
        stem = filename[: -len(Path(filename).suffix)]
    elif folded.endswith(".pyc"):
        stem = filename[:-4]
    elif folded.endswith((".pyd", ".so")):
        stem = filename.split(".", 1)[0]
    else:
        return None
    module_parts = (
        (*parts[:-1],) if stem.casefold() == "__init__" else (*parts[:-1], stem)
    )
    return _module_name_for_parts(module_parts)


def _is_link_or_reparse(metadata: os.stat_result) -> bool:
    return stat.S_ISLNK(metadata.st_mode) or bool(
        getattr(metadata, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    )


def _module_name_for_path(path: str) -> str:
    validate_portable_relative_path(path)
    module = _module_name_for_source_path(path)
    if module is None:
        raise ValueError(f"path is not an importable Python module: {path}")
    return module


def _module_name_for_source_path(path: str) -> str | None:
    if not path.endswith(".py"):
        return None
    parts = path[:-3].split("/")
    if parts[-1] == "__init__":
        parts.pop()
    return _module_name_for_parts(tuple(parts))


def _resolve_local_module(
    index: _LocalPythonIndex,
    module: str,
    *,
    required: bool,
) -> tuple[bool, str | None]:
    """Resolve one exact-case local module or namespace package."""

    folded = index.names_by_import_key.get(_import_name_key(module), ())
    if len(folded) > 1:
        raise ValueError(
            "local Python modules collide after import normalization/case folding: "
            f"requested={module}, available={list(folded)}"
        )
    parts = module.split(".")
    for count in range(1, len(parts) + 1):
        prefix = ".".join(parts[:count])
        blocked = tuple(
            candidate
            for candidate in index.blocked_modules
            if _import_name_key(candidate) == _import_name_key(prefix)
        )
        if blocked:
            if prefix not in blocked:
                raise ValueError(
                    "local Python import differs only by case or Unicode "
                    "normalization: "
                    f"requested={prefix}, available={list(blocked)}"
                )
            raise ValueError(
                "local Python import traverses linked, nonportable, bytecode-only, "
                f"or native code that cannot enter the source bundle: {prefix}"
            )
    if (
        module not in index.paths_by_module
        and module not in index.namespaces
        and module not in index.blocked_modules
    ):
        if folded:
            raise ValueError(
                "local Python import differs only by case or Unicode normalization: "
                f"requested={module}, available={list(folded)}"
            )
        if required:
            raise ValueError(f"cannot resolve local Python import: {module}")
        return False, None
    paths = index.paths_by_module.get(module, ())
    if len(paths) > 1:
        raise ValueError(
            f"local Python module is ambiguous: module={module}, paths={list(paths)}"
        )
    if paths:
        return True, paths[0]
    if module in index.namespaces and not _namespace_has_concrete_package(
        index,
        module,
    ):
        raise ValueError(
            f"top-level namespace-package resolution cannot be proven: {module}"
        )
    return True, None


def _namespace_has_concrete_package(
    index: _LocalPythonIndex,
    module: str,
) -> bool:
    parts = module.split(".")
    for count in range(1, len(parts)):
        prefix = ".".join(parts[:count])
        paths = index.paths_by_module.get(prefix, ())
        if len(paths) == 1 and paths[0].endswith("/__init__.py"):
            return True
    return False


def _parse_static_python(content: bytes, *, path: str) -> ast.Module:
    """Parse one UTF-8 source file and reject recognized dynamic execution."""

    if not content:
        raise ValueError(f"P1 Python code must not be empty: {path}")
    try:
        encoding, _ = tokenize.detect_encoding(io.BytesIO(content).readline)
    except (SyntaxError, UnicodeError) as error:
        raise ValueError(f"cannot detect P1 Python encoding: {path}") from error
    if encoding != "utf-8":
        raise ValueError(
            f"P1 Python code must declare plain UTF-8 when encoded: {path}"
        )
    try:
        source = content.decode(encoding)
    except UnicodeError as error:
        raise ValueError(f"P1 Python code is not UTF-8: {path}") from error
    try:
        tree = ast.parse(source, filename=path)
    except SyntaxError as error:
        raise ValueError(f"cannot parse P1 Python code {path}: {error}") from error

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            dynamic = sorted(
                alias.name.partition(".")[0]
                for alias in node.names
                if alias.name.partition(".")[0] in _DYNAMIC_IMPORT_MODULES
            )
            if dynamic:
                raise ValueError(
                    f"dynamic Python import module is forbidden in {path}: {dynamic}"
                )
        elif isinstance(node, ast.ImportFrom):
            if any(alias.name == "*" for alias in node.names):
                raise ValueError(
                    f"dynamic Python star imports are forbidden in P1 code: {path}"
                )
            imported_root = (
                (node.module or "").partition(".")[0] if node.level == 0 else ""
            )
            if imported_root in _DYNAMIC_IMPORT_MODULES:
                raise ValueError(
                    "dynamic Python import module is forbidden in "
                    f"{path}: {imported_root}"
                )
        elif isinstance(node, ast.Name) and (
            (isinstance(node.ctx, ast.Load) and node.id in _DYNAMIC_CODE_CALLS)
            or node.id in _DYNAMIC_NAMESPACE_NAMES
        ):
            raise ValueError(
                f"dynamic Python execution is forbidden in {path}: {node.id}"
            )
        elif isinstance(node, ast.Attribute) and (
            node.attr in _DYNAMIC_NAMESPACE_NAMES
            or (
                node.attr in _DYNAMIC_CODE_CALLS
                and not (
                    node.attr == "compile"
                    and isinstance(node.value, ast.Name)
                    and node.value.id == "re"
                )
            )
        ):
            raise ValueError(
                f"dynamic Python execution is forbidden in {path}: .{node.attr}"
            )
        elif (
            isinstance(node, ast.Subscript)
            and isinstance(node.slice, ast.Constant)
            and isinstance(node.slice.value, str)
            and node.slice.value in _DYNAMIC_LOOKUP_NAMES
        ):
            raise ValueError(
                "dynamic Python namespace lookup is forbidden in "
                f"{path}: {node.slice.value}"
            )
        elif (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id in {"delattr", "getattr", "setattr"}
            and len(node.args) >= 2
            and isinstance(node.args[1], ast.Constant)
            and isinstance(node.args[1].value, str)
            and node.args[1].value in _DYNAMIC_LOOKUP_NAMES
        ):
            raise ValueError(
                "dynamic Python attribute lookup is forbidden in "
                f"{path}: {node.args[1].value}"
            )
    return tree


def _local_import_targets(
    tree: ast.Module,
    *,
    package: str,
    local_roots: set[str],
    module_index: _LocalPythonIndex,
) -> tuple[tuple[str, bool], ...]:
    """Return concrete/possible local targets from all static imports."""

    targets: list[tuple[str, bool]] = []
    local_root_keys = {_import_name_key(root) for root in local_roots}

    def root_is_local(imported: str) -> bool:
        root = imported.partition(".")[0]
        if _import_name_key(root) in _FORBIDDEN_IMPORT_ROOT_KEYS:
            raise ValueError(
                "imports from generated or environment directories are forbidden: "
                f"{imported}"
            )
        return root in local_roots or _import_name_key(root) in local_root_keys

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if root_is_local(alias.name):
                    targets.append((alias.name, True))
            continue
        if not isinstance(node, ast.ImportFrom):
            continue

        if node.level:
            if not package:
                raise ValueError("relative import has no containing local package")
            package_parts = package.split(".")
            if node.level > len(package_parts):
                raise ValueError(
                    "relative import escapes its containing local package: "
                    f"package={package}, level={node.level}"
                )
            base_parts = package_parts[: len(package_parts) - node.level + 1]
            if node.module:
                base_parts.extend(node.module.split("."))
            base = ".".join(base_parts)
            is_local = True
        else:
            base = node.module or ""
            is_local = bool(base) and root_is_local(base)
        if not is_local:
            continue

        targets.append((base, True))
        for alias in node.names:
            if alias.name == "*":
                continue
            child = f"{base}.{alias.name}"
            # A from-import name can be either a submodule or an attribute.
            # Schedule it only if repository structure makes it a possible
            # submodule; exact/case ambiguity is checked by the resolver.
            folded = module_index.names_by_import_key.get(
                _import_name_key(child),
                (),
            )
            if (
                child in module_index.paths_by_module
                or child in module_index.namespaces
                or folded
            ):
                targets.append((child, False))
    return tuple(targets)


class CodeRole(StrEnum):
    """Why one repository file can influence normalized split inputs."""

    SPLITTER = "splitter"
    ADAPTER = "adapter"
    SHARED = "shared"


@dataclass(frozen=True)
class CodeFileEntry:
    """One exact repository-relative file in an approved code bundle."""

    path: str
    role: CodeRole
    bytes: int
    sha256: str

    def __post_init__(self) -> None:
        validate_portable_relative_path(self.path)
        if not isinstance(self.role, CodeRole):
            raise ValueError("code-file role must be a CodeRole")
        if (
            type(self.bytes) is not int
            or self.bytes <= 0
            or self.bytes > _MAX_CODE_FILE_BYTES
        ):
            raise ValueError("code-file bytes must be between 1 and 10,000,000")
        if not _SHA256.fullmatch(self.sha256):
            raise ValueError(
                "code-file SHA-256 must be 64 lowercase hexadecimal digits"
            )

    def to_dict(self) -> dict[str, object]:
        return {
            "bytes": self.bytes,
            "path": self.path,
            "role": self.role.value,
            "sha256": self.sha256,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> CodeFileEntry:
        if set(value) != {"bytes", "path", "role", "sha256"}:
            raise ValueError("code-file keys differ from the schema")
        if type(value["bytes"]) is not int:
            raise ValueError("code-file bytes must be an integer")
        for field in ("path", "role", "sha256"):
            if type(value[field]) is not str:
                raise ValueError(f"code-file {field} must be a string")
        try:
            role = CodeRole(value["role"])
        except ValueError as error:
            raise ValueError("code-file role is unsupported") from error
        return cls(
            path=value["path"],
            role=role,
            bytes=value["bytes"],
            sha256=value["sha256"],
        )


@dataclass(frozen=True)
class CodeBundleManifest:
    """Canonical splitter/adapter source snapshot approved through Git."""

    schema_version: int
    files: tuple[CodeFileEntry, ...]

    def __post_init__(self) -> None:
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError(f"unsupported code-bundle schema: {self.schema_version}")
        if not self.files:
            raise ValueError("code bundle must contain files")
        paths = tuple(entry.path for entry in self.files)
        if paths != tuple(sorted(paths, key=lambda value: value.encode("utf-8"))):
            raise ValueError("code-bundle files must be sorted by path")
        if len(paths) != len(set(paths)):
            raise ValueError("code-bundle file paths must be unique")
        folded = [_import_name_key(path) for path in paths]
        if len(folded) != len(set(folded)):
            raise ValueError(
                "code-bundle paths collide after import normalization/case folding"
            )
        roles = {entry.role for entry in self.files}
        if CodeRole.SPLITTER not in roles or CodeRole.ADAPTER not in roles:
            raise ValueError("code bundle must contain splitter and adapter source")
        if sum(entry.bytes for entry in self.files) > _MAX_CODE_BUNDLE_BYTES:
            raise ValueError("code bundle exceeds 50,000,000 bytes")

    def to_dict(self) -> dict[str, object]:
        return {
            "files": [entry.to_dict() for entry in self.files],
            "schema_version": self.schema_version,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @property
    def commitment_sha256(self) -> str:
        return hashlib.sha256(self.canonical_bytes()).hexdigest()

    def verify_worktree(self, worktree_root: Path) -> None:
        """Rehash every declared file from one safe repository worktree."""

        root = normalize_path(worktree_root)
        for entry in self.files:
            candidate = normalize_path(entry.path, base=root)
            if not path_is_within(candidate, root):
                raise ValueError(f"code-bundle path escapes its worktree: {entry.path}")
            content = _read_stable_plain_file(candidate)
            if len(content) != entry.bytes:
                raise ValueError(f"code-bundle byte count differs for {entry.path}")
            if hashlib.sha256(content).hexdigest() != entry.sha256:
                raise ValueError(f"code-bundle SHA-256 differs for {entry.path}")

    def require_exact_implementation(
        self,
        *,
        adapter_paths: Iterable[str],
        worktree_root: Path,
    ) -> None:
        """Reject omitted, extra, or mislabelled executable P1 code."""

        supplied_adapters = tuple(adapter_paths)
        adapter_values = tuple(
            sorted(set(supplied_adapters), key=lambda value: value.encode("utf-8"))
        )
        if len(adapter_values) != len(supplied_adapters):
            raise ValueError("adapter code paths must be unique")
        for path in adapter_values:
            validate_portable_relative_path(path)
            if not path.startswith("ml/rosid_ml/adapters/") or not path.endswith(".py"):
                raise ValueError("adapter code must be below ml/rosid_ml/adapters")
        root = normalize_path(worktree_root)
        adapter_root = normalize_path("ml/rosid_ml/adapters", base=root)
        discovered_adapter_paths: set[str] = set()
        if adapter_root.exists():
            for raw_candidate in adapter_root.rglob("*.py"):
                candidate = normalize_path(raw_candidate)
                content = _read_stable_plain_file(candidate)
                if not content:
                    raise ValueError(f"adapter code must not be empty: {candidate}")
                try:
                    relative = candidate.relative_to(root).as_posix()
                except ValueError as error:
                    raise ValueError(
                        f"adapter code escapes its worktree: {candidate}"
                    ) from error
                discovered_adapter_paths.add(relative)
        if set(adapter_values) != discovered_adapter_paths:
            raise ValueError(
                "adapter configs must name every Python file in the adapter "
                "package; "
                f"missing={sorted(discovered_adapter_paths - set(adapter_values))}, "
                f"extra={sorted(set(adapter_values) - discovered_adapter_paths)}"
            )
        implementation_paths = set(
            discover_p1_implementation_paths(
                root,
                adapter_paths=adapter_values,
            )
        )
        discovered_core_paths = implementation_paths - set(adapter_values)
        declared_core_paths = set(REQUIRED_CORE_CODE_ROLES)
        if declared_core_paths != discovered_core_paths:
            raise ValueError(
                "fixed P1 code closure differs from its transitive local-import "
                "graph; "
                f"missing={sorted(discovered_core_paths - declared_core_paths)}, "
                f"stale={sorted(declared_core_paths - discovered_core_paths)}"
            )
        expected = {
            path: CodeRole(role) for path, role in REQUIRED_CORE_CODE_ROLES.items()
        }
        for path in adapter_values:
            if path in expected:
                raise ValueError(f"adapter code collides with core code: {path}")
            expected[path] = CodeRole.ADAPTER
        actual = {entry.path: entry.role for entry in self.files}
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        wrong_roles = sorted(
            path
            for path in set(expected) & set(actual)
            if actual[path] != expected[path]
        )
        if missing or extra or wrong_roles:
            raise ValueError(
                "code bundle differs from the exact P1 implementation closure; "
                f"missing={missing}, extra={extra}, wrong_roles={wrong_roles}"
            )

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> CodeBundleManifest:
        if set(value) != {"files", "schema_version"}:
            raise ValueError("code-bundle keys differ from the schema")
        if type(value["schema_version"]) is not int:
            raise ValueError("code-bundle schema_version must be an integer")
        files = value["files"]
        if not isinstance(files, list) or any(
            not isinstance(item, dict) for item in files
        ):
            raise ValueError("code-bundle files must be an object list")
        return cls(
            schema_version=value["schema_version"],
            files=tuple(CodeFileEntry.from_dict(item) for item in files),
        )

    @classmethod
    def from_json_file(cls, path: Path) -> CodeBundleManifest:
        value, raw = _read_strict_json_object(path)
        manifest = cls.from_dict(value)
        if raw != manifest.canonical_bytes():
            raise ValueError(f"code bundle is not canonical UTF-8/LF JSON: {path}")
        return manifest


def build_code_bundle(
    worktree_root: Path,
    *,
    splitter_files: Iterable[Path],
    adapter_files: Iterable[Path],
    shared_files: Iterable[Path] = (),
) -> CodeBundleManifest:
    """Snapshot exact worktree files for review as a canonical code bundle."""

    root = normalize_path(worktree_root)
    entries: list[CodeFileEntry] = []
    for role, paths in (
        (CodeRole.SPLITTER, splitter_files),
        (CodeRole.ADAPTER, adapter_files),
        (CodeRole.SHARED, shared_files),
    ):
        for path in paths:
            candidate = normalize_path(path, base=root)
            if not path_is_within(candidate, root):
                raise ValueError(f"code file is outside its worktree: {path}")
            try:
                relative = candidate.relative_to(root).as_posix()
            except ValueError as error:
                raise ValueError(
                    f"cannot make code path repository-relative: {path}"
                ) from error
            validate_portable_relative_path(relative)
            content = _read_stable_plain_file(candidate)
            entries.append(
                CodeFileEntry(
                    path=relative,
                    role=role,
                    bytes=len(content),
                    sha256=hashlib.sha256(content).hexdigest(),
                )
            )
    entries.sort(key=lambda entry: entry.path.encode("utf-8"))
    return CodeBundleManifest(schema_version=1, files=tuple(entries))


def _read_stable_plain_file(path: Path) -> bytes:
    try:
        initial = path.stat(follow_symlinks=False)
        attributes = getattr(initial, "st_file_attributes", 0)
        reparse = attributes & getattr(
            stat,
            "FILE_ATTRIBUTE_REPARSE_POINT",
            0,
        )
        if (
            path.is_symlink()
            or reparse
            or not stat.S_ISREG(initial.st_mode)
            or initial.st_nlink != 1
        ):
            raise ValueError(f"code input must be one unlinked plain file: {path}")
        if initial.st_size > _MAX_CODE_FILE_BYTES:
            raise ValueError(f"code input exceeds 10,000,000 bytes: {path}")
        with path.open("rb") as source:
            opened = os.fstat(source.fileno())
            if not _same_identity(initial, opened):
                raise ValueError(f"code input changed before reading: {path}")
            content = source.read(_MAX_CODE_FILE_BYTES + 1)
            finished = os.fstat(source.fileno())
        final = path.stat(follow_symlinks=False)
        with path.open("rb") as confirmation:
            confirmed = confirmation.read(_MAX_CODE_FILE_BYTES + 1)
            confirmed_stat = os.fstat(confirmation.fileno())
        last = path.stat(follow_symlinks=False)
    except OSError as error:
        raise ValueError(f"cannot read code input {path}: {error}") from error
    if (
        len(content) > _MAX_CODE_FILE_BYTES
        or not _same_snapshot(opened, finished)
        or not _same_snapshot(initial, final)
        or not _same_identity(finished, final)
        or not _same_identity(final, confirmed_stat)
        or not _same_snapshot(final, last)
        or content != confirmed
    ):
        raise ValueError(f"code input changed while reading: {path}")
    return content


def _same_identity(first: os.stat_result, second: os.stat_result) -> bool:
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


def _same_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
    return _same_identity(first, second) and first.st_ctime_ns == second.st_ctime_ns


def _read_strict_json_object(path: Path) -> tuple[dict[str, object], bytes]:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in code bundle: {key}")
            result[key] = value
        return result

    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read code-bundle manifest {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError("code-bundle manifest root must be an object")
    return value, raw
