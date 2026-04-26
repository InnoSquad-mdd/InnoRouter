#!/usr/bin/env bash
# scripts/check-examples-parity.sh
#
# Examples↔ExamplesSmoke parity gate.
#
# - Every `Examples/<Name>Example.swift` MUST have a matching
#   `ExamplesSmoke/<Name>Smoke.swift`. The smoke is the
#   compiler-stable mirror of the human-facing example, so a
#   missing pair means a feature has documentation without a CI
#   build gate.
#
# - Smoke files that are not mirrors of an example are allowed
#   (e.g. `ModalSmoke.swift`, `MacrosSmoke.swift` exercise
#   surface that has no narrative example yet). They live in the
#   allowlist below; anything else without a matching example
#   fails the gate.
#
# - `Package.swift` MUST declare a target for every example file
#   and every solo smoke. Hand-edits to `Examples/` or
#   `ExamplesSmoke/` that forget the manifest update get caught
#   here, before they reach `swift build`.
#
# Exits non-zero on any drift; prints every violation it finds
# (does not stop on the first one) so a single run reports the
# full delta.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

EXAMPLES_DIR="Examples"
SMOKE_DIR="ExamplesSmoke"
MANIFEST="Package.swift"

# Smoke files that intentionally have no Examples/ counterpart.
# Keep this list short — the default expectation is one-to-one.
SMOKE_ONLY_ALLOWLIST=(
    "MacrosSmoke.swift"
    "ModalSmoke.swift"
)

errors=0

report() {
    echo "❌ $*" >&2
    errors=$((errors + 1))
}

contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Collect Example basenames: "Standalone", "Coordinator", ...
example_bases=()
for path in "$EXAMPLES_DIR"/*Example.swift; do
    [[ -e "$path" ]] || continue
    file="$(basename "$path")"
    base="${file%Example.swift}"
    example_bases+=("$base")
done

# Collect Smoke basenames: "Standalone", "Coordinator", ...
smoke_bases=()
smoke_files=()
for path in "$SMOKE_DIR"/*Smoke.swift; do
    [[ -e "$path" ]] || continue
    file="$(basename "$path")"
    smoke_files+=("$file")
    base="${file%Smoke.swift}"
    smoke_bases+=("$base")
done

# 1) Every Example must have a matching Smoke.
for base in "${example_bases[@]}"; do
    if ! contains "$base" "${smoke_bases[@]}"; then
        report "$EXAMPLES_DIR/${base}Example.swift has no matching $SMOKE_DIR/${base}Smoke.swift"
    fi
done

# 2) Every Smoke must either match an Example or be allowlisted.
for file in "${smoke_files[@]}"; do
    base="${file%Smoke.swift}"
    if contains "$base" "${example_bases[@]}"; then
        continue
    fi
    if contains "$file" "${SMOKE_ONLY_ALLOWLIST[@]}"; then
        continue
    fi
    report "$SMOKE_DIR/$file has no matching $EXAMPLES_DIR/${base}Example.swift (and is not in SMOKE_ONLY_ALLOWLIST)"
done

# 3) Manifest must reference every example source and every solo smoke.
manifest_text="$(cat "$MANIFEST")"

for base in "${example_bases[@]}"; do
    src="${base}Example.swift"
    if ! grep -q "\"$src\"" <<<"$manifest_text"; then
        report "$MANIFEST does not reference $EXAMPLES_DIR/$src"
    fi
done

for file in "${smoke_files[@]}"; do
    if ! grep -q "\"$file\"" <<<"$manifest_text"; then
        report "$MANIFEST does not reference $SMOKE_DIR/$file"
    fi
done

if (( errors > 0 )); then
    echo "" >&2
    echo "Examples↔ExamplesSmoke parity gate failed with $errors violation(s)." >&2
    exit 1
fi

echo "✅ Examples↔ExamplesSmoke parity OK ("${#example_bases[@]}" examples, "${#smoke_files[@]}" smokes)"
