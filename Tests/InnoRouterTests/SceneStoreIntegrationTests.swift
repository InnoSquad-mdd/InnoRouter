// MARK: - SceneStoreIntegrationTests.swift
// Integration coverage for the three visionOS SceneStore hardening
// paths. Exercises SceneStore + SceneDispatchDriver end-to-end via
// mocked environment closures, without requiring a live SwiftUI view
// hierarchy. Scene types are #if os(visionOS), so this test file is
// similarly gated and runs on the visionOS CI leg.
// Copyright © 2026 Inno Squad. All rights reserved.

#if os(visionOS)

import Foundation
import SwiftUI
import Testing

@testable import InnoRouterSwiftUI
import InnoRouterCore

private enum SpatialRoute: String, Route {
    case main
    case theatre
}

private func makeRegistry() -> SceneRegistry<SpatialRoute> {
    SceneRegistry(
        .window(.main, id: "main"),
        .immersive(.theatre, id: "theatre", style: .mixed)
    )
}

/// Collects the first event matching `predicate` or returns nil after
/// `timeout` seconds. Used to assert that a specific rejection or
/// registration event reaches subscribers.
@MainActor
private func collectEvent<R: Route>(
    from store: SceneStore<R>,
    timeoutSeconds: Double = 2.0,
    where predicate: @escaping @Sendable (SceneEvent<R>) -> Bool
) async -> SceneEvent<R>? {
    let events = store.events
    let deadlineNanoseconds = UInt64(timeoutSeconds * 1_000_000_000)

    return await withTaskGroup(of: SceneEvent<R>?.self) { group in
        group.addTask { @MainActor in
            for await event in events {
                if predicate(event) {
                    return event
                }
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: deadlineNanoseconds)
            return nil
        }

        let first = await group.next() ?? nil
        group.cancelAll()
        return first ?? nil
    }
}

@Suite("SceneStore integration tests", .tags(.integration))
struct SceneStoreIntegrationTests {

    // MARK: - Hardening path 1: fallback anchor cannot dispatch cross-scene opens

    @Test("Fallback anchor rejects cross-scene open with .fallbackCannotDispatch")
    @MainActor
    func fallbackAnchorRejectsCrossSceneOpen() async {
        let store = SceneStore<SpatialRoute>()
        let scenes = makeRegistry()

        // Only a fallback anchor is registered. It is attached to
        // `.theatre`, so a pending `openWindow(.main)` must be refused.
        let anchorToken = UUID()
        store.registerFallbackDispatcher(anchorToken)

        store.openWindow(.main)

        let driver = SceneDispatchDriver<SpatialRoute>(
            store: store,
            scenes: scenes,
            dispatcherToken: anchorToken,
            capability: .fallbackAnchor(
                attachedTo: scenes.declaration(for: .theatre)!.presentation
            ),
            openWindow: { _ in
                Issue.record("openWindow must not be called on a cross-scene fallback dispatch")
            },
            openImmersiveSpace: { _ in
                Issue.record("openImmersiveSpace must not be called")
                return .userCancelled
            },
            dismissImmersiveSpace: {
                Issue.record("dismissImmersiveSpace must not be called")
            },
            dismissWindow: { _ in
                Issue.record("dismissWindow must not be called")
            }
        )

        let collectTask = Task { @MainActor in
            await collectEvent(from: store) { event in
                if case .rejected(_, .fallbackCannotDispatch) = event {
                    return true
                }
                return false
            }
        }

        await driver.run()
        let collected = await collectTask.value

        #expect(collected != nil)
        if case .rejected(let intent, .fallbackCannotDispatch)? = collected {
            #expect(intent == .open(.window(.main)))
        }
        #expect(store.currentScene == nil)
    }

    // MARK: - Hardening path 2: duplicate SceneHost registration does not crash

    @Test("Duplicate SceneHost registration is recoverable and broadcasts .duplicateHostRegistration")
    @MainActor
    func duplicateHostRegistrationIsRecoverable() async {
        let store = SceneStore<SpatialRoute>()

        let collectTask = Task { @MainActor in
            await collectEvent(from: store) { event in
                if case .hostRegistrationRejected(.duplicateHostRegistration) = event {
                    return true
                }
                return false
            }
        }

        let firstToken = UUID()
        let secondToken = UUID()

        let firstRegistered = store.registerDispatcherHost(firstToken)
        let secondRegistered = store.registerDispatcherHost(secondToken)

        #expect(firstRegistered == true)
        #expect(secondRegistered == false)

        let collected = await collectTask.value
        #expect(collected != nil)
    }

    // MARK: - Hardening path 3: dispatch Task cancellation abandons the claim

    @Test("Cancelling the dispatch task abandons the claim with .hostTornDownDuringDispatch")
    @MainActor
    func dispatchTaskCancellationAbandonsClaim() async {
        let store = SceneStore<SpatialRoute>()
        let scenes = makeRegistry()

        let hostToken = UUID()
        _ = store.registerDispatcherHost(hostToken)

        store.openImmersive(.theatre, style: .mixed)

        let driver = SceneDispatchDriver<SpatialRoute>(
            store: store,
            scenes: scenes,
            dispatcherToken: hostToken,
            capability: .primaryHost,
            openWindow: { _ in
                Issue.record("openWindow must not be called in the immersive path")
            },
            openImmersiveSpace: { _ in
                // Block long enough that the outer test can cancel the
                // driver's Task while we are still awaiting. Task.sleep
                // is cancellation-aware — on cancel it throws and the
                // `try?` converts it to nil so the closure returns.
                try? await Task.sleep(nanoseconds: 500_000_000)
                return .opened
            },
            dismissImmersiveSpace: {},
            dismissWindow: { _ in }
        )

        let collectTask = Task { @MainActor in
            await collectEvent(from: store) { event in
                if case .rejected(_, .hostTornDownDuringDispatch) = event {
                    return true
                }
                return false
            }
        }

        let driverTask = Task { @MainActor in
            await driver.run()
        }

        // Let the driver reach the await inside openImmersiveSpace
        // before cancelling.
        try? await Task.sleep(nanoseconds: 50_000_000)
        driverTask.cancel()

        _ = await driverTask.value
        let collected = await collectTask.value

        #expect(collected != nil)
        if case .rejected(let intent, .hostTornDownDuringDispatch)? = collected {
            #expect(intent == .open(.immersive(.theatre, style: .mixed)))
        }
        #expect(store.currentScene == nil)
    }
}

#endif
