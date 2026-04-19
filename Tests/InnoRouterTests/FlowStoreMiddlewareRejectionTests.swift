// MARK: - FlowStoreMiddlewareRejectionTests.swift
// InnoRouterTests - FlowStore rolls back on middleware cancellations
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
@testable import InnoRouterSwiftUI

private enum FlowMiddlewareRoute: Route {
    case home
    case detail
    case secure
}

@Suite("FlowStore Middleware Rejection Tests")
struct FlowStoreMiddlewareRejectionTests {

    @Test("navigation middleware cancel rolls back path and emits middlewareRejected")
    @MainActor
    func navigationMiddlewareCancelRollsBackPath() {
        let rejections = Mutex<[(FlowIntent<FlowMiddlewareRoute>, FlowRejectionReason)]>([])
        let gate = AnyNavigationMiddleware<FlowMiddlewareRoute>(
            willExecute: { command, _ in
                if case .push(let route) = command, route == .secure {
                    return .cancel(.middleware(debugName: "nav-gate", command: command))
                }
                return .proceed(command)
            }
        )
        let config = FlowStoreConfiguration<FlowMiddlewareRoute>(
            navigation: .init(middlewares: [.init(middleware: gate, debugName: "nav-gate")]),
            onIntentRejected: { intent, reason in
                rejections.withLock { $0.append((intent, reason)) }
            }
        )
        let store = FlowStore<FlowMiddlewareRoute>(configuration: config)
        store.send(.push(.home))

        store.send(.push(.secure))

        #expect(store.path == [.push(.home)])
        #expect(store.navigationStore.state.path == [.home])

        let events = rejections.withLock { $0 }
        #expect(events.count == 1)
        if let event = events.first {
            #expect(event.0 == .push(.secure))
            #expect(event.1 == .middlewareRejected(debugName: "nav-gate"))
        }
    }

    @Test("modal middleware cancel rolls back modal tail and emits middlewareRejected")
    @MainActor
    func modalMiddlewareCancelRollsBackPath() {
        let rejections = Mutex<[(FlowIntent<FlowMiddlewareRoute>, FlowRejectionReason)]>([])
        let gate = AnyModalMiddleware<FlowMiddlewareRoute>(
            willExecute: { command, _, _ in
                if case .present = command {
                    return .cancel(.middleware(debugName: "sheet-gate", command: command))
                }
                return .proceed(command)
            }
        )
        let config = FlowStoreConfiguration<FlowMiddlewareRoute>(
            modal: .init(middlewares: [.init(middleware: gate, debugName: "sheet-gate")]),
            onIntentRejected: { intent, reason in
                rejections.withLock { $0.append((intent, reason)) }
            }
        )
        let store = FlowStore<FlowMiddlewareRoute>(configuration: config)
        store.send(.push(.home))

        store.send(.presentSheet(.secure))

        #expect(store.path == [.push(.home)])
        #expect(store.modalStore.currentPresentation == nil)

        let events = rejections.withLock { $0 }
        #expect(events.count == 1)
        if let event = events.first {
            #expect(event.0 == .presentSheet(.secure))
            #expect(event.1 == .middlewareRejected(debugName: "sheet-gate"))
        }
    }
}
