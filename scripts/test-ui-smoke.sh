#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

./scripts/run-xcode-tests.sh \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testPrimarySecondaryActionGroupsAndInitialButtonState \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFailureScenarioShowsFailureCard \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFailureRecoveryActionCanReachSuccessSheet \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testSuccessScenarioShowsSuccessSheet \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testInvalidScenarioBlocksPrimaryActionAndShowsStatus \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testFirstRunReadyScenarioAllowsExport \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testEnglishSuccessScenarioShowsEnglishLabels \
  -only-testing:ReelFlowUITests/ReelFlowUITests/testEnglishFreeTierScenarioShowsEnglishQuotaCopy
