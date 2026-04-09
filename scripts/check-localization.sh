#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[localization] checking String Catalog english coverage..."
python3 - <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path("ReelFlow/Localizable.xcstrings")
data = json.loads(path.read_text())
strings = data.get("strings", {})
han = re.compile(r"[\u4e00-\u9fff]")

missing = []
leaks = []
for key, entry in strings.items():
    if not key:
        continue
    en = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
    if en is None:
        missing.append(key)
        continue
    if han.search(en):
        leaks.append((key, en))

if missing or leaks:
    if missing:
        print("[localization] ERROR: missing english translations:")
        for key in missing[:50]:
            print(f"  - {key}")
    if leaks:
        print("[localization] ERROR: english translations still contain Chinese:")
        for key, value in leaks[:50]:
            print(f"  - {key} => {value}")
    sys.exit(1)

print("[localization] String Catalog english coverage PASSED")
PY

echo "[localization] checking for non-localized Chinese literals in app code..."
raw_matches="$(rg -n 'return "[^"]*[\p{Han}]|= "[^"]*[\p{Han}]|throw [^(]*\("[^"]*[\p{Han}]' ReelFlow --glob '*.swift' || true)"

filtered_matches="$(printf '%s\n' "$raw_matches" | rg -v 'ExportConfiguration.swift:614|ExportConfiguration.swift:616|ExportConfiguration.swift:618|ExportConfiguration.swift:620|ExportConfiguration.swift:624|ExportConfiguration.swift:626' || true)"

if [[ -n "${filtered_matches// }" ]]; then
  echo "[localization] ERROR: found Chinese literals outside localization APIs:"
  printf '%s\n' "$filtered_matches"
  exit 1
fi

echo "[localization] PASSED"
