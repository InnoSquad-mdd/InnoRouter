#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/.build/performance-smoke.json}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

swift run --package-path "$ROOT_DIR" InnoRouterPerformanceSmoke --output "$OUTPUT_PATH"

echo "Performance smoke report written to $OUTPUT_PATH"
cat "$OUTPUT_PATH"

# Enforce the per-sample regression thresholds that
# InnoRouterPerformanceSmoke embeds directly in the report. Each
# sample carries a `threshold` and a computed `ratio` (largeMs /
# smallMs); if any sample's ratio exceeds the threshold the smoke
# tool flips `passed` to false. Before this check was wired in, the
# CI job uploaded the JSON but never failed on a regression — so a
# perf blow-up only surfaced by manual artefact inspection.
if ! python3 - "$OUTPUT_PATH" <<'PY'; then
import json
import sys

report_path = sys.argv[1]
with open(report_path, "r", encoding="utf-8") as handle:
    report = json.load(handle)

failed = [sample for sample in report.get("samples", []) if not sample.get("passed", True)]
if report.get("passed", True) and not failed:
    sys.exit(0)

print(f"[performance-smoke] Failed: {len(failed)} sample(s) regressed past their threshold")
for sample in failed:
    print(
        "  - {name}: ratio {ratio:.2f} > threshold {threshold:.2f} "
        "(small {smallMs:.2f}ms / large {largeMs:.2f}ms)".format(
            name=sample.get("name", "<unknown>"),
            ratio=sample.get("ratio", float("nan")),
            threshold=sample.get("threshold", float("nan")),
            smallMs=sample.get("smallMilliseconds", float("nan")),
            largeMs=sample.get("largeMilliseconds", float("nan")),
        )
    )
sys.exit(1)
PY
    exit 1
fi

echo "[performance-smoke] All scaling ratios within threshold"
