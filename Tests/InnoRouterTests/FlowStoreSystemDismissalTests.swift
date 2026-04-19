// MARK: - FlowStoreSystemDismissalTests.swift
// InnoRouterTests - FlowStore reacts to SwiftUI system dismissals
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
@testable import InnoRouterSwiftUI

private enum FlowSystemRoute: Route {
    case home
    case share
    case detail
}

@Suite("FlowStore System Dismissal Tests")
struct FlowStoreSystemDismissalTests {

    @Test("system-initiated modal dismissal trims modal tail from flow path")
    @MainActor
    func systemModalDismissalTrimsPath() {
        let store = FlowStore<FlowSystemRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.share))

        // Simulate swipe-to-dismiss triggered from SwiftUI (binding setter).
        store.modalStore.binding(for: .sheet).wrappedValue = nil

        #expect(store.path == [.push(.home)])
        #expect(store.modalStore.currentPresentation == nil)
    }

    @Test("non-system modal dismiss path does not double-remove modal tail")
    @MainActor
    func userDismissDoesNotDoublyTrim() {
        let store = FlowStore<FlowSystemRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.share))

        store.send(.dismiss)

        #expect(store.path == [.push(.home)])
        #expect(store.modalStore.currentPresentation == nil)
    }
}
