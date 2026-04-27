// MARK: - ModalEnvironmentStorageTests.swift
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

// MARK: - ModalEnvironmentStorage Tests

@Suite("ModalEnvironmentStorage Tests")
struct ModalEnvironmentStorageTests {
    @Test("Manual modal dispatcher single registration presents and dismisses through send")
    @MainActor
    func testManualModalDispatcherSingleRegistration() {
        let store = ModalStore<TestModalRoute>()
        let storage = ModalEnvironmentStorage()
        storage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            store.send(intent)
        }

        guard let dispatcher = storage[TestModalRoute.self] else {
            Issue.record("Expected modal dispatcher")
            return
        }

        dispatcher.send(.present(.profile, style: .sheet))
        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .sheet)

        dispatcher.send(.dismiss)
        #expect(store.currentPresentation == nil)
    }

    @Test("ModalEnvironmentStorage accepts stable-owner dispatcher refreshes")
    @MainActor
    func testModalEnvironmentStorageStableOwnerRefresh() {
        let store = ModalStore<TestModalRoute>()
        let storage = ModalEnvironmentStorage()
        let ownerID = ObjectIdentifier(store)

        storage.setIntentDispatcher(
            AnyModalIntentDispatcher { store.send($0) },
            ownerID: ownerID,
            routeType: TestModalRoute.self
        )
        storage.setIntentDispatcher(
            AnyModalIntentDispatcher { store.send($0) },
            ownerID: ownerID,
            routeType: TestModalRoute.self
        )

        storage[TestModalRoute.self]?.send(.present(.profile, style: .sheet))

        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .sheet)
    }

    @Test("Multiple modal host storages keep intent dispatch isolated")
    @MainActor
    func testModalEnvironmentStorageIsolationBetweenHosts() {
        let firstStore = ModalStore<TestModalRoute>()
        let secondStore = ModalStore<TestModalRoute>()
        let firstStorage = ModalEnvironmentStorage()
        let secondStorage = ModalEnvironmentStorage()

        firstStorage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            firstStore.send(intent)
        }
        secondStorage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            secondStore.send(intent)
        }

        guard let firstDispatcher = firstStorage[TestModalRoute.self] else {
            Issue.record("Expected first modal dispatcher")
            return
        }

        firstDispatcher.send(.present(.profile, style: .sheet))

        #expect(firstStore.currentPresentation?.route == .profile)
        #expect(secondStore.currentPresentation == nil)
    }

    @Test("ModalHost body can be constructed around NavigationHost")
    @MainActor
    func testModalHostConstructionWithNavigationHost() {
        let navigationStore = NavigationStore<TestRoute>()
        let modalStore = ModalStore<TestModalRoute>()
        let host = ModalHost(store: modalStore) { route in
            switch route {
            case .profile:
                Text("Profile")
            case .onboarding:
                Text("Onboarding")
            }
        } content: {
            NavigationHost(store: navigationStore) { _ in
                Text("Destination")
            } root: {
                Text("Root")
            }
        }

        _ = host.body
        navigationStore.send(.go(.settings))
        modalStore.send(.present(.profile, style: .sheet))

        #expect(navigationStore.state.path == [.settings])
        #expect(modalStore.currentPresentation?.route == .profile)
    }
}
