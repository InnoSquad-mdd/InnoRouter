// MARK: - CoreCodableTests.swift
// InnoRouterTests - Opt-in Codable on RouteStack / RouteStep / FlowPlan
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouterCore

// Route that happens to be Codable — a plain enum with raw values.
private enum CodableRoute: String, Route, Codable {
    case home
    case detail
    case settings
}

@Suite("Core Codable Tests")
struct CoreCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("RouteStack round-trips through JSON when R is Codable")
    func routeStackRoundTrip() throws {
        let original = try RouteStack<CodableRoute>(
            validating: [.home, .detail, .settings]
        )

        let data = try encoder.encode(original)
        let restored = try decoder.decode(RouteStack<CodableRoute>.self, from: data)

        #expect(restored == original)
        #expect(restored.path == [.home, .detail, .settings])
    }

    @Test("RouteStep round-trips each case when R is Codable")
    func routeStepRoundTrip() throws {
        let cases: [RouteStep<CodableRoute>] = [
            .push(.home),
            .sheet(.detail),
            .cover(.settings),
        ]

        for step in cases {
            let data = try encoder.encode(step)
            let restored = try decoder.decode(RouteStep<CodableRoute>.self, from: data)
            #expect(restored == step)
        }
    }

    @Test("FlowPlan round-trips a mixed push + modal-tail sequence")
    func flowPlanRoundTrip() throws {
        let original = FlowPlan<CodableRoute>(steps: [
            .push(.home),
            .push(.detail),
            .sheet(.settings),
        ])

        let data = try encoder.encode(original)
        let restored = try decoder.decode(FlowPlan<CodableRoute>.self, from: data)

        #expect(restored == original)
        #expect(restored.steps.count == 3)
    }

    @Test("Empty FlowPlan round-trips cleanly")
    func emptyFlowPlanRoundTrip() throws {
        let original = FlowPlan<CodableRoute>()

        let data = try encoder.encode(original)
        let restored = try decoder.decode(FlowPlan<CodableRoute>.self, from: data)

        #expect(restored.steps.isEmpty)
    }

    @Test("Cover-tail FlowPlan round-trips without losing style")
    func coverTailFlowPlanRoundTrip() throws {
        let original = FlowPlan<CodableRoute>(steps: [
            .push(.home),
            .cover(.settings),
        ])

        let data = try encoder.encode(original)
        let restored = try decoder.decode(FlowPlan<CodableRoute>.self, from: data)

        #expect(restored == original)
        if case .cover = restored.steps.last {
            // Expected — cover case preserved.
        } else {
            Issue.record("Expected the decoded tail to remain .cover, got \(String(describing: restored.steps.last))")
        }
    }
}
