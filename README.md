# InnoRouter

InnoRouter is a SwiftUI-native navigation framework built around **state**, **unidirectional execution**, and **dependency inversion**.

Core ideas:
- Navigation is expressed as data (`NavStack`, `NavCommand`) and rendered by SwiftUI.
- Features/Coordinators depend on `Navigator` (interface), not a concrete router/store.
- Deep links are handled as **plans** (`DeepLinkPipeline → DeepLinkDecision → NavPlan`) instead of ad-hoc `if/switch` chains.

## Requirements

- iOS 18+ / macOS 15+ / tvOS 18+ / watchOS 11+
- Swift 6+

## Installation (SPM)

```swift
dependencies: [
  .package(url: "https://github.com/your-org/InnoRouter.git", from: "3.0.0")
]
```

## Modules

- `InnoRouter` (recommended): umbrella re-export of `InnoRouterCore` + `InnoRouterSwiftUI` + `InnoRouterDeepLink`
- `InnoRouterCore`: runtime (`NavStack`, `NavCommand`, `NavEngine`, `AnyNavigator`, middleware)
- `InnoRouterSwiftUI`: SwiftUI integration (`NavStore`, hosts, `@UseNavigator`)
- `InnoRouterDeepLink`: parsing/matching/pipeline (`DeepLinkMatcher`, `DeepLinkPipeline`)
- `InnoRouterMacros` (optional): `@Routable`, `@CasePathable`
- `InnoRouterInnoFlowAdapter` (optional): effect-style adapters

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
  @State private var store = NavStore<HomeRoute>()

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

### 3) Navigate from a view

`NavigationHost` injects an `AnyNavigator<Route>` into the environment. Use `@UseNavigator`:

```swift
struct HomeView: View {
  @UseNavigator(HomeRoute.self) private var navigator

  var body: some View {
    List {
      Button("Detail") { navigator?.push(.detail(id: "123")) }
      Button("Settings") { navigator?.push(.settings) }
    }
  }
}
```

## Middleware

Attach cross-cutting policies (auth guard, logging, analytics, de-dupe) without `switch` sprawl.

```swift
@State private var store = NavStore<HomeRoute>()

store.addMiddleware(
  AnyNavMiddleware(
    willExecute: { command, state in
      // Example: prevent duplicate consecutive pushes
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

Use Coordinators to centralize navigation policy (redirects, auth flow, multi-step flows).

```swift
import SwiftUI
import InnoRouter

@MainActor
final class HomeCoordinator: Coordinator {
  typealias RouteType = HomeRoute
  typealias Destination = AnyView

  let store = NavStore<HomeRoute>()

  func handle(_ intent: NavIntent<HomeRoute>) {
    switch intent {
    case .go(let route):
      _ = store.execute(.push(route))
    default:
      break
    }
  }

  func destination(for route: HomeRoute) -> AnyView {
    switch route {
    case .detail(let id): AnyView(DetailView(id: id))
    default: AnyView(EmptyView())
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

### Matcher (URL → Route)

```swift
import InnoRouter

let matcher = DeepLinkMatcher<HomeRoute> {
  DeepLinkMapping("/home") { _ in .list }
  DeepLinkMapping("/product/:id") { params in
    params["id"].map { .detail(id: $0) }
  }
}
```

### Pipeline (URL → Decision)

```swift
let pipeline = DeepLinkPipeline<HomeRoute>(
  allowedSchemes: ["myapp", "https"],
  allowedHosts: ["myapp.com"],
  resolve: { matcher.match($0) },
  requiresAuthentication: { route in
    if case .settings = route { return true }
    return false
  },
  isAuthenticated: { authManager.isLoggedIn },
  plan: { route in NavPlan(commands: [.push(route)]) }
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
  case .pending:
    // show login flow, then execute pending later
    break
  case .rejected, .unhandled:
    break
  }
}
```

### Coordinator policy (recommended)

If you want deep links to be handled by your policy layer, conform to `DeepLinkCoordinating`:

```swift
final class AppCoordinator: DeepLinkCoordinating {
  typealias RouteType = HomeRoute
  typealias Destination = AnyView

  let store = NavStore<HomeRoute>()
  var pendingDeepLink: PendingNav<HomeRoute>?
  let deepLinkPipeline: DeepLinkPipeline<HomeRoute>

  // handle(.deepLink(url)) is provided by DeepLinkCoordinating default implementation
}
```

## Examples

See `Examples/StandaloneExample.swift`, `Examples/CoordinatorExample.swift`, `Examples/DeepLinkExample.swift`.

## Development

- Run tests: `swift test`
- Release checklist: `RELEASING.md`

