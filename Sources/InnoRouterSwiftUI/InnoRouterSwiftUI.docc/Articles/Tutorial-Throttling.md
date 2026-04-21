# Throttling Rapid Navigation Taps

Rate-limit navigation commands without threading timestamps through
every call site. `ThrottleNavigationMiddleware` cancels commands that
arrive within a minimum interval of a previously accepted command
sharing the same key.

## Scenario

Users double-tap a "Buy" button. The first tap pushes the purchase
screen; the second should be silently dropped. Rolling that logic
into every button is noise — middleware is the right layer.

## Installation

```swift
let store = NavigationStore<AppRoute>(
    configuration: NavigationStoreConfiguration(
        middlewares: [
            .init(
                middleware: AnyNavigationMiddleware(
                    ThrottleNavigationMiddleware<AppRoute>(
                        interval: .milliseconds(300)
                    )
                ),
                debugName: "throttle"
            )
        ]
    )
)
```

The default initializer uses `ContinuousClock` and groups all
commands under a single global window. Within 300 ms of a previous
accepted command, the next one is cancelled with
`.cancelled(.middleware(debugName: "throttle", command: …))`.

## Per-command keys

Group throttle windows by the command's identity or shape:

```swift
AnyNavigationMiddleware(
    ThrottleNavigationMiddleware<AppRoute>(interval: .milliseconds(300)) { command in
        if case .push(let route) = command {
            return "push-\(route)"   // each push route gets its own window
        }
        return nil                    // other commands pass through
    }
)
```

Return `nil` to opt a command out of throttling entirely.

## Testing with an injected clock

The middleware is generic over `Clock`, so tests can drive time
deterministically:

```swift
let clock = TestClock()
let throttle = ThrottleNavigationMiddleware<AppRoute, TestClock>(
    interval: .milliseconds(300),
    clock: clock,
    key: { _ in "all" }
)
store.addMiddleware(AnyNavigationMiddleware(throttle), debugName: "throttle")

store.send(.go(.home))
clock.advance(by: .milliseconds(50))
store.send(.go(.detail))         // cancelled — within window

clock.advance(by: .milliseconds(400))
store.send(.go(.settings))       // accepted — beyond window
```

## Composing with `.whenCancelled`

A throttle cancel surfaces as `.cancelled`, so
`.whenCancelled(primary, fallback:)` treats a throttled command the
same as any other cancelled command:

```swift
store.execute(
    .whenCancelled(
        .push(.detail),
        fallback: .push(.home)
    )
)
```

If the throttle middleware cancels the `.push(.detail)`, the
fallback `.push(.home)` runs instead.

## Debounce?

`.debounce` semantics — "wait N ms, then fire the latest" — require
a timer + cancellable `Task` and are tracked as a separate, deferred
item. For now, throttle + `.whenCancelled` covers the most common
"rate-limit + graceful fallback" pattern.

## Next steps

- See <doc:Tutorial-StoreObserver> for a protocol-style adapter
  that can observe throttle cancellations via
  `NavigationStore.events` without threading callbacks.
- See <doc:Tutorial-MiddlewareComposition> for the broader
  middleware composition story (logging, entitlement gating,
  analytics).
