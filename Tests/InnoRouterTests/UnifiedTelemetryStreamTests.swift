// MARK: - UnifiedTelemetryStreamTests.swift
// InnoRouterTests - store.events AsyncStream coverage
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum StreamRoute: Route {
    case home
    case detail
    case sheet
    case settings
}

@MainActor
private func noopNavMiddleware() -> AnyNavigationMiddleware<StreamRoute> {
    AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) })
}

@Suite("Unified Telemetry Stream Tests")
struct UnifiedTelemetryStreamTests {

    // MARK: - NavigationStore

    @Test("NavigationStore.events emits .changed for a single push")
    @MainActor
    func navigationEventsEmitsChangedOnPush() async {
        let store = NavigationStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        store.send(.go(.home))

        let first = await iterator.next()
        guard case .changed(let from, let to) = first else {
            Issue.record("Expected .changed, got \(String(describing: first))")
            return
        }
        #expect(from.path.isEmpty)
        #expect(to.path == [.home])
    }

    @Test("NavigationStore.events emits .batchExecuted alongside a coalesced .changed")
    @MainActor
    func navigationEventsEmitsBatchExecuted() async {
        let store = NavigationStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        _ = store.executeBatch([.push(.home), .push(.detail)])

        // Order: one coalesced .changed, then the .batchExecuted summary.
        let first = await iterator.next()
        let second = await iterator.next()
        guard case .changed = first else {
            Issue.record("Expected .changed, got \(String(describing: first))")
            return
        }
        guard case .batchExecuted(let result) = second else {
            Issue.record("Expected .batchExecuted, got \(String(describing: second))")
            return
        }
        #expect(result.executedCommands.count == 2)
    }

    @Test("NavigationStore.events emits .transactionExecuted on commit")
    @MainActor
    func navigationEventsEmitsTransactionExecuted() async {
        let store = NavigationStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        _ = store.executeTransaction([.push(.home)])

        _ = await iterator.next() // .changed
        let second = await iterator.next()
        guard case .transactionExecuted(let result) = second else {
            Issue.record("Expected .transactionExecuted, got \(String(describing: second))")
            return
        }
        #expect(result.isCommitted)
    }

    @Test("NavigationStore.events emits .middlewareMutation when middleware is added")
    @MainActor
    func navigationEventsEmitsMiddlewareMutation() async {
        let store = NavigationStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        _ = store.addMiddleware(noopNavMiddleware(), debugName: "added")

        let event = await iterator.next()
        guard case .middlewareMutation(let mutation) = event else {
            Issue.record("Expected .middlewareMutation, got \(String(describing: event))")
            return
        }
        #expect(mutation.action == .added)
    }

    @Test("NavigationStore.events emits .pathMismatch on non-prefix rewrite")
    @MainActor
    func navigationEventsEmitsPathMismatch() async {
        let store = NavigationStore<StreamRoute>()
        store.send(.go(.home))

        // Drain the initial .changed.
        var iterator = store.events.makeAsyncIterator()

        store.pathBinding.wrappedValue = [.detail]

        let first = await iterator.next()
        guard case .pathMismatch(let event) = first else {
            Issue.record("Expected .pathMismatch, got \(String(describing: first))")
            return
        }
        #expect(event.oldPath == [.home])
        #expect(event.newPath == [.detail])
    }

    @Test("NavigationStore.events supports multiple independent subscribers")
    @MainActor
    func navigationEventsSupportsMultipleSubscribers() async {
        let store = NavigationStore<StreamRoute>()
        var iteratorA = store.events.makeAsyncIterator()
        var iteratorB = store.events.makeAsyncIterator()

        store.send(.go(.home))

        let eventA = await iteratorA.next()
        let eventB = await iteratorB.next()

        guard case .changed(_, let toA) = eventA, case .changed(_, let toB) = eventB else {
            Issue.record("Expected both subscribers to see .changed")
            return
        }
        #expect(toA.path == [.home])
        #expect(toB.path == [.home])
    }

