// MARK: - NavigationCommandWhenCancelledTests.swift
// InnoRouterTests - .whenCancelled fallback behaviour
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
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
}
