// MARK: - ModalStoreQueueStressTests.swift
// InnoRouterTests - modal queue depth and FIFO stress
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouterCore
import InnoRouterSwiftUI

private enum QueueRoute: Route {
    case sheet(Int)
}

@Suite("ModalStore queue stress")
@MainActor
struct ModalStoreQueueStressTests {

    @Test("100 deferred presentations preserve FIFO order")
    func deepQueue_preservesFIFO() {
        let store = ModalStore<QueueRoute>()

        // First call wins the active slot; subsequent calls queue.
        for i in 0..<100 {
            _ = store.present(.sheet(i), style: .sheet)
        }

        #expect(store.currentPresentation?.route == .sheet(0))
        #expect(store.queuedPresentations.count == 99)

        // FIFO: index 1 surfaces next.
        let queuedRoutes = store.queuedPresentations.map(\.route)
        let expectedQueue = (1..<100).map(QueueRoute.sheet)
        #expect(queuedRoutes == expectedQueue)
    }

    @Test("dismissAll on a deep queue clears the entire backlog")
    func dismissAll_clearsDeepQueue() {
        let store = ModalStore<QueueRoute>()
        for i in 0..<100 {
            _ = store.present(.sheet(i), style: .sheet)
        }
        #expect(store.queuedPresentations.count == 99)

        store.dismissAll()

        #expect(store.currentPresentation == nil)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("queued route promotes to current when active dismisses")
    func sequentialDismiss_drainsQueue() {
        let store = ModalStore<QueueRoute>()
        for i in 0..<5 {
            _ = store.present(.sheet(i), style: .sheet)
        }
        #expect(store.currentPresentation?.route == .sheet(0))

        store.dismissCurrent()
        #expect(store.currentPresentation?.route == .sheet(1))
        store.dismissCurrent()
        #expect(store.currentPresentation?.route == .sheet(2))
        store.dismissCurrent()
        #expect(store.currentPresentation?.route == .sheet(3))
        store.dismissCurrent()
        #expect(store.currentPresentation?.route == .sheet(4))
        store.dismissCurrent()
        #expect(store.currentPresentation == nil)
        #expect(store.queuedPresentations.isEmpty)
    }
}
