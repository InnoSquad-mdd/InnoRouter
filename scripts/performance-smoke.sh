#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/.build/performance-smoke.json}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

swift run --package-path "$ROOT_DIR" InnoRouterPerformanceSmoke --output "$OUTPUT_PATH"

echo "Performance smoke report written to $OUTPUT_PATH"
cat "$OUTPUT_PATH"
