// MARK: - FlowStorePropertyBasedTests.swift
// InnoRouterTests - seed-parameterised invariants on FlowStore
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterSwiftUI

@MainActor
private func randomFlowIntent(
    rng: inout PropertyPBTGenerator
) -> FlowIntent<PropertyRoute> {
    let route = rng.nextRoute()
    switch rng.nextInt(upperBound: 100) {
    case 0..<18:
        return .push(route)
    case 18..<32:
        return .presentSheet(route)
    case 32..<42:
        return .presentCover(route)
    case 42..<54:
        return .pop
    case 54..<64:
        return .dismiss
    case 64..<76:
        return .reset(rng.nextFlowSteps())
    case 76..<84:
        return .replaceStack(rng.nextRoutes(maxCount: 3))
    case 84..<90:
        return .backOrPush(route)
    case 90..<95:
        return .pushUniqueRoot(route)
    case 95..<98:
        return .backOrPushDismissingModal(route)
    default:
        return .pushUniqueRootDismissingModal(route)
    }
}

@Suite("FlowStore property-based tests")
struct FlowStorePropertyBasedTests {

    @Test(
        "Random FlowIntent streams preserve invariants and match the reference model",
        arguments: Array(0..<100)
    )
    @MainActor
    func randomIntentStreamsMatchModel(seed: Int) async {
        var rng = PropertyPBTGenerator(seed: seed)
        let store = FlowStore<PropertyRoute>()
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        var model = FlowModelState()

        for step in 0..<25 {
            let intent = randomFlowIntent(rng: &rng)
            let marker = recorder.mark()

            let expectation = model.apply(intent)
            store.send(intent)

            let events = (
                await recorder.rawEvents(
                    since: marker,
                    minimumCount: minimumExpectedFlowEventCount(expectation)
                )
            ).compactMap(normalizeFlowEvent)

            assertFlowStoreMatchesModel(
                store: store,
                model: model,
                seed: seed,
                step: step
            )
            assertFlowEventContract(
                events,
                expectation: expectation,
                seed: seed,
                step: step
            )
        }
    }

    @Test(
        "Deterministic middleware cancel/rewrite policies keep FlowStore aligned with the reference model",
        arguments: Array(0..<48)
    )
    @MainActor
    func middlewareMatrixMatchesModel(seed: Int) async {
        var rng = PropertyPBTGenerator(seed: seed)
        let policy = PropertyMiddlewarePolicy(seed: seed)
        let store = FlowStore<PropertyRoute>(
            configuration: FlowStoreConfiguration(
                navigation: NavigationStoreConfiguration(
                    middlewares: [policy.navigationRegistration()]
                ),
                modal: ModalStoreConfiguration(
                    middlewares: [policy.modalRegistration()]
                )
            )
        )
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        var model = FlowModelState()

        for step in 0..<20 {
            let intent = randomFlowIntent(rng: &rng)
            let marker = recorder.mark()

            let expectation = model.apply(intent, middlewarePolicy: policy)
            store.send(intent)

            let events = (
                await recorder.rawEvents(
                    since: marker,
                    minimumCount: minimumExpectedFlowEventCount(expectation)
                )
            ).compactMap(normalizeFlowEvent)

            assertFlowStoreMatchesModel(
                store: store,
                model: model,
                seed: seed,
                step: step
            )
            assertFlowEventContract(
                events,
                expectation: expectation,
                seed: seed,
                step: step
            )
        }
    }

    @Test(
        "Multi-middleware nav/modal chains preserve FlowStore invariants and match the reference model",
        arguments: Array(0..<32)
    )
    @MainActor
    func middlewareChainMatchesModel(seed: Int) async {
        var rng = PropertyPBTGenerator(seed: seed)
        let policy = PropertyMiddlewareChainPolicy(seed: seed)
        let store = FlowStore<PropertyRoute>(
            configuration: FlowStoreConfiguration(
                navigation: NavigationStoreConfiguration(
                    middlewares: policy.navigationRegistrations()
                ),
                modal: ModalStoreConfiguration(
                    middlewares: policy.modalRegistrations()
                )
            )
        )
        let recorder = FlowEventRecorder(store: store)
        defer { recorder.cancel() }

        var model = FlowModelState()

        for step in 0..<20 {
            let intent = randomFlowIntent(rng: &rng)
            let marker = recorder.mark()

            let expectation = model.apply(intent, middlewarePolicy: policy)
            store.send(intent)

            let events = (
                await recorder.rawEvents(
                    since: marker,
                    minimumCount: minimumExpectedFlowEventCount(expectation)
                )
            ).compactMap(normalizeFlowEvent)

            assertFlowStoreMatchesModel(
                store: store,
                model: model,
                seed: seed,
                step: step
            )
            assertFlowEventContract(
                events,
                expectation: expectation,
                seed: seed,
                step: step
            )
        }
    }
}
