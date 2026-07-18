"""Fail-closed extraction for reviewed ZIP dataset archives.

The extractor never delegates path creation to :mod:`zipfile`. It bounds and
scans the central directory before Python parses it, validates the complete
member plan, reserves a fresh private destination, writes only regular files,
and inventories and seals the result before returning it.

This is a trusted-operator boundary, not a hostile-filesystem sandbox. The
opened source archive, its filesystem namespace, parent directories, and the
destination must not be mutated concurrently while an extraction is running.
The final re-hash detects ordinary drift; it cannot retroactively bound parsing
under a hostile concurrent writer.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import stat
import struct
import unicodedata
import zipfile
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Final

from .acquisition import (
    DirectoryInventory,
    inventory_directory,
    validate_portable_relative_path,
)
from .provenance import DatasetSource, Eligibility
from .storage import normalize_path, paths_overlap


_WINDOWS_REPARSE_POINT: Final = 0x400
_DOS_DIRECTORY: Final = 0x10
_MAX_PORTABLE_COMPONENT_BYTES: Final = 255
_MAX_PORTABLE_PATH_BYTES: Final = 4096
_COPY_CHUNK_BYTES: Final = 1024 * 1024
_ESTIMATED_ENTRY_DISK_OVERHEAD_BYTES: Final = 64 * 1024
_MINIMUM_FREE_INODES_AFTER: Final = 1024
_EOCD_SIGNATURE: Final = b"PK\x05\x06"
_ZIP64_EOCD_SIGNATURE: Final = b"PK\x06\x06"
_ZIP64_LOCATOR_SIGNATURE: Final = b"PK\x06\x07"
_CENTRAL_MEMBER_SIGNATURE: Final = b"PK\x01\x02"
_SUPPORTED_COMPRESSION: Final = frozenset(
    {
        zipfile.ZIP_STORED,
        zipfile.ZIP_DEFLATED,
    }
)
SAFE_ZIP_EXTRACTOR_ID: Final = "rosid-safe-zip/1"


class SafeExtractionError(ValueError):
    """A reviewed archive cannot be extracted without violating policy."""


@dataclass(frozen=True)
class ZipExtractionLimits:
    """Explicit resource ceilings for one extraction attempt."""

    max_members: int
    max_central_directory_bytes: int
    max_total_uncompressed_bytes: int
    max_member_uncompressed_bytes: int
    max_compression_ratio: int
    minimum_free_bytes_after: int

    def __post_init__(self) -> None:
        positive = {
            "maximum ZIP members": self.max_members,
            "maximum central-directory bytes": self.max_central_directory_bytes,
            "maximum total uncompressed bytes": self.max_total_uncompressed_bytes,
            "maximum member uncompressed bytes": self.max_member_uncompressed_bytes,
            "maximum compression ratio": self.max_compression_ratio,
        }
        for label, value in positive.items():
            if type(value) is not int or value <= 0:
                raise SafeExtractionError(f"{label} must be a positive integer")
        if (
            type(self.minimum_free_bytes_after) is not int
            or self.minimum_free_bytes_after <= 0
        ):
            raise SafeExtractionError(
                "minimum free bytes after extraction must be a positive integer"
            )
        if self.max_member_uncompressed_bytes > self.max_total_uncompressed_bytes:
            raise SafeExtractionError(
                "per-member byte ceiling must not exceed the total byte ceiling"
            )

    def to_dict(self) -> dict[str, int]:
        return {
            "max_central_directory_bytes": self.max_central_directory_bytes,
            "max_compression_ratio": self.max_compression_ratio,
            "max_member_uncompressed_bytes": self.max_member_uncompressed_bytes,
            "max_members": self.max_members,
            "max_total_uncompressed_bytes": self.max_total_uncompressed_bytes,
            "minimum_free_bytes_after": self.minimum_free_bytes_after,
        }


@dataclass(frozen=True)
class SafeExtractionResult:
    """Private result of one verified extraction."""

    dataset_id: str
    destination: Path
    inventory: DirectoryInventory
    member_count: int
    directory_count: int
    compressed_bytes: int

    @property
    def file_count(self) -> int:
        return len(self.inventory.files)


@dataclass(frozen=True)
class _PlannedMember:
    info: zipfile.ZipInfo
    relative_path: str
    is_directory: bool


@dataclass(frozen=True)
class _ExtractionPlan:
    members: tuple[_PlannedMember, ...]
    file_count: int
    directory_count: int
    filesystem_entry_count: int
    total_uncompressed_bytes: int
    compressed_bytes: int


def safe_extract_zip(
    source: DatasetSource,
    archive_path: Path,
    destination: Path,
    *,
    limits: ZipExtractionLimits,
    require_production: bool = True,
) -> SafeExtractionResult:
    """Verify and safely extract one canonical dataset ZIP into a fresh path."""

    if not isinstance(source, DatasetSource):
        raise SafeExtractionError("source must be a validated DatasetSource")
    if not isinstance(limits, ZipExtractionLimits):
        raise SafeExtractionError("limits must be validated ZipExtractionLimits")
    if type(require_production) is not bool:
        raise SafeExtractionError("require_production must be a boolean")
    if source.eligibility == Eligibility.EXCLUDED:
        raise SafeExtractionError(f"{source.dataset_id} is excluded from acquisition")
    if require_production and source.eligibility != Eligibility.PRODUCTION:
        raise SafeExtractionError(
            f"{source.dataset_id} eligibility is {source.eligibility.value}, "
            "not production"
        )

    archive = normalize_path(archive_path)
    target = normalize_path(destination)
    if archive.name != source.filename:
        raise SafeExtractionError(
            "archive leaf name differs from the reviewed source manifest"
        )
    if paths_overlap(archive, target):
        raise SafeExtractionError(
            "source archive and extraction target must not overlap"
        )
    if os.path.lexists(os.fspath(target)):
        raise SafeExtractionError("extraction target must not already exist")

    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = normalize_path(target)
    if os.path.lexists(os.fspath(target)):
        raise SafeExtractionError("extraction target must not already exist")
    parent_initial = _require_plain_directory(
        target.parent,
        label="extraction target parent",
    )

    target_created = False
    target_identity: os.stat_result | None = None
    committed = False
    try:
        initial = _require_unlinked_regular_file(archive, label="dataset archive")
        if initial.st_size != source.bytes:
            raise SafeExtractionError(
                f"dataset byte count is {initial.st_size}; expected {source.bytes}"
            )

        with archive.open("rb") as archive_file:
            opened = os.fstat(archive_file.fileno())
            if not _same_file_identity(initial, opened):
                raise SafeExtractionError("dataset archive changed before verification")
            first_sha256, first_bytes = _hash_open_file(archive_file)
            if first_bytes != source.bytes:
                raise SafeExtractionError(
                    f"dataset byte count is {first_bytes}; expected {source.bytes}"
                )
            if first_sha256 != source.sha256:
                raise SafeExtractionError(
                    f"dataset SHA-256 is {first_sha256}; expected {source.sha256}"
                )

            expected_members = _preflight_zip_directory(
                archive_file,
                archive_bytes=first_bytes,
                limits=limits,
            )
            archive_file.seek(0)
            try:
                with zipfile.ZipFile(archive_file, mode="r", allowZip64=True) as zipped:
                    plan = _build_plan(
                        zipped,
                        limits,
                        expected_members=expected_members,
                    )
                    _require_disk_capacity(
                        target.parent,
                        plan.total_uncompressed_bytes,
                        plan.filesystem_entry_count,
                        limits.minimum_free_bytes_after,
                    )
                    target.mkdir(mode=0o700, exist_ok=False)
                    target_created = True
                    target_identity = _require_plain_directory(
                        target,
                        label="reserved extraction target",
                    )
                    _materialize_plan(zipped, plan, target)
            except SafeExtractionError:
                raise
            except (
                EOFError,
                NotImplementedError,
                OSError,
                RuntimeError,
                zlib.error,
                zipfile.BadZipFile,
                zipfile.LargeZipFile,
            ) as error:
                raise SafeExtractionError(
                    f"ZIP validation or extraction failed: {error}"
                ) from error

            inventory = inventory_directory(target)
            if (
                len(inventory.files) != plan.file_count
                or inventory.total_bytes != plan.total_uncompressed_bytes
            ):
                raise SafeExtractionError(
                    "extracted inventory differs from the validated ZIP plan"
                )

            second_sha256, second_bytes = _hash_open_file(archive_file)
            finished = os.fstat(archive_file.fileno())

        final = archive.stat(follow_symlinks=False)
        if (
            second_bytes != first_bytes
            or second_sha256 != first_sha256
            or not _same_file_snapshot(opened, finished)
            or not _same_file_snapshot(initial, final)
            or not _same_file_identity(finished, final)
        ):
            raise SafeExtractionError("dataset archive changed during extraction")
        parent_final = _require_plain_directory(
            target.parent,
            label="extraction target parent",
        )
        target_final = _require_plain_directory(
            target,
            label="reserved extraction target",
        )
        if not _same_directory_object(parent_initial, parent_final) or not (
            target_identity is not None
            and _same_directory_object(target_identity, target_final)
        ):
            raise SafeExtractionError(
                "extraction target or its parent changed during extraction"
            )
        inventory.verify_directory(target)
        target_confirmed = _require_plain_directory(
            target,
            label="reserved extraction target",
        )
        if not _same_directory_object(target_final, target_confirmed):
            raise SafeExtractionError("extraction target changed during confirmation")
        _require_remaining_capacity(
            target.parent,
            limits.minimum_free_bytes_after,
        )
        _seal_tree_read_only(target)
        inventory.verify_directory(target)
        sealed_target = _require_plain_directory(
            target,
            label="sealed extraction target",
        )
        if not _same_directory_object(target_confirmed, sealed_target):
            raise SafeExtractionError("extraction target changed while being sealed")
        committed = True
        return SafeExtractionResult(
            dataset_id=source.dataset_id,
            destination=target,
            inventory=inventory,
            member_count=len(plan.members),
            directory_count=plan.directory_count,
            compressed_bytes=plan.compressed_bytes,
        )
    except SafeExtractionError:
        raise
    except (OSError, ValueError) as error:
        raise SafeExtractionError(f"safe ZIP extraction failed: {error}") from error
    finally:
        if target_created and not committed:
            _remove_created_tree(target, expected=target_identity)


def _build_plan(
    zipped: zipfile.ZipFile,
    limits: ZipExtractionLimits,
    *,
    expected_members: int,
) -> _ExtractionPlan:
    infos = zipped.infolist()
    if len(infos) != expected_members:
        raise SafeExtractionError(
            "ZIP central-directory member count changed during parsing"
        )
    if not infos:
        raise SafeExtractionError("ZIP archive contains no members")
    if len(infos) > limits.max_members:
        raise SafeExtractionError(
            f"ZIP archive has {len(infos)} members; limit is {limits.max_members}"
        )

    explicit_keys: set[tuple[str, ...]] = set()
    file_keys: set[tuple[str, ...]] = set()
    directory_keys: set[tuple[str, ...]] = set()
    spelling_by_key: dict[tuple[str, ...], str] = {}
    planned: list[_PlannedMember] = []
    file_count = 0
    total_bytes = 0
    compressed_bytes = 0

    for info in infos:
        _validate_raw_local_header(zipped, info)
        relative, is_directory = _validate_member(info)
        parts = relative.split("/")
        key_parts = tuple(
            unicodedata.normalize("NFKC", part).casefold() for part in parts
        )
        full_key = key_parts
        if full_key in explicit_keys:
            raise SafeExtractionError(
                f"ZIP members collide under portable path rules: {relative!r}"
            )
        for index in range(1, len(parts) + 1):
            prefix_key = key_parts[:index]
            prefix = "/".join(parts[:index])
            previous = spelling_by_key.get(prefix_key)
            if previous is not None and previous != prefix:
                raise SafeExtractionError(
                    "ZIP paths collide after Unicode compatibility/case folding"
                )
            spelling_by_key[prefix_key] = prefix

        for index in range(1, len(parts)):
            prefix_key = key_parts[:index]
            if prefix_key in file_keys:
                raise SafeExtractionError(
                    "ZIP file path is also used as a parent directory"
                )
            directory_keys.add(prefix_key)

        if is_directory:
            if full_key in file_keys:
                raise SafeExtractionError("ZIP path is both a file and directory")
            directory_keys.add(full_key)
        else:
            if full_key in directory_keys:
                raise SafeExtractionError("ZIP path is both a file and directory")
            file_keys.add(full_key)
            file_count += 1
            total_bytes += info.file_size
            compressed_bytes += info.compress_size
            if info.file_size > limits.max_member_uncompressed_bytes:
                raise SafeExtractionError(
                    "ZIP member exceeds the per-member uncompressed byte limit"
                )
            if total_bytes > limits.max_total_uncompressed_bytes:
                raise SafeExtractionError(
                    "ZIP archive exceeds the total uncompressed byte limit"
                )
            if info.file_size > 0 and (
                info.compress_size == 0
                or info.file_size > info.compress_size * limits.max_compression_ratio
            ):
                raise SafeExtractionError(
                    "ZIP member exceeds the declared compression-ratio limit"
                )

        explicit_keys.add(full_key)
        planned.append(_PlannedMember(info, relative, is_directory))

    if file_count == 0:
        raise SafeExtractionError("ZIP archive contains no regular files")
    planned.sort(key=lambda member: member.relative_path.encode("utf-8"))
    return _ExtractionPlan(
        members=tuple(planned),
        file_count=file_count,
        directory_count=len(directory_keys),
        filesystem_entry_count=file_count + len(directory_keys) + 1,
        total_uncompressed_bytes=total_bytes,
        compressed_bytes=compressed_bytes,
    )


def _validate_raw_local_header(
    zipped: zipfile.ZipFile,
    info: zipfile.ZipInfo,
) -> None:
    archive_file = zipped.fp
    if archive_file is None:
        raise SafeExtractionError("ZIP archive closed during preflight")
    previous = archive_file.tell()
    try:
        archive_file.seek(info.header_offset)
        header = archive_file.read(30)
        if len(header) != 30 or header[:4] != b"PK\x03\x04":
            raise SafeExtractionError("ZIP member has an invalid local header")
        local_flags, local_method = struct.unpack_from("<HH", header, 6)
        name_length, extra_length = struct.unpack_from("<HH", header, 26)
        raw_name = archive_file.read(name_length)
        raw_extra = archive_file.read(extra_length)
        if len(raw_name) != name_length or len(raw_extra) != extra_length:
            raise SafeExtractionError("ZIP member has a truncated local header")
    finally:
        archive_file.seek(previous)

    if local_flags != info.flag_bits or local_method != info.compress_type:
        raise SafeExtractionError("ZIP local and central member metadata do not agree")
    if b"\\" in raw_name or b"\x00" in raw_name:
        raise SafeExtractionError("unsafe ZIP member path encoding")
    encoding = "utf-8" if local_flags & 0x800 else "cp437"
    try:
        decoded = raw_name.decode(encoding)
    except UnicodeError as error:
        raise SafeExtractionError("ZIP member name is not valid text") from error
    if decoded != info.orig_filename:
        raise SafeExtractionError("ZIP member name changed during platform decoding")


def _validate_member(info: zipfile.ZipInfo) -> tuple[str, bool]:
    original = info.orig_filename
    if original != info.filename or "\x00" in original:
        raise SafeExtractionError("ZIP member name contains a NUL byte")
    is_directory = info.is_dir()
    if is_directory:
        if not original.endswith("/") or original.endswith("//"):
            raise SafeExtractionError("ZIP directory name is not canonical")
        relative = original[:-1]
    else:
        if original.endswith("/"):
            raise SafeExtractionError("ZIP file name has a directory suffix")
        relative = original

    try:
        validate_portable_relative_path(relative)
    except ValueError as error:
        raise SafeExtractionError(f"unsafe ZIP member path: {error}") from error
    encoded = relative.encode("utf-8")
    if len(encoded) > _MAX_PORTABLE_PATH_BYTES or any(
        len(part.encode("utf-8")) > _MAX_PORTABLE_COMPONENT_BYTES
        for part in relative.split("/")
    ):
        raise SafeExtractionError("ZIP member path exceeds portable byte limits")

    if info.flag_bits & 0x1:
        raise SafeExtractionError("encrypted ZIP members are not accepted")
    if info.compress_type not in _SUPPORTED_COMPRESSION:
        raise SafeExtractionError(
            f"unsupported ZIP compression method: {info.compress_type}"
        )
    if (
        type(info.file_size) is not int
        or type(info.compress_size) is not int
        or info.file_size < 0
        or info.compress_size < 0
    ):
        raise SafeExtractionError("ZIP member has invalid declared byte counts")

    unix_mode = (info.external_attr >> 16) & 0xFFFF
    unix_type = stat.S_IFMT(unix_mode)
    allowed_type = stat.S_IFDIR if is_directory else stat.S_IFREG
    if unix_type not in {0, allowed_type}:
        raise SafeExtractionError("ZIP member is a link or special file")
    dos_attributes = info.external_attr & 0xFFFF
    if dos_attributes & _WINDOWS_REPARSE_POINT:
        raise SafeExtractionError("ZIP member declares a Windows reparse point")
    if bool(dos_attributes & _DOS_DIRECTORY) != is_directory and (
        dos_attributes & _DOS_DIRECTORY
    ):
        raise SafeExtractionError("ZIP member has inconsistent directory metadata")
    if is_directory and (info.file_size != 0 or info.compress_size != 0):
        raise SafeExtractionError("ZIP directory member declares file content")
    return relative, is_directory


def _materialize_plan(
    zipped: zipfile.ZipFile,
    plan: _ExtractionPlan,
    staging: Path,
) -> None:
    observed_files = 0
    observed_bytes = 0
    for member in plan.members:
        output = staging.joinpath(*member.relative_path.split("/"))
        if member.is_directory:
            output.mkdir(mode=0o700, parents=True, exist_ok=False)
            continue

        output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        written = 0
        with zipped.open(member.info, mode="r") as source, output.open("xb") as sink:
            for chunk in iter(lambda: source.read(_COPY_CHUNK_BYTES), b""):
                written += len(chunk)
                if written > member.info.file_size:
                    raise SafeExtractionError(
                        "ZIP member expanded beyond its declared byte count"
                    )
                sink.write(chunk)
        output.chmod(0o600)
        if written != member.info.file_size:
            raise SafeExtractionError(
                "ZIP member output differs from its declared byte count"
            )
        observed_files += 1
        observed_bytes += written

    if (
        observed_files != plan.file_count
        or observed_bytes != plan.total_uncompressed_bytes
    ):
        raise SafeExtractionError("materialized ZIP output differs from its plan")


def _hash_open_file(source: BinaryIO) -> tuple[str, int]:
    source.seek(0)
    digest = hashlib.sha256()
    observed = 0
    for chunk in iter(lambda: source.read(_COPY_CHUNK_BYTES), b""):
        observed += len(chunk)
        digest.update(chunk)
    source.seek(0)
    return digest.hexdigest(), observed


def _preflight_zip_directory(
    source: BinaryIO,
    *,
    archive_bytes: int,
    limits: ZipExtractionLimits,
) -> int:
    """Bound and scan one conventional single-disk ZIP central directory.

    ``zipfile.ZipFile`` reads the declared central directory into memory before
    exposing ``infolist()``. This raw preflight therefore enforces both a byte
    ceiling and the actual member count before constructing ``ZipFile``.
    """

    if type(archive_bytes) is not int or archive_bytes < 22:
        raise SafeExtractionError("ZIP archive is too short for an end record")
    previous = source.tell()
    try:
        tail_bytes = min(archive_bytes, 22 + 65_535)
        source.seek(archive_bytes - tail_bytes)
        tail = source.read(tail_bytes)
        if len(tail) != tail_bytes:
            raise SafeExtractionError("ZIP end record is truncated")

        final_record = len(tail) - 22
        if (
            final_record >= 0
            and tail[final_record : final_record + 4] == _EOCD_SIGNATURE
            and tail[-2:] == b"\x00\x00"
        ):
            candidate = final_record
        else:
            candidate = tail.rfind(_EOCD_SIGNATURE)
        if candidate < 0 or candidate + 22 > len(tail):
            raise SafeExtractionError("ZIP archive has no canonical end record")
        comment_bytes = struct.unpack_from("<H", tail, candidate + 20)[0]
        eocd_offset = archive_bytes - tail_bytes + candidate
        if eocd_offset + 22 + comment_bytes != archive_bytes:
            raise SafeExtractionError("ZIP archive has no canonical end record")
        eocd = tail[candidate : candidate + 22]

        (
            signature,
            disk_number,
            central_disk,
            disk_members,
            declared_members,
            central_bytes_32,
            central_offset_32,
            _comment_bytes,
        ) = struct.unpack("<4s4H2LH", eocd)
        if signature != _EOCD_SIGNATURE:
            raise SafeExtractionError("ZIP end record signature is invalid")

        has_zip64_locator = (
            eocd_offset >= 20
            and _read_exact_at(
                source,
                eocd_offset - 20,
                4,
                label="possible ZIP64 end locator",
            )
            == _ZIP64_LOCATOR_SIGNATURE
        )
        uses_zip64 = has_zip64_locator or any(
            (
                disk_number == 0xFFFF,
                central_disk == 0xFFFF,
                disk_members == 0xFFFF,
                declared_members == 0xFFFF,
                central_bytes_32 == 0xFFFFFFFF,
                central_offset_32 == 0xFFFFFFFF,
            )
        )
        if uses_zip64:
            (
                declared_members,
                central_bytes,
                central_offset,
                central_end,
            ) = _read_zip64_directory_metadata(
                source,
                eocd_offset=eocd_offset,
                legacy=(
                    disk_number,
                    central_disk,
                    disk_members,
                    declared_members,
                    central_bytes_32,
                    central_offset_32,
                ),
            )
        else:
            if (
                disk_number != 0
                or central_disk != 0
                or disk_members != declared_members
            ):
                raise SafeExtractionError("multi-disk ZIP archives are not accepted")
            declared_members = int(declared_members)
            central_bytes = int(central_bytes_32)
            central_offset = int(central_offset_32)
            central_end = eocd_offset

        if declared_members > limits.max_members:
            raise SafeExtractionError(
                f"ZIP archive has {declared_members} members; "
                f"limit is {limits.max_members}"
            )
        if central_bytes > limits.max_central_directory_bytes:
            raise SafeExtractionError(
                f"ZIP central directory has {central_bytes} bytes; "
                f"limit is {limits.max_central_directory_bytes}"
            )
        if central_offset + central_bytes != central_end:
            raise SafeExtractionError("ZIP central-directory bounds are not canonical")
        if declared_members and central_bytes < declared_members * 46:
            raise SafeExtractionError(
                "ZIP central directory is too short for its declared members"
            )
        actual_members = _scan_central_directory(
            source,
            offset=central_offset,
            size=central_bytes,
            max_members=limits.max_members,
        )
        if actual_members != declared_members:
            raise SafeExtractionError(
                "ZIP central-directory member count differs from its end record"
            )
        return actual_members
    except SafeExtractionError:
        raise
    except (OSError, OverflowError, struct.error, ValueError) as error:
        raise SafeExtractionError(
            f"cannot preflight ZIP central directory: {error}"
        ) from error
    finally:
        try:
            source.seek(previous)
        except OSError:
            pass


def _read_zip64_directory_metadata(
    source: BinaryIO,
    *,
    eocd_offset: int,
    legacy: tuple[int, int, int, int, int, int],
) -> tuple[int, int, int, int]:
    locator_offset = eocd_offset - 20
    if locator_offset < 0:
        raise SafeExtractionError("ZIP64 end locator is missing")
    locator = _read_exact_at(source, locator_offset, 20, label="ZIP64 end locator")
    signature, locator_disk, zip64_offset, total_disks = struct.unpack(
        "<4sLQL", locator
    )
    if signature != _ZIP64_LOCATOR_SIGNATURE:
        raise SafeExtractionError("ZIP64 end locator is missing")
    if locator_disk != 0 or total_disks != 1:
        raise SafeExtractionError("multi-disk ZIP64 archives are not accepted")
    if zip64_offset > locator_offset - 56:
        raise SafeExtractionError("ZIP64 end-record offset is invalid")

    record = _read_exact_at(source, zip64_offset, 56, label="ZIP64 end record")
    (
        signature,
        record_bytes,
        _version_made,
        _version_needed,
        disk_number,
        central_disk,
        disk_members,
        declared_members,
        central_bytes,
        central_offset,
    ) = struct.unpack("<4sQ2H2L4Q", record)
    if signature != _ZIP64_EOCD_SIGNATURE or record_bytes < 44:
        raise SafeExtractionError("ZIP64 end record is invalid")
    if zip64_offset + 12 + record_bytes != locator_offset:
        raise SafeExtractionError("ZIP64 end-record bounds are not canonical")
    if disk_number != 0 or central_disk != 0 or disk_members != declared_members:
        raise SafeExtractionError("multi-disk ZIP64 archives are not accepted")

    (
        legacy_disk,
        legacy_central_disk,
        legacy_disk_members,
        legacy_members,
        legacy_bytes,
        legacy_offset,
    ) = legacy
    comparisons = (
        (legacy_disk, 0xFFFF, disk_number),
        (legacy_central_disk, 0xFFFF, central_disk),
        (legacy_disk_members, 0xFFFF, disk_members),
        (legacy_members, 0xFFFF, declared_members),
        (legacy_bytes, 0xFFFFFFFF, central_bytes),
        (legacy_offset, 0xFFFFFFFF, central_offset),
    )
    if any(
        value != sentinel and value != expanded
        for value, sentinel, expanded in comparisons
    ):
        raise SafeExtractionError("ZIP64 and legacy end records do not agree")
    return (
        int(declared_members),
        int(central_bytes),
        int(central_offset),
        int(zip64_offset),
    )


def _scan_central_directory(
    source: BinaryIO,
    *,
    offset: int,
    size: int,
    max_members: int,
) -> int:
    end = offset + size
    position = offset
    members = 0
    while position < end:
        if members >= max_members:
            raise SafeExtractionError(
                f"ZIP archive has more than {max_members} members"
            )
        header = _read_exact_at(
            source,
            position,
            46,
            label="ZIP central-directory member",
        )
        if header[:4] != _CENTRAL_MEMBER_SIGNATURE:
            raise SafeExtractionError("ZIP central-directory member is invalid")
        name_bytes, extra_bytes, comment_bytes = struct.unpack_from("<3H", header, 28)
        disk_number = struct.unpack_from("<H", header, 34)[0]
        if disk_number != 0:
            raise SafeExtractionError("multi-disk ZIP members are not accepted")
        position += 46 + name_bytes + extra_bytes + comment_bytes
        if position > end:
            raise SafeExtractionError("ZIP central-directory member is truncated")
        members += 1
    if position != end:
        raise SafeExtractionError("ZIP central-directory bounds are invalid")
    return members


def _read_exact_at(
    source: BinaryIO,
    offset: int,
    size: int,
    *,
    label: str,
) -> bytes:
    if offset < 0 or size < 0:
        raise SafeExtractionError(f"{label} has invalid bounds")
    source.seek(offset)
    value = source.read(size)
    if len(value) != size:
        raise SafeExtractionError(f"{label} is truncated")
    return value


def _require_disk_capacity(
    parent: Path,
    total: int,
    filesystem_entries: int,
    reserve: int,
) -> None:
    try:
        free = shutil.disk_usage(parent).free
    except OSError as error:
        raise SafeExtractionError(
            f"cannot determine extraction filesystem capacity: {error}"
        ) from error
    required = (
        total + filesystem_entries * _ESTIMATED_ENTRY_DISK_OVERHEAD_BYTES + reserve
    )
    if free < required:
        raise SafeExtractionError(
            "insufficient free space for declared output, filesystem overhead, "
            "and required reserve"
        )
    free_inodes = _free_inode_count(parent)
    if free_inodes is not None and (
        free_inodes < filesystem_entries + _MINIMUM_FREE_INODES_AFTER
    ):
        raise SafeExtractionError(
            "insufficient free inodes for declared output plus required reserve"
        )


def _require_remaining_capacity(parent: Path, reserve: int) -> None:
    try:
        free = shutil.disk_usage(parent).free
    except OSError as error:
        raise SafeExtractionError(
            f"cannot recheck extraction filesystem capacity: {error}"
        ) from error
    if free < reserve:
        raise SafeExtractionError(
            "extraction filesystem fell below the required free-space reserve"
        )
    free_inodes = _free_inode_count(parent)
    if free_inodes is not None and free_inodes < _MINIMUM_FREE_INODES_AFTER:
        raise SafeExtractionError(
            "extraction filesystem fell below the required free-inode reserve"
        )


def _free_inode_count(path: Path) -> int | None:
    statvfs = getattr(os, "statvfs", None)
    if statvfs is None:
        return None
    try:
        filesystem = statvfs(path)
    except OSError as error:
        raise SafeExtractionError(
            f"cannot determine extraction filesystem inode capacity: {error}"
        ) from error
    if filesystem.f_files == 0:
        return None
    return int(filesystem.f_favail)


def _seal_tree_read_only(root: Path) -> None:
    files: list[Path] = []
    directories: list[Path] = []

    def raise_walk_error(error: OSError) -> None:
        raise error

    try:
        for current, child_directories, child_files in os.walk(
            root,
            topdown=True,
            followlinks=False,
            onerror=raise_walk_error,
        ):
            current_path = Path(current)
            _require_plain_directory(current_path, label="extracted directory")
            directories.append(current_path)
            for name in child_directories:
                directory = current_path / name
                _require_plain_directory(directory, label="extracted directory")
            for name in child_files:
                file_path = current_path / name
                _require_unlinked_regular_file(file_path, label="extracted file")
                files.append(file_path)

        for file_path in files:
            file_path.chmod(0o400)
            metadata = _require_unlinked_regular_file(
                file_path,
                label="sealed extracted file",
            )
            if metadata.st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
                raise SafeExtractionError(
                    "extracted file remained writable after sealing"
                )
        for directory in sorted(
            directories,
            key=lambda path: len(path.parts),
            reverse=True,
        ):
            directory.chmod(0o500)
            metadata = _require_plain_directory(
                directory,
                label="sealed extracted directory",
            )
            if metadata.st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
                raise SafeExtractionError(
                    "extracted directory remained writable after sealing"
                )
    except SafeExtractionError:
        raise
    except OSError as error:
        raise SafeExtractionError(
            f"cannot seal extracted tree read-only: {error}"
        ) from error


def _remove_created_tree(
    root: Path,
    *,
    expected: os.stat_result | None,
) -> None:
    if not os.path.lexists(os.fspath(root)):
        return
    if expected is None:
        raise SafeExtractionError(
            "cannot verify incomplete extraction identity; private residue remains"
        )
    actual = _require_plain_directory(root, label="incomplete extraction target")
    if not _same_directory_object(expected, actual):
        raise SafeExtractionError(
            "cleanup refused because the incomplete extraction target changed; "
            "private residue remains"
        )

    def raise_walk_error(error: OSError) -> None:
        raise error

    try:
        directories: list[Path] = [root]
        files: list[Path] = []
        for current, child_directories, child_files in os.walk(
            root,
            topdown=True,
            followlinks=False,
            onerror=raise_walk_error,
        ):
            current_path = Path(current)
            _require_plain_directory(
                current_path,
                label="incomplete extraction directory",
            )
            for name in child_directories:
                directory = current_path / name
                _require_plain_directory(
                    directory,
                    label="incomplete extraction directory",
                )
                directories.append(directory)
            for name in child_files:
                file_path = current_path / name
                _require_unlinked_regular_file(
                    file_path,
                    label="incomplete extraction file",
                )
                files.append(file_path)
        for file_path in files:
            file_path.chmod(0o600)
        for directory in sorted(
            directories,
            key=lambda path: len(path.parts),
            reverse=True,
        ):
            directory.chmod(0o700)
        confirmed = _require_plain_directory(
            root,
            label="incomplete extraction target",
        )
        if not _same_directory_object(expected, confirmed):
            raise SafeExtractionError(
                "cleanup refused because the incomplete extraction target changed; "
                "private residue remains"
            )
        shutil.rmtree(root)
    except SafeExtractionError:
        raise
    except OSError as error:
        raise SafeExtractionError(
            f"failed to remove incomplete private extraction; residue remains: {error}"
        ) from error
    if os.path.lexists(os.fspath(root)):
        raise SafeExtractionError(
            "failed to remove incomplete private extraction; residue remains"
        )


def _require_plain_directory(path: Path, *, label: str) -> os.stat_result:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as error:
        raise SafeExtractionError(f"cannot inspect {label}: {error}") from error
    if path.is_symlink() or _is_reparse(metadata) or not stat.S_ISDIR(metadata.st_mode):
        raise SafeExtractionError(f"{label} must be a plain directory")
    return metadata


def _require_unlinked_regular_file(
    path: Path,
    *,
    label: str,
) -> os.stat_result:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as error:
        raise SafeExtractionError(f"cannot inspect {label}: {error}") from error
    if (
        path.is_symlink()
        or _is_reparse(metadata)
        or not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
    ):
        raise SafeExtractionError(f"{label} must be one unlinked regular file")
    return metadata


def _is_reparse(metadata: os.stat_result) -> bool:
    return bool(
        getattr(metadata, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", _WINDOWS_REPARSE_POINT)
    )


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


def _same_file_snapshot(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        _same_file_identity(first, second) and first.st_ctime_ns == second.st_ctime_ns
    )


def _same_directory_object(first: os.stat_result, second: os.stat_result) -> bool:
    return (
        first.st_dev == second.st_dev
        and (first.st_ino == 0 or second.st_ino == 0 or first.st_ino == second.st_ino)
        and stat.S_IFMT(first.st_mode) == stat.S_IFDIR
        and stat.S_IFMT(second.st_mode) == stat.S_IFDIR
        and _is_reparse(first) == _is_reparse(second)
    )
