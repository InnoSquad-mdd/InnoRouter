// MARK: - NavigationCommandWhenCancelledTests.swift
// InnoRouterTests - .whenCancelled fallback behaviour
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum WCRoute: Route {
    case home
    case detail
    case settings
}

@MainActor
private func blockCommandMiddleware(
    predicate: @escaping @MainActor @Sendable (NavigationCommand<WCRoute>) -> Bool
) -> AnyNavigationMiddleware<WCRoute> {
    AnyNavigationMiddleware(willExecute: { command, _ in
        if predicate(command) {
            return .cancel(.middleware(debugName: "block", command: command))
        }
        return .proceed(command)
    })
}

@Suite("NavigationCommand .whenCancelled Tests")
struct NavigationCommandWhenCancelledTests {

    @Test("Engine: primary succeeds → primary result, fallback untouched")
    func engineSuccessSkipsFallback() {
        let engine = NavigationEngine<WCRoute>()
        var state = RouteStack<WCRoute>()
        let result = engine.apply(
            .whenCancelled(.push(.home), fallback: .push(.detail)),
            to: &state
        )
        #expect(result.isSuccess)
        #expect(state.path == [.home])
    }

    @Test("Engine: primary engine-level failure rolls back and runs fallback")
    func engineFailureTriggersFallback() {
        let engine = NavigationEngine<WCRoute>()
        var state = RouteStack<WCRoute>()
        // pop on empty stack fails → fallback runs on rolled-back state
        let result = engine.apply(
            .whenCancelled(.pop, fallback: .push(.home)),
            to: &state
        )
        #expect(result.isSuccess)
        #expect(state.path == [.home])
    }

    @Test("Engine: primary with partial side effect rolls back before fallback")
    func engineSnapshotRollback() {
        let engine = NavigationEngine<WCRoute>()
        var state = RouteStack<WCRoute>()
        // sequence(push(home), pop on empty now filled, popTo(settings)) —
        // the last pop fails. State rolled back.
        let result = engine.apply(
            .whenCancelled(
                .sequence([.push(.home), .popTo(.settings)]),
                fallback: .push(.detail)
            ),
            to: &state
        )
        #expect(result.isSuccess)
        // partial .push(.home) rolled back; only fallback's push committed.
        #expect(state.path == [.detail])
    }

    @Test("Store: middleware cancellation on primary runs fallback through middleware")
    @MainActor
    func storeMiddlewareCancelRunsFallback() {
        let store = NavigationStore<WCRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(middleware: blockCommandMiddleware { command in
                        if case .push(.detail) = command { return true }
                        return false
                    })
                ]
            )
        )

        // .push(.detail) is cancelled by middleware → .push(.home) runs.
        _ = store.execute(
            .whenCancelled(.push(.detail), fallback: .push(.home))
        )
        #expect(store.state.path == [.home])
    }

    @Test("Store: nested .whenCancelled unwraps left-to-right")
    @MainActor
    func storeNestedWhenCancelled() {
        let store = NavigationStore<WCRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(middleware: blockCommandMiddleware { command in
                        if case .push(.detail) = command { return true }
                        if case .push(.settings) = command { return true }
                        return false
                    })
                ]
            )
        )

        // detail → cancelled → settings → cancelled → home → succeeds
        _ = store.execute(
            .whenCancelled(
                .push(.detail),
                fallback: .whenCancelled(.push(.settings), fallback: .push(.home))
            )
        )
        #expect(store.state.path == [.home])
    }

    @Test("Store: fallback also gated by middleware surfaces as cancelled overall")
    @MainActor
    func storeFallbackAlsoCancelledSurfacesCancelled() {
        let store = NavigationStore<WCRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(middleware: blockCommandMiddleware { _ in true })
                ]
            )
        )
        let result = store.execute(
            .whenCancelled(.push(.detail), fallback: .push(.home))
        )
        // both cancelled → final result is cancelled
        if case .cancelled = result {
            #expect(store.state.path.isEmpty)
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
    }

    @Test("Store: rollback path emits only the committed change")
    @MainActor
    func storeRollbackNotifiesOnlyCommittedState() async {
        let observedChanges = Mutex<[(RouteStack<WCRoute>, RouteStack<WCRoute>)]>([])
        let observedEvents = Mutex<[NavigationEvent<WCRoute>]>([])
        let store = NavigationStore<WCRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { old, new in
                    observedChanges.withLock { $0.append((old, new)) }
                }
            )
        )
        let stream = store.events
        let listener = Task {
            for await event in stream {
                observedEvents.withLock { $0.append(event) }
            }
        }

        _ = store.execute(
            .whenCancelled(
                .sequence([.push(.detail), .popTo(.settings)]),
                fallback: .push(.home)
            )
        )

        for _ in 0..<10 { await Task.yield() }
        listener.cancel()
        _ = await listener.result

        let changes = observedChanges.withLock { $0 }
        #expect(changes.count == 1)
        #expect(changes[0].0.path.isEmpty)
        #expect(changes[0].1.path == [.home])

        let changedEvents = observedEvents.withLock { events in
            events.compactMap { event -> (RouteStack<WCRoute>, RouteStack<WCRoute>)? in
                guard case .changed(let from, let to) = event else { return nil }
                return (from, to)
            }
        }
        #expect(changedEvents.count == 1)
        #expect(changedEvents[0].0.path.isEmpty)
        #expect(changedEvents[0].1.path == [.home])
    }

    @Test("Transaction: middleware-cancelled primary commits the fallback leg")
    @MainActor
    func transactionMiddlewareCancelledPrimaryUsesFallback() {
        var didExecuteCommands: [NavigationCommand<WCRoute>] = []
        let store = NavigationStore<WCRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(
                        middleware: AnyNavigationMiddleware(
                            willExecute: { command, _ in
                                if case .push(.detail) = command {
                                    return .cancel(.middleware(debugName: nil, command: command))
                                }
                                return .proceed(command)
                            },
                            didExecute: { command, result, _ in
                                didExecuteCommands.append(command)
                                return result
                            }
                        ),
                        debugName: "block"
                    )
                ]
            )
        )

        let transaction = store.executeTransaction([
            .whenCancelled(.push(.detail), fallback: .push(.home))
        ])

        #expect(transaction.isCommitted)
        #expect(transaction.failureIndex == nil)
        #expect(transaction.executedCommands == [.push(.home)])
        #expect(transaction.results == [.success])
        #expect(transaction.stateAfter.path == [.home])
        #expect(store.state.path == [.home])
        #expect(didExecuteCommands == [.push(.home)])
    }
}
