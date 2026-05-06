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
    case profile(id: String)
}

private let flowDelegationProfileCase = CasePath<FlowDelegationRoute, String>(
    embed: FlowDelegationRoute.profile(id:),
    extract: {
        if case .profile(let id) = $0 {
            return id
        }
        return nil
    }
)

@MainActor
private final class FlowDelegationRecordingReconciler<R: Route>: NavigationPathReconciling {
    var calls: [(old: [R], new: [R])] = []

    nonisolated init() {}

    func reconcile(
        from oldPath: [R],
        to newPath: [R],
        resolveMismatch: @MainActor ([R], [R]) -> NavigationPathMismatchResolution<R>,
        execute: @MainActor (NavigationCommand<R>) -> Void,
        executeBatch: @MainActor ([NavigationCommand<R>]) -> Void
    ) {
        calls.append((old: oldPath, new: newPath))
        NavigationPathReconciler<R>().reconcile(
            from: oldPath,
            to: newPath,
            resolveMismatch: resolveMismatch,
            execute: execute,
            executeBatch: executeBatch
        )
    }
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

    @Test("direct modal replacement updates flow path")
    @MainActor
    func directModalReplacementUpdatesFlowPath() {
        let changes = Mutex<[([RouteStep<FlowDelegationRoute>], [RouteStep<FlowDelegationRoute>])]>([])
        let store = FlowStore<FlowDelegationRoute>(
            configuration: .init(
                onPathChanged: { oldPath, newPath in
                    changes.withLock { $0.append((oldPath, newPath)) }
                }
            )
        )

        store.send(.presentSheet(.share))
        store.modalStore.replaceCurrent(.paywall, style: .fullScreenCover)

        #expect(store.modalStore.currentPresentation?.route == .paywall)
        #expect(store.modalStore.currentPresentation?.style == .fullScreenCover)
        #expect(store.path == [.cover(.paywall)])

        let capturedChanges = changes.withLock { $0 }
        #expect(capturedChanges.map { $0.1 } == [[.sheet(.share)], [.cover(.paywall)]])
        #expect(capturedChanges.last?.0 == [.sheet(.share)])
    }

    @Test("modal binding replacement updates associated route in flow path")
    @MainActor
    func modalBindingReplacementUpdatesFlowPath() {
        let store = FlowStore<FlowDelegationRoute>()
        store.send(.presentSheet(.profile(id: "1")))

        store.modalStore.binding(case: flowDelegationProfileCase, style: .sheet).wrappedValue = "2"

        #expect(store.modalStore.currentPresentation?.route == .profile(id: "2"))
        #expect(store.modalStore.currentPresentation?.style == .sheet)
        #expect(store.modalStore.queuedPresentations.isEmpty)
        #expect(store.path == [.sheet(.profile(id: "2"))])
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

    @Test("inner navigation onPathMismatch still fires and flow path stays in sync")
    @MainActor
    func userNavOnPathMismatchStillFires() {
        let mismatches = Mutex<[NavigationPathMismatchEvent<FlowDelegationRoute>]>([])
        let config = FlowStoreConfiguration<FlowDelegationRoute>(
            navigation: .init(
                onPathMismatch: { event in
                    mismatches.withLock { $0.append(event) }
                }
            )
        )
        let store = FlowStore<FlowDelegationRoute>(configuration: config)

        store.send(.push(.home))
        store.navigationStore.pathBinding.wrappedValue = [.detail]

        let captured = mismatches.withLock { $0 }
        #expect(captured.count == 1)
        #expect(captured.first?.oldPath == [.home])
        #expect(captured.first?.newPath == [.detail])
        #expect(store.navigationStore.state.path == [.detail])
        #expect(store.path == [.push(.detail)])
    }

    @Test("inner navigation receives FlowStoreConfiguration path reconciler")
    @MainActor
    func customPathReconcilerPropagatesToInnerNavigationStore() {
        let recorder = FlowDelegationRecordingReconciler<FlowDelegationRoute>()
        let config = FlowStoreConfiguration<FlowDelegationRoute>(
            navigation: .init(pathReconciler: recorder)
        )
        let store = FlowStore<FlowDelegationRoute>(configuration: config)

        store.send(.push(.home))
        store.navigationStore.pathBinding.wrappedValue = [.home, .detail]

        #expect(recorder.calls.count == 1)
        #expect(recorder.calls.first?.old == [.home])
        #expect(recorder.calls.first?.new == [.home, .detail])
        #expect(store.navigationStore.state.path == [.home, .detail])
        #expect(store.path == [.push(.home), .push(.detail)])
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

    @Test("inner modal receives FlowStoreConfiguration queue cancellation policy")
    @MainActor
    func queueCancellationPolicyPropagatesToInnerModalStore() {
        let gate = AnyModalMiddleware<FlowDelegationRoute>(
            willExecute: { command, _, _ in
                if case .dismissAll = command {
                    return .cancel(.middleware(debugName: "dismiss-gate", command: command))
                }
                return .proceed(command)
            }
        )
        let config = FlowStoreConfiguration<FlowDelegationRoute>(
            modal: .init(
                middlewares: [.init(middleware: gate, debugName: "dismiss-gate")],
                queueCancellationPolicy: .dropQueued
            )
        )
        let store = FlowStore<FlowDelegationRoute>(configuration: config)

        store.send(.presentSheet(.share))
        store.send(.presentSheet(.paywall))
        _ = store.modalStore.execute(.dismissAll)

        #expect(store.modalStore.currentPresentation?.route == .share)
        #expect(store.modalStore.queuedPresentations.isEmpty)
        #expect(store.path == [.sheet(.share)])
    }
}
