// MARK: - DebouncingNavigatorTests.swift
// InnoRouterTests - DebouncingNavigator deterministic timing
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Synchronization
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum DebounceRoute: Route {
    case detail(Int)
}

private final class DebounceTestClock: Clock, Sendable {
    typealias Duration = Swift.Duration

    struct Instant: InstantProtocol, Sendable, Comparable {
        typealias Duration = Swift.Duration

        let elapsed: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant {
            Instant(elapsed: elapsed + duration)
        }

        func duration(to other: Instant) -> Swift.Duration {
            other.elapsed - elapsed
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.elapsed < rhs.elapsed
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct State {
        var now = Instant(elapsed: .zero)
        var sleepers: [UUID: Sleeper] = [:]
        var sleepRegistrationCount = 0
    }

    private let state = Mutex(State())

    var now: Instant {
        state.withLock { $0.now }
    }

    let minimumResolution: Swift.Duration = .nanoseconds(1)

    var sleepRegistrationCount: Int {
        state.withLock { $0.sleepRegistrationCount }
    }

    func advance(by duration: Swift.Duration) {
        let continuations = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let readyIDs = state.sleepers
                .filter { $0.value.deadline <= state.now }
                .map(\.key)
            return readyIDs.compactMap { state.sleepers.removeValue(forKey: $0)?.continuation }
        }

        for continuation in continuations {
            continuation.resume()
        }
    }

    func sleep(until deadline: Instant, tolerance: Swift.Duration?) async throws {
        if deadline <= now {
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let shouldResumeNow = state.withLock { state in
                    if deadline <= state.now {
                        return true
                    }
                    state.sleepRegistrationCount += 1
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return false
                }

                if shouldResumeNow {
                    continuation.resume()
                }
            }
        } onCancel: {
            let continuation = state.withLock {
                $0.sleepers.removeValue(forKey: id)?.continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
    }
}

@Suite("DebouncingNavigator", .tags(.unit))
@MainActor
struct DebouncingNavigatorTests {

    @Test("a single debouncedExecute fires after the interval elapses")
    func singleCall_firesAfterInterval() async {
        let clock = DebounceTestClock()
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(20),
            clock: clock
        )

        async let pending = debouncing.debouncedExecute(.push(.detail(1)))
        await clock.waitForSleepRegistrationCount(1)
        clock.advance(by: .milliseconds(20))

        let result = await pending
        #expect(result?.isSuccess == true)
        #expect(store.state.path == [.detail(1)])
    }

    @Test("rapid sequence collapses to the last command")
    func rapidSequence_keepsOnlyLast() async {
        let clock = DebounceTestClock()
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(40),
            clock: clock
        )

        async let firstResult = debouncing.debouncedExecute(.push(.detail(1)))
        await clock.waitForSleepRegistrationCount(1)
        async let secondResult = debouncing.debouncedExecute(.push(.detail(2)))
        await clock.waitForSleepRegistrationCount(2)

        clock.advance(by: .milliseconds(40))

        let (first, second) = await (firstResult, secondResult)
        #expect(first == nil)
        #expect(second?.isSuccess == true)
        #expect(store.state.path == [.detail(2)])
    }

    @Test("cancelPending stops a queued command from firing")
    func cancelPending_dropsQueuedCommand() async {
        let clock = DebounceTestClock()
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(50),
            clock: clock
        )

        async let pending = debouncing.debouncedExecute(.push(.detail(7)))
        await clock.waitForSleepRegistrationCount(1)
        debouncing.cancelPending()
        clock.advance(by: .milliseconds(50))

        let result = await pending
        #expect(result == nil)
        #expect(store.state.path.isEmpty)
    }

    @Test("cancelling the caller cancels the queued command")
    func callerCancellation_cancelsQueuedCommand() async {
        let clock = DebounceTestClock()
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(50),
            clock: clock
        )

        let task = Task {
            await debouncing.debouncedExecute(.push(.detail(9)))
        }
        await clock.waitForSleepRegistrationCount(1)

        task.cancel()
        clock.advance(by: .milliseconds(50))

        let result = await task.value
        #expect(result == nil)
        #expect(store.state.path.isEmpty)
    }
}

private extension DebounceTestClock {
    func waitForSleepRegistrationCount(_ count: Int) async {
        while sleepRegistrationCount < count {
            await Task.yield()
        }
    }
}
