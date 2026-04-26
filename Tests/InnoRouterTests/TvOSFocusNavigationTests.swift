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

@Suite("tvOS focus-driven navigation", .tags(.unit))
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
    func replaceOnFocusChange_coalescesEvents() async throws {
        let store = NavigationStore<FocusRoute>()
        var iterator = store.events.makeAsyncIterator()

        _ = store.execute(.replace([.grid, .detail(1)]))

        let event = try #require(await iterator.next())
        guard case .changed(let old, let new) = event else {
            Issue.record("Expected .changed, got \(event)")
            return
        }
        #expect(old.path.isEmpty)
        #expect(new.path == [.grid, .detail(1)])
    }
}

#endif
