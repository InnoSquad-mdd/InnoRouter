// MARK: - StoreObserverTests.swift
// InnoRouterTests - StoreObserver protocol adapter
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum ObsRoute: Route {
    case home
    case detail
    case sheet
}

private final class RecordingObserver: StoreObserver, Sendable {
    typealias RouteType = ObsRoute
    let navEvents = Mutex<[NavigationEvent<ObsRoute>]>([])
    let modalEvents = Mutex<[ModalEvent<ObsRoute>]>([])
    let flowEvents = Mutex<[FlowEvent<ObsRoute>]>([])
    let navOnMainThread = Mutex<[Bool]>([])
    let modalOnMainThread = Mutex<[Bool]>([])
    let flowOnMainThread = Mutex<[Bool]>([])

    func handle(_ event: NavigationEvent<ObsRoute>) {
        navOnMainThread.withLock { $0.append(Thread.isMainThread) }
        navEvents.withLock { $0.append(event) }
    }
    func handle(_ event: ModalEvent<ObsRoute>) {
        modalOnMainThread.withLock { $0.append(Thread.isMainThread) }
        modalEvents.withLock { $0.append(event) }
    }
    func handle(_ event: FlowEvent<ObsRoute>) {
        flowOnMainThread.withLock { $0.append(Thread.isMainThread) }
        flowEvents.withLock { $0.append(event) }
    }
}

@Suite("StoreObserver Tests")
struct StoreObserverTests {

    @Test("NavigationStore.observe delivers .changed events")
    @MainActor
    func navigationObserveDelivers() async {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        // Yield enough to let the Task subscriber pump.
        for _ in 0..<5 { await Task.yield() }

        let events = observer.navEvents.withLock { $0 }
        #expect(events.contains { if case .changed = $0 { return true }; return false })

        subscription.cancel()
    }

    @Test("NavigationStore.observe delivers on the main actor")
    @MainActor
    func navigationObserveDeliversOnMainActor() async {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        for _ in 0..<5 { await Task.yield() }

        let delivery = observer.navOnMainThread.withLock { $0 }
        #expect(!delivery.isEmpty)
        #expect(delivery.allSatisfy { $0 })

        subscription.cancel()
    }

    @Test("Multiple observers on one store both receive events")
    @MainActor
    func multipleObservers() async {
        let store = NavigationStore<ObsRoute>()
        let observerA = RecordingObserver()
        let observerB = RecordingObserver()
        let subA = store.observe(observerA)
        let subB = store.observe(observerB)

        store.send(.go(.home))
        for _ in 0..<5 { await Task.yield() }

        #expect(observerA.navEvents.withLock { $0.count } >= 1)
        #expect(observerB.navEvents.withLock { $0.count } >= 1)

        subA.cancel()
        subB.cancel()
    }

    @Test("subscription.cancel stops delivery")
    @MainActor
    func subscriptionCancelStops() async {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        for _ in 0..<5 { await Task.yield() }
        let countAfterFirst = observer.navEvents.withLock { $0.count }

        subscription.cancel()
        // Give cancellation a moment to land.
        for _ in 0..<5 { await Task.yield() }

        store.send(.go(.detail))
        for _ in 0..<5 { await Task.yield() }

        let countAfterSecond = observer.navEvents.withLock { $0.count }
        #expect(countAfterSecond == countAfterFirst)
    }

    @Test("ModalStore.observe delivers on the main actor")
    @MainActor
    func modalObserveDeliversOnMainActor() async {
        let store = ModalStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.present(.sheet, style: .sheet)
        for _ in 0..<5 { await Task.yield() }

        let delivery = observer.modalOnMainThread.withLock { $0 }
        #expect(!delivery.isEmpty)
        #expect(delivery.allSatisfy { $0 })

        subscription.cancel()
    }

    @Test("FlowStore.observe routes inner navigation and modal events through typed handlers")
    @MainActor
    func flowObserveRoutesInnerEvents() async {
        let store = FlowStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.push(.home))
        store.send(.presentSheet(.sheet))
        for _ in 0..<10 { await Task.yield() }

        #expect(!observer.navEvents.withLock { $0.isEmpty })
        #expect(!observer.modalEvents.withLock { $0.isEmpty })
        // Flow-level pathChanged also surfaces.
        #expect(observer.flowEvents.withLock { $0 }.contains {
            if case .pathChanged = $0 { return true }
            return false
        })

        subscription.cancel()
    }

    @Test("FlowStore.observe delivers flow-level callbacks on the main actor")
    @MainActor
    func flowObserveDeliversOnMainActor() async {
        let store = FlowStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.push(.home))
        for _ in 0..<10 { await Task.yield() }

        let delivery = observer.flowOnMainThread.withLock { $0 }
        #expect(!delivery.isEmpty)
        #expect(delivery.allSatisfy { $0 })

        subscription.cancel()
    }
}
