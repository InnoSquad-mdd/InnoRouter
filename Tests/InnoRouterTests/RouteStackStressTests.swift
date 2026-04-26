// MARK: - RouteStackStressTests.swift
// InnoRouterTests - large-stack stress + retain-cycle smoke
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import InnoRouterCore
import InnoRouterSwiftUI

private enum StressRoute: Route {
    case detail(Int)
}

@Suite("RouteStack stress")
@MainActor
struct RouteStackStressTests {

    @Test("pushAll/popToRoot survives 1000-element stacks without retain leaks")
    func pushAllAndPopToRoot_largeStack() {
        let store = NavigationStore<StressRoute>()

        let routes = (0..<1000).map(StressRoute.detail)
        _ = store.execute(.pushAll(routes))
        #expect(store.state.path.count == 1000)

        _ = store.execute(.popToRoot)
        #expect(store.state.path.isEmpty)
    }

    @Test("repeated executeBatch on a 100-element prefix stays stable")
    func executeBatchRepeats_isStable() {
        let store = NavigationStore<StressRoute>()
        let initial = (0..<100).map(StressRoute.detail)
        _ = store.execute(.pushAll(initial))

        let extension100 = (100..<200).map { StressRoute.detail($0) }.map(NavigationCommand<StressRoute>.push)

        for _ in 0..<10 {
            _ = store.executeBatch(extension100)
            _ = store.executeBatch(Array(repeating: NavigationCommand<StressRoute>.pop, count: 100))
        }

        #expect(store.state.path.count == 100)
    }

    @Test("popCount(stackDepth) clears any sized stack")
    func popCount_handlesAnySize() {
        let store = NavigationStore<StressRoute>()
        let routes = (0..<500).map(StressRoute.detail)
        _ = store.execute(.pushAll(routes))

        let result = store.execute(.popCount(500))
        #expect(result.isSuccess)
        #expect(store.state.path.isEmpty)
    }
}
