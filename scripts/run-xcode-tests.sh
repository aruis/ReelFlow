#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${PROJECT_FILE:-ReelFlow.xcodeproj}"
SCHEME_NAME="${SCHEME_NAME:-ReelFlow}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.derivedData}"
DESTINATION="${DESTINATION:-platform=macOS}"

cd "$ROOT_DIR"

xcodebuild test \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME_NAME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='-' \
  "$@"
