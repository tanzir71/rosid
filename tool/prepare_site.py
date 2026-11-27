#!/usr/bin/env python3
"""Inject immutable Rosid release metadata into docs/index.html and docs/en/index.html."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def to_bn_digits(value: str) -> str:
    return value.translate(BN_DIGITS)


def parse_sha256sums(path: Path) -> dict[str, str]:
    sums: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        digest, name = parts[0].lower(), parts[-1].lstrip("*")
        if SHA256_RE.fullmatch(digest):
            sums[name] = digest
    return sums


def normalize_cert_sha256(raw: str) -> str:
    hex_only = re.sub(r"[^0-9a-fA-F]", "", raw).upper()
    if len(hex_only) != 64:
        raise ValueError(f"Expected 64 hex chars for cert SHA-256, got {len(hex_only)}: {raw}")
    return ":".join(hex_only[i : i + 2] for i in range(0, 64, 2))


def replace_marker(html: str, name: str, value: str) -> str:
    pattern = re.compile(
        rf"(<!--\s*release:{re.escape(name)}\s*-->)(.*?)(<!--\s*/release\s*-->)",
        re.DOTALL,
    )
    updated, count = pattern.subn(rf"\g<1>{value}\g<3>", html)
    if count == 0:
        raise ValueError(f"Missing release marker: {name}")
    return updated


def replace_links(html: str, arm64_url: str, arm32_url: str) -> str:
    html, n64 = re.subn(
        r'(data-release-link="arm64"\s+href=")[^"]*(")',
        rf'\g<1>{arm64_url}\g<2>',
        html,
    )
    html, n32 = re.subn(
        r'(data-release-link="arm32"\s+href=")[^"]*(")',
        rf'\g<1>{arm32_url}\g<2>',
        html,
    )
    if n64 < 1 or n32 < 1:
        raise ValueError(f"Missing release download link attributes (arm64={n64}, arm32={n32})")
    return html


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--docs", type=Path, default=Path("docs"))
    parser.add_argument("--repository", default="tanzir71/rosid")
    parser.add_argument("--version", required=True, help="e.g. 2.0.0")
    parser.add_argument("--sha256sums", type=Path, required=True)
    parser.add_argument("--cert-sha256", required=True)
    parser.add_argument("--arm64-name", default="rosid-arm64-v8a.apk")
    parser.add_argument("--arm32-name", default="rosid-armeabi-v7a.apk")
    args = parser.parse_args()

    sums = parse_sha256sums(args.sha256sums)
    if args.arm64_name not in sums:
        raise ValueError(f"{args.arm64_name} missing from {args.sha256sums}")
    if args.arm32_name not in sums:
        raise ValueError(f"{args.arm32_name} missing from {args.sha256sums}")

    version = args.version.strip()
    version_bn = to_bn_digits(version)
    apk_sha256 = sums[args.arm64_name].lower()
    cert_sha256 = normalize_cert_sha256(args.cert_sha256)

    base = f"https://github.com/{args.repository}/releases/download/v{version}"
    arm64_url = f"{base}/{args.arm64_name}"
    arm32_url = f"{base}/{args.arm32_name}"

    bn_path = args.docs / "index.html"
    en_path = args.docs / "en" / "index.html"

    bn_html = bn_path.read_text(encoding="utf-8")
    bn_html = replace_marker(bn_html, "version_bn", version_bn)
    bn_html = replace_marker(
        bn_html, "version_line_bn", f"সংস্করণ {version_bn}, অ্যান্ড্রয়েড ৮ বা নতুন"
    )
    bn_html = replace_marker(
        bn_html, "version_line_bn_closing", f"সংস্করণ {version_bn}, অ্যান্ড্রয়েড ৮ বা নতুন"
    )
    bn_html = replace_marker(bn_html, "apk_name", args.arm64_name)
    bn_html = replace_marker(bn_html, "apk_sha256", apk_sha256)
    bn_html = replace_marker(bn_html, "cert_sha256", cert_sha256)
    bn_html = replace_links(bn_html, arm64_url, arm32_url)
    bn_path.write_text(bn_html, encoding="utf-8", newline="\n")

    en_html = en_path.read_text(encoding="utf-8")
    en_html = replace_marker(en_html, "version", version)
    en_html = replace_marker(
        en_html, "version_line_en", f"Version {version} for Android 8 or newer"
    )
    en_html = replace_marker(
        en_html, "version_line_en_closing", f"Version {version} for Android 8 or newer"
    )
    en_html = replace_marker(en_html, "apk_name", args.arm64_name)
    en_html = replace_marker(en_html, "apk_sha256", apk_sha256)
    en_html = replace_marker(en_html, "cert_sha256", cert_sha256)
    en_html = replace_links(en_html, arm64_url, arm32_url)
    en_path.write_text(en_html, encoding="utf-8", newline="\n")

    for p in (bn_path, en_path):
        txt = p.read_text(encoding="utf-8")
        if "written here when the release is built" in txt or "রিলিজ তৈরির সময় এখানে বসবে" in txt:
            raise ValueError(f"Unfilled placeholder remains in {p}")
    print(f"Prepared docs/ for Rosid {version} ({args.arm64_name}, sha256={apk_sha256[:12]}...)")


if __name__ == "__main__":
    main()
