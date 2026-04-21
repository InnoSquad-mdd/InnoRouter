#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "[principle-gates] Failed: ripgrep (rg) is required but was not found in PATH"
  exit 1
fi

echo "[principle-gates] Running swift test"
swift test

echo "[principle-gates] Building DocC preview site"
./scripts/build-docc-site.sh --version preview

echo "[principle-gates] Checking public API baselines"
./scripts/check-public-api.sh

echo "[principle-gates] Building example smoke targets"
swift build --target InnoRouterStandaloneExampleSmoke
swift build --target InnoRouterCoordinatorExampleSmoke
swift build --target InnoRouterDeepLinkExampleSmoke
swift build --target InnoRouterSplitCoordinatorExampleSmoke
swift build --target InnoRouterAppShellExampleSmoke
swift build --target InnoRouterModalExampleSmoke
swift build --target InnoRouterMacrosExampleSmoke
swift build --target InnoRouterNavigationEffects
swift build --target InnoRouterDeepLinkEffects
swift build --target InnoRouterEffects

echo "[principle-gates] Building human-facing example targets"
swift build --target InnoRouterStandaloneExample
swift build --target InnoRouterCoordinatorExample
swift build --target InnoRouterDeepLinkExample
swift build --target InnoRouterSplitCoordinatorExample
swift build --target InnoRouterAppShellExample

echo "[principle-gates] Checking Nav* public symbols"
if rg -n "public .*\\bNav[A-Z]" Sources; then
  echo "[principle-gates] Failed: legacy Nav* public symbols found"
  exit 1
fi

echo "[principle-gates] Checking deprecated/availability shims"
if rg -n "deprecated|@available\\(" Sources --glob '*.swift' --glob '!Sources/InnoRouterSwiftUI/NavigationStore.swift'; then
  echo "[principle-gates] Failed: deprecated or availability shim found"
  exit 1
fi

echo "[principle-gates] Checking legacy SwiftUI navigator surface"
if rg -n "@EnvironmentNavigator|public func navigator\\(" Sources Examples ExamplesSmoke README.md; then
  echo "[principle-gates] Failed: legacy navigator API found"
  exit 1
fi

echo "[principle-gates] Checking AnyCoordinator removal"
if rg -n "AnyCoordinator" Sources Examples ExamplesSmoke README.md; then
  echo "[principle-gates] Failed: AnyCoordinator symbol found"
  exit 1
fi

echo "[principle-gates] Checking optional intent dispatch usage"
if rg -n "navigationIntent\\?\\.send" Sources Examples ExamplesSmoke README.md RELEASING.md CLAUDE.md Docs --glob '*.swift' --glob '*.md'; then
  echo "[principle-gates] Failed: optional intent dispatch usage found"
  exit 1
fi

echo "[principle-gates] Checking deep-link intent removal from SwiftUI surface"
if rg -n "\\.deepLink\\(|case \\.deepLink" Sources/InnoRouterSwiftUI Sources/InnoRouterUmbrella Examples ExamplesSmoke README.md Tests/InnoRouterTests; then
  echo "[principle-gates] Failed: deep-link intent surface found"
  exit 1
fi

echo "[principle-gates] Checking deep-link fallback removal"
if rg -n "about:blank|schemeNotAllowed\\(actualScheme: nil\\)" Sources/InnoRouterEffects Sources/InnoRouterDeepLinkEffects Sources/InnoRouterNavigationEffects; then
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

echo "[principle-gates] Checking documentation for semver tag formatting"
if rg -n '\bvX\.Y\.Z\b|\bv[0-9]+\.[0-9]+\.[0-9]+\b' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[principle-gates] Failed: documentation still references v-prefixed release tags"
  exit 1
fi

echo "[principle-gates] Checking documentation for renamed path mismatch policy symbols"
if rg -n 'NonPrefixPathRewritePolicy|NonPrefixPathRewriteResolution|nonPrefixPathRewritePolicy' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[principle-gates] Failed: documentation still references legacy path mismatch symbols"
  exit 1
fi

echo "[principle-gates] Checking documentation for legacy effect module names"
if rg -n 'Sources/InnoRouterEffects/NavigationEffectHandler.swift|Sources/InnoRouterEffects/DeepLinkEffectHandler.swift' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[principle-gates] Failed: documentation still references legacy effect implementation paths"
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
