// MARK: - TestStoreExhaustivityTests.swift
// InnoRouterTestingTests - TestExhaustivity .strict vs .off
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouter
import InnoRouterSwiftUI
import InnoRouterTesting

private enum ExhaustivityRoute: Route {
    case a
    case b
}

@Suite("TestStore Exhaustivity Tests")
struct TestStoreExhaustivityTests {

    @Test(".strict finish with unasserted events records an issue")
    @MainActor
    func strictFinishFailsWithUnassertedEvents() {
        withKnownIssue {
            let store = NavigationTestStore<ExhaustivityRoute>()
            store.send(.go(.a)) // enqueues a .changed event
            // Swift Testing currently reports isolated-deinit issues as
            // belonging to an unknown test, so trigger the same strict
            // exhaustivity path via finish() inside withKnownIssue.
            store.finish()
        }
    }

    @Test(".off finish with unasserted events does not record an issue")
    @MainActor
    func offFinishDoesNotFail() {
        let store = NavigationTestStore<ExhaustivityRoute>(exhaustivity: .off)
        store.send(.go(.a))
        store.finish() // should be silent under .off
    }

    @Test("skipReceivedEvents drains the queue without firing")
    @MainActor
    func skipReceivedEventsDrains() {
        let store = NavigationTestStore<ExhaustivityRoute>()
        store.send(.go(.a))
        store.send(.go(.b))
        store.skipReceivedEvents()
        store.expectNoMoreEvents()
        store.finish()
    }

    @Test("finish() is idempotent — subsequent calls do not re-fire")
    @MainActor
    func finishIsIdempotent() {
        let store = NavigationTestStore<ExhaustivityRoute>()
        store.send(.go(.a))
        store.receiveChange()
        store.finish()
        store.finish() // second call is a no-op
    }
}
