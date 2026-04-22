#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "[principle-gates] Failed: ripgrep (rg) is required but was not found in PATH"
  exit 1
fi

# --platforms=all runs a per-platform build probe after the core checks.
# macOS-only CI runners can pass it to gate the Apple platform matrix
# locally without spinning up the full GitHub Actions workflow.
# Individual platforms are space- or comma-separated and must be one of:
# ios, ipados, macos, tvos, watchos, visionos.
PLATFORMS_ARG=""
for arg in "$@"; do
  case "$arg" in
    --platforms=*)
      PLATFORMS_ARG="${arg#--platforms=}"
      ;;
  esac
done

NORMALIZED_PLATFORMS_ARG=""
if [[ -n "$PLATFORMS_ARG" ]]; then
  NORMALIZED_PLATFORMS_ARG="$(echo "$PLATFORMS_ARG" | tr '[:upper:]' '[:lower:]' | tr ',' ' ' | xargs)"
  if [[ -z "$NORMALIZED_PLATFORMS_ARG" ]]; then
    echo "[principle-gates] Failed: --platforms= must not be empty"
    exit 1
  fi

  VALID_PLATFORM_TOKENS="all ios ipados macos tvos watchos visionos"
  for token in $NORMALIZED_PLATFORMS_ARG; do
    if [[ ! " $VALID_PLATFORM_TOKENS " =~ " $token " ]]; then
      echo "[principle-gates] Failed: unsupported platform token '$token'"
      exit 1
    fi
  done

  # Rejecting `all` combined with individual names keeps the flag
  # unambiguous. Before this guard, `--platforms=all,ios` silently
  # behaved the same as `--platforms=all`, which would have hidden
  # a typo or a confused expectation about what the probe actually
  # ran.
  TOKEN_COUNT="$(echo "$NORMALIZED_PLATFORMS_ARG" | wc -w | tr -d ' ')"
  if [[ " $NORMALIZED_PLATFORMS_ARG " == *" all "* && "$TOKEN_COUNT" != "1" ]]; then
    echo "[principle-gates] Failed: --platforms=all cannot be combined with specific platforms"
    echo "[principle-gates]         Use --platforms=all on its own, or drop 'all' and list platforms explicitly"
    exit 1
  fi
fi

echo "[principle-gates] Running swift test"
swift test

echo "[principle-gates] Building DocC preview site"
./scripts/build-docc-site.sh --version preview

echo "[principle-gates] Checking public API baselines"
./scripts/check-public-api.sh

echo "[principle-gates] Checking maintainer docs consistency"
./scripts/check-docs-consistency.sh

echo "[principle-gates] Building example smoke targets"
swift build --target InnoRouterExamplesSmoke
swift build --target InnoRouterStandaloneExampleSmoke
swift build --target InnoRouterCoordinatorExampleSmoke
swift build --target InnoRouterNavigationEffects
swift build --target InnoRouterDeepLinkEffects
swift build --target InnoRouterEffects

echo "[principle-gates] Building human-facing example targets"
swift build --target InnoRouterStandaloneExample
swift build --target InnoRouterCoordinatorExample
swift build --target InnoRouterDeepLinkExample
swift build --target InnoRouterSplitCoordinatorExample
swift build --target InnoRouterAppShellExample
swift build --target InnoRouterMultiPlatformExample
swift build --target InnoRouterVisionOSImmersiveExample

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

if [[ -n "$PLATFORMS_ARG" ]]; then
  echo "[principle-gates] Running per-platform build probe ($PLATFORMS_ARG)"
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "[principle-gates] Failed: xcodebuild is required for per-platform probe"
    exit 1
  fi

  # Map shorthand platform names to compile-only xcodebuild destinations.
  # Generic simulator destinations avoid local / runner drift when
  # exact device names or runtime images differ.
  declare -a PLATFORM_ENTRIES
  PLATFORM_ENTRIES=(
    "iOS|generic/platform=iOS Simulator"
    "iPadOS|generic/platform=iOS Simulator"
    "macOS|platform=macOS"
    "tvOS|generic/platform=tvOS Simulator"
    "watchOS|generic/platform=watchOS Simulator"
    "visionOS|generic/platform=visionOS Simulator"
  )

  # Normalise the user's filter list: lowercase, split on , or space.
  REQUESTED="$NORMALIZED_PLATFORMS_ARG"

  MATCHED_PLATFORM_COUNT=0

  for entry in "${PLATFORM_ENTRIES[@]}"; do
    name="${entry%%|*}"
    dest="${entry#*|}"
    name_lc="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

    if [[ "$REQUESTED" != "all" && ! " $REQUESTED " =~ " $name_lc " ]]; then
      continue
    fi

    MATCHED_PLATFORM_COUNT=$((MATCHED_PLATFORM_COUNT + 1))
    echo "[principle-gates] xcodebuild build -scheme InnoRouterSwiftUI ($name)"
    xcodebuild build \
      -scheme InnoRouterSwiftUI \
      -destination "$dest" \
      -quiet
  done

  if [[ "$MATCHED_PLATFORM_COUNT" -eq 0 ]]; then
    echo "[principle-gates] Failed: --platforms= matched no supported platforms"
    exit 1
  fi
fi

echo "[principle-gates] All checks passed"
