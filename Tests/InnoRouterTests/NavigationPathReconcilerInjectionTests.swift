// MARK: - NavigationPathReconcilerInjectionTests.swift
// InnoRouterTests - 5.0 NavigationPathReconciling injection.
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum InjectionRoute: Route {
    case home
    case detail(Int)
}

/// Records every reconcile invocation so the test can assert that
/// the injected reconciler — not the framework default — saw the
/// path mutation.
@MainActor
private final class RecordingReconciler<R: Route>: NavigationPathReconciling {
    var calls: [(old: [R], new: [R])] = []
    nonisolated init() {}

    func reconcile(
        from oldPath: [R],
        to newPath: [R],
        resolveMismatch: @MainActor ([R], [R]) -> NavigationPathMismatchResolution<R>,
        execute: @MainActor (NavigationCommand<R>) -> Void,
        executeBatch: @MainActor ([NavigationCommand<R>]) -> Void
    ) {
        calls.append((old: oldPath, new: newPath))
        // Defer to a default conforming reconciler so the store
        // still sees structural reductions through the normal path.
        NavigationPathReconciler<R>().reconcile(
            from: oldPath,
            to: newPath,
            resolveMismatch: resolveMismatch,
            execute: execute,
            executeBatch: executeBatch
        )
    }
}

@Suite("NavigationPathReconciling injection")
@MainActor
struct NavigationPathReconcilerInjectionTests {

    @Test("injected reconciler observes binding-driven path writes")
    func injectedReconciler_observesBindingWrites() {
        let recorder = RecordingReconciler<InjectionRoute>()
        let store = try! NavigationStore<InjectionRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathReconciler: recorder
            )
        )

        store.pathBinding.wrappedValue = [.home, .detail(7)]

        #expect(recorder.calls.count == 1)
        #expect(recorder.calls[0].old == [.home])
        #expect(recorder.calls[0].new == [.home, .detail(7)])
        #expect(store.state.path == [.home, .detail(7)])
    }

    @Test("default reconciler is used when none is supplied")
    func defaultReconciler_isUsedWhenUnconfigured() {
        let store = try! NavigationStore<InjectionRoute>(
            initialPath: [.home]
        )

        store.pathBinding.wrappedValue = [.home, .detail(1)]

        // The default reconciler routes a prefix-expand into a
        // .push so the resulting state should match.
        #expect(store.state.path == [.home, .detail(1)])
    }
}
