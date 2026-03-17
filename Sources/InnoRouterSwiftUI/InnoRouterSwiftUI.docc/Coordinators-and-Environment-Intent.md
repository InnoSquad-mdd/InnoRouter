# Coordinators and environment intent

@Metadata {
  @PageKind(article)
}

Coordinators in InnoRouter are SwiftUI-adapted reference authorities, not UIKit-era imperative routers.

## Coordinator role

``Coordinator`` exists for cases where view intent should flow through a policy object before it reaches the store.

A coordinator:

- receives ``NavigationIntent``
- decides whether to forward, rewrite, or replace commands
- maps routes to destinations
- stays observable for SwiftUI

`Coordinator` remains `AnyObject` by design because it is a shared authority object, not ephemeral view state.

## Environment intent

``EnvironmentNavigationIntent`` and `EnvironmentModalIntent` are the primary view-facing APIs.

This keeps view code declarative:

- child views do not need a direct store reference
- fail-fast behavior catches host wiring mistakes early
- multi-host trees can keep separate routing authorities in the same hierarchy

## Flow and tab coordinators

``FlowCoordinator`` and ``TabCoordinator`` complement `NavigationStore`; they do not replace it.

Recommended mental model:

- `NavigationStore` owns route-stack authority
- `TabCoordinator` owns shell tab state
- `FlowCoordinator` owns local step state inside a destination

Use composition rather than trying to collapse all three responsibilities into one type.
