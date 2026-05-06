// MARK: - FlowStateReadingTests.swift
// InnoRouterTests - non-SPI FlowStateReading projection
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum ReadingRoute: Route {
    case home
    case detail(Int)
    case settings
}

@Suite("FlowStateReading projection")
@MainActor
struct FlowStateReadingTests {

    @Test("empty FlowStore exposes empty navigationPath and nil modal")
    func empty_projection() {
        let flow = FlowStore<ReadingRoute>()

        #expect(flow.path.isEmpty)
        #expect(flow.navigationPath.isEmpty)
        #expect(flow.currentModalRoute == nil)
    }

    @Test("push-only path projects to navigationPath without a modal route")
    func pushOnly_projection() {
        let flow = FlowStore<ReadingRoute>()
        flow.apply(FlowPlan(steps: [.push(.home), .push(.detail(1))]))

        #expect(flow.navigationPath == [.home, .detail(1)])
        #expect(flow.currentModalRoute == nil)
    }

    @Test("trailing sheet step projects to currentModalRoute")
    func sheetTail_projection() {
        let flow = FlowStore<ReadingRoute>()
        flow.apply(FlowPlan(steps: [.push(.home), .sheet(.settings)]))

        #expect(flow.navigationPath == [.home])
        #expect(flow.currentModalRoute == .settings)
    }

    @Test("trailing cover step also projects to currentModalRoute")
    func coverTail_projection() {
        let flow = FlowStore<ReadingRoute>()
        flow.apply(FlowPlan(steps: [.push(.home), .cover(.detail(2))]))

        #expect(flow.navigationPath == [.home])
        #expect(flow.currentModalRoute == .detail(2))
    }

    @Test("FlowStateReading existential lets generic helpers read flow state")
    func existential_canBeUsedAsParameter() {
        let flow = FlowStore<ReadingRoute>()
        flow.apply(FlowPlan(steps: [.push(.home)]))

        let reading: any FlowStateReading<ReadingRoute> = flow

        #expect(reading.navigationPath == [.home])
        #expect(reading.currentModalRoute == nil)
    }
}
