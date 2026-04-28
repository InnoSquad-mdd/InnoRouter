# Macro Dependency Cost Measurement

Date: 2026-04-28

Purpose: measure the current macro dependency surface before deciding whether
to introduce SwiftPM package traits, split products, or a separate macro
package. This 4.0.0 release-ready pass records evidence and operating
guidance only; it does not change `Package.swift`.

## Environment

```text
swift-driver version: 1.148.6 Apple Swift version 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
Target: arm64-apple-macosx26.0
```

## Commands

```bash
swift package show-traits
/usr/bin/time -p swift build --target InnoRouter
/usr/bin/time -p swift build --target InnoRouterMacros
swift test
```

## Results

`swift package show-traits` exited successfully and printed no traits, matching
the current `Package.swift` state.

The local build measurements were incremental workspace builds, so treat them
as directional rather than clean-room benchmark numbers:

| Command | Result | real | user | sys |
| --- | --- | ---: | ---: | ---: |
| `swift build --target InnoRouter` | passed | 3.19s | 1.41s | 0.51s |
| `swift build --target InnoRouterMacros` | passed | 1.20s | 0.50s | 0.19s |

`swift test` passed after `swift package clean` with 626 tests in 91 suites and
13 known issues.

## Decision

Keep the macro package layout unchanged for this work. The measured cost does
not justify adding package traits, product splitting, or a separate macro
package before there is stronger consumer evidence that `swift-syntax` exposure
is creating real adoption friction.

## Operating guidance

When bumping `swift-syntax`, re-run the measurement commands above before
changing the package layout. Keep `InnoRouterMacros` in-package unless the
measured cost or consumer reports show that the macro dependency is blocking
adoption.

If `swift test` fails at link time with an undefined symbol involving
`SwiftSyntaxMacrosTestSupport.assertMacroExpansion`, suspect stale SwiftPM build
artifacts before assuming a source regression. First run:

```bash
swift package clean
swift test
```

If the failure persists, verify with a clean scratch build:

```bash
swift test --scratch-path /tmp/innorouter-clean-scratch --disable-experimental-prebuilts --skip-update
```

A passing clean scratch build means the checked-in source and pinned
`swift-syntax` revision are coherent, and the local `.build` directory should be
recreated before running the release gates again.
