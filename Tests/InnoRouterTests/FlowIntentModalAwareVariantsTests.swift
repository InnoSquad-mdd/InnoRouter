// MARK: - FlowIntentModalAwareVariantsTests.swift
// InnoRouterTests - .backOrPushDismissingModal / .pushUniqueRootDismissingModal
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
@testable import InnoRouterSwiftUI

private enum MARoute: Route {
    case home
    case detail
    case settings
    case sheet
    case queuedSheet
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

    @Test(".backOrPushDismissingModal stops when a queued modal is promoted")
    @MainActor
    func backOrPushDismissingQueuedModalPromotion() throws {
        var rejections: [(FlowIntent<MARoute>, FlowRejectionReason)] = []
        let store = FlowStore<MARoute>(
            configuration: FlowStoreConfiguration(
                onIntentRejected: { intent, reason in
                    rejections.append((intent, reason))
                }
            )
        )
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))
        store.send(.presentSheet(.queuedSheet))

        store.send(.backOrPushDismissingModal(.detail))

        #expect(store.modalStore.currentPresentation?.route == .queuedSheet)
        #expect(store.modalStore.queuedPresentations.isEmpty)
        #expect(store.navigationStore.state.path == [.home])
        let rejection = try #require(rejections.first)
        #expect(rejection.0 == .backOrPushDismissingModal(.detail))
        #expect(rejection.1 == .pushBlockedByModalTail)
    }

    @Test(".pushUniqueRootDismissingModal stops when a queued modal is promoted")
    @MainActor
    func pushUniqueRootDismissingQueuedModalPromotion() throws {
        var rejections: [(FlowIntent<MARoute>, FlowRejectionReason)] = []
        let store = FlowStore<MARoute>(
            configuration: FlowStoreConfiguration(
                onIntentRejected: { intent, reason in
                    rejections.append((intent, reason))
                }
            )
        )
        store.send(.presentSheet(.sheet))
        store.send(.presentSheet(.queuedSheet))

        store.send(.pushUniqueRootDismissingModal(.home))

        #expect(store.modalStore.currentPresentation?.route == .queuedSheet)
        #expect(store.modalStore.queuedPresentations.isEmpty)
        #expect(store.navigationStore.state.path.isEmpty)
        let rejection = try #require(rejections.first)
        #expect(rejection.0 == .pushUniqueRootDismissingModal(.home))
        #expect(rejection.1 == .pushBlockedByModalTail)
    }
}
