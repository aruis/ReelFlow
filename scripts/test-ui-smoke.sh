#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

./scripts/run-xcode-tests.sh \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testPrimarySecondaryActionGroupsAndInitialButtonState \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFailureScenarioShowsFailureCard \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFailureRecoveryActionCanReachSuccessCard \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testSuccessScenarioShowsSuccessCard \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testInvalidScenarioShowsInlineValidation \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFirstRunReadyScenarioAllowsExport
