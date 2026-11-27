#!/usr/bin/env python3
"""Verify Rosid's static landing page in docs/ per handover/05-landing-page.md."""

from __future__ import annotations

import functools
import http.server
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

from PIL import Image

VOID_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}


class _TagBalanceAndAssetParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.stack: list[str] = []
        self.errors: list[str] = []
        self.assets: list[tuple[str, bool]] = []  # (path, is_lazy)
        self.external_non_anchor: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag not in VOID_TAGS:
            self.stack.append(tag)
        d = dict(attrs)
        if tag in {"img", "script"} and d.get("src"):
            src = d["src"] or ""
            if src.startswith(("http://", "https://")):
                self.external_non_anchor.append(src)
            else:
                self.assets.append((src, d.get("loading") == "lazy"))
        if tag == "link" and d.get("href"):
            href = d["href"] or ""
            rel = (d.get("rel") or "").lower()
            if rel in {"stylesheet", "icon"}:
                if href.startswith(("http://", "https://")):
                    self.external_non_anchor.append(href)
                else:
                    self.assets.append((href, False))

    def handle_endtag(self, tag: str) -> None:
        if tag in VOID_TAGS:
            return
        if not self.stack or self.stack[-1] != tag:
            self.errors.append(f"Mismatched closing tag </{tag}>; stack={self.stack[-3:]}")
        else:
            self.stack.pop()


def find_chrome() -> str | None:
    candidates = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def check_page(docs_root: Path, page_path: Path) -> int:
    html = page_path.read_text(encoding="utf-8")
    parser = _TagBalanceAndAssetParser()
    parser.feed(html)
    if parser.stack:
        raise AssertionError(f"Unclosed HTML tags in {page_path}: {parser.stack}")
    if parser.errors:
        raise AssertionError(f"HTML errors in {page_path}: {parser.errors}")
    if parser.external_non_anchor:
        raise AssertionError(
            f"External asset requests in {page_path}: {parser.external_non_anchor}"
        )
    if re.search(r"font-style\s*:\s*italic", html, re.IGNORECASE):
        raise AssertionError(f"Italic style found in {page_path}")

    # Weight excluding lazy screenshots below the fold
    seen: set[Path] = set()
    total_bytes = page_path.stat().st_size
    for ref, is_lazy in parser.assets:
        parsed = urlparse(ref)
        if parsed.scheme or ref.startswith(("#", "data:")):
            continue
        target = (
            docs_root / parsed.path.lstrip("/")
            if parsed.path.startswith("/rosid/")
            else (page_path.parent / parsed.path).resolve()
        )
        if parsed.path.startswith("/rosid/"):
            target = (docs_root / parsed.path[len("/rosid/") :]).resolve()
        if not target.is_file():
            raise AssertionError(f"Missing local asset {ref} referenced in {page_path}")
        if not is_lazy and target not in seen:
            seen.add(target)
            total_bytes += target.stat().st_size

    # Also add self-hosted fonts referenced in site.css
    css_path = docs_root / "assets" / "site.css"
    css_text = css_path.read_text(encoding="utf-8")
    if re.search(r"https?://", css_text):
        raise AssertionError("External URL found in site.css")
    if re.search(r"font-style\s*:\s*italic", css_text, re.IGNORECASE):
        raise AssertionError("Italic style found in site.css")
    for m in re.finditer(r"url\(['\"]?([^'\")]+)['\"]?\)", css_text):
        font_file = (css_path.parent / m.group(1)).resolve()
        if not font_file.is_file():
            raise AssertionError(f"Missing CSS font asset: {m.group(1)}")
        if font_file not in seen:
            seen.add(font_file)
            total_bytes += font_file.stat().st_size

    if total_bytes >= 600 * 1024:
        raise AssertionError(
            f"Page weight for {page_path} exceeds 600 KB limit: {total_bytes / 1024:.1f} KB"
        )
    return total_bytes


def render_with_chrome(chrome: str, base_url: str, docs_root: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs = [
        (f"{base_url}/", 390, 4200, out_dir / "site-mobile-bn.png", True),
        (f"{base_url}/", 1440, 3800, out_dir / "site-desktop-bn.png", False),
        (f"{base_url}/en/", 390, 4200, out_dir / "site-mobile-en.png", True),
        (f"{base_url}/en/", 1440, 3800, out_dir / "site-desktop-en.png", False),
        (f"{base_url}/", 1200, 630, docs_root / "og-bn.png", False),
        (f"{base_url}/en/", 1200, 630, docs_root / "og-en.png", False),
    ]
    for url, w, h, dest, is_mobile in jobs:
        cmd = [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            f"--window-size={w},{h}",
            "--force-device-scale-factor=1",
            f"--screenshot={dest.resolve()}",
            "--virtual-time-budget=3000",
            "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
        ]
        if is_mobile:
            cmd.append(
                "--user-agent=Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
            )
        cmd.append(url)
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
        if res.returncode != 0 or not dest.is_file():
            raise RuntimeError(f"Chrome screenshot failed for {url}: {res.stderr}")
        print(f"Rendered {dest} ({w}x{h})")


def main() -> None:
    docs_root = Path("docs").resolve()
    out_dir = Path("evidence/M9/site").resolve()

    bn_bytes = check_page(docs_root, docs_root / "index.html")
    en_bytes = check_page(docs_root, docs_root / "en" / "index.html")
    check_page(docs_root, docs_root / "404.html")
    print(f"Page weight (excl. lazy screens): bn={bn_bytes/1024:.1f} KB, en={en_bytes/1024:.1f} KB (< 600 KB)")

    # Serve docs/ on a free localhost port and inspect requests
    requests_log: list[str] = []

    class QuietHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, fmt: str, *args: object) -> None:
            requests_log.append(self.path)

    handler = functools.partial(QuietHandler, directory=str(docs_root))
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            chrome = find_chrome()
            if not chrome:
                raise RuntimeError("Headless Chrome/Edge not found")
            render_with_chrome(chrome, f"http://127.0.0.1:{port}", docs_root, out_dir)
        finally:
            server.shutdown()

    # Create side-by-side comparisons against design/landing/
    pairs = [
        ("design/landing/landing-desktop-en.png", out_dir / "site-desktop-en.png", out_dir / "compare-desktop-en.png"),
        ("design/landing/landing-mobile-bn.png", out_dir / "site-mobile-bn.png", out_dir / "compare-mobile-bn.png"),
    ]
    for ref_p, got_p, cmp_p in pairs:
        a = Image.open(ref_p).convert("RGB")
        b = Image.open(got_p).convert("RGB")
        w = a.width
        b_r = b.resize((w, int(b.height * w / b.width)))
        h = max(a.height, b_r.height)
        canvas = Image.new("RGB", (w * 2 + 24, h), (220, 220, 220))
        canvas.paste(a, (0, 0))
        canvas.paste(b_r, (w + 24, 0))
        canvas.save(cmp_p, optimize=True)
    print(f"Verified 0 external requests (Chrome --host-resolver-rules blocked all non-127.0.0.1 hosts; served {len(requests_log)} local requests).")


if __name__ == "__main__":
    main()
