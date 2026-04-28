// MARK: - QueueCoalescePolicyTests.swift
// InnoRouterTests - covers the three QueueCoalescePolicy paths
// (`.preserve` / `.dropQueued` / `.custom`) introduced in v4.0.0.
//
// `.replaceStack` is the meaningful regression vector: it is one of
// the few flow-level commands that is legal while a modal tail is
// active (it dismisses the modal as part of the reset) and therefore
// reaches navigation middleware. A cancel at that point is the
// canonical "navigation prefix did not commit, but the modal queue
// is still hanging around" scenario the policy is meant to handle.
// `.push` is intentionally excluded because the FlowStore invariant
// rejects it with `.pushBlockedByModalTail` before it ever reaches
// middleware.
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Synchronization
import Testing

import InnoRouter
import InnoRouterCore
@_spi(FlowStoreInternals) import InnoRouterSwiftUI

private enum QueueRoute: Route {
    case home
    case detail
    case sheetA
    case sheetB
}

@Suite("QueueCoalescePolicy")
@MainActor
struct QueueCoalescePolicyTests {

    /// Builds a FlowStore with a navigation middleware that cancels
    /// every `.replace` command and the supplied queue policy.
    private func makeStore(policy: QueueCoalescePolicy<QueueRoute>) -> FlowStore<QueueRoute> {
        let cancelMiddleware = AnyNavigationMiddleware<QueueRoute>(
            willExecute: { command, _ in
                if case .replace = command {
                    return .cancel(.middleware(debugName: "test-cancel", command: command))
                }
                return .proceed(command)
            }
        )
        return FlowStore<QueueRoute>(
            configuration: FlowStoreConfiguration(
                navigation: NavigationStoreConfiguration(
                    middlewares: [.init(middleware: cancelMiddleware, debugName: "test-cancel")]
                ),
                queueCoalescePolicy: policy
            )
        )
    }

    @Test("default policy is .preserve")
    func defaultPolicy_isPreserve() {
        let config = FlowStoreConfiguration<QueueRoute>()
        if case .preserve = config.queueCoalescePolicy {
            // expected
        } else {
            Issue.record("Expected default queueCoalescePolicy to be .preserve")
        }
    }

    @Test(".preserve keeps the modal queue intact when middleware cancels replaceStack")
    func preservePolicy_keepsQueueIntact() {
        let store = makeStore(policy: .preserve)

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))
        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.map(\.route) == [.sheetB])

        store.send(.replaceStack([.home]))

        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.map(\.route) == [.sheetB])
    }

    @Test(".dropQueued dismisses the active modal and clears the queue")
    func dropQueuedPolicy_clearsModalState() {
        let store = makeStore(policy: .dropQueued)

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))
        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.count == 1)

        store.send(.replaceStack([.home]))

        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.modalStore.queuedPresentations.isEmpty)
    }

    @Test(".custom returning .dropQueued behaves like .dropQueued")
    func customPolicy_dropQueued() {
        let invoked = Mutex<Int>(0)
        let store = makeStore(
            policy: .custom { _, _ in
                invoked.withLock { $0 += 1 }
                return .dropQueued
            }
        )

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))
        store.send(.replaceStack([.home]))

        #expect(invoked.withLock { $0 } == 1)
        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.modalStore.queuedPresentations.isEmpty)
    }

    @Test(".custom returning .preserve behaves like .preserve")
    func customPolicy_preserve() {
        let store = makeStore(
            policy: .custom { _, _ in .preserve }
        )

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))
        store.send(.replaceStack([.home]))

        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.map(\.route) == [.sheetB])
    }

    @Test(".dropQueued does not engage on caller-side invariant rejections")
    func dropQueuedPolicy_skipsCallerErrors() {
        // Configuration with no middleware so any rejection is a
        // caller-side invariant violation, not a middleware cancel.
        let store = FlowStore<QueueRoute>(
            configuration: FlowStoreConfiguration(queueCoalescePolicy: .dropQueued)
        )

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))

        // `.push` while a modal tail is active is rejected with
        // `.pushBlockedByModalTail`, not `.middlewareRejected`. The
        // policy should ignore this rejection class.
        store.send(.push(.home))

        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.map(\.route) == [.sheetB])
    }

    @Test(".dropQueued does not engage on modal present middleware rejections")
    func dropQueuedPolicy_skipsModalPresentMiddlewareRejections() {
        let cancelSheetB = AnyModalMiddleware<QueueRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command,
                    presentation.route == .sheetB {
                    return .cancel(.middleware(debugName: "modal-cancel", command: command))
                }
                return .proceed(command)
            }
        )
        let store = FlowStore<QueueRoute>(
            configuration: FlowStoreConfiguration(
                modal: ModalStoreConfiguration(
                    middlewares: [.init(middleware: cancelSheetB, debugName: "modal-cancel")]
                ),
                queueCoalescePolicy: .dropQueued
            )
        )

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))

        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.isEmpty)
    }

    @Test(".custom does not engage on modal middleware rejections")
    func customPolicy_skipsModalMiddlewareRejections() {
        let invoked = Mutex<Int>(0)
        let cancelDismissAll = AnyModalMiddleware<QueueRoute>(
            willExecute: { command, _, _ in
                if case .dismissAll = command {
                    return .cancel(.middleware(debugName: "modal-cancel", command: command))
                }
                return .proceed(command)
            }
        )
        let store = FlowStore<QueueRoute>(
            configuration: FlowStoreConfiguration(
                modal: ModalStoreConfiguration(
                    middlewares: [.init(middleware: cancelDismissAll, debugName: "modal-cancel")]
                ),
                queueCoalescePolicy: .custom { _, _ in
                    invoked.withLock { $0 += 1 }
                    return .dropQueued
                }
            )
        )

        store.send(.presentSheet(.sheetA))
        store.send(.presentSheet(.sheetB))
        store.send(.replaceStack([.home]))

        #expect(invoked.withLock { $0 } == 0)
        #expect(store.modalStore.currentPresentation?.route == .sheetA)
        #expect(store.modalStore.queuedPresentations.map(\.route) == [.sheetB])
    }
}
