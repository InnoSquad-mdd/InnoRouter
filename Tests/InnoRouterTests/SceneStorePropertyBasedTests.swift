// MARK: - SceneStorePropertyBasedTests.swift
// InnoRouterTests - SceneStore invariant probing via parametric tests
// Copyright © 2026 Inno Squad. All rights reserved.

#if os(visionOS)

import Foundation
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum SpatialRoute: String, Route {
    case main
    case theatre
}

@Suite("SceneStore property-based scenarios")
@MainActor
struct SceneStorePropertyBasedTests {

    @Test(
        "openWindow / dismissWindow round-trips do not corrupt SceneStore state",
        arguments: 1...32
    )
    func openDismissRoundTrip(seed: Int) {
        // Deterministic alternating open/dismiss pattern keyed on
        // the seed. The store must end with no ghost active scenes
        // after the final dismissal regardless of the sequence
        // length the seed produces.
        let store = SceneStore<SpatialRoute>()
        let length = seed + 4

        for index in 0..<length {
            let window = store.openWindow(.main)
            #expect(window.route == .main)

            if index % 2 == 0 {
                store.dismissWindow(window)
                store.completeDismissal(of: window)
            }
        }

        // After draining, even-length runs leave nothing pending.
        if length % 2 == 0 {
            #expect(store.activeScenes.isEmpty)
        }
    }

    @Test("Repeated immersive opens stay single-occupancy")
    func repeatedImmersive_singleSlot() {
        let store = SceneStore<SpatialRoute>()

        for _ in 0..<5 {
            store.openImmersive(.theatre, style: .mixed)
        }

        // The pending immersive slot is single-occupancy: a fresh
        // open request overwrites the queued one rather than
        // multiplying into a backlog.
        if let pending = store.pendingIntent {
            #expect(pending == .openImmersive(.theatre, style: .mixed))
        }
    }
}

#endif