    @Test("NavigationStore.events coexists with configuration onChange callback")
    @MainActor
    func navigationEventsCoexistsWithCallback() async {
        let captured = Mutex<[RouteStack<StreamRoute>]>([])
        let store = NavigationStore<StreamRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, new in
                    captured.withLock { $0.append(new) }
                }
            )
        )
        var iterator = store.events.makeAsyncIterator()

        store.send(.go(.home))

        _ = await iterator.next()

        let callbackPaths = captured.withLock { $0.map(\.path) }
        #expect(callbackPaths == [[.home]])
    }

    // MARK: - ModalStore

    @Test("ModalStore.events emits .presented for a single sheet")
    @MainActor
    func modalEventsEmitsPresented() async {
        let store = ModalStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        store.present(.sheet, style: .sheet)

        let first = await iterator.next()
        guard case .presented(let presentation) = first else {
            Issue.record("Expected .presented, got \(String(describing: first))")
            return
        }
        #expect(presentation.route == .sheet)
    }

    @Test("ModalStore.events emits .commandIntercepted for every execute")
    @MainActor
    func modalEventsEmitsCommandIntercepted() async {
        let store = ModalStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        store.present(.sheet, style: .sheet)

        _ = await iterator.next() // .presented
        let second = await iterator.next()
        guard case .commandIntercepted(_, let result) = second else {
            Issue.record("Expected .commandIntercepted, got \(String(describing: second))")
            return
        }
        if case .executed = result { /* ok */ } else {
            Issue.record("Expected .executed result, got \(result)")
        }
    }

    @Test("ModalStore.events emits .dismissed and promoted .queueChanged + .presented")
    @MainActor
    func modalEventsEmitsPromotionSequence() async {
        let store = ModalStore<StreamRoute>()
        store.present(.sheet, style: .sheet)
        store.present(.settings, style: .sheet) // queued

        var iterator = store.events.makeAsyncIterator()

        store.dismissCurrent()

        // Order: dismissed → queueChanged (queue drained) → presented (promoted) → commandIntercepted.
        let first = await iterator.next()
        guard case .dismissed(let dismissed, let reason) = first else {
            Issue.record("Expected .dismissed first, got \(String(describing: first))")
            return
        }
        #expect(dismissed.route == .sheet)
        #expect(reason == .dismiss)

        _ = await iterator.next() // .queueChanged
        let third = await iterator.next()
        guard case .presented(let promoted) = third else {
            Issue.record("Expected .presented (promoted), got \(String(describing: third))")
            return
        }
        #expect(promoted.route == .settings)
    }

    // MARK: - FlowStore

    @Test("FlowStore.events wraps inner navigation events and emits .pathChanged last")
    @MainActor
    func flowEventsWrapsNavigation() async {
        let store = FlowStore<StreamRoute>()
        var iterator = store.events.makeAsyncIterator()

        store.send(.push(.home))

        // Expect: .navigation(.changed) + .pathChanged in order.
        // The inner-nav Task runs on the MainActor, so events fan in
        // synchronously with respect to MainActor scheduling.
        var sawNavigationChanged = false
        var sawPathChanged = false

        for _ in 0..<4 {
            let event = await iterator.next()
            if case .navigation(.changed) = event { sawNavigationChanged = true }
            if case .pathChanged = event { sawPathChanged = true }
            if sawNavigationChanged && sawPathChanged { break }
        }
        #expect(sawNavigationChanged)
        #expect(sawPathChanged)
    }

    @Test("FlowStore.events surfaces .intentRejected for push-after-modal")
    @MainActor
    func flowEventsSurfacesIntentRejected() async {
        let store = FlowStore<StreamRoute>()
        store.send(.presentSheet(.sheet))

        var iterator = store.events.makeAsyncIterator()

        store.send(.push(.detail))

        var sawRejected = false
        for _ in 0..<4 {
            let event = await iterator.next()
            if case .intentRejected(_, let reason) = event, reason == .pushBlockedByModalTail {
                sawRejected = true
                break
            }
        }
        #expect(sawRejected)
    }
}
