// MARK: - StoreRaceStressTests.swift
// InnoRouterTests - concurrency stress for @MainActor stores under
// many concurrent Tasks.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// All InnoRouter stores are `@MainActor`-isolated, so the main-actor
// hop serialises every `send` / `execute` regardless of how many
// Tasks issue them. The contracts these tests pin under load are:
//
// 1. Path consistency — N concurrent pushes from N Tasks produce a
//    final stack of size N with each route present exactly once,
//    regardless of interleaving.
// 2. Event fan-out — subscribers attached *before* a burst observe
//    every change emitted by that burst, in some order. The default
//    `bufferingNewest(1024)` policy is well above the burst sizes
//    here, so no drops are expected.
// 3. Multi-subscriber parity — two subscribers attached simultaneously
//    drain the same set of events.
//
// Bursts stay below the default per-subscriber buffer (1024) so any
// drop indicates a regression in `EventBroadcaster`, not a buffer
// overflow.

import Foundation
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum RaceRoute: Route, Hashable {
    case detail(Int)
}

private actor AsyncSignal {
    private var didSignal = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        guard !didSignal else { return }
        didSignal = true
        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume()
        }
    }

    func wait() async {
        guard !didSignal else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

@Suite("Store race / concurrency stress", .tags(.unit))
@MainActor
struct StoreRaceStressTests {

    // MARK: - 1. Concurrent pushes preserve path consistency

    @Test("100 concurrent push tasks land 100 distinct routes on the stack")
    func concurrentPushes_landAllDistinctRoutes() async {
        let store = NavigationStore<RaceRoute>()
        let count = 100

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<count {
                group.addTask { @MainActor in
                    _ = store.execute(.push(.detail(index)))
                }
            }
        }

        let path = store.state.path
        #expect(path.count == count)

        var seen = Set<Int>()
        for route in path {
            guard case .detail(let id) = route else {
                Issue.record("Unexpected non-detail route on the stack: \(route)")
                continue
            }
            #expect(seen.insert(id).inserted, "Duplicate route detail(\(id)) on the stack")
        }
        #expect(seen.count == count)
    }

    // MARK: - 2. Event fan-out under a burst

    @Test("a 200-push burst delivers 200 .changed events to the pre-burst subscriber")
    func burst_deliversEveryChangeEvent() async throws {
        let store = NavigationStore<RaceRoute>()
        let burst = 200

        // Drain in a child Task that lives long enough to receive the
        // whole burst. Using a counted async iterator keeps the test
        // deterministic even if events arrive out of dispatch order.
        let ready = AsyncSignal()
        let drainTask: Task<Int, Never> = Task { @MainActor in
            var changes = 0
            var iterator = store.events.makeAsyncIterator()
            await ready.signal()
            while let event = await iterator.next() {
                if case .changed = event {
                    changes += 1
                    if changes == burst {
                        break
                    }
                }
            }
            return changes
        }

        await ready.wait()

        for index in 0..<burst {
            _ = store.execute(.push(.detail(index)))
        }

        let observed = await drainTask.value
        #expect(observed == burst)
    }

    // MARK: - 3. Multi-subscriber parity

    @Test("two subscribers each see the same 100-event burst")
    func twoSubscribers_seeIdenticalBurst() async throws {
        let store = NavigationStore<RaceRoute>()
        let burst = 100

        // Each subscriber owns its own AsyncStream — fan-out is
        // independent, so both must reach `burst` events.
        let firstReady = AsyncSignal()
        let firstDrain: Task<Int, Never> = Task { @MainActor in
            var changes = 0
            var iterator = store.events.makeAsyncIterator()
            await firstReady.signal()
            while let event = await iterator.next() {
                if case .changed = event {
                    changes += 1
                    if changes == burst {
                        break
                    }
                }
            }
            return changes
        }
        let secondReady = AsyncSignal()
        let secondDrain: Task<Int, Never> = Task { @MainActor in
            var changes = 0
            var iterator = store.events.makeAsyncIterator()
            await secondReady.signal()
            while let event = await iterator.next() {
                if case .changed = event {
                    changes += 1
                    if changes == burst {
                        break
                    }
                }
            }
            return changes
        }

        await firstReady.wait()
        await secondReady.wait()

        for index in 0..<burst {
            _ = store.execute(.push(.detail(index)))
        }

        let first = await firstDrain.value
        let second = await secondDrain.value
        #expect(first == burst)
        #expect(second == burst)
    }
}
