// MARK: - TvOSFocusNavigationTests.swift
// InnoRouterTests - tvOS-focused navigation regression coverage
// Copyright © 2026 Inno Squad. All rights reserved.
//
// tvOS uses a focus engine instead of a touch event stream, so a
// remote-driven `Move Right` traversing a `NavigationStack(value:)`
// dispatches `.push` through the same intent surface as iOS.
// These tests assert that the underlying NavigationStore semantics
// stay correct regardless of the producing platform — the actual
// focus-driven UI is exercised by the platform CI matrix.

#if os(tvOS)

import Testing
import InnoRouterCore
import InnoRouterSwiftUI

private enum FocusRoute: Route {
    case grid
    case detail(Int)
}

@Suite("tvOS focus-driven navigation")
@MainActor
struct TvOSFocusNavigationTests {

    @Test("rapid push/pop pairs stay synchronised with state.path")
    func rapidPushPop_keepsPathConsistent() {
        let store = NavigationStore<FocusRoute>()

        for index in 0..<20 {
            _ = store.execute(.push(.detail(index)))
            #expect(store.state.path.count == 1)
            _ = store.execute(.pop)
            #expect(store.state.path.isEmpty)
        }
    }

    @Test("focus-equivalent .replace coalesces a path swap into a single change")
    func replaceOnFocusChange_coalescesEvents() async {
        let store = NavigationStore<FocusRoute>()
        var emittedChanges = 0

        let task = Task {
            for await event in store.events {
                if case .changed = event {
                    emittedChanges += 1
                }
            }
        }

        _ = store.execute(.replace([.grid, .detail(1)]))
        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()

        // .replace is a single command; the events stream emits
        // exactly one .changed for the operation regardless of how
        // many path entries it rewrites.
        #expect(emittedChanges == 1)
    }
}

#endif
