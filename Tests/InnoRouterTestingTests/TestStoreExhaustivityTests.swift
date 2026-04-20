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

    @Test(".strict deinit with unasserted events records an issue")
    @MainActor
    func strictDeinitFailsWithUnassertedEvents() {
        withKnownIssue {
            let store = NavigationTestStore<ExhaustivityRoute>()
            store.send(.go(.a)) // enqueues a .changed event
            // No receive, no finish — deinit should fire Issue.record.
            store.finish() // run the check now so withKnownIssue observes it
        }
    }

    @Test(".off deinit with unasserted events does not record an issue")
    @MainActor
    func offDeinitDoesNotFail() {
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
