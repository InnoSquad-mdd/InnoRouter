// MARK: - ChildCoordinatorTaskTrackerTests.swift
// InnoRouterTests - ChildCoordinatorTaskTracker behaviour
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

@Suite("ChildCoordinatorTaskTracker Tests")
struct ChildCoordinatorTaskTrackerTests {

    @Test("tracked task runs to completion when not cancelled")
    @MainActor
    func runsToCompletion() async {
        let tracker = ChildCoordinatorTaskTracker()
        let finished = Mutex<Bool>(false)

        tracker.track {
            finished.withLock { $0 = true }
        }

        // Give the tracked task a chance to complete.
        await Task.yield()
        await Task.yield()

        #expect(finished.withLock { $0 })
    }

    @Test("cancelAll cancels outstanding tasks")
    @MainActor
    func cancelAllCancels() async {
        let tracker = ChildCoordinatorTaskTracker()
        let observedCancellation = Mutex<Bool>(false)

        tracker.track {
            while !Task.isCancelled {
                await Task.yield()
            }
            observedCancellation.withLock { $0 = true }
        }

        // Let the task start.
        await Task.yield()
        tracker.cancelAll()
        // Let the cancelled body observe the signal.
        await Task.yield()
        await Task.yield()

        #expect(observedCancellation.withLock { $0 })
    }

    @Test("active count drops back to zero after tracked tasks complete")
    @MainActor
    func activeCountTracks() async {
        let tracker = ChildCoordinatorTaskTracker()
        #expect(tracker.activeCount == 0)

        tracker.track { await Task.yield() }
        tracker.track { await Task.yield() }
        #expect(tracker.activeCount == 2)

        // Drain scheduler.
        for _ in 0..<5 { await Task.yield() }

        #expect(tracker.activeCount == 0)
    }
}
