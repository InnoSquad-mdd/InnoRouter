// MARK: - ModalQueueCancellationPolicyTests.swift
// InnoRouterTests - ModalQueueCancellationPolicy applied when a
// ModalMiddleware cancels a command.
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum QueueRoute: String, Route {
    case alpha
    case beta
    case gamma
}

private struct AlwaysCancellingMiddleware: ModalMiddleware {
    typealias RouteType = QueueRoute

    func willExecute(
        _ command: ModalCommand<QueueRoute>,
        currentPresentation: ModalPresentation<QueueRoute>?,
        queuedPresentations: [ModalPresentation<QueueRoute>]
    ) -> ModalInterception<QueueRoute> {
        .cancel(.custom("test cancellation"))
    }

    func didExecute(
        _ command: ModalCommand<QueueRoute>,
        currentPresentation: ModalPresentation<QueueRoute>?,
        queuedPresentations: [ModalPresentation<QueueRoute>]
    ) {
    }
}

@Suite("ModalQueueCancellationPolicy")
@MainActor
struct ModalQueueCancellationPolicyTests {

    // MARK: - .preserve (default)

    @Test("default policy preserves the queue when middleware cancels")
    func defaultPolicy_preservesQueue() {
        let initialQueue: [ModalPresentation<QueueRoute>] = [
            ModalPresentation(route: .beta, style: .sheet),
            ModalPresentation(route: .gamma, style: .sheet),
        ]

        // Build the store with two queued presentations and an
        // active alpha presentation.
        let store = ModalStore<QueueRoute>(
            currentPresentation: ModalPresentation(
                route: .alpha,
                style: .sheet
            ),
            queuedPresentations: initialQueue,
            configuration: ModalStoreConfiguration()
        )

        // Add the cancelling middleware AFTER seed so the cancel
        // applies to whatever command we run next.
        _ = store.addMiddleware(AnyModalMiddleware(AlwaysCancellingMiddleware()))

        let result = store.execute(.dismissAll)

        guard case .cancelled = result else {
            Issue.record("Expected cancelled, got \(result)")
            return
        }

        #expect(store.queuedPresentations == initialQueue)
    }

    // MARK: - .dropQueued

    @Test("dropQueued policy clears the queue on cancellation, leaves active alone")
    func dropQueuedPolicy_clearsQueue_keepsActive() {
        let active = ModalPresentation<QueueRoute>(route: .alpha, style: .sheet)

        let store = ModalStore<QueueRoute>(
            currentPresentation: active,
            queuedPresentations: [
                ModalPresentation(route: .beta, style: .sheet),
                ModalPresentation(route: .gamma, style: .sheet),
            ],
            configuration: ModalStoreConfiguration(
                queueCancellationPolicy: .dropQueued
            )
        )

        _ = store.addMiddleware(AnyModalMiddleware(AlwaysCancellingMiddleware()))

        _ = store.execute(.dismissAll)

        #expect(store.queuedPresentations.isEmpty)
        #expect(store.currentPresentation == active)
    }

    // MARK: - .custom

    @Test("custom policy receives the cancelled command and reason")
    func customPolicy_receivesCommandAndReason() {
        var observedReasons: [String] = []
        let policy = ModalQueueCancellationPolicy<QueueRoute>.custom { _, reason in
            if case .custom(let text) = reason {
                observedReasons.append(text)
            }
            return .preserve
        }

        let store = ModalStore<QueueRoute>(
            currentPresentation: ModalPresentation(
                route: .alpha,
                style: .sheet
            ),
            queuedPresentations: [
                ModalPresentation(route: .beta, style: .sheet),
            ],
            configuration: ModalStoreConfiguration(
                queueCancellationPolicy: policy
            )
        )

        _ = store.addMiddleware(AnyModalMiddleware(AlwaysCancellingMiddleware()))

        _ = store.execute(.dismissAll)

        #expect(observedReasons == ["test cancellation"])
    }

    // MARK: - empty queue is a no-op

    @Test("policy is not invoked when the queue is already empty")
    func emptyQueue_policyNoop() {
        var customCalled = 0
        let policy = ModalQueueCancellationPolicy<QueueRoute>.custom { _, _ in
            customCalled += 1
            return .dropQueued
        }

        let store = ModalStore<QueueRoute>(
            currentPresentation: ModalPresentation(
                route: .alpha,
                style: .sheet
            ),
            queuedPresentations: [],
            configuration: ModalStoreConfiguration(
                queueCancellationPolicy: policy
            )
        )

        _ = store.addMiddleware(AnyModalMiddleware(AlwaysCancellingMiddleware()))

        _ = store.execute(.dismissAll)

        #expect(customCalled == 0)
    }
}
