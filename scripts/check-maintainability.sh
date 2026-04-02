#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

search_debt_markers() {
  local pattern='\b(TODO|FIXME|HACK|XXX)\b'
  if command -v rg >/dev/null 2>&1; then
    rg -n --hidden --glob '!.git/**' --glob '!.derivedData/**' --glob '!*.xcresult/**' \
      "$pattern" \
      ReelFlow ReelFlowTests ReelFlowUITests
    return
  fi

  grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=.derivedData \
    --exclude-dir='*.xcresult' \
    "$pattern" \
    ReelFlow ReelFlowTests ReelFlowUITests
}

echo "[maintainability] checking debt markers..."
if search_debt_markers; then
  echo "[maintainability] ERROR: debt markers detected. Please resolve or track via explicit issue process."
  exit 1
fi

echo "[maintainability] checking core file size budgets..."
content_view_lines="$(wc -l < ReelFlow/App/ContentView.swift | tr -d ' ')"
export_vm_export_lines="$(wc -l < ReelFlow/Features/Export/ExportViewModel+Export.swift | tr -d ' ')"

if [[ "$content_view_lines" -gt 950 ]]; then
  echo "[maintainability] ERROR: ReelFlow/App/ContentView.swift is too large (${content_view_lines} > 950)."
  exit 1
fi

if [[ "$export_vm_export_lines" -gt 850 ]]; then
  echo "[maintainability] ERROR: ReelFlow/Features/Export/ExportViewModel+Export.swift is too large (${export_vm_export_lines} > 850)."
  exit 1
fi

echo "[maintainability] PASSED"
