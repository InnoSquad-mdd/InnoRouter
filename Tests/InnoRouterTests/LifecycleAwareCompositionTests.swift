// MARK: - LifecycleAwareCompositionTests.swift
// InnoRouterTests - 5.0 LifecycleAware capability composition.
// Copyright © 2026 Inno Squad. All rights reserved.

import SwiftUI
import Testing

import InnoRouterCore
import InnoRouterSwiftUI

private enum CompositionRoute: Route {
    case home
}

@MainActor
private final class OptInCoordinator: Coordinator, LifecycleAware {
    typealias RouteType = CompositionRoute
    let store = NavigationStore<CompositionRoute>()
    var lifecycleSignals: LifecycleSignals = LifecycleSignals()
    @ViewBuilder
    func destination(for route: CompositionRoute) -> some View {
        EmptyView()
    }
}

@MainActor
private final class CompositionChild: ChildCoordinator {
    typealias Result = Int
    var onFinish: (@MainActor @Sendable (Int) -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?
    var lifecycleSignals: LifecycleSignals = LifecycleSignals()
}

@Suite("LifecycleAware composition")
struct LifecycleAwareCompositionTests {

    @Test("ChildCoordinator inherits the LifecycleAware capability protocol")
    @MainActor
    func childCoordinator_isLifecycleAware() {
        let child = CompositionChild()
        let aware: any LifecycleAware = child

        // Existential is reachable; the cast that drives lifecycle
        // signal routing in the push helper is satisfied.
        #expect(aware.lifecycleSignals.onParentCancel == nil)

        var fired = 0
        aware.lifecycleSignals.onParentCancel = { fired += 1 }
        aware.lifecycleSignals.fireParentCancel()
        #expect(fired == 1)
    }

    @Test("Coordinator can opt into LifecycleAware")
    @MainActor
    func coordinator_optsIntoLifecycleAware() {
        let parent = OptInCoordinator()
        let aware: any LifecycleAware = parent

        var teardownFired = 0
        aware.lifecycleSignals.onTeardown = { teardownFired += 1 }
        aware.lifecycleSignals.fireTeardown()
        #expect(teardownFired == 1)
    }
}
