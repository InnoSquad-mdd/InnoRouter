#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[principle-gates] Running swift test"
swift test

echo "[principle-gates] Checking Nav* public symbols"
if rg -n "public .*\\bNav[A-Z]" Sources; then
  echo "[principle-gates] Failed: legacy Nav* public symbols found"
  exit 1
fi

echo "[principle-gates] Checking deprecated/availability shims"
if rg -n "deprecated|@available\\(" Sources; then
  echo "[principle-gates] Failed: deprecated or availability shim found"
  exit 1
fi

echo "[principle-gates] Checking legacy SwiftUI navigator surface"
if rg -n "@EnvironmentNavigator|public func navigator\\(" Sources Examples README.md; then
  echo "[principle-gates] Failed: legacy navigator API found"
  exit 1
fi

echo "[principle-gates] Checking AnyCoordinator removal"
if rg -n "AnyCoordinator" Sources Examples README.md; then
  echo "[principle-gates] Failed: AnyCoordinator symbol found"
  exit 1
fi

echo "[principle-gates] Checking optional intent dispatch usage"
if rg -n "navigationIntent\\?\\.send" Sources Examples README.md; then
  echo "[principle-gates] Failed: optional intent dispatch usage found"
  exit 1
fi

echo "[principle-gates] Checking deep-link fallback removal"
if rg -n "about:blank|schemeNotAllowed\\(actualScheme: nil\\)" Sources/InnoRouterEffects; then
  echo "[principle-gates] Failed: legacy fallback found"
  exit 1
fi

echo "[principle-gates] Checking @unchecked Sendable removal"
if rg -n "@unchecked Sendable" Sources Tests; then
  echo "[principle-gates] Failed: @unchecked Sendable usage found"
  exit 1
fi

echo "[principle-gates] Checking README SwiftUI philosophy section uniqueness"
SWIFTUI_ALIGNMENT_SECTION_COUNT="$(rg -n "^### SwiftUI Philosophy Alignment$" README.md | wc -l | tr -d ' ' || true)"
if [[ "$SWIFTUI_ALIGNMENT_SECTION_COUNT" != "1" ]]; then
  echo "[principle-gates] Failed: expected 1 SwiftUI Philosophy Alignment section, got $SWIFTUI_ALIGNMENT_SECTION_COUNT"
  exit 1
fi

echo "[principle-gates] Checking fail-fast probe (missing NavigationEnvironmentStorage)"
PROBE_OUTPUT_FILE="$(mktemp)"
set +e
swift run NavigationEnvironmentFailFastProbe >"$PROBE_OUTPUT_FILE" 2>&1
PROBE_EXIT_CODE=$?
set -e

if [[ "$PROBE_EXIT_CODE" -eq 0 ]]; then
  echo "[principle-gates] Failed: fail-fast probe unexpectedly succeeded"
  cat "$PROBE_OUTPUT_FILE"
  rm -f "$PROBE_OUTPUT_FILE"
  exit 1
fi

if ! rg -q "NavigationEnvironmentStorage is missing" "$PROBE_OUTPUT_FILE"; then
  echo "[principle-gates] Failed: fail-fast probe did not report expected message"
  cat "$PROBE_OUTPUT_FILE"
  rm -f "$PROBE_OUTPUT_FILE"
  exit 1
fi

rm -f "$PROBE_OUTPUT_FILE"

echo "[principle-gates] Checking public Bool naming"
PUBLIC_BOOL_NAMES="$(rg -n --no-heading "public (var|let) [A-Za-z_][A-Za-z0-9_]*: Bool" Sources \
  | sed -E 's/.*public (var|let) ([A-Za-z_][A-Za-z0-9_]*) *: Bool.*/\2/' || true)"

if [[ -n "$PUBLIC_BOOL_NAMES" ]]; then
  INVALID_BOOL_NAMES="$(printf '%s\n' "$PUBLIC_BOOL_NAMES" | rg -v '^(is|has|can|should)[A-Z].*' || true)"
  if [[ -n "$INVALID_BOOL_NAMES" ]]; then
    echo "[principle-gates] Failed: public Bool names must start with is/has/can/should"
    echo "$INVALID_BOOL_NAMES"
    exit 1
  fi
fi

echo "[principle-gates] All checks passed"
