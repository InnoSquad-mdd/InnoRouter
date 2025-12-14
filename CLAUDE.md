# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

InnoRouter is a SwiftUI-native navigation framework built around **state**, **unidirectional execution**, and **dependency inversion**. Navigation is expressed as data (`NavStack`, `NavCommand`) and rendered by SwiftUI. Features depend on `Navigator` interface, not concrete implementations.

**Requirements**: iOS 18+ / macOS 15+ / tvOS 18+ / watchOS 11+, Swift 6.2+

## Common Commands

### Testing
```bash
swift test                    # Run all tests
swift test --filter InnoRouterTests           # Run specific test target
swift test --filter InnoRouterMacrosTests     # Run macro tests only
```

### Building
```bash
swift build                   # Build all targets
swift build --target InnoRouter               # Build umbrella module
swift build --target InnoRouterCore           # Build core runtime only
```

### Testing Single Test
```bash
swift test --filter NavStoreTests             # Run NavStore test suite
swift test --filter "testPush"                # Run specific test method
```

## Architecture

### Module Structure

InnoRouter is split into modular products with clear separation of concerns:

1. **InnoRouterCore**: Runtime engine
   - `Route` protocol: Marker for route types (must be `Equatable`, `Hashable`, `Sendable`)
   - `NavStack<R>`: Navigation state container with `path: [R]`
   - `NavCommand<R>`: Enum of navigation commands (push, pop, replace, conditional, sequence)
   - `NavEngine<R>`: Pure function that applies commands to state
   - `Navigator`: Protocol combining `NavStateReadable` + `NavCommandExecuting`
   - `AnyNavigator<R>`: Type-erased navigator wrapper
   - `NavMiddleware`: Cross-cutting policies (auth guards, logging, analytics)

2. **InnoRouterSwiftUI**: SwiftUI integration
   - `NavStore<R>`: Observable state container + middleware execution + `@Observable` support
   - `NavigationHost`: SwiftUI view that hosts navigation and injects `AnyNavigator` into environment
   - `Coordinator`: Protocol for centralizing navigation policy (`handle(NavIntent)`, `destination(for:)`)
   - `CoordinatorHost`: SwiftUI view for coordinator-driven navigation
   - `FlowCoordinator`: Protocol for multi-step flows with progress tracking
   - `TabCoordinator`: Protocol for tab-based navigation
   - `@UseNavigator`: Property wrapper to extract navigator from environment

3. **InnoRouterDeepLink**: Deep link handling
   - `DeepLinkMatcher<R>`: URL pattern matching with `DeepLinkMapping` DSL
   - `DeepLinkPipeline<R>`: Decision pipeline (scheme/host validation, auth checks, plan generation)
   - `DeepLinkDecision<R>`: Enum of outcomes (`.plan`, `.pending`, `.rejected`, `.unhandled`)
   - `NavPlan<R>`: List of `NavCommand<R>` to execute
   - `DeepLinkCoordinating`: Protocol for coordinators with deep link support

4. **InnoRouter** (umbrella): Re-exports Core + SwiftUI + DeepLink

5. **InnoRouterMacros** (optional): Swift macros
   - `@Routable`: Generates `Route` conformance + CasePath support
   - `@CasePathable`: Lightweight CasePath generation for general enums
   - Implemented via `InnoRouterMacrosPlugin` using SwiftSyntax 602.0.0

6. **InnoRouterEffects** (optional): Effect-style helpers for architecture integration

### Key Execution Flow

1. **NavStore.execute(_:)** is the entry point:
   - For `.sequence` and `.conditional`: recursively calls `execute` on nested commands
   - For all other commands: runs middleware chain → applies via `NavEngine` → triggers `onChange` callback
   - Middleware runs **per executed command** (including each step of `.sequence`)

2. **Middleware Contract**:
   - `willExecute`: Called before command execution, can transform or cancel (return `nil`)
   - `didExecute`: Called after execution with result
   - Runs in order for all middlewares before applying to engine
   - If middleware returns `nil`, execution is cancelled and `.cancelled` result returned

