#!/usr/bin/env bash
set -euo pipefail

EMULATOR=0
RELEASE=0
EVIDENCE=""
AVD_NAME="rosid_test"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emulator) EMULATOR=1; shift ;;
    --release) RELEASE=1; EMULATOR=1; shift ;;
    --evidence) EVIDENCE="${2:?--evidence requires a milestone name}"; shift 2 ;;
    --avd) AVD_NAME="${2:?--avd requires a name}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FLUTTER_RESOLVED="$(command -v "$FLUTTER_BIN" || printf '%s' "$FLUTTER_BIN")"
DART_BIN="${DART_BIN:-$(dirname "$FLUTTER_RESOLVED")/dart}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
ADB_BIN="$(command -v adb || echo "$SDK_ROOT/platform-tools/adb")"
EMULATOR_BIN="$SDK_ROOT/emulator/emulator"

STARTED_SERIAL=""
STARTED_PID=""
STEPS_MD=""
METRICS_MD=""

cleanup() {
  if [[ -n "$STARTED_SERIAL" ]]; then
    "$ADB_BIN" -s "$STARTED_SERIAL" emu kill >/dev/null 2>&1 || true
  fi
  if [[ -n "$STARTED_PID" ]]; then
    kill "$STARTED_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

run_step() {
  local name="$1"
  shift
  echo "=== STEP: $name ==="
  local start_ts
  start_ts=$(date +%s)
  if "$@"; then
    local end_ts
    end_ts=$(date +%s)
    local dur=$((end_ts - start_ts))
    STEPS_MD="${STEPS_MD}| ${name} | pass | ${dur} |\n"
    echo "PASS: $name (${dur}s)"
  else
    local end_ts
    end_ts=$(date +%s)
    local dur=$((end_ts - start_ts))
    STEPS_MD="${STEPS_MD}| ${name} | fail | ${dur} |\n"
    echo "FAIL: $name (${dur}s)" >&2
    write_summary || true
    exit 1
  fi
}

write_summary() {
  [[ -z "$EVIDENCE" ]] && return 0
  local ev_dir="$PROJECT_DIR/evidence/$EVIDENCE"
  mkdir -p "$ev_dir"
  local commit flutter_ver level
  commit="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  flutter_ver="$("$FLUTTER_BIN" --version 2>/dev/null | head -n 1 || echo unknown)"
  level="A"
  [[ "$EMULATOR" == "1" ]] && level="B"
  [[ "$RELEASE" == "1" ]] && level="Release"
  {
    echo "# Verification summary: $EVIDENCE"
    echo
    echo "- **Date**: $(date -Iseconds)"
    echo "- **Commit**: \`$commit\`"
    echo "- **Level**: $level"
    echo "- **Flutter**: $flutter_ver"
    echo
    echo "## Steps"
    echo
    echo "| Step | Status | Duration (s) |"
    echo "|---|---|---|"
    printf "%b" "$STEPS_MD"
    if [[ -n "$METRICS_MD" ]]; then
      echo
      echo "## Measured numbers"
      echo
      echo "| Metric | Value |"
      echo "|---|---|"
      printf "%b" "$METRICS_MD"
    fi
  } > "$ev_dir/summary.md"
}

cd "$PROJECT_DIR"

# Level A
run_step "Generate localizations (gen-l10n)" "$FLUTTER_BIN" --no-version-check gen-l10n
run_step "Code generation (build_runner)" bash -c '"$1" run build_runner build --delete-conflicting-outputs && "$1" format lib/data/database/app_database.g.dart' _ "$DART_BIN"
run_step "Generate OCR fixture bundle" "$DART_BIN" run tool/generate_ocr_fixture_bundle.dart
run_step "Format check" "$DART_BIN" format --output=none --set-exit-if-changed lib test integration_test tool
run_step "Static analysis" "$FLUTTER_BIN" --no-version-check analyze
run_step "Unit and widget tests" "$FLUTTER_BIN" --no-version-check test
run_step "Offline audit (source)" "$PROJECT_DIR/tool/audit_offline.sh"

# Level B
if [[ "$EMULATOR" == "1" ]]; then
  run_step "Build debug APK" "$FLUTTER_BIN" --no-version-check build apk --debug --dart-define=ROSID_FAKE_CAMERA=true

  EMU_SERIAL="$("$ADB_BIN" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/{print $1; exit}')"
  if [[ -z "$EMU_SERIAL" ]]; then
    "$EMULATOR_BIN" -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim -camera-back none -camera-front none >/dev/null 2>&1 &
    STARTED_PID=$!
    for _ in $(seq 1 80); do
      EMU_SERIAL="$("$ADB_BIN" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/{print $1; exit}')"
      if [[ -n "$EMU_SERIAL" ]]; then
        boot="$("$ADB_BIN" -s "$EMU_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
        if [[ "$boot" == "1" ]]; then
          STARTED_SERIAL="$EMU_SERIAL"
          sleep 3
          break
        fi
      fi
      sleep 3
    done
  fi
  [[ -n "$EMU_SERIAL" ]] || { echo "Emulator failed to start" >&2; exit 1; }

  run_step "Install debug APK" "$ADB_BIN" -s "$EMU_SERIAL" install -r -g build/app/outputs/flutter-apk/app-debug.apk
  "$ADB_BIN" -s "$EMU_SERIAL" shell am force-stop app.rosid.rosid >/dev/null 2>&1 || true
  LAUNCH_OUT="$("$ADB_BIN" -s "$EMU_SERIAL" shell am start -W -n app.rosid.rosid/.MainActivity)"
  echo "$LAUNCH_OUT"
  COLD_MS="$(printf '%s\n' "$LAUNCH_OUT" | awk '/TotalTime:/{print $2; exit}' | tr -d '\r')"
  [[ -n "$COLD_MS" ]] && METRICS_MD="${METRICS_MD}| Cold start (ms) | ${COLD_MS} |\n"
  sleep 3
  if [[ -n "$EVIDENCE" ]]; then
    mkdir -p "$PROJECT_DIR/evidence/$EVIDENCE/screens"
    "$ADB_BIN" -s "$EMU_SERIAL" exec-out screencap -p > "$PROJECT_DIR/evidence/$EVIDENCE/screens/launch-home.png"
  fi
fi

# Release
if [[ "$RELEASE" == "1" ]]; then
  if [[ -n "$(git ls-files android/key.properties '*.jks' '*.keystore')" ]]; then
    echo "Signing material is tracked in git!" >&2
    exit 1
  fi
  run_step "Build split release APKs" "$FLUTTER_BIN" --no-version-check build apk --release --split-per-abi --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=build/symbols --tree-shake-icons
  run_step "Offline audit (merged release manifest)" "$PROJECT_DIR/tool/audit_offline.sh" --require-merged
fi

write_summary
