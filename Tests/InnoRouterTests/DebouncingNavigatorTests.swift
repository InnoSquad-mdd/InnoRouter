// MARK: - DebouncingNavigatorTests.swift
// InnoRouterTests - DebouncingNavigator deterministic timing
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouterCore
import InnoRouterSwiftUI

private enum DebounceRoute: Route {
    case detail(Int)
}

@Suite("DebouncingNavigator")
@MainActor
struct DebouncingNavigatorTests {

    @Test("a single debouncedExecute fires after the interval elapses")
    func singleCall_firesAfterInterval() async {
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(20),
            clock: ContinuousClock()
        )

        let result = await debouncing.debouncedExecute(.push(.detail(1)))
        #expect(result?.isSuccess == true)
        #expect(store.state.path.count == 1)
    }

    @Test("rapid sequence collapses to the last command")
    func rapidSequence_keepsOnlyLast() async {
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(40),
            clock: ContinuousClock()
        )

        // The first call schedules; the second cancels and reschedules.
        async let firstResult = debouncing.debouncedExecute(.push(.detail(1)))
        // Yield so the first task starts before being superseded.
        await Task.yield()
        async let secondResult = debouncing.debouncedExecute(.push(.detail(2)))

        let (first, second) = await (firstResult, secondResult)

        // Only the second command can complete; the first was
        // cancelled in flight.
        #expect(first == nil)
        #expect(second?.isSuccess == true)
        #expect(store.state.path == [.detail(2)])
    }

    @Test("cancelPending stops a queued command from firing")
    func cancelPending_dropsQueuedCommand() async {
        let store = NavigationStore<DebounceRoute>()
        let debouncing = DebouncingNavigator(
            wrapping: store,
            interval: .milliseconds(50),
            clock: ContinuousClock()
        )

        async let pending = debouncing.debouncedExecute(.push(.detail(7)))
        await Task.yield()
        debouncing.cancelPending()

        let result = await pending
        #expect(result == nil)
        #expect(store.state.path.isEmpty)
    }
}
