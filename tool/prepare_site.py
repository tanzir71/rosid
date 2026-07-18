#!/usr/bin/env python3
"""Prepare Rosid's static site with immutable release metadata."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import shutil
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


PLACEHOLDERS = {
    "OWNER/REPO": "repository",
    "ROSID_TAG_PLACEHOLDER": "release_tag",
    "ROSID_VERSION_PLACEHOLDER": "version",
    "ROSID_RELEASE_DATE_PLACEHOLDER": "release_date",
    "ROSID_APK_SIZE_PLACEHOLDER": "apk_size",
    "ROSID_APK_SHA256_PLACEHOLDER": "apk_sha256",
    "ROSID_CERTIFICATE_SHA256_PLACEHOLDER": "certificate_sha256",
    "ROSID_IOS_SIZE_PLACEHOLDER": "ios_size",
    "ROSID_IOS_SHA256_PLACEHOLDER": "ios_sha256",
    "ROSID_ANDROID_DOWNLOAD_URL_PLACEHOLDER": "android_download_url",
    "ROSID_IOS_DOWNLOAD_URL_PLACEHOLDER": "ios_download_url",
    "ROSID_RELEASE_URL_PLACEHOLDER": "release_url",
}

SHA256_RE = re.compile(r"^[0-9A-F]{64}$")
UNRESOLVED_RE = re.compile(r"OWNER/REPO|ROSID_[A-Z0-9_]+_PLACEHOLDER")


class _ReferenceParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.references: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag in {"img", "script"} and values.get("src"):
            self.references.append(values["src"] or "")
        if tag == "link" and values.get("href"):
            self.references.append(values["href"] or "")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("site"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--release-date", required=True)
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--apk-size", required=True)
    parser.add_argument("--apk-sha256", required=True)
    parser.add_argument("--certificate-sha256", required=True)
    parser.add_argument("--ios-size", required=True)
    parser.add_argument("--ios-sha256", required=True)
    return parser.parse_args()


def _validate_args(args: argparse.Namespace) -> None:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise ValueError("--repository must use the OWNER/REPO form")
    if not re.fullmatch(r"v[A-Za-z0-9._+-]+", args.release_tag):
        raise ValueError("--release-tag must be a v-prefixed tag without path separators")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?\+\d+", args.version):
        raise ValueError("--version must be a pubspec semantic version with a numeric build")
    try:
        dt.date.fromisoformat(args.release_date)
    except ValueError as error:
        raise ValueError("--release-date must be a real ISO date") from error
    for name in ("apk_size", "ios_size"):
        if not re.fullmatch(r"\d+(?:\.\d)? MB", getattr(args, name)):
            raise ValueError(f"--{name.replace('_', '-')} must use the 'N.N MB' form")
    for name in ("apk_sha256", "certificate_sha256", "ios_sha256"):
        value = getattr(args, name).upper()
        if not SHA256_RE.fullmatch(value):
            raise ValueError(f"--{name.replace('_', '-')} must be a 64-character SHA-256")
        setattr(args, name, value)
    release_base = f"https://github.com/{args.repository}/releases/download/{args.release_tag}"
    args.android_download_url = f"{release_base}/rosid.apk"
    args.ios_download_url = f"{release_base}/rosid-ios-unsigned.ipa"
    args.release_url = f"https://github.com/{args.repository}/releases/tag/{args.release_tag}"


def _copy_and_replace(args: argparse.Namespace) -> Path:
    source = args.source.resolve()
    output = args.output.resolve()
    if source == output or source in output.parents or output in source.parents:
        raise ValueError("--output must be outside both the source site directory and its ancestors")
    if output.exists():
        raise ValueError("--output already exists; choose a fresh path")
    shutil.copytree(source, output)

    index = output / "index.html"
    contents = index.read_text(encoding="utf-8")
    values = vars(args)
    for placeholder, attribute in PLACEHOLDERS.items():
        if placeholder not in contents:
            raise ValueError(f"Required placeholder is missing: {placeholder}")
        contents = contents.replace(placeholder, str(values[attribute]))
    if UNRESOLVED_RE.search(contents):
        raise ValueError("Prepared site still contains an unresolved placeholder")
    index.write_text(contents, encoding="utf-8", newline="\n")
    return output


def _validate_output(output: Path) -> None:
    index = output / "index.html"
    contents = index.read_text(encoding="utf-8")
    if re.search(r"TestFlight\s+(coming soon|শিগগিরই)", contents, re.IGNORECASE):
        raise ValueError("The site must not promise TestFlight without Apple distribution signing")
    if "https://github.com/OWNER/REPO" in contents:
        raise ValueError("Repository links were not prepared")

    parser = _ReferenceParser()
    parser.feed(contents)
    for reference in parser.references:
        parsed = urlparse(reference)
        if parsed.scheme or parsed.netloc or reference.startswith(("#", "data:")):
            continue
        target = (output / parsed.path).resolve()
        if output not in target.parents and target != output:
            raise ValueError(f"Local reference escapes the site root: {reference}")
        if not target.is_file():
            raise ValueError(f"Missing local site asset: {reference}")


def main() -> None:
    args = _parse_args()
    _validate_args(args)
    output = _copy_and_replace(args)
    _validate_output(output)
    print(f"Prepared {output}")


if __name__ == "__main__":
    main()
