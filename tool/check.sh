#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_RESOLVED="$(command -v "$FLUTTER_BIN" || printf '%s' "$FLUTTER_BIN")"
DART_BIN="${DART_BIN:-$(dirname "$FLUTTER_RESOLVED")/dart}"

cd "$PROJECT_DIR"

"$FLUTTER_BIN" --no-version-check gen-l10n
"$DART_BIN" run build_runner build
"$DART_BIN" format --output=none --set-exit-if-changed lib test
"$FLUTTER_BIN" --no-version-check analyze
"$FLUTTER_BIN" --no-version-check test

if [[ "${ROSID_RUN_BUILD:-0}" == "1" ]]; then
  "$FLUTTER_BIN" --no-version-check build apk --debug
else
  echo "Skipping APK build (set ROSID_RUN_BUILD=1 on a provisioned machine)."
fi
