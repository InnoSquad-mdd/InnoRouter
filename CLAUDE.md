# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Project Overview

InnoRouter is a SwiftUI-native navigation framework built around **state**, **unidirectional execution**, and **dependency inversion**.

- Navigation data model: `RouteStack`, `NavigationCommand`, `NavigationEngine`
- SwiftUI integration: `NavigationStore`, `NavigationHost`, `CoordinatorHost`
- View interaction contract: `NavigationIntent` + `@EnvironmentNavigationIntent`
- Deep link pipeline: `DeepLinkPipeline` -> `DeepLinkDecision` -> `NavigationPlan`

**Requirements**: iOS 18+ / macOS 15+ / tvOS 18+ / watchOS 11+, Swift 6.2+

## Common Commands

### Testing
```bash
swift test
swift test --filter InnoRouterTests
swift test --filter InnoRouterMacrosTests
```

### Build
```bash
swift build
swift build --target InnoRouter
swift build --target InnoRouterCore
```

## Architecture

### Modules

1. **InnoRouterCore**
- `Route`
- `RouteStack<R>`
- `NavigationCommand<R>`
- `NavigationEngine<R>`
- `Navigator`, `AnyNavigator<R>`
- `NavigationMiddleware`

2. **InnoRouterSwiftUI**
- `NavigationStore<R>` (`@Observable`, `@MainActor`)
- `NavigationHost`, `CoordinatorHost`
- `Coordinator`
- `NavigationIntent<R>`
- `@EnvironmentNavigationIntent`
- `AnyNavigationIntentDispatcher<R>`
- `FlowCoordinator`, `TabCoordinator`

3. **InnoRouterDeepLink**
- `DeepLinkMatcher<R>`
- `DeepLinkPipeline<R>`
- `DeepLinkDecision<R>`
- `NavigationPlan<R>`
- `DeepLinkCoordinating`

4. **InnoRouter** (umbrella)

5. **InnoRouterMacros**

6. **InnoRouterEffects**

### Execution Flow

1. `NavigationStore.execute(_:)`
- `.sequence` recursively executes each nested command
- middleware chain executes before engine apply
- `onChange` fires only when state changed

2. `NavigationStore.send(_:)`
- maps `NavigationIntent` to command execution
- canonical path for SwiftUI view-initiated navigation

3. Deep link
- `decide(for:)` returns `.plan`, `.pending`, `.rejected(reason:)`, `.unhandled(url:)`
- `PendingDeepLink.plan` should be replayed after auth succeeds

### SwiftUI Philosophy (v7)

- Views emit intent only; no public direct navigator injection.
- `NavigationStore.state` remains single rendering source.
- Coordinator centralizes policy and destination mapping.
- Missing environment wiring fails fast.

## Testing Conventions

- Use Swift Testing (`@Suite`, `@Test`, `#expect`)
- Navigation tests run on `@MainActor`
- Verify middleware call order/count for `.sequence`
- Verify deep-link payload semantics and pending replay behavior
- Verify typed deep-link effect results (`invalidURL`, `missingDeepLinkURL`, `noPendingDeepLink`)
- Verify multi-host isolation

## Release Gates

- `rg -n "public .*\\bNav[A-Z]" Sources` returns 0
- `rg -n "deprecated|@available\\(" Sources` returns 0
- `rg -n "@EnvironmentNavigator|public func navigator\\(" Sources Examples README.md` returns 0
- `rg -n "AnyCoordinator" Sources Examples README.md` returns 0
- `rg -n "navigationIntent\\?\\.send" Sources Examples README.md` returns 0
- `rg -n "about:blank|schemeNotAllowed\\(actualScheme: nil\\)" Sources/InnoRouterEffects` returns 0

## Release Process

See `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/RELEASING.md`.
