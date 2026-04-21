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

        let task = tracker.track {
            finished.withLock { $0 = true }
        }

        await task.value
        #expect(finished.withLock { $0 })
    }

    @Test("cancelAll cancels outstanding tasks")
    @MainActor
    func cancelAllCancels() async {
        let tracker = ChildCoordinatorTaskTracker()
        let observedCancellation = Mutex<Bool>(false)

        let task = tracker.track {
            while !Task.isCancelled {
                await Task.yield()
            }
            observedCancellation.withLock { $0 = true }
        }

        tracker.cancelAll()
        await task.value
        #expect(observedCancellation.withLock { $0 })
    }

    @Test("active count drops back to zero after tracked tasks complete")
    @MainActor
    func activeCountTracks() async {
        let tracker = ChildCoordinatorTaskTracker()
        #expect(tracker.activeCount == 0)

        let first = tracker.track { await Task.yield() }
        let second = tracker.track { await Task.yield() }
        #expect(tracker.activeCount == 2)

        await first.value
        await second.value
        #expect(tracker.activeCount == 0)
    }
}
