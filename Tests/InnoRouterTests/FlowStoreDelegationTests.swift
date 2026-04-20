// MARK: - FlowStoreDelegationTests.swift
// InnoRouterTests - FlowStore delegation to inner navigation/modal stores
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
@testable import InnoRouterSwiftUI

private enum FlowDelegationRoute: Route {
    case home
    case detail
    case share
    case paywall
}

@Suite("FlowStore Delegation Tests")
struct FlowStoreDelegationTests {

    @Test("push delegates to navigation store and updates state")
    @MainActor
    func pushDelegatesToNavigation() {
        let store = FlowStore<FlowDelegationRoute>()

        store.send(.push(.home))
        store.send(.push(.detail))

        #expect(store.navigationStore.state.path == [.home, .detail])
        #expect(store.path == [.push(.home), .push(.detail)])
    }

    @Test("presentSheet delegates to modal store with sheet style")
    @MainActor
    func presentSheetDelegatesToModal() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.share))

        #expect(store.modalStore.currentPresentation?.route == .share)
        #expect(store.modalStore.currentPresentation?.style == .sheet)
        #expect(store.path.last == .sheet(.share))
    }

    @Test("presentCover delegates to modal store with fullScreenCover style")
    @MainActor
    func presentCoverDelegatesToModal() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.presentCover(.paywall))

        #expect(store.modalStore.currentPresentation?.style == .fullScreenCover)
        #expect(store.path == [.cover(.paywall)])
    }

    @Test("modal middleware rewrite updates flow path to committed presentation style")
    @MainActor
    func modalRewriteProjectsCommittedStyle() {
        let middleware = AnyModalMiddleware<FlowDelegationRoute>(
            willExecute: { command, _, _ in
                if case .present(let presentation) = command, presentation.style == .sheet {
                    return .proceed(
                        .present(
                            ModalPresentation(
                                id: presentation.id,
                                route: presentation.route,
                                style: .fullScreenCover
                            )
                        )
                    )
                }
                return .proceed(command)
            }
        )
        let store = FlowStore<FlowDelegationRoute>(
            configuration: .init(
                modal: .init(middlewares: [.init(middleware: middleware)])
            )
        )

        store.send(.presentSheet(.share))

        #expect(store.modalStore.currentPresentation?.style == .fullScreenCover)
        #expect(store.path == [.cover(.share)])
    }

    @Test("pop delegates to navigation and trims path tail")
    @MainActor
    func popDelegatesToNavigation() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.push(.home))
        store.send(.push(.detail))
        store.send(.pop)

        #expect(store.navigationStore.state.path == [.home])
        #expect(store.path == [.push(.home)])
    }

    @Test("dismiss delegates to modal store and trims modal tail")
    @MainActor
    func dismissDelegatesToModal() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.share))
        store.send(.dismiss)

        #expect(store.modalStore.currentPresentation == nil)
        #expect(store.path == [.push(.home)])
    }

    @Test("dismiss keeps promoted queued modal as new path tail")
    @MainActor
    func dismissKeepsPromotedQueuedModalTail() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.share))
        store.send(.presentSheet(.paywall))

        store.send(.dismiss)

        #expect(store.modalStore.currentPresentation?.route == .paywall)
        #expect(store.modalStore.currentPresentation?.style == .sheet)
        #expect(store.path == [.push(.home), .sheet(.paywall)])
    }

    @Test("reset replaces navigation prefix and applies modal tail")
    @MainActor
    func resetReplacesStacksAndPresentsModal() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.push(.home))
        store.send(.push(.detail))

        store.send(.reset([.push(.home), .sheet(.share)]))

        #expect(store.navigationStore.state.path == [.home])
        #expect(store.modalStore.currentPresentation?.route == .share)
        #expect(store.path == [.push(.home), .sheet(.share)])
    }

    @Test("navigation middleware rewrite updates flow path to committed stack")
    @MainActor
    func navigationRewriteProjectsCommittedStack() {
        let middleware = AnyNavigationMiddleware<FlowDelegationRoute>(
            willExecute: { command, _ in
                if case .push(.detail) = command {
                    return .proceed(.replace([.home, .paywall]))
                }
                return .proceed(command)
            }
        )
        let store = FlowStore<FlowDelegationRoute>(
            configuration: .init(
                navigation: .init(middlewares: [.init(middleware: middleware)])
            )
        )

        store.send(.push(.detail))

        #expect(store.navigationStore.state.path == [.home, .paywall])
        #expect(store.path == [.push(.home), .push(.paywall)])
    }

    @Test("inner navigation onChange still fires when caller supplies a hook")
    @MainActor
    func userNavOnChangeStillFires() {
        let changes = Mutex<Int>(0)
        let config = FlowStoreConfiguration<FlowDelegationRoute>(
            navigation: .init(
                onChange: { _, _ in changes.withLock { $0 += 1 } }
            )
        )
        let store = FlowStore<FlowDelegationRoute>(configuration: config)

        store.send(.push(.home))
        store.send(.push(.detail))

        #expect(changes.withLock { $0 } == 2)
    }

    @Test("inner modal onPresented still fires when caller supplies a hook")
    @MainActor
    func userModalOnPresentedStillFires() {
        let presented = Mutex<[FlowDelegationRoute]>([])
        let config = FlowStoreConfiguration<FlowDelegationRoute>(
            modal: .init(
                onPresented: { presentation in
                    presented.withLock { $0.append(presentation.route) }
                }
            )
        )
        let store = FlowStore<FlowDelegationRoute>(configuration: config)

        store.send(.presentSheet(.share))

        #expect(presented.withLock { $0 } == [.share])
    }
}
