// MARK: - FlowIntentModalAwareVariantsTests.swift
// InnoRouterTests - .backOrPushDismissingModal / .pushUniqueRootDismissingModal
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum MARoute: Route {
    case home
    case detail
    case settings
    case sheet
}

@Suite("FlowIntent Modal-Aware Variant Tests")
struct FlowIntentModalAwareVariantsTests {

    @Test(".backOrPushDismissingModal with active modal dismisses then pops to existing route")
    @MainActor
    func backOrPushDismissingExisting() {
        let store = FlowStore<MARoute>()
        store.send(.push(.home))
        store.send(.push(.detail))
        store.send(.presentSheet(.sheet))

        store.send(.backOrPushDismissingModal(.home))

        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.navigationStore.state.path == [.home])
    }

    @Test(".backOrPushDismissingModal with active modal dismisses then pushes new route")
    @MainActor
    func backOrPushDismissingNew() {
        let store = FlowStore<MARoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))

        store.send(.backOrPushDismissingModal(.detail))

        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.navigationStore.state.path == [.home, .detail])
    }

    @Test(".backOrPushDismissingModal with no modal behaves exactly like .backOrPush")
    @MainActor
    func backOrPushDismissingNoModal() {
        let store = FlowStore<MARoute>()
        store.send(.push(.home))
        store.send(.push(.detail))

        store.send(.backOrPushDismissingModal(.home))

        #expect(store.navigationStore.state.path == [.home])
    }

    @Test(".pushUniqueRootDismissingModal dismisses modal then pushes missing route")
    @MainActor
    func pushUniqueRootDismissingNew() {
        let store = FlowStore<MARoute>()
        store.send(.presentSheet(.sheet))

        store.send(.pushUniqueRootDismissingModal(.home))

        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.navigationStore.state.path == [.home])
    }

    @Test(".pushUniqueRootDismissingModal silent no-op on stack side when route already present")
    @MainActor
    func pushUniqueRootDismissingExisting() {
        let store = FlowStore<MARoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))

        store.send(.pushUniqueRootDismissingModal(.home))

        // Modal dismissed; stack unchanged because .home already present.
        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.navigationStore.state.path == [.home])
    }
}