3. **Deep Link Pipeline**:
   - `decide(for: URL)` → validates scheme/host → resolves URL to Route → checks auth → returns Decision
   - `.plan(NavPlan)`: Ready to execute commands
   - `.pending(PendingNav)`: Requires auth first, store pending nav for later
   - `.rejected`/`.unhandled`: Invalid or unknown URL
   - Coordinators conforming to `DeepLinkCoordinating` get `handle(.deepLink(URL))` default implementation

### SwiftUI Integration Patterns

1. **Standalone (no Coordinator)**:
   ```swift
   @State private var store = NavStore<HomeRoute>()
   NavigationHost(store: store) { route in ... } root: { ... }
   ```

2. **Coordinator-driven**:
   ```swift
   @State private var coordinator = HomeCoordinator()
   CoordinatorHost(coordinator: coordinator) { ... }
   ```

3. **Navigation from Views**:
   ```swift
   @UseNavigator(HomeRoute.self) private var navigator
   navigator?.push(.detail(id: "123"))
   ```

### Testing Conventions

- Uses Swift Testing framework (`@Suite`, `@Test`, `#expect`)
- All navigation operations must be `@MainActor`
- Test routes defined as simple enums (e.g., `TestRoute` in InnoRouterTests)
- Middleware tests verify both `willExecute` and `didExecute` are called per step
- Macro tests use `SwiftSyntaxMacrosTestSupport` for AST validation

## Important Behavioral Contracts

### NavStore Execution Semantics
- `onChange` triggers **only on real state changes** (compares old vs new state)
- Middleware runs deterministically for each executed command
- `.sequence([.push(a), .push(b)])` will call middleware 2 times (once per nested command)
- `.conditional` commands check condition first, then execute nested command if true

### Deep Link Policy
- Pending deep links are stored in application policy layer (not in NavStore)
- `DeepLinkCoordinating` protocol provides default implementation of `handle(.deepLink(URL))`
- After auth completion, app code should check `pendingDeepLink` and execute the plan

### Swift 6 Strict Concurrency
- All types are marked `Sendable` where appropriate
- `NavStore` is `@unchecked Sendable` because it's `@MainActor` isolated
- `@ObservationIgnored` used for stored properties that don't trigger observation
- All navigation operations assume `@MainActor` context

## File Organization

```
Sources/
├── InnoRouterCore/          # Runtime (NavStack, NavCommand, NavEngine, Navigator, Middleware)
├── InnoRouterSwiftUI/       # SwiftUI integration (NavStore, Hosts, Coordinators, Environment)
├── InnoRouterDeepLink/      # Deep link matching and pipeline
├── InnoRouterUmbrella/      # Re-exports (InnoRouter.swift, Coordinator+DeepLink.swift)
├── InnoRouterMacros/        # Macro declarations (Macros.swift, CasePath.swift)
├── InnoRouterMacrosPlugin/  # Macro implementation (RoutableMacro, CasePathableMacro)
└── InnoRouterEffects/       # Effect handlers (NavigationEffectHandler, DeepLinkEffectHandler)

Tests/
├── InnoRouterTests/         # Main tests (NavStore, Commands, DeepLink, Coordinator, Flow)
└── InnoRouterMacrosTests/   # Macro expansion tests

Examples/
├── StandaloneExample.swift  # Basic NavigationHost usage
├── CoordinatorExample.swift # Coordinator pattern
└── DeepLinkExample.swift    # Deep link pipeline setup
```

## Development Notes

- **Middleware design**: Each middleware should be single-purpose (logging, auth guard, analytics, de-dupe). Avoid `switch` sprawl in business logic.
- **Route protocol**: Routes must be `Equatable` for `NavStack.path` comparison and middleware deduplication.
- **SwiftUI integration**: `NavStore` is `@Observable`, so views automatically update when `state.path` changes.
- **Deep link patterns**: Use `DeepLinkMapping` DSL with `:param` syntax (e.g., `/product/:id`) for route parameters.
- **Examples as documentation**: The `Examples/` directory contains runnable examples demonstrating each integration pattern.

## Release Process

See `RELEASING.md` for full checklist. Key points:
- Confirm public API surface (what stays `public` vs `internal`)
- Run `swift test` locally before releasing
- Add/verify release notes in README (especially migration notes for breaking changes)
- Ensure macro tests pass (SwiftSyntax formatter output may change between versions)
- Tag releases as `vX.Y.Z`
