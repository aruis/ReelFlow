#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

./scripts/run-xcode-tests.sh \
  -only-testing:ReelFlowTests/RenderEngineSmokeTests/exportPipelineIncludesAudioTrackWhenConfigured \
  -only-testing:ReelFlowTests/RenderEngineSmokeTests/exportPipelineKeepsShortAudioWithoutLoop \
  -only-testing:ReelFlowTests/RenderEngineSmokeTests/exportPipelineLoopsAudioTrackWhenEnabled
