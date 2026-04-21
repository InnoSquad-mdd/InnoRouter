// MARK: - StoreObserverTests.swift
// InnoRouterTests - StoreObserver protocol adapter
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterSwiftUI

private enum ObsRoute: Route {
    case home
    case detail
    case sheet
}

@MainActor
private final class RecordingObserver: StoreObserver {
    typealias RouteType = ObsRoute

    enum RecordedEvent {
        case navigation(NavigationEvent<ObsRoute>)
        case modal(ModalEvent<ObsRoute>)
        case flow(FlowEvent<ObsRoute>)
    }

    private struct Waiter {
        let predicate: (RecordedEvent) -> Bool
        let continuation: CheckedContinuation<RecordedEvent?, Never>
    }

    var navEvents: [NavigationEvent<ObsRoute>] = []
    var modalEvents: [ModalEvent<ObsRoute>] = []
    var flowEvents: [FlowEvent<ObsRoute>] = []
    var navOnMainThread: [Bool] = []
    var modalOnMainThread: [Bool] = []
    var flowOnMainThread: [Bool] = []

    private var bufferedEvents: [RecordedEvent] = []
    private var waiters: [UUID: Waiter] = [:]

    func handle(_ event: NavigationEvent<ObsRoute>) {
        navOnMainThread.append(Thread.isMainThread)
        navEvents.append(event)
        publish(.navigation(event))
    }

    func handle(_ event: ModalEvent<ObsRoute>) {
        modalOnMainThread.append(Thread.isMainThread)
        modalEvents.append(event)
        publish(.modal(event))
    }

    func handle(_ event: FlowEvent<ObsRoute>) {
        flowOnMainThread.append(Thread.isMainThread)
        flowEvents.append(event)
        publish(.flow(event))
    }

    func waitForEvent(
        matching predicate: @escaping (RecordedEvent) -> Bool,
        timeout: Duration = .seconds(1)
    ) async -> RecordedEvent? {
        if let index = bufferedEvents.firstIndex(where: predicate) {
            return bufferedEvents.remove(at: index)
        }

        let waiterID = UUID()
        return await withCheckedContinuation { continuation in
            waiters[waiterID] = Waiter(predicate: predicate, continuation: continuation)
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                await MainActor.run {
                    guard let self, let waiter = self.waiters.removeValue(forKey: waiterID) else { return }
                    waiter.continuation.resume(returning: nil)
                }
            }
        }
    }

    private func publish(_ event: RecordedEvent) {
        guard let waiterID = waiters.first(where: { $0.value.predicate(event) })?.key,
              let waiter = waiters.removeValue(forKey: waiterID) else {
            bufferedEvents.append(event)
            return
        }
        waiter.continuation.resume(returning: event)
    }
}

@Suite("StoreObserver Tests")
struct StoreObserverTests {

    @Test("NavigationStore.observe delivers .changed events")
    @MainActor
    func navigationObserveDelivers() async throws {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))

        #expect(observer.navEvents.contains { if case .changed = $0 { return true }; return false })

        subscription.cancel()
    }

    @Test("NavigationStore.observe delivers on the main actor")
    @MainActor
    func navigationObserveDeliversOnMainActor() async throws {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))

        #expect(!observer.navOnMainThread.isEmpty)
        #expect(observer.navOnMainThread.allSatisfy { $0 })

        subscription.cancel()
    }

    @Test("Multiple observers on one store both receive events")
    @MainActor
    func multipleObservers() async throws {
        let store = NavigationStore<ObsRoute>()
        let observerA = RecordingObserver()
        let observerB = RecordingObserver()
        let subA = store.observe(observerA)
        let subB = store.observe(observerB)

        store.send(.go(.home))
        _ = try #require(await observerA.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))
        _ = try #require(await observerB.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))

        #expect(observerA.navEvents.count >= 1)
        #expect(observerB.navEvents.count >= 1)

        subA.cancel()
        subB.cancel()
    }

    @Test("subscription.cancel stops delivery")
    @MainActor
    func subscriptionCancelStops() async throws {
        let store = NavigationStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.go(.home))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))
        let countAfterFirst = observer.navEvents.count

        subscription.cancel()

        store.send(.go(.detail))
        let unexpectedEvent = await observer.waitForEvent(
            matching: { event in
                guard case .navigation(.changed(_, let to)) = event else { return false }
                return to.path == [.home, .detail]
            },
            timeout: .milliseconds(100)
        )

        let countAfterSecond = observer.navEvents.count
        #expect(unexpectedEvent == nil)
        #expect(countAfterSecond == countAfterFirst)
    }

    @Test("ModalStore.observe delivers on the main actor")
    @MainActor
    func modalObserveDeliversOnMainActor() async throws {
        let store = ModalStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.present(.sheet, style: .sheet)
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .modal(.presented) = event else { return false }
            return true
        }))

        #expect(!observer.modalOnMainThread.isEmpty)
        #expect(observer.modalOnMainThread.allSatisfy { $0 })

        subscription.cancel()
    }

    @Test("FlowStore.observe routes inner navigation and modal events through typed handlers")
    @MainActor
    func flowObserveRoutesInnerEvents() async throws {
        let store = FlowStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.push(.home))
        store.send(.presentSheet(.sheet))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .navigation(.changed) = event else { return false }
            return true
        }))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .modal(.presented) = event else { return false }
            return true
        }))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .flow(.pathChanged) = event else { return false }
            return true
        }))

        #expect(!observer.navEvents.isEmpty)
        #expect(!observer.modalEvents.isEmpty)
        #expect(observer.flowEvents.contains {
            if case .pathChanged = $0 { return true }
            return false
        })

        subscription.cancel()
    }

    @Test("FlowStore.observe delivers flow-level callbacks on the main actor")
    @MainActor
    func flowObserveDeliversOnMainActor() async throws {
        let store = FlowStore<ObsRoute>()
        let observer = RecordingObserver()
        let subscription = store.observe(observer)

        store.send(.push(.home))
        _ = try #require(await observer.waitForEvent(matching: { event in
            guard case .flow(.pathChanged) = event else { return false }
            return true
        }))

        #expect(!observer.flowOnMainThread.isEmpty)
        #expect(observer.flowOnMainThread.allSatisfy { $0 })

        subscription.cancel()
    }
}
