// MARK: - FlowHostCompositionTests.swift
// InnoRouterTests - FlowHost composition and environment dispatcher injection
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import SwiftUI
import InnoRouter
@_spi(FlowStoreInternals) @testable import InnoRouterSwiftUI

private enum FlowHostRoute: Route {
    case landing
    case child
    case sheetChild
}

@Suite("FlowHost Composition Tests")
struct FlowHostCompositionTests {

    @Test("FlowHost body can be constructed over NavigationHost + ModalHost")
    @MainActor
    func flowHostConstructs() {
        let store = FlowStore<FlowHostRoute>()
        let host = FlowHost(
            store: store,
            destination: { _ in EmptyView() },
            root: { EmptyView() }
        )
        _ = host.body
    }

    @Test("FlowStore intentDispatcher is cached and forwards flow intents")
    @MainActor
    func flowStoreIntentDispatcherIsCachedAndForwardsIntents() {
        let store = FlowStore<FlowHostRoute>()
        let dispatcher = store.intentDispatcher
        let secondRead = store.intentDispatcher

        #expect(dispatcher === secondRead)

        dispatcher.send(.push(.landing))
        dispatcher.send(.push(.child))
        dispatcher.send(.presentSheet(.sheetChild))

        #expect(store.path == [.push(.landing), .push(.child), .sheet(.sheetChild)])
        #expect(store.modalStore.currentPresentation?.route == .sheetChild)
    }

    @Test("FlowEnvironmentStorage isolates dispatchers across hosts")
    @MainActor
    func flowEnvironmentStorageIsolatesDispatchers() {
        let firstStore = FlowStore<FlowHostRoute>()
        let secondStore = FlowStore<FlowHostRoute>()
        let firstStorage = FlowEnvironmentStorage()
        let secondStorage = FlowEnvironmentStorage()

        firstStorage[FlowHostRoute.self] = AnyFlowIntentDispatcher { firstStore.send($0) }
        secondStorage[FlowHostRoute.self] = AnyFlowIntentDispatcher { secondStore.send($0) }

        firstStorage[FlowHostRoute.self]?.send(.push(.landing))
        secondStorage[FlowHostRoute.self]?.send(.push(.child))

        #expect(firstStore.path == [.push(.landing)])
        #expect(secondStore.path == [.push(.child)])
    }

    @Test("FlowEnvironmentStorage accepts same-store dispatcher refreshes")
    @MainActor
    func flowEnvironmentStorageAcceptsSameStoreDispatcherRefreshes() {
        let store = FlowStore<FlowHostRoute>()
        let storage = FlowEnvironmentStorage()
        let ownerID = ObjectIdentifier(store)

        storage.setIntentDispatcher(
            AnyFlowIntentDispatcher { store.send($0) },
            ownerID: ownerID,
            routeType: FlowHostRoute.self
        )
        storage.setIntentDispatcher(
            AnyFlowIntentDispatcher { store.send($0) },
            ownerID: ownerID,
            routeType: FlowHostRoute.self
        )

        storage[FlowHostRoute.self]?.send(.push(.landing))

        #expect(store.path == [.push(.landing)])
    }

    @Test("FlowNavigating default handle forwards to flowStore.send")
    @MainActor
    func flowNavigatingDefaultHandle() {
        final class FakeNavigator: FlowNavigating {
            typealias RouteType = FlowHostRoute
            let flowStore: FlowStore<FlowHostRoute>
            init(store: FlowStore<FlowHostRoute>) { self.flowStore = store }
        }
        let store = FlowStore<FlowHostRoute>()
        let navigator = FakeNavigator(store: store)

        navigator.handle(.push(.landing))
        navigator.handle(.presentSheet(.sheetChild))

        #expect(store.path == [.push(.landing), .sheet(.sheetChild)])
    }
}
