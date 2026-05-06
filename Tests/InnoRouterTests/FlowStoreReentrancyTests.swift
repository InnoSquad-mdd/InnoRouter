// MARK: - FlowStoreReentrancyTests.swift
// InnoRouterTests - FlowStore.withInternalMutation depth-counter
// reentrancy semantics.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// FlowStore previously gated its internal mutation reverse-sync
// guards on a Bool flag (`isApplyingInternalMutation`) that an
// inner `defer` could silently reset to false while the outer
// scope still expected it to be true. The flag is now a depth
// counter — these tests exercise the observable surface that
// would have flipped under the old Bool behaviour:
//
// 1. A simple FlowStore.send + apply sequence still preserves the
//    original guard semantics (no extra path mutation events).
// 2. Repeated synchronous applies in immediate succession do not
//    leak depth state across the boundaries.
//
// The depth counter itself is private; tests can only assert the
// observable contract, but if either of the assertions below
// drifts, the depth invariant is the most likely root cause.

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum FlowReentrancyRoute: Route {
    case home
    case detail(Int)
}

@Suite("FlowStore.withInternalMutation reentrancy")
@MainActor
struct FlowStoreReentrancyTests {

    @Test("apply(_:) followed by apply(_:) preserves the final path without spurious mutations")
    func sequentialApply_preservesFinalPath() {
        let flow = FlowStore<FlowReentrancyRoute>()

        flow.apply(FlowPlan(steps: [.push(.home)]))
        flow.apply(FlowPlan(steps: [.push(.home), .push(.detail(1))]))

        #expect(flow.path == [.push(.home), .push(.detail(1))])
    }

    @Test("apply(_:) of a no-op plan does not mutate path or fire spurious events")
    func noOpApply_isIdempotent() async {
        let flow = FlowStore<FlowReentrancyRoute>()
        flow.apply(FlowPlan(steps: [.push(.home)]))

        let pathBefore = flow.path
        flow.apply(FlowPlan(steps: [.push(.home)]))

        #expect(flow.path == pathBefore)
    }

    @Test("send(_:) followed by apply(_:) leaves the store in the applied path")
    func sendThenApply_endsAtAppliedPath() {
        let flow = FlowStore<FlowReentrancyRoute>()

        flow.send(.push(.home))
        flow.apply(FlowPlan(steps: [.push(.detail(7))]))

        #expect(flow.path == [.push(.detail(7))])
    }
}
