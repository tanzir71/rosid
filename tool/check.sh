#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_RESOLVED="$(command -v "$FLUTTER_BIN" || printf '%s' "$FLUTTER_BIN")"
DART_BIN="${DART_BIN:-$(dirname "$FLUTTER_RESOLVED")/dart}"

cd "$PROJECT_DIR"

"$FLUTTER_BIN" --no-version-check gen-l10n
"$DART_BIN" run build_runner build
"$DART_BIN" run tool/generate_ocr_fixture_bundle.dart
"$DART_BIN" run tool/generate_v2_preprocess_goldens.dart --check
"$DART_BIN" format --output=none --set-exit-if-changed lib test integration_test tool
"$FLUTTER_BIN" --no-version-check analyze
"$FLUTTER_BIN" --no-version-check test
"${PYTHON_BIN:-python3}" -m unittest tool.test_audit_v2_model
"${PYTHON_BIN:-python3}" -m unittest discover -s ml/tests -v
"$PROJECT_DIR/tool/audit_offline.sh"

if [[ "${ROSID_RUN_BUILD:-0}" == "1" ]]; then
  "$FLUTTER_BIN" --no-version-check build apk --debug
  "$PROJECT_DIR/tool/audit_offline.sh"
else
  echo "Skipping APK build (set ROSID_RUN_BUILD=1 on a provisioned machine)."
fi
