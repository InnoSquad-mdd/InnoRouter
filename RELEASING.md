# Releasing InnoRouter

This project is a Swift Package with modular products:

- `InnoRouterCore`: runtime (`NavStack`, `NavCommand`, `NavEngine`, `AnyNavigator`, middleware)
- `InnoRouterSwiftUI`: SwiftUI integration (`NavStore`, hosts, environment)
- `InnoRouterDeepLink`: deep link parsing/matching/pipeline
- `InnoRouter`: umbrella re-export (Core + SwiftUI + DeepLink)
- `InnoRouterMacros`: optional macros (`@Routable`, `@CasePathable`)
- `InnoRouterInnoFlowAdapter`: optional effect adapter

## Checklist

### API & SemVer
- Confirm intended public API surface (what should stay `public` vs `internal`).
- If breaking changes exist, bump major version.
- Add/verify release notes in `README.md` (high-level changes + migration notes if applicable).

### Behavioral Contracts
- `NavStore.execute(_:)` semantics:
  - Middleware runs deterministically for each executed command.
  - `.sequence` / `.conditional` behavior is documented (whether middleware observes outer/composite commands).
  - `onChange` triggers only on real state changes.
- Deep link policy:
  - Decide where pending deep links live (app policy layer).
  - Document how `DeepLinkCoordinating` should handle auth completion.

### Tests
- `swift test` passes locally.
- Add tests for any new contract or bug fix (especially middleware/deeplink).
- Ensure macro tests match the current SwiftSyntax formatter output.

### Package Health
- `Package.swift` products/targets are consistent with folder names.
- No unused/legacy directories remain under `Sources/` and `Tests/`.
- Examples compile against the current API (even if not built by SPM).

### Tag & Publish
- Create a git tag `vX.Y.Z`.
- Publish release notes (GitHub Releases or equivalent).

