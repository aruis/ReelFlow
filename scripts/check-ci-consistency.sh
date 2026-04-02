#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORKFLOW_FILE=".github/workflows/ci.yml"
PROJECT_FILE="ReelFlow.xcodeproj/project.pbxproj"

search() {
  local mode="$1"
  local pattern="$2"
  shift 2

  if command -v rg >/dev/null 2>&1; then
    case "$mode" in
      quiet) rg -q "$pattern" "$@" ;;
      lines) rg -n "$pattern" "$@" ;;
      *)
        echo "[ci-consistency] ERROR: unsupported search mode: $mode"
        exit 1
        ;;
    esac
    return
  fi

  case "$mode" in
    quiet) grep -Eq "$pattern" "$@" ;;
    lines) grep -En "$pattern" "$@" ;;
    *)
      echo "[ci-consistency] ERROR: unsupported search mode: $mode"
      exit 1
      ;;
  esac
}

echo "[ci-consistency] checking required files..."
for path in \
  "$WORKFLOW_FILE" \
  "$PROJECT_FILE" \
  "scripts/run-xcode-tests.sh" \
  "scripts/check-maintainability.sh" \
  "scripts/test-non-ui.sh" \
  "scripts/test-audio-regression.sh" \
  "scripts/test-ui-smoke.sh"; do
  if [[ ! -f "$path" ]]; then
    echo "[ci-consistency] ERROR: missing required file: $path"
    exit 1
  fi
done

echo "[ci-consistency] checking for stale project names in CI files..."
if search lines 'PhotoTime|phototime' \
  .github/workflows/ci.yml \
  scripts/check-maintainability.sh \
  scripts/run-xcode-tests.sh \
  scripts/test-ci-gate.sh \
  scripts/test-non-ui.sh \
  scripts/test-audio-regression.sh \
  scripts/test-ui-smoke.sh \
  scripts/release-gate.sh \
  scripts/collect-diagnostics.sh; then
  echo "[ci-consistency] ERROR: stale project name detected in CI-related files."
  exit 1
fi

echo "[ci-consistency] checking workflow references..."
if ! search quiet 'PROJECT_FILE: ReelFlow\.xcodeproj' "$WORKFLOW_FILE"; then
  echo "[ci-consistency] ERROR: workflow PROJECT_FILE env is missing or incorrect."
  exit 1
fi
if ! search quiet 'SCHEME_NAME: ReelFlow' "$WORKFLOW_FILE"; then
  echo "[ci-consistency] ERROR: workflow SCHEME_NAME env is missing or incorrect."
  exit 1
fi
if ! search quiet 'DERIVED_DATA_PATH: \.derivedData' "$WORKFLOW_FILE"; then
  echo "[ci-consistency] ERROR: workflow DERIVED_DATA_PATH env is missing or incorrect."
  exit 1
fi
if ! search quiet "hashFiles\\('ReelFlow\\.xcodeproj/project\\.pbxproj'\\)" "$WORKFLOW_FILE"; then
  echo "[ci-consistency] ERROR: workflow cache key is not tied to ReelFlow.xcodeproj/project.pbxproj."
  exit 1
fi

echo "[ci-consistency] checking shared xcode test runner usage..."
for path in \
  "scripts/test-non-ui.sh" \
  "scripts/test-audio-regression.sh" \
  "scripts/test-ui-smoke.sh"; do
  if ! search quiet '\./scripts/run-xcode-tests\.sh' "$path"; then
    echo "[ci-consistency] ERROR: expected shared test runner usage in $path"
    exit 1
  fi
done

echo "[ci-consistency] PASSED"
