# InnoRouter Project

## Project Overview

InnoRouter is a SwiftUI-native navigation framework focused on state-driven navigation, unidirectional command execution, and dependency inversion.

v2 guidance:
- SwiftUI views use `@EnvironmentNavigationIntent` and `send(_:)`.
- Coordinator/Store layer owns command execution.
- Direct view-level navigator APIs are not part of public SwiftUI surface.
- Missing host environment wiring fails fast.

## Building and Running

### Build
```bash
swift build
```

### Test
```bash
swift test
```

## Module Summary

- `InnoRouter`: umbrella package
- `InnoRouterCore`: route stack, command engine, navigator contracts
- `InnoRouterSwiftUI`: store, hosts, coordinator, intent dispatch environment
- `InnoRouterDeepLink`: matcher/pipeline/plan
- `InnoRouterMacros`: macro helpers
- `InnoRouterEffects`: async effect handlers

## Development Conventions

- Prefer `NavigationIntent` for view-to-policy communication.
- Keep deep-link decisions payload-rich (`rejected(reason:)`, `unhandled(url:)`).
- Keep tests deterministic and actor-safe (`@MainActor` where needed).
- Preserve host-scoped environment isolation across multiple navigation hosts.

## Release/Quality Gates

- `rg -n "public .*\\bNav[A-Z]" Sources` => 0
- `rg -n "deprecated|@available\\(" Sources` => 0
- `rg -n "@EnvironmentNavigator|public func navigator\\(" Sources Examples README.md` => 0
- `rg -n "AnyCoordinator" Sources Examples README.md` => 0
- `rg -n "navigationIntent\\?\\.send" Sources Examples README.md` => 0
- `rg -n "about:blank|schemeNotAllowed\\(actualScheme: nil\\)" Sources/InnoRouterEffects` => 0

Release checklist lives in `RELEASING.md`.
