# Migrating from 4.2 to 5.0

5.0 is the first major release that breaks 4.x source
compatibility. The break is mechanical for most adopters — every
change is something the 4.2.0 prep phase made visible as either
an additive protocol or a planned deprecation. This page is the
per-call-site checklist.

If you are still on 4.1 or earlier, land
[`Docs/migration-4.1-to-4.2.md`](migration-4.1-to-4.2.md) first.
4.2 is intentionally a source-compatible stop on the way to 5.0.

## Bumping the package version

```diff
 dependencies: [
-    .package(url: "https://github.com/InnoSquadCorp/InnoRouter.git", from: "4.2.0")
+    .package(url: "https://github.com/InnoSquadCorp/InnoRouter.git", from: "5.0.0")
 ]
```

## What broke and how to fix it

### 1. `NavigationStoreConfiguration` gains a `pathReconciler` parameter

Positional callers update the call site; keyword callers compile
unchanged.

```diff
 let store = try NavigationStore<AppRoute>(
     initialPath: [.home],
     configuration: NavigationStoreConfiguration(
         routeStackValidator: validator,
         pathMismatchPolicy: .replace,
-        eventBufferingPolicy: .default
+        eventBufferingPolicy: .default
+        // pathReconciler defaults to nil → NavigationPathReconciler()
     )
 )
```

If you want a domain-specific reconciler:

```swift skip
let store = try NavigationStore<AppRoute>(
    initialPath: [.home],
    configuration: NavigationStoreConfiguration(
        pathReconciler: MyDomainReconciler()
    )
)
```

`NavigationPathReconciling` is now `Sendable`-required. The
default `NavigationPathReconciler<R>` conformance is `public`,
so app code can compose it as a fallback inside custom
conformances.

### 2. `@_spi(FlowStoreInternals)` is removed

```diff
-@_spi(FlowStoreInternals) @testable import InnoRouterSwiftUI
+@testable import InnoRouterSwiftUI
```

For non-test code that previously read FlowStore's inner stores:

```diff
-let path = flowStore.navigationStore.state.path
-let modal = flowStore.modalStore.currentPresentation
+let path = flowStore.navigationPath           // FlowStateReading
+let modal = flowStore.currentModalPresentation
```

For non-test code that previously *mutated* FlowStore via the
inner stores, that path was a leak — every mutation should flow
through `FlowStore.send(_:)` or `FlowStore.apply(_:)` so the
unified path projection stays consistent.

### 3. `ChildCoordinator` requires `lifecycleSignals`

Every `ChildCoordinator` conformance must add a stored
`lifecycleSignals: LifecycleSignals` property:

```diff
 final class SignUpCoordinator: ChildCoordinator {
     typealias Result = UserID
     var onFinish: (@MainActor @Sendable (UserID) -> Void)?
     var onCancel: (@MainActor @Sendable () -> Void)?
+    var lifecycleSignals: LifecycleSignals = LifecycleSignals()
 }
```

If your coordinator already overrides `parentDidCancel()`, that
keeps working — the parent push helper now fires
`lifecycleSignals.fireParentCancel()` *in addition to* the
override, so adopters can switch to a closure-style teardown
when convenient:

```swift skip
final class SignUpCoordinator: ChildCoordinator {
    var onFinish: (@MainActor @Sendable (UserID) -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?
    var lifecycleSignals = LifecycleSignals(onParentCancel: {
        signUpAPIClient.cancelActiveRequests()
    })
}
```

### 4. New `LifecycleAware` capability protocol

`ChildCoordinator` now inherits from `LifecycleAware`. Apps that
added `lifecycleSignals` in the 4.2 prep phase need no further
work — the property satisfies both protocols. `Coordinator`,
`FlowCoordinator`, and `TabCoordinator` may opt into
`LifecycleAware` to expose teardown hooks through host code.

## What stays the same

- `NavigationStore`, `ModalStore`, `FlowStore` public mutation API
  (`send` / `execute` / `executeBatch` / `executeTransaction` /
  `apply`).
- `NavigationCommand`, `NavigationIntent`, `ModalIntent`, and
  `FlowIntent` shapes.
- The deep-link pipeline (push-only and flow).
- Middleware contracts (`willExecute` / `didExecute` /
  `NavigationInterception` / `NavigationCancellationReason`).
- `AsyncNavigationMiddleware<R>` and `AsyncNavigationMiddlewareExecutor<R>`
  added in 4.2.
- `ModalQueueCancellationPolicy<M>` added in 4.2.
- The macro surface (`@Routable`, `@CasePathable`).
- Apple platform floors (iOS 18+, macOS 15+, etc.).
- Swift 6.2 package tools floor.

## Verification

After applying the diffs above:

```bash
swift build
swift test
./scripts/principle-gates.sh
```

The principle-gates script regenerates the public API baseline
when run with `--write-baseline`. If your fork carries downstream
private patches, regenerate with the same Xcode pin used in CI.

## Beyond 5.0.0

5.x continues as an additive minor line. The 5.0 cleanup pulls
the visible knobs into the shape they should have for the
foreseeable future; later 5.x minors can layer additional
capabilities on top of `LifecycleAware`, additional reconciler
implementations, etc., without further breaking changes.
