// MARK: - FlowStorePropertyBasedTests.swift
// InnoRouterTests - seed-parameterised invariants on FlowStore
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterSwiftUI

@Suite("FlowStore property-based tests")
struct FlowStorePropertyBasedTests {

    @Test(
        "Random FlowIntent streams preserve invariants and match the reference model",
        arguments: Array(0..<100)
    )
    @MainActor
    func randomIntentStreamsMatchModel(seed: Int) async {
        let store = FlowStore<PropertyRoute>()
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        await runFlowStoreModelComparison(
            seed: seed,
            stepCount: 25,
            store: store,
            recorder: recorder
        ) { model, intent in
            model.apply(intent)
        }
    }

    @Test(
        "Deterministic middleware cancel/rewrite policies keep FlowStore aligned with the reference model",
        arguments: Array(0..<48)
    )
    @MainActor
    func middlewareMatrixMatchesModel(seed: Int) async {
        let policy = PropertyMiddlewarePolicy(seed: seed)
        let store = FlowStore<PropertyRoute>(
            configuration: FlowStoreConfiguration(
                navigation: NavigationStoreConfiguration(
                    middlewares: [policy.navigationRegistration()]
                ),
                modal: ModalStoreConfiguration(
                    middlewares: [policy.modalRegistration()]
                ),
                // The reference model in this suite predates the 4.0
                // `.dropQueued` default and assumes the modal queue
                // outlives a cancelled navigation prefix. Pin the
                // pre-4.0 behaviour so the property-based comparison
                // stays valid; a separate suite exercises the new
                // default explicitly.
                queueCoalescePolicy: .preserve
            )
        )
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        await runFlowStoreModelComparison(
            seed: seed,
            stepCount: 20,
            store: store,
            recorder: recorder
        ) { model, intent in
            model.apply(intent, middlewarePolicy: policy)
        }
    }

    @Test(
        "Multi-middleware nav/modal chains preserve FlowStore invariants and match the reference model",
        arguments: Array(0..<32)
    )
    @MainActor
    func middlewareChainMatchesModel(seed: Int) async {
        let policy = PropertyMiddlewareChainPolicy(seed: seed)
        let store = FlowStore<PropertyRoute>(
            configuration: FlowStoreConfiguration(
                navigation: NavigationStoreConfiguration(
                    middlewares: policy.navigationRegistrations()
                ),
                modal: ModalStoreConfiguration(
                    middlewares: policy.modalRegistrations()
                ),
                queueCoalescePolicy: .preserve
            )
        )
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        await runFlowStoreModelComparison(
            seed: seed,
            stepCount: 20,
            store: store,
            recorder: recorder
        ) { model, intent in
            model.apply(intent, middlewarePolicy: policy)
        }
    }
}
