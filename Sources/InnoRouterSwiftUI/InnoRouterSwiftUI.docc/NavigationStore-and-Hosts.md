# NavigationStore and hosts

@Metadata {
  @PageKind(article)
}

`NavigationStore` is the shared stack-navigation authority for SwiftUI.

## What the store owns

`NavigationStore` owns:

- the current `RouteStack` snapshot
- command execution
- batch execution
- transactional execution
- path reconciliation from `NavigationStack(path:)`
- middleware registry orchestration
- telemetry and lifecycle callbacks

Configuration is centralized in `NavigationStoreConfiguration`.

## Host responsibilities

`NavigationHost` and `CoordinatorHost` connect SwiftUI navigation UI to the store or coordinator:

- render the root view
- render destinations for pushed routes
- inject environment intent dispatchers
- bridge system path changes back into router commands

Views should not mutate a store directly. They should emit `NavigationIntent` through the environment.

## Path reconciliation

When SwiftUI changes the path, InnoRouter translates that change back into semantic commands:

- prefix shrink -> `.popCount` or `.popToRoot`
- prefix expand -> per-step `.push` batch
- mismatch -> `NavigationPathMismatchPolicy`

This preserves command meaning instead of treating every path change as a blind replacement.
