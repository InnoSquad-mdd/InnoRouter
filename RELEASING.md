# Releasing InnoRouter

This project is a Swift Package with modular products:

- `InnoRouterCore`: runtime (`RouteStack`, `NavigationCommand`, `NavigationEngine`, `AnyNavigator`, middleware)
- `InnoRouterSwiftUI`: SwiftUI integration (`NavigationStore`, hosts, coordinator contracts, environment intent dispatch)
- `InnoRouterDeepLink`: deep link parsing/matching/pipeline
- `InnoRouter`: umbrella re-export (Core + SwiftUI + DeepLink)
- `InnoRouterMacros`: optional macros (`@Routable`, `@CasePathable`)
- `InnoRouterEffects`: optional effect helpers

## Checklist

### API & SemVer
- Confirm intended public API surface (what should stay `public` vs `internal`).
- If breaking changes exist, bump major version.
- Add release notes in `README.md` with these sections:
  - `Renamed/Removed Public APIs`
  - `Behavior Changes`
  - `SwiftUI Philosophy Alignment`
  - `Framework Comparison`
  - `SOLID and iOS Rules Mapping`

### Behavioral Contracts
- `NavigationStore.send(_:)` and `NavigationStore.execute(_:)` semantics are documented and tested.
- `.sequence` behavior is documented (middleware ordering and execution count).
- `onChange` triggers only on real state changes.
- Deep link policy is documented:
  - pending deep links live in app policy layer
  - `PendingDeepLink.plan` replay path is explicit after authentication

### v2 Breaking Release Notes
- SwiftUI public helper shortcuts removed from `Coordinator` public surface.
- `@EnvironmentNavigationIntent` non-optional fail-fast behavior is documented.
- Typed deep-link effect result changes are documented (`invalidURL`, `missingDeepLinkURL`, `noPendingDeepLink`).
- Added intent set (`goMany`, `backBy`, `backTo`, `backToRoot`) remains documented.

### Tests
- `swift test` passes locally.
- Tests include intent-dispatch path from host/coordinator integration.
- Fail-fast probe fails as expected on missing environment injection:
  - `swift run NavigationEnvironmentFailFastProbe` exits non-zero and reports `NavigationEnvironmentStorage is missing`.
- Deep link and effect contracts from v5 remain green.
- Macro tests remain green against current SwiftSyntax output.
- Multi-host isolation tests remain green.

### Package Health
- `Package.swift` products/targets are consistent with folder names.
- No unused/legacy directories remain under `Sources/` and `Tests/`.
- Examples compile against the current API.
- Gate checks:
  - `./scripts/principle-gates.sh`
  - `rg -n "@unchecked Sendable" Sources Tests` returns 0 results.
  - `rg -n "^### SwiftUI Philosophy Alignment$" README.md | wc -l` equals 1.

### Tag & Publish
- Create a git tag `vX.Y.Z`.
- Publish release notes.
