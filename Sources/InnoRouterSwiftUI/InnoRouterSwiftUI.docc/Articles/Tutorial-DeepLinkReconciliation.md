# Reconciling Deep Links End-to-End

Match a URL, apply an authentication policy, and produce a
`NavigationPlan` that `NavigationStore.executeBatch` applies in one
observable step. Queue the deep link while the user is signed out,
replay it after sign-in, and surface cancellation reasons through
typed outcomes.

## Scenario

`myapp://order/42` should land the user on the order detail for
order 42, but only when they're signed in. If the link arrives
while signed out, the app must remember it, route through the
sign-in flow, and then replay it — without dropping the original
URL context.

## Modeling the routes

```swift skip doc-fragment
enum AppRoute: Route {
    case home
    case signIn
    case order(id: String)
}
```

## Wiring the pipeline

`DeepLinkPipeline` owns the match-then-validate-then-authorize flow:

```swift skip doc-fragment
let matcher = DeepLinkMatcher<AppRoute>(patterns: [
    .init(pattern: "myapp://home")                   { _ in .home },
    .init(pattern: "myapp://signin")                 { _ in .signIn },
    .init(pattern: "myapp://order/:id")              { params in
        guard let id = params["id"] else { return nil }
        return .order(id: id)
    },
])

let policy: DeepLinkAuthenticationPolicy<AppRoute> = { route, isAuthenticated in
    switch route {
    case .home, .signIn:
        return .proceed
    case .order where !isAuthenticated:
        return .defer // the pipeline will queue a PendingDeepLink
    case .order:
        return .proceed
    }
}

let pipeline = DeepLinkPipeline(matcher: matcher, policy: policy)
```

## Handling a URL

The `DeepLinkEffectHandler` bridges the pipeline output into
`NavigationStore`:

```swift skip doc-fragment
@MainActor
final class AppCoordinator {
    let store: NavigationStore<AppRoute>
    let pipeline: DeepLinkPipeline<AppRoute>
    let effectHandler: DeepLinkEffectHandler<AppRoute>

    func handle(_ url: URL, isAuthenticated: Bool) {
        let outcome = pipeline.process(url: url, isAuthenticated: isAuthenticated)

        switch outcome {
        case .plan(let plan):
            _ = store.executeBatch(plan.commands)
        case .pending(let pending):
            effectHandler.retain(pending)
            store.send(.go(.signIn))
        case .rejected(let reason):
            Log.warning("deep link rejected: \(reason)")
        case .unhandled(let url):
            Log.warning("deep link unhandled: \(url)")
        }
    }
}
```

## Replaying after sign-in

Once the user signs in, the handler resumes any queued deep link:

```swift skip doc-fragment
func userDidSignIn() {
    effectHandler.resumePendingDeepLinkIfAllowed(
        isAuthenticated: true,
        executor: { plan in
            _ = store.executeBatch(plan.commands)
        }
    )
}
```

The handler consults the retained `PendingDeepLink`, re-evaluates
the authentication policy, and only commits the batch if the new
state now permits the original URL. Any stale pending link (one
the user cancelled or that no longer validates) is dropped.

## Observing the reconciliation

`NavigationStore.events` exposes the full sequence of batch +
path-mismatch events as a single stream, which is handy for
diagnostics dashboards:

```swift skip doc-fragment
Task {
    for await event in store.events {
        switch event {
        case .batchExecuted(let result):
            analytics.track("deep_link_applied", [
                "routes": result.stateAfter.path.map(String.init(describing:))
            ])
        case .pathMismatch(let event):
            analytics.track("deep_link_mismatch", [
                "policy": event.policy.rawValue,
                "old": event.oldPath.map(String.init(describing:)),
                "new": event.newPath.map(String.init(describing:))
            ])
        default:
            continue
        }
    }
}
```

## Testing the chain

`NavigationTestStore` (in `InnoRouterTesting`) asserts the batch +
side effects for each branch:

```swift skip doc-fragment
@Test
@MainActor
func signedOutDeepLinkDefersUntilSignIn() {
    let store = NavigationTestStore<AppRoute>()
    // ...pipeline + handler wired to `store.store`
    pipeline.handle(URL(string: "myapp://order/42")!, isAuthenticated: false)

    store.receiveChange { _, new in new.path == [.signIn] }
    // Pending deep link remains queued; no .batchExecuted yet.
}
```

## Next steps

- Read <doc:Tutorial-LoginOnboarding> for how the sign-in flow that
  replays this deep link is modelled.
- Read <doc:Tutorial-MigratingFromNestedHosts> if the existing app
  still uses `ModalHost { NavigationHost { ... } }` pairs.
