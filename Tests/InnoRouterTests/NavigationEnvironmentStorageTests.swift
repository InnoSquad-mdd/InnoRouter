// MARK: - NavigationEnvironmentStorageTests.swift
// InnoRouter Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import Foundation
import Observation
import OSLog
import Synchronization
import SwiftUI
import InnoRouter
import InnoRouterEffects
@testable import InnoRouterSwiftUI

// MARK: - NavigationEnvironmentStorage Tests

@Suite("NavigationEnvironmentStorage Tests")
struct NavigationEnvironmentStorageTests {
    @Test("Multiple host storages keep intent dispatch isolated")
    @MainActor
    func testNavigationEnvironmentStorageIsolationBetweenHosts() {
        let firstStore = NavigationStore<TestRoute>()
        let secondStore = NavigationStore<TestRoute>()
        let firstStorage = NavigationEnvironmentStorage()
        let secondStorage = NavigationEnvironmentStorage()

        firstStorage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            firstStore.send(intent)
        }
        secondStorage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            secondStore.send(intent)
        }

        guard let firstDispatcher = firstStorage[TestRoute.self] else {
            Issue.record("Expected first dispatcher")
            return
        }
        firstDispatcher.send(.go(.home))

        #expect(firstStore.state.path == [.home])
        #expect(secondStore.state.path.isEmpty)
    }

    @Test("NavigationHost-style dispatcher pushes route through send")
    @MainActor
    func testNavigationHostStyleDispatcher() {
        let store = NavigationStore<TestRoute>()
        let storage = NavigationEnvironmentStorage()
        storage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            store.send(intent)
        }

        guard let dispatcher = storage[TestRoute.self] else {
            Issue.record("Expected dispatcher")
            return
        }
        dispatcher.send(.go(.detail(id: "123")))

        #expect(store.state.path == [.detail(id: "123")])
    }

    // MARK: - Platform: NavigationSplitHost is unavailable on watchOS
    // because SwiftUI's NavigationSplitView is unavailable there. The
    // construction smoke test is gated to match.
    #if !os(watchOS)
    @Test("NavigationSplitHost body can be constructed")
    @MainActor
    func testNavigationSplitHostConstruction() {
        let store = NavigationStore<TestRoute>()
        let host = NavigationSplitHost(store: store) {
            Text("Sidebar")
        } destination: { _ in
            Text("Destination")
        } root: {
            Text("Root")
        }

        _ = host.body
        store.send(.go(.settings))

        #expect(store.state.path == [.settings])
    }
    #endif
}
