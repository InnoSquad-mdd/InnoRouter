# InnoRouterMacrosBehaviorTests

Behavioral tests for the `@Routable` and `@CasePathable` macros — exercises
the **expanded** code (not the syntactic expansion itself, which is what
`Tests/InnoRouterMacrosTests` covers via `assertMacroExpansion`).

## Platform requirement: macOS-only

This test target depends on `InnoRouterMacros`, which transitively
depends on the `InnoRouterMacrosPlugin` Swift compiler plugin. Compiler
plugins are built host-only and require SwiftSyntax host-plugin support;
on Apple platforms that means **macOS only**. As a result:

- `Package.swift` gates the dependency:
  ```swift
  .target(
      name: "InnoRouterMacros",
      condition: .when(platforms: [.macOS])
  )
  ```
- Each test source is wrapped in `#if canImport(InnoRouterMacrosPlugin)`
  so the module compiles to an empty translation unit on non-macOS.
- The `platforms.yml` matrix builds `InnoRouterCore` /
  `InnoRouterDeepLink` / `InnoRouterSwiftUI` on every Apple platform,
  but **does not** run macro tests on iOS / tvOS / watchOS / visionOS.
  CI macro coverage lives in `principle-gates.yml`, which runs on a
  macOS runner.
- Linux CI may compile `InnoRouterMacrosPlugin` for build coverage but
  cannot expand macros without a SwiftSyntax host-plugin, so macro
  tests are not run on Linux either.

The release checklist in [`RELEASING.md`](../../RELEASING.md) reminds
maintainers to confirm the macOS runner before tagging.

## Disabled tests

Some tests in `RoutableBehaviorTests` are temporarily disabled because
they trip Swift 6.3 SIL-lowering bugs in generated code. Each disabled
test carries a `// NOTE: …` comment with:

- the exact upstream issue (or a description of the trigger pattern),
- the conditions under which it is safe to re-enable (typically: a
  Swift compiler fix landing AND a clean local probe on the CI-pinned
  Xcode toolchain).

Re-enabling is a focused PR — do not bundle macro re-enables with
unrelated work, since the Swift toolchain dependency moves
independently of the package.

## Running locally

```bash
# Full macro coverage (macOS only):
swift test --filter InnoRouterMacrosBehaviorTests

# Syntactic expansion tests (separate target, also macOS-only):
swift test --filter InnoRouterMacrosTests
```

If you see "No such module 'InnoRouterMacros'" on macOS, run
`swift package clean && swift build` — the macro plugin sometimes
needs a fresh build after Xcode toolchain changes.
