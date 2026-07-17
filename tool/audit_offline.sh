#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$PROJECT_DIR/android/app/src/main/AndroidManifest.xml"

if rg -n 'android.permission.(INTERNET|ACCESS_NETWORK_STATE)' "$MANIFEST"; then
  echo "Network permission found in Android main manifest." >&2
  exit 1
fi

if rg -n '^\s+(firebase_|sentry|http:|dio:|amplitude_|mixpanel_)' "$PROJECT_DIR/pubspec.yaml"; then
  echo "Banned network/analytics dependency found in pubspec.yaml." >&2
  exit 1
fi

for merged in \
  "$PROJECT_DIR/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml" \
  "$PROJECT_DIR/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml"; do
  if [[ -f "$merged" ]] && rg -n 'android.permission.INTERNET' "$merged"; then
    echo "INTERNET permission found in merged release manifest: $merged" >&2
    exit 1
  fi
done

echo "Offline audit passed: no declared network permission or direct network SDK."
