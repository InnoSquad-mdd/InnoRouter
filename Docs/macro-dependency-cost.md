# Macro Dependency Cost Measurement

Date: 2026-04-26

Purpose: measure the current macro dependency surface before deciding whether
to introduce SwiftPM package traits, split products, or a separate macro
package. This pass records evidence only; it does not change `Package.swift`.

## Environment

```text
swift-driver version: 1.148.6 Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
Target: arm64-apple-macosx26.0
```

## Commands

```bash
swift package show-traits
/usr/bin/time -p swift build --target InnoRouter
/usr/bin/time -p swift build --target InnoRouterMacros
```

## Results

`swift package show-traits` exited successfully and printed no traits, matching
the current `Package.swift` state.

The local build measurements were incremental workspace builds, so treat them
as directional rather than clean-room benchmark numbers:

| Command | Result | real | user | sys |
| --- | --- | ---: | ---: | ---: |
| `swift build --target InnoRouter` | passed | 3.98s | 2.65s | 1.08s |
| `swift build --target InnoRouterMacros` | passed | 2.82s | 1.49s | 0.66s |

## Decision

Keep the macro package layout unchanged for this work. The measured cost does
not justify adding package traits, product splitting, or a separate macro
package before there is stronger consumer evidence that `swift-syntax` exposure
is creating real adoption friction.
