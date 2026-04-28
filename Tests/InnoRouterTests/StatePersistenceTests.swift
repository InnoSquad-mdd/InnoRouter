// MARK: - StatePersistenceTests.swift
// InnoRouterTests - StatePersistence Data <-> value round-trips
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterCore
@_spi(FlowStoreInternals) @testable import InnoRouterSwiftUI

private enum PersistRoute: String, Route, Codable {
    case root
    case profile
    case settings
    case onboarding
}

@Suite("StatePersistence Tests")
struct StatePersistenceTests {

    @Test("FlowPlan round-trips through StatePersistence")
    func flowPlanRoundTrip() throws {
        let persistence = StatePersistence<PersistRoute>()
        let original = FlowPlan<PersistRoute>(steps: [
            .push(.root),
            .push(.profile),
            .sheet(.settings),
        ])

        let data = try persistence.encode(original)
        let restored = try persistence.decode(data)

        #expect(restored == original)
    }

    @Test("RouteStack round-trips through StatePersistence")
    func routeStackRoundTrip() throws {
        let persistence = StatePersistence<PersistRoute>()
        let original = try RouteStack<PersistRoute>(validating: [.root, .profile])

        let data = try persistence.encode(original)
        let restored = try persistence.decodeStack(data)

        #expect(restored == original)
    }

    @Test("Empty FlowPlan round-trips without side effects")
    func emptyFlowPlanRoundTrip() throws {
        let persistence = StatePersistence<PersistRoute>()

        let data = try persistence.encode(FlowPlan<PersistRoute>())
        let restored = try persistence.decode(data)

        #expect(restored.steps.isEmpty)
    }

    @Test("FlowStore.apply(decoded) reproduces the original path")
    @MainActor
    func flowStoreApplyAfterDecodeReproducesPath() throws {
        let persistence = StatePersistence<PersistRoute>()
        let original = FlowPlan<PersistRoute>(steps: [
            .push(.root),
            .push(.profile),
            .sheet(.onboarding),
        ])

        let data = try persistence.encode(original)
        let restored = try persistence.decode(data)

        let store = FlowStore<PersistRoute>()
        store.apply(restored)

        #expect(store.path == original.steps)
        #expect(store.navigationStore.state.path == [.root, .profile])
        #expect(store.modalStore.currentPresentation?.route == .onboarding)
    }

    @Test("Malformed JSON surfaces as DecodingError")
    func malformedJSONThrowsDecodingError() {
        let persistence = StatePersistence<PersistRoute>()
        let garbage = Data("not json".utf8)

        #expect(throws: DecodingError.self) {
            _ = try persistence.decode(garbage)
        }
    }

    @Test("Custom encoder configuration is preserved (sortedKeys)")
    func customEncoderConfigurationIsPreserved() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let persistence = StatePersistence<PersistRoute>(encoder: encoder)
        let plan = FlowPlan<PersistRoute>(steps: [.push(.root), .sheet(.settings)])

        let data1 = try persistence.encode(plan)
        let data2 = try persistence.encode(plan)

        // Sorted keys => byte-deterministic output for identical inputs.
        #expect(data1 == data2)
    }
}
