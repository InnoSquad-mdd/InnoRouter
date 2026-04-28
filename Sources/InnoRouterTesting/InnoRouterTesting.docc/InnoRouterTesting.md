# InnoRouterTesting

Host-less, Swift-Testing native assertion harness for InnoRouter's navigation, modal, and flow authorities.

## Overview

`InnoRouterTesting` ships three test stores that mirror the production stores' public API and transparently subscribe to every public observation callback:

- `NavigationTestStore` — asserts `NavigationStore` events (push/pop/batch/transaction/middleware mutation/path mismatch).
- `ModalTestStore` — asserts `ModalStore` events (present/dismiss/queue/intercept/middleware mutation).
- `FlowTestStore` — asserts `FlowStore` intents end-to-end, including the inner navigation and modal emissions.

No `@testable import` is required. The harness itself avoids app-side access
to FlowStore internals; configure inner navigation / modal behavior through
`FlowStoreConfiguration`.

### Event queue model

Each test store owns a FIFO queue. Every time the underlying store emits an observation callback, the corresponding event is appended. Tests consume events in order via `receive(...)` or its typed helpers (`receiveChange`, `receivePresented`, `receiveIntentRejected`, and so on). A strict-mode test store fails via Swift Testing `Issue.record` if any events are left unasserted at deinit.

```swift skip doc-fragment
import Testing
import InnoRouterTesting

@Test
@MainActor
func pushHomeLogsChangeEvent() {
    let store = NavigationTestStore<AppRoute>()
    store.send(.push(.home))
    store.receiveChange { old, new in
        old.path.isEmpty && new.path == [.home]
    }
    store.finish()
}
```

### Exhaustivity

The default mode is `TestExhaustivity.strict`: unasserted events at store deinit (or at an explicit `finish()`) are reported as test issues. `TestExhaustivity.off` preserves the `receive(...)` assertions but silences the final drain check — useful when incrementally migrating large legacy suites.

### User callbacks are preserved

When you pass a production `NavigationStoreConfiguration`, `ModalStoreConfiguration`, or `FlowStoreConfiguration` into a test store, every hook (including `onChange`, `onPresented`, `onCommandIntercepted`, `onPathMismatch`, etc.) still fires. The test store appends events after the user callback runs, so production middleware and analytics pipelines behave under test exactly as they would in the app.

### End-to-end flow assertions

`FlowTestStore` subscribes to the inner `NavigationStore` and `ModalStore`'s full observation surface and wraps those emissions into `.navigation(...)` / `.modal(...)` events on a single queue. This lets a test assert the complete chain triggered by one `FlowIntent` — for instance, that a sheet-blocking middleware prevents the inner navigation store from seeing any command:

```swift skip doc-fragment
let store = FlowTestStore<AppRoute>(
    configuration: FlowStoreConfiguration(
        modal: ModalStoreConfiguration(
            middlewares: [
                ModalMiddlewareRegistration(
                    middleware: BlockSheetMiddleware(),
                    debugName: "BlockSheet"
                )
            ]
        )
    )
)

store.send(.presentSheet(.onboarding))
store.receiveIntentRejected(
    intent: .presentSheet(.onboarding),
    reason: .middlewareRejected(debugName: "BlockSheet")
)
store.expectNoMoreEvents()
```

## Topics

### Tutorials

- <doc:Tutorial-TestingFlows>
