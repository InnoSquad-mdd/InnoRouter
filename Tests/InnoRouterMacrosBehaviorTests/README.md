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
  ```swift skip package-manifest-fragment
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

## Temporarily unexecutable tuple-subscript probes

The current suite does not contain Swift Testing `.disabled` cases.
Instead, two tuple-valued `[case:]` probes are intentionally left as
documented gaps because they trip a Swift 6.3 SIL-lowering bug in
generated generic-subscript code:

- `RoutableBehaviorTests.embedExtract_roundtrip_multiLabeled` keeps the
  tuple extraction coverage through direct `CasePath.extract(_:)` calls;
  the adjacent `// NOTE:` explains why the equivalent
  `route[case: ShapeRoute.Cases.rectangle]` probe is not executable yet.
- `CasePathableBehaviorTests.subscriptCaseMatchesOnlyCorrectCase`
  covers single-value `[case:]` access and keeps the tuple-valued
  `event[case: UIEvent.Cases.swiped]` probe documented in a `// NOTE:`.

Re-enabling either probe is a focused PR after the Swift compiler fix
lands and `swift test --filter InnoRouterMacrosBehaviorTests` passes on
the CI-pinned Xcode toolchain. Do not bundle that re-enable with
unrelated work, since the Swift toolchain dependency moves independently
of the package.

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
