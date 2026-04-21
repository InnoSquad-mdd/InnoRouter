# Observing Stores via Protocol Adapters

`StoreObserver` is a thin protocol adapter over the `events`
`AsyncStream` that every InnoRouter store publishes. Use it when
protocol dispatch reads clearer than a `for await` loop — typically
in AppDelegate wiring, analytics adapters, or anywhere you want
static methods instead of iterator plumbing.

## Scenario

An analytics adapter wants to react to every navigation change,
modal present, and flow path rewrite. Writing three `for await`
loops, one per store, reads noisy. `StoreObserver` lets the adapter
implement three typed `handle(_:)` methods and subscribe once per
store.

## Implementation

```swift
@MainActor
final class AnalyticsObserver: StoreObserver {
    typealias RouteType = AppRoute

    func handle(_ event: NavigationEvent<AppRoute>) {
        if case .changed(_, let to) = event {
            Analytics.track("nav_change", ["path": to.path.description])
        }
    }

    func handle(_ event: ModalEvent<AppRoute>) {
        if case .presented(let presentation) = event {
            Analytics.track("modal_open", ["route": "\(presentation.route)"])
        }
    }

    func handle(_ event: FlowEvent<AppRoute>) {
        if case .intentRejected(_, let reason) = event {
            Analytics.track("flow_rejected", ["reason": "\(reason)"])
        }
    }
}
```

Any subset of the three `handle(_:)` methods is fine — the others
default to no-ops via a protocol extension.

## Attaching

```swift
let observer = AnalyticsObserver()
let navSubscription = navigationStore.observe(observer)
let modalSubscription = modalStore.observe(observer)
let flowSubscription = flowStore.observe(observer)
```

Each `observe(_:)` returns a `StoreObserverSubscription`. Keep it
around for the observer's lifetime; the subscription auto-cancels
on deinit via `isolated deinit`.

To stop observing early:

```swift
navSubscription.cancel()
```

Subsequent store events are not delivered to the observer.

## FlowStore routing

`FlowStore.observe(_:)` is special: it iterates the flow's
`events` stream (which already wraps inner navigation / modal
emissions) and routes them through the observer's matching typed
`handle(_:)` overload. One subscription covers all three authorities
on a flow surface.

```swift
let flowSubscription = flowStore.observe(observer)
// observer.handle(.navigation(.changed(…))) → observer.handle(_:NavigationEvent)
// observer.handle(.modal(.presented(…)))    → observer.handle(_:ModalEvent)
// observer.handle(.pathChanged(…))          → observer.handle(_:FlowEvent)
```

## When to reach for `for await` instead

Use the raw `events` stream when:

- cancellation flow needs to compose with other async sequences
  (combine, merge, retry, …)
- the handler body wants to `await` inside an event (e.g. log to
  a remote service and gate subsequent events on the response)
- events feed a structured concurrency pipeline with explicit task
  lifetimes

Use `StoreObserver` when:

- the adapter is a long-lived object (analytics, crash reporting)
  and protocol methods read clearer than an iterator loop
- multiple stores feed the same observer with typed dispatch

## Multiple observers

Every `observe(_:)` call creates an independent subscription, so
multiple observers on the same store all receive the same events.
Fan-out is free — the underlying `events` `AsyncStream` multicasts
through `EventBroadcaster`.

## Next steps

- See <doc:Tutorial-Throttling> for one more use case — observing
  throttle cancellations through the same protocol dispatch.
- See <doc:Tutorial-MiddlewareComposition> for pre-execution hooks
  that complement post-execution observation.
