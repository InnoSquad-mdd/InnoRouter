# Route stack and validation

@Metadata {
  @PageKind(article)
}

`RouteStack` is the canonical snapshot type for navigation state in InnoRouter.

## Snapshot model

`RouteStack` is a value type. That matters because:

- execution APIs can compare before/after state cheaply and explicitly
- batch and transaction APIs can stage changes on temporary snapshots
- validation can happen before state is adopted by a store or coordinator

`RouteStack` intentionally exposes only a read-only `path` outside `InnoRouterCore`. External callers can rebuild a snapshot with:

- `RouteStack.init()`
- `RouteStack.init(validating:using:)`

## Validation model

Use `RouteStackValidator` when an app needs stronger invariants than “any path is valid”.

Built-in validators:

- `RouteStackValidator.permissive`
- `RouteStackValidator.nonEmpty`
- `RouteStackValidator.uniqueRoutes`
- `RouteStackValidator.rooted(at:)`

Validators compose through `RouteStackValidator.combined(with:)`. This gives you a simple way to express app-specific rules without putting those rules into the core engine.

```swift
let validator = RouteStackValidator<MyRoute>
    .nonEmpty
    .combined(with: .rooted(at: .home))
```

Built-in failures are typed through `RouteStackValidationError`.

## Where validation belongs

Use validation at adoption boundaries:

- when a store is initialized from an existing path
- when a coordinator restores persisted state
- when tests want to encode a stronger invariant

Do not use `RouteStackValidator` as a replacement for command legality. Command legality stays in `NavigationEngine`.
