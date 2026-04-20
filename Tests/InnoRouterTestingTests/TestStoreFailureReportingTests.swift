// MARK: - TestStoreFailureReportingTests.swift
// InnoRouterTestingTests - failure paths verified via withKnownIssue
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouter
import InnoRouterSwiftUI
import InnoRouterTesting

private enum FailRoute: Route {
    case a
    case b
}

@Suite("TestStore Failure Reporting Tests")
struct TestStoreFailureReportingTests {

    @Test("receive on empty queue fires an issue")
    @MainActor
    func receiveOnEmptyQueueFires() {
        withKnownIssue {
            let store = NavigationTestStore<FailRoute>(exhaustivity: .off)
            store.receiveChange()
        }
    }

    @Test("receive with equality mismatch fires an issue")
    @MainActor
    func receiveEqualityMismatchFires() {
        withKnownIssue {
            let store = NavigationTestStore<FailRoute>(exhaustivity: .off)
            store.send(.go(.a)) // enqueues .changed([], [.a])
            // Expect a batch event — mismatch vs .changed.
            store.receiveBatch()
        }
    }

    @Test("expectNoMoreEvents with queued event fires an issue")
    @MainActor
    func expectNoMoreEventsFiresWhenQueued() {
        withKnownIssue {
            let store = NavigationTestStore<FailRoute>(exhaustivity: .off)
            store.send(.go(.a))
            store.expectNoMoreEvents()
        }
    }

    @Test("ModalTestStore: receiveIntercepted on wrong case fires an issue")
    @MainActor
    func modalReceiveInterceptedWrongCaseFires() {
        withKnownIssue {
            let store = ModalTestStore<FailRoute>(exhaustivity: .off)
            store.present(.a)
            // First queued event is .commandIntercepted; receiveDismissed expects .dismissed.
            store.receiveDismissed()
        }
    }

    @Test("FlowTestStore: receiveIntentRejected mismatch fires an issue")
    @MainActor
    func flowReceiveIntentRejectedMismatchFires() {
        withKnownIssue {
            let store = FlowTestStore<FailRoute>(exhaustivity: .off)
            store.send(.presentSheet(.a))
            store.skipReceivedEvents()

            store.send(.push(.b)) // rejected with pushBlockedByModalTail

            // Expect wrong reason — should fire.
            store.receiveIntentRejected(
                intent: .push(.b),
                reason: .invalidResetPath
            )
        }
    }
}
