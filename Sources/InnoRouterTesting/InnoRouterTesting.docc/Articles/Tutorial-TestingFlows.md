# Testing Flows End-to-End with `FlowTestStore`

Assert the complete chain triggered by a single `FlowIntent` —
navigation, modal, middleware cancellation, path reconciliation —
through a single FIFO receive queue, without mounting any SwiftUI
host.

## Setup

Add `InnoRouterTesting` to the test target only:

```swift
.testTarget(
    name: "AppTests",
    dependencies: [
        .product(name: "InnoRouter",        package: "InnoRouter"),
        .product(name: "InnoRouterTesting", package: "InnoRouter"),
    ]
)
```

Then import both modules alongside Swift Testing:

```swift
import Testing
import InnoRouter
import InnoRouterTesting
```

## The happy path

```swift
private enum AppRoute: Route {
    case welcome, preAuth, signup
}

@Test
@MainActor
func pushingPreAuthEmitsNavigationAndPathChange() {
    let store = FlowTestStore<AppRoute>()

    store.send(.push(.preAuth))

    store.receiveNavigation { event in
        if case .changed(_, let to) = event { return to.path == [.preAuth] }
        return false
    }
    store.receivePathChanged { old, new in
        old.isEmpty && new == [.push(.preAuth)]
    }
    store.expectNoMoreEvents()
}
```

`FlowTestStore` owns a real `FlowStore` and subscribes to every
observation surface it exposes (flow, inner navigation, inner
modal). Events land in one FIFO queue; `receive*` helpers dequeue
them in the order the production stores emit.

## Modal + cancellation

`FlowTestStore` surfaces cancellations as first-class events, so
tests can assert them precisely:

```swift
@MainActor
private func blockSheetMiddleware() -> AnyModalMiddleware<AppRoute> {
    AnyModalMiddleware(willExecute: { command, _, _ in
        if case .present(let p) = command, p.style == .sheet {
            return .cancel(.middleware(debugName: nil, command: command))
        }
        return .proceed(command)
    })
}

@Test
@MainActor
func sheetBlockingMiddlewareCancelsTheIntent() {
    let store = FlowTestStore<AppRoute>(
        configuration: .init(
            modal: .init(
                middlewares: [.init(middleware: blockSheetMiddleware(), debugName: "BlockSheet")]
            )
        )
    )

    store.send(.presentSheet(.signup))

    // The preview path never commits — only .intentRejected fires.
    store.receiveIntentRejected(
        intent: .presentSheet(.signup),
        reason: .middlewareRejected(debugName: "BlockSheet")
    )
    #expect(store.path.isEmpty)
    store.expectNoMoreEvents()
}
```

## Skipping and draining

`skipReceivedEvents()` discards everything currently queued
without asserting, which is useful when a test only cares about
events *after* a setup mutation:

```swift
store.send(.presentSheet(.signup)) // enqueues .modal + .pathChanged
store.skipReceivedEvents()         // we don't care about setup

store.send(.push(.preAuth))
store.receiveIntentRejected(intent: .push(.preAuth), reason: .pushBlockedByModalTail)
```

## Exhaustivity

Default is ``TestExhaustivity/strict`` — any unasserted event at
`finish()` (or at deinit of the test store) triggers a Swift
Testing `Issue.record`. This catches the common mistake of
"missed that the modal also fired a `.presented` after the
intended intent."

Opt out selectively:

```swift
let store = FlowTestStore<AppRoute>(exhaustivity: .off)
```

`.off` preserves per-call assertions; only the end-of-life drain
check is silenced. Useful when migrating a legacy test in stages.

## Direct state inspection

`FlowTestStore` exposes the underlying `FlowStore` for occasional
direct assertions:

```swift
#expect(store.path == [.push(.preAuth)])
#expect(store.store.navigationStore.state.path == [.preAuth])
#expect(store.store.modalStore.currentPresentation == nil)
```

Prefer `receive*` for production assertions — they cover both
state and the emission order — but escape hatches are useful for
sanity checks.

## Next steps

- Read the `Tutorial-LoginOnboarding` guide in the
  `InnoRouterSwiftUI` documentation catalog for the end-to-end flow
  being tested here.
- Read the `Tutorial-MiddlewareComposition` guide in the
  `InnoRouterSwiftUI` documentation catalog for the middleware
  surfaces the harness asserts against.
