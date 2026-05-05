#!/usr/bin/env bash
set -euo pipefail

# Source-level lint gates extracted from `principle-gates.sh` so they
# can run independently — locally during edit/refactor work, and on
# CI in parallel with the heavier `swift test` and DocC build steps.
#
# The full set of gates remains driven by `principle-gates.sh`; this
# script is the authoritative implementation, and the parent gate
# script delegates to it. A future SwiftSyntax-based linter can
# replace these grep checks one rule at a time without touching the
# parent script's call signature.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "[lint-source-gates] Failed: ripgrep (rg) is required but was not found in PATH"
  exit 1
fi

echo "[lint-source-gates] Checking swiftformat in lint mode when available"
if command -v swiftformat >/dev/null 2>&1; then
  if [[ -f .swiftformat ]]; then
    swiftformat Sources Tests Examples ExamplesSmoke --lint
  else
    echo "[lint-source-gates] .swiftformat not found; skipping swiftformat check-only gate"
  fi
else
  echo "[lint-source-gates] swiftformat not found; skipping check-only gate"
fi

echo "[lint-source-gates] Checking swiftlint in lint mode when available"
if command -v swiftlint >/dev/null 2>&1; then
  if [[ -f .swiftlint.yml || -f .swiftlint.yaml ]]; then
    swiftlint lint --strict
  else
    echo "[lint-source-gates] .swiftlint.yml not found; skipping swiftlint check-only gate"
  fi
else
  echo "[lint-source-gates] swiftlint not found; skipping check-only gate"
fi

echo "[lint-source-gates] Checking non-ASCII letters in source comments (Hangul, etc.)"
# Public-facing comments and docstrings must be English so the
# library is usable outside the original team's locale. Test
# fixtures still legitimately exercise non-ASCII payloads (see
# `DeepLinkPercentEncodingTests`); restrict the check to Sources/
# and the user-facing example trees.
if rg -nP '[\p{Hangul}]' Sources Examples ExamplesSmoke; then
  echo "[lint-source-gates] Failed: non-ASCII (Hangul) characters found in source comments"
  exit 1
fi

echo "[lint-source-gates] Checking Nav* public symbols"
if rg -n "public .*\\bNav[A-Z]" Sources; then
  echo "[lint-source-gates] Failed: legacy Nav* public symbols found"
  exit 1
fi

echo "[lint-source-gates] Checking deprecated/availability shims"
if rg -n "deprecated|@available\\(" Sources --glob '*.swift' --glob '!Sources/InnoRouterSwiftUI/NavigationStore.swift'; then
  echo "[lint-source-gates] Failed: deprecated or availability shim found"
  exit 1
fi

echo "[lint-source-gates] Checking legacy SwiftUI navigator surface"
if rg -n "@EnvironmentNavigator|public func navigator\\(" Sources Examples ExamplesSmoke README.md; then
  echo "[lint-source-gates] Failed: legacy navigator API found"
  exit 1
fi

echo "[lint-source-gates] Checking AnyCoordinator removal"
if rg -n "AnyCoordinator" Sources Examples ExamplesSmoke README.md; then
  echo "[lint-source-gates] Failed: AnyCoordinator symbol found"
  exit 1
fi

echo "[lint-source-gates] Checking optional intent dispatch usage"
if rg -n "navigationIntent\\?\\.send" Sources Examples ExamplesSmoke README.md RELEASING.md CLAUDE.md Docs --glob '*.swift' --glob '*.md'; then
  echo "[lint-source-gates] Failed: optional intent dispatch usage found"
  exit 1
fi

echo "[lint-source-gates] Checking deep-link intent removal from SwiftUI surface"
if rg -n "\\.deepLink\\(|case \\.deepLink" Sources/InnoRouterSwiftUI Sources/InnoRouterUmbrella Examples ExamplesSmoke README.md Tests/InnoRouterTests; then
  echo "[lint-source-gates] Failed: deep-link intent surface found"
  exit 1
fi

echo "[lint-source-gates] Checking deep-link fallback removal"
DEEP_LINK_FALLBACK_PATHS=()
for path in Sources/InnoRouterEffects Sources/InnoRouterDeepLinkEffects Sources/InnoRouterNavigationEffects; do
  if [[ -e "$path" ]]; then
    DEEP_LINK_FALLBACK_PATHS+=("$path")
  fi
done
if [[ ${#DEEP_LINK_FALLBACK_PATHS[@]} -gt 0 ]] && rg -n "about:blank|schemeNotAllowed\\(actualScheme: nil\\)" "${DEEP_LINK_FALLBACK_PATHS[@]}"; then
  echo "[lint-source-gates] Failed: legacy fallback found"
  exit 1
fi

echo "[lint-source-gates] Checking @unchecked Sendable removal"
if rg -n "@unchecked Sendable" Sources Tests; then
  echo "[lint-source-gates] Failed: @unchecked Sendable usage found"
  exit 1
fi

echo "[lint-source-gates] Checking modal trace privacy"
if rg -n -F 'metadata=\(metadataSummary, privacy: .public)' Sources/InnoRouterSwiftUI/ModalStore.swift \
  || rg -n -F 'outcome=\(outcome, privacy: .public)' Sources/InnoRouterSwiftUI/ModalStore.swift; then
  echo "[lint-source-gates] Failed: modal trace metadata/outcome must stay private"
  exit 1
fi

echo "[lint-source-gates] Checking modal cancellation privacy"
if rg -n -F 'cancellation=\(cancellationReason.map { String(describing: $0) } ?? "nil", privacy: .public)' Sources/InnoRouterSwiftUI/ModalStoreTelemetrySink.swift; then
  echo "[lint-source-gates] Failed: modal command cancellation payload must stay private"
  exit 1
fi

echo "[lint-source-gates] Checking README SwiftUI philosophy section uniqueness"
SWIFTUI_ALIGNMENT_SECTION_COUNT="$(rg -n "^### SwiftUI Philosophy Alignment$" README.md | wc -l | tr -d ' ' || true)"
if [[ "$SWIFTUI_ALIGNMENT_SECTION_COUNT" != "1" ]]; then
  echo "[lint-source-gates] Failed: expected 1 SwiftUI Philosophy Alignment section, got $SWIFTUI_ALIGNMENT_SECTION_COUNT"
  exit 1
fi

echo "[lint-source-gates] Checking documentation for semver tag formatting"
if rg -n '\bvX\.Y\.Z\b|\bv[0-9]+\.[0-9]+\.[0-9]+\b' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[lint-source-gates] Failed: documentation still references v-prefixed release tags"
  exit 1
fi

echo "[lint-source-gates] Checking documentation for renamed path mismatch policy symbols"
if rg -n 'NonPrefixPathRewritePolicy|NonPrefixPathRewriteResolution|nonPrefixPathRewritePolicy' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[lint-source-gates] Failed: documentation still references legacy path mismatch symbols"
  exit 1
fi

echo "[lint-source-gates] Checking documentation for legacy effect module names"
if rg -n 'Sources/InnoRouterEffects/NavigationEffectHandler.swift|Sources/InnoRouterEffects/DeepLinkEffectHandler.swift' README.md RELEASING.md CLAUDE.md Docs Sources --glob '*.md'; then
  echo "[lint-source-gates] Failed: documentation still references legacy effect implementation paths"
  exit 1
fi

echo "[lint-source-gates] All source-level lint gates passed"
