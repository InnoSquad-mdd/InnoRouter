# CI Gates

`scripts/principle-gates.sh` is the single entry point that mirrors the
GitHub Actions release-readiness contract. Every commit landed on
`main` is expected to pass it locally before the PR opens.

This document covers what each gate enforces, the failure signal
operators see, and how to reproduce a single gate without running
the whole pipeline.

## Quick reference

```bash
# Full pipeline — used in CI and on tag pushes.
./scripts/principle-gates.sh

# Full pipeline + per-platform xcodebuild compile probe.
./scripts/principle-gates.sh --platforms=all
./scripts/principle-gates.sh --platforms=ios,macos
```

Environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SWIFTPM_JOBS` | `2` | `swift test` / `swift build` parallelism |
| `XCODEBUILD_JOBS` | `2` | `xcodebuild` parallelism for Gate 13 |

Hard requirement: `rg` (ripgrep) must be on `PATH`. The script aborts
early with a clear message if it is missing.

## Gates

| # | Gate | Purpose | Local repro |
| --- | --- | --- | --- |
| 1 | `swift test` | Full Swift Testing suite (`Tests/`). | `swift test` |
| 2 | DocC preview build | Rebuilds every `.docc` catalog; catches symbol drift and broken cross-refs. | `./scripts/build-docc-site.sh --version preview --skip-latest` |
| 3 | Public API baselines | Diff against recorded baselines under `Baselines/`. SemVer 4.x is additive only — removals/renames fail. | `./scripts/check-public-api.sh` |
| 4 | Maintainer docs consistency | README / CLAUDE.md / AGENTS.md / RELEASING.md / CHANGELOG.md cross-reference and version-string sync. | `./scripts/check-docs-consistency.sh` |
| 5 | Doc Swift code blocks | Code blocks tagged `swift compile` / `swift skip` typecheck against the published API. | `./scripts/check-docs-code-blocks.sh` |
| 6 | Examples ↔ ExamplesSmoke parity | 1:1 file alignment between the two example trees. See `Examples/README.md` for which side to edit. | `./scripts/check-examples-parity.sh` |
| 7 | Smoke targets build | Compiler-stable fixtures (no macros) so toolchain churn does not break unrelated examples. | `swift build --target InnoRouterExamplesSmoke` (and siblings) |
| 8 | Human-facing examples build | Macro-using examples in `Examples/` — exercises the idiomatic surface. | `swift build --target InnoRouterStandaloneExample` (and siblings) |
| 9 | Performance smoke | Coarse timing budget for engine dispatch / command algebra. | `./scripts/performance-smoke.sh` |
| 10 | Source-level lint gates | Forbidden patterns (`@unchecked Sendable`, `nonisolated(unsafe)`, etc.) and debug-only fences. | `./scripts/lint-source-gates.sh` |
| 11 | Fail-fast probe | Missing `NavigationEnvironmentStorage` must crash deterministically with the documented message — guards against silent fallback regressions. | `swift run NavigationEnvironmentFailFastProbe` (expected to fail) |
| 12 | Public Bool naming | Public `Bool` properties must start with `is`, `has`, `can`, or `should`. | `rg "public (var|let) [A-Za-z_][A-Za-z0-9_]*: Bool" Sources` |
| 13 | Per-platform compile probe (optional) | `xcodebuild` against each Apple-platform generic simulator destination. Only runs when `--platforms=…` is passed. | `./scripts/principle-gates.sh --platforms=all` |

## `--platforms=` flag

Accepted tokens (lowercase, comma- or space-separated):

```
all  ios  ipados  macos  tvos  watchos  visionos
```

Rules:

- Empty value (`--platforms=`) is rejected.
- `all` cannot be combined with explicit names — `--platforms=all,ios`
  is rejected to keep the flag unambiguous.
- Each requested platform invokes `xcodebuild build -scheme
  InnoRouterSwiftUI -destination "<generic>"`. Generic destinations
  avoid drift between local toolchains and CI runners.
- `xcodebuild` must be available; the gate aborts otherwise.

## CI workflow mapping

Every gate above runs under one of the workflows in `.github/workflows/`:

| Workflow | Gates |
| --- | --- |
| `principle-gates.yml` | 1–12 (every PR / push to `main`) |
| `platforms.yml` | 13 (full Apple matrix, `fail-fast: false`) |
| `docs-ci.yml` | 2 (DocC build validation) |
| `coverage.yml` | 1 (with coverage instrumentation) |
| `performance-smoke.yml` | 9 (perf regression detection) |
| `release.yml` | reruns 1–13 + DocC publishing on bare semver tags |

Tag format is bare semver (`4.2.0`) — leading-`v` or prefixed tags
(`v4.2.0`, `release-4.2.0`) are rejected by the regex in `release.yml`.

## When a gate fails

Default response order:

1. Re-read the failing gate's purpose above.
2. Reproduce locally with the single command in the table — most
   gates run in a few seconds independently.
3. If the failure is genuine, fix the underlying cause rather than
   the symptom. Bypassing a gate (`--no-verify`, environment
   override) is not the intended workflow.
4. If the failure is a baseline drift (Gate 3) caused by a deliberate
   *additive* change, regenerate the baseline through the dedicated
   helper documented in `scripts/check-public-api.sh`.

## See also

- [`RELEASING.md`](../RELEASING.md) — tag/release flow that reruns this script.
- [`Docs/v2-principle-scorecard.md`](v2-principle-scorecard.md) — the principles that motivate the gates.
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — when to run `principle-gates.sh` during development.
