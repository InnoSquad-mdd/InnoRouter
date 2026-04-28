// MARK: - EventBufferingPolicyTests.swift
// InnoRouterTests - store event broadcaster backpressure coverage
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
@_spi(FlowStoreInternals) import InnoRouterSwiftUI
@testable import InnoRouterCore

private enum BufferRoute: Route {
    case home
    case detail
    case settings
    case profile
}

@Suite("EventBufferingPolicy backpressure")
struct EventBufferingPolicyTests {

    @Test("EventBroadcaster.bufferingNewest retains only the most recent N events")
    @MainActor
    func bufferingNewestRetainsOnlyMostRecent() async {
        let broadcaster = EventBroadcaster<Int>(bufferingPolicy: .bufferingNewest(2))
        let stream = broadcaster.stream()
        var iterator = stream.makeAsyncIterator()

        // Five synchronous broadcasts before the consumer reads anything; the
        // continuation buffer holds at most two and must drop the oldest three.
        for i in 0..<5 {
            broadcaster.broadcast(i)
        }

        let first = await iterator.next()
        let second = await iterator.next()
        #expect(first == 3)
        #expect(second == 4)
    }

    @Test("EventBroadcaster.bufferingOldest retains only the oldest N events")
    @MainActor
    func bufferingOldestRetainsOldest() async {
        let broadcaster = EventBroadcaster<Int>(bufferingPolicy: .bufferingOldest(2))
        let stream = broadcaster.stream()
        var iterator = stream.makeAsyncIterator()

        for i in 0..<5 {
            broadcaster.broadcast(i)
        }

        let first = await iterator.next()
        let second = await iterator.next()
        #expect(first == 0)
        #expect(second == 1)
    }

    @Test("EventBroadcaster.unbounded delivers every broadcast event in order")
    @MainActor
    func unboundedDeliversEveryEvent() async {
        let broadcaster = EventBroadcaster<Int>(bufferingPolicy: .unbounded)
        let stream = broadcaster.stream()
        var iterator = stream.makeAsyncIterator()

        for i in 0..<5 {
            broadcaster.broadcast(i)
        }

        var collected: [Int] = []
        for _ in 0..<5 {
            if let value = await iterator.next() {
                collected.append(value)
            }
        }
        #expect(collected == [0, 1, 2, 3, 4])
    }

    @Test("EventBufferingPolicy default is bufferingNewest(1024)")
    func defaultPolicyIsBoundedNewest() {
        #expect(EventBufferingPolicy.default == .bufferingNewest(1024))
    }

    @Test("NavigationStoreConfiguration.eventBufferingPolicy is honoured by the store")
    @MainActor
    func navigationStoreHonoursConfiguredPolicy() async {
        let store = NavigationStore<BufferRoute>(
            configuration: .init(eventBufferingPolicy: .bufferingNewest(2))
        )
        var iterator = store.events.makeAsyncIterator()

        store.execute(.push(.home))
        store.execute(.push(.detail))
        store.execute(.push(.settings))
        store.execute(.push(.profile))

        let first = await iterator.next()
        let second = await iterator.next()

        // Only the last two `.changed` events should remain in the buffer.
        guard
            case .changed(_, let firstTo) = first,
            case .changed(_, let secondTo) = second
        else {
            Issue.record("Expected two .changed events, got \(String(describing: first)), \(String(describing: second))")
            return
        }
        #expect(firstTo.path == [.home, .detail, .settings])
        #expect(secondTo.path == [.home, .detail, .settings, .profile])
    }

    @Test("NavigationStoreConfiguration.eventBufferingPolicy.unbounded preserves every event")
    @MainActor
    func navigationStoreUnboundedPreservesAllEvents() async {
        let store = NavigationStore<BufferRoute>(
            configuration: .init(eventBufferingPolicy: .unbounded)
        )
        var iterator = store.events.makeAsyncIterator()

        store.execute(.push(.home))
        store.execute(.push(.detail))
        store.execute(.push(.settings))
        store.execute(.push(.profile))

        var paths: [[BufferRoute]] = []
        for _ in 0..<4 {
            guard case .changed(_, let to) = await iterator.next() else {
                Issue.record("Expected .changed event")
                return
            }
            paths.append(to.path)
        }

        #expect(paths == [
            [.home],
            [.home, .detail],
            [.home, .detail, .settings],
            [.home, .detail, .settings, .profile]
        ])
    }

    @Test("FlowStore preserves configured inner navigation buffering policy")
    @MainActor
    func flowStorePreservesInnerNavigationBufferingPolicy() async {
        let store = FlowStore<BufferRoute>(
            configuration: .init(
                navigation: .init(eventBufferingPolicy: .bufferingNewest(1))
            )
        )
        var iterator = store.navigationStore.events.makeAsyncIterator()

        store.navigationStore.execute(.push(.home))
        store.navigationStore.execute(.push(.detail))
        store.navigationStore.execute(.push(.settings))

        guard case .changed(_, let to) = await iterator.next() else {
            Issue.record("Expected the newest inner navigation .changed event")
            return
        }
        #expect(to.path == [.home, .detail, .settings])
    }

    @Test("FlowStore preserves configured inner modal buffering policy")
    @MainActor
    func flowStorePreservesInnerModalBufferingPolicy() async {
        let store = FlowStore<BufferRoute>(
            configuration: .init(
                modal: .init(eventBufferingPolicy: .bufferingNewest(1))
            )
        )
        var iterator = store.modalStore.events.makeAsyncIterator()

        store.modalStore.present(.home, style: .sheet)

        guard
            case .commandIntercepted(command: .present(let commandPresentation), result: let result) = await iterator.next()
        else {
            Issue.record("Expected the newest inner modal .commandIntercepted event")
            return
        }
        #expect(commandPresentation.route == .home)
        guard case .executed(.present(let presentation)) = result else {
            Issue.record("Expected executed present result, got \(result)")
            return
        }
        #expect(presentation.route == .home)
    }
}
