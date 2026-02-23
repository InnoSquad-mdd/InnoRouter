# InnoRouter

InnoRouter is a SwiftUI-native navigation framework built around **state**, **unidirectional execution**, and **dependency inversion**.

Core ideas:
- Navigation is expressed as data (`RouteStack`, `NavigationCommand`) and rendered by SwiftUI.
- Features/Coordinators depend on `Navigator` (interface), not a concrete router/store.
- Deep links are handled as **plans** (`DeepLinkPipeline -> DeepLinkDecision -> NavigationPlan`) instead of ad-hoc branching.
- SwiftUI views emit **intent** (`NavigationIntent`) and do not directly execute router commands.

## Requirements

- iOS 18+ / macOS 15+ / tvOS 18+ / watchOS 11+
- Swift 6.2+

## Installation (SPM)

```swift
dependencies: [
  .package(url: "https://github.com/your-org/InnoRouter.git", from: "2.0.0")
]
```

## Modules

- `InnoRouter` (recommended): umbrella re-export of `InnoRouterCore` + `InnoRouterSwiftUI` + `InnoRouterDeepLink`
- `InnoRouterCore`: runtime (`RouteStack`, `NavigationCommand`, `NavigationEngine`, `AnyNavigator`, middleware)
- `InnoRouterSwiftUI`: SwiftUI integration (`NavigationStore`, hosts, coordinators, `@EnvironmentNavigationIntent`)
- `InnoRouterDeepLink`: parsing/matching/pipeline (`DeepLinkMatcher`, `DeepLinkPipeline`)
- `InnoRouterMacros` (optional): `@Routable`, `@CasePathable`
- `InnoRouterEffects` (optional): effect-style helpers (works with any architecture)
- InnoFlow state-driven integration (separate package): `InnoRouterFlowBridge` — https://github.com/InnoSquad-mdd/InnoRouterFlowBridge

## Quick Start (SwiftUI)

### 1) Define routes

Without macros:

```swift
import InnoRouter

enum HomeRoute: Route {
  case list
  case detail(id: String)
  case settings
}
```

With macros (optional):

```swift
import InnoRouter
import InnoRouterMacros

@Routable
enum HomeRoute {
  case list
  case detail(id: String)
  case settings
}
```

### 2) Create a store and host it

```swift
import SwiftUI
import InnoRouter

struct AppRoot: View {
  @State private var store = NavigationStore<HomeRoute>()

  var body: some View {
    NavigationHost(store: store) { route in
      switch route {
      case .list: HomeView()
      case .detail(let id): DetailView(id: id)
      case .settings: SettingsView()
      }
    } root: {
      HomeView()
    }
  }
}
```

### 3) Emit intent from a view

`NavigationHost` injects an intent dispatcher. Use `@EnvironmentNavigationIntent`:

```swift
struct HomeView: View {
  @EnvironmentNavigationIntent(HomeRoute.self) private var navigationIntent

  var body: some View {
    List {
      Button("Detail") { navigationIntent.send(.go(.detail(id: "123"))) }
      Button("Settings") { navigationIntent.send(.go(.settings)) }
      Button("Back") { navigationIntent.send(.back) }
    }
  }
}
```

## Navigation Intent Catalog

`NavigationIntent` is the official SwiftUI entry point:

- `.go(Route)`
- `.goMany([Route])`
- `.back`
- `.backBy(Int)`
- `.backTo(Route)`
- `.backToRoot`
- `.resetTo([Route])`
- `.deepLink(URL)`

## Middleware

Attach cross-cutting policies (auth guard, logging, analytics, de-dupe) without policy leakage into view code.

```swift
@State private var store = NavigationStore<HomeRoute>()

store.addMiddleware(
  AnyNavigationMiddleware(
    willExecute: { command, state in
      if case .push(let next) = command, state.path.last == next { return nil }
      return command
    }
  )
)
```

Notes:
- Middleware runs **per executed command** (including each step of `.sequence`).
- If `willExecute` returns `nil`, execution is cancelled with `.cancelled`.

## Coordinator Pattern

Use coordinators to centralize policy (auth redirects, flow routing, deep link orchestration).

