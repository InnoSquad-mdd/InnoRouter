#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROADMAP_PATH="$ROOT_DIR/Docs/competitive-analysis-and-roadmap.md"

failures=0

check_absent() {
  local file_path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Fn "$pattern" "$file_path" >/dev/null 2>&1; then
    echo "[check-docs-consistency] Failed: $message" >&2
    grep -Fn "$pattern" "$file_path" >&2
    failures=1
  fi
}

echo "[check-docs-consistency] Checking known roadmap drift claims"
check_absent "$ROADMAP_PATH" 'Remaining gap: `RouteStep` / `FlowPlan` are not yet' \
  "roadmap still claims RouteStep / FlowPlan are not Codable"
check_absent "$ROADMAP_PATH" 'state restoration still requires hand-rolling a plan.' \
  "roadmap still claims flow state restoration requires manual planning"
check_absent "$ROADMAP_PATH" 'requires hand-rolling commands.' \
  "roadmap still claims multi-step deep-link rehydration needs hand-rolled commands"
check_absent "$ROADMAP_PATH" '`FlowIntent` parallels were intentionally skipped' \
  "roadmap still claims FlowIntent ergonomic parity was skipped entirely"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "[check-docs-consistency] Known drift-prone claims are up to date"
