# InnoRouterMacros

Route and case-path convenience macros for InnoRouter.

## Overview

`InnoRouterMacros` reduces route boilerplate without changing runtime semantics.

It currently exposes:

- `@Routable`
- `@CasePathable`

These macros are optional. Everything in InnoRouter can still be written manually with plain Swift types.

## Imports

InnoRouter intentionally ships the macros as a distinct product from
the main umbrella so apps can opt into macro expansion per-file.
That means **different imports pull different surfaces into scope**:

- `import InnoRouterMacros` is required to use `@Routable` or
  `@CasePathable` on a declaration. The umbrella `InnoRouter` does
  **not** re-export the macros — this is deliberate so non-macro
  files don't pay the macro-plugin resolution cost.
- `import InnoRouter` (or `import InnoRouterSwiftUI` directly) is
  enough for everything else — stores, hosts, intents, events,
  `@EnvironmentNavigationIntent`, `@EnvironmentModalIntent`,
  `innoRouterSceneHost`, `innoRouterOrnament`, and the Core types.

A file that uses both macros and runtime symbols imports both:

```swift skip doc-fragment
import InnoRouter
import InnoRouterMacros

@Routable
enum HomeRoute {
    case list
    case detail
}

struct HomeListView: View {
    @EnvironmentNavigationIntent(HomeRoute.self) private var navigationIntent
    // ...
}
```

A file that only consumes the routing runtime (for example a plain
view that reads `@EnvironmentNavigationIntent` for an already-declared
route) doesn't need `import InnoRouterMacros` at all.

## Topics

### Essentials

- <doc:Routable-and-CasePathable>

### Guides

- <doc:Guide-MacroVisibility>