```swift
import SwiftUI
import InnoRouter

@MainActor
@Observable
final class HomeCoordinator: Coordinator {
  typealias RouteType = HomeRoute
  typealias Destination = HomeDestinationView

  let store = NavigationStore<HomeRoute>()

  func handle(_ intent: NavigationIntent<HomeRoute>) {
    switch intent {
    case .go(let route):
      if route == .settings {
        _ = store.execute(.replace([.settings]))
      } else {
        store.send(intent)
      }
    default:
      store.send(intent)
    }
  }

  func destination(for route: HomeRoute) -> HomeDestinationView {
    HomeDestinationView(route: route)
  }
}

struct HomeDestinationView: View {
  let route: HomeRoute

  var body: some View {
    switch route {
    case .list: Text("List")
    case .detail(let id): Text("Detail \(id)")
    case .settings: Text("Settings")
    }
  }
}

struct Root: View {
  @State private var coordinator = HomeCoordinator()

  var body: some View {
    CoordinatorHost(coordinator: coordinator) {
      HomeView()
    }
  }
}
```

## Deep Links

### Matcher (URL -> Route)

```swift
import InnoRouter

let matcher = DeepLinkMatcher<HomeRoute> {
  DeepLinkMapping("/home") { _ in .list }
  DeepLinkMapping("/product/:id") { params in
    params.firstValue(forName: "id").map { .detail(id: $0) }
  }
}
```

### Pipeline (URL -> Decision)

```swift
let pipeline = DeepLinkPipeline<HomeRoute>(
  allowedSchemes: ["myapp", "https"],
  allowedHosts: ["myapp.com"],
  resolve: { matcher.match($0) },
  authenticationPolicy: .required(
    shouldRequireAuthentication: { route in
      if case .settings = route { return true }
      return false
    },
    isAuthenticated: { authManager.isLoggedIn }
  ),
  plan: { route in NavigationPlan(commands: [.push(route)]) }
)
```

### SwiftUI usage

```swift
.onOpenURL { url in
  switch pipeline.decide(for: url) {
  case .plan(let plan):
    Task { @MainActor in
      for command in plan.commands { _ = store.execute(command) }
    }
  case .pending(let pendingDeepLink):
    // show login flow, then execute pendingDeepLink.plan later
    break
  case .rejected(let reason):
    print("Rejected deep link: \(reason)")
  case .unhandled(let unhandledURL):
    print("Unhandled deep link: \(unhandledURL)")
  }
}
```

## v2 Breaking Changes

InnoRouter v2 is a SwiftUI/SOLID/API-guideline hardening release focused on strict intent-first surface, fail-fast environment semantics, and typed effect outcomes.

### Renamed/Removed Public APIs

1. Legacy navigator environment wrapper removed.
2. `@EnvironmentNavigationIntent` introduced as the official SwiftUI view entry point.
3. Public coordinator helper shortcuts removed from SwiftUI public surface (`navigate(to:)`, `execute(_:)`, `goBack()`, `goToRoot()`, `navigator`).
4. Type-erased coordinator API remains removed.

### Behavior Changes

1. `EnvironmentNavigationIntent.wrappedValue` is non-optional and fails fast when host injection is missing.
2. `NavigationHost` and `CoordinatorHost` inject route-scoped intent dispatchers; view samples route through `send(_:)` only.
3. `NavigationIntent` includes practical multi-step/back-stack variants:
   - `goMany`, `backBy`, `backTo`, `backToRoot`
4. `DeepLinkEffectHandler.Result` now distinguishes:
   - `.invalidURL(input:)`
   - `.missingDeepLinkURL`
   - `.noPendingDeepLink`

### SwiftUI Philosophy Alignment

1. Single source of truth remains `NavigationStore.state`.
2. Views emit intent and avoid direct imperative path mutation.
3. Configuration errors in environment wiring are surfaced immediately.

### Framework Comparison

InnoRouter v2 decisions were benchmarked against four external frameworks:

| Framework | Adopted in v2 | Not adopted in v2 |
|---|---|---|
| `SwiftNavigation` | Type-safe route/state modeling and declarative transition boundaries | Observation/perception-specific binding strategy coupling |
| `TCACoordinators` | Deterministic command execution/testing strategy (`execute(_:stopOnFailure:)`) | Full TCA-first reducer/runtime dependency |
| `FlowStacks` | Plan-based deep-link replay model | Stack internals API shape compatibility |
| `Stinsen` | Host-scoped coordinator boundary and isolation patterns | Container-specific runtime/DI coupling |

## Examples

See `Examples/StandaloneExample.swift`, `Examples/CoordinatorExample.swift`, `Examples/DeepLinkExample.swift`.

## Development

- Run tests: `swift test`
- Release checklist: `RELEASING.md`
