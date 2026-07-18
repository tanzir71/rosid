#!/usr/bin/env python3
"""Fail if iOS dependency inputs contain ML Kit telemetry/network components."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PACKAGE_INPUTS = (ROOT / "pubspec.yaml", ROOT / "pubspec.lock")
POD_LOCK = ROOT / "ios" / "Podfile.lock"
FORBIDDEN_TERMS = (
    "mlkit",
    "GoogleDataTransport",
    "GTMSessionFetcher",
)


def find_forbidden_terms(contents: str) -> list[str]:
    lowered = contents.casefold()
    return [term for term in FORBIDDEN_TERMS if term.casefold() in lowered]


def _find_terms(path: Path) -> list[str]:
    if not path.is_file():
        raise SystemExit(f"Required privacy-audit input is missing: {path}")
    contents = path.read_text(encoding="utf-8")
    return find_forbidden_terms(contents)


def main() -> None:
    violations: list[str] = []
    for path in PACKAGE_INPUTS:
        for term in _find_terms(path):
            violations.append(f"{path.relative_to(ROOT)} contains {term}")
    for term in _find_terms(POD_LOCK):
        violations.append(f"{POD_LOCK.relative_to(ROOT)} contains {term}")

    if violations:
        details = "\n".join(f"- {violation}" for violation in violations)
        raise SystemExit(
            "iOS privacy audit failed; telemetry/network-capable ML Kit "
            f"components are forbidden:\n{details}"
        )
    print("iOS privacy audit passed: no forbidden ML Kit pods or packages.")


if __name__ == "__main__":
    main()
