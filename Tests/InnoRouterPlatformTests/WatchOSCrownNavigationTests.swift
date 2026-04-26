// MARK: - WatchOSCrownNavigationTests.swift
// InnoRouterPlatformTests - watchOS Digital Crown navigation regression coverage
// Copyright © 2026 Inno Squad. All rights reserved.
//
// On watchOS the Digital Crown drives both list scrolling and
// `NavigationStack(value:)` traversal. From the store's perspective
// each crown-driven push is just a `.push`, but the input cadence is
// noticeably finer than touch-driven navigation, so the regression
// vector is "rapid sequence stays consistent" plus "crown-driven
// over-scroll requests leave root state unchanged via .pop".
// The focus engine and crown gestures themselves are system-owned;
// these tests pin the underlying NavigationStore semantics.

#if os(watchOS)

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum CrownRoute: Route {
    case workouts
    case workout(Int)
}

@Suite("watchOS Digital Crown navigation", .tags(.unit))
@MainActor
struct WatchOSCrownNavigationTests {

    @Test("dense crown-driven push sequence keeps state.path monotonically growing")
    func densePush_growsMonotonically() {
        let store = NavigationStore<CrownRoute>()
        _ = store.execute(.push(.workouts))

        for index in 0..<32 {
            _ = store.execute(.push(.workout(index)))
            #expect(store.state.path.count == index + 2)
        }
    }

    @Test("rapid crown back-traversal collapses the stack one step at a time")
    func rapidPop_collapsesOneStepAtATime() {
        let store = NavigationStore<CrownRoute>()
        _ = store.execute(.replace([
            .workouts,
            .workout(0),
            .workout(1),
            .workout(2),
            .workout(3),
        ]))

        for expectedDepth in (0..<4).reversed() {
            _ = store.execute(.pop)
            #expect(store.state.path.count == expectedDepth + 1)
        }
    }

    @Test("crown over-scroll past root reports emptyStack and keeps path empty")
    func overscrollPastRoot_reportsEmptyStack() {
        let store = NavigationStore<CrownRoute>()
        _ = store.execute(.push(.workouts))

        let firstPop = store.execute(.pop)
        #expect(firstPop == .success)
        #expect(store.state.path.isEmpty)

        for _ in 0..<4 {
            let result = store.execute(.pop)
            #expect(result == .emptyStack)
            #expect(store.state.path.isEmpty)
        }
    }
}

#endif
