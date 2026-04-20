// MARK: - FlowIntentNamedIntentsTests.swift
// InnoRouterTests - FlowIntent.replaceStack / .backOrPush / .pushUniqueRoot
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum NamedRoute: Route {
    case home
    case detail
    case settings
    case sheet
}

@Suite("FlowIntent Named Intent Tests")
struct FlowIntentNamedIntentsTests {

    // MARK: - replaceStack

    @Test(".replaceStack from clean path swaps the push prefix")
    @MainActor
    func replaceStackFromCleanPath() {
        let store = FlowStore<NamedRoute>()

        store.send(.replaceStack([.home, .detail]))

        #expect(store.path == [.push(.home), .push(.detail)])
        #expect(store.navigationStore.state.path == [.home, .detail])
        #expect(store.modalStore.currentPresentation == nil)
    }

    @Test(".replaceStack drops an active modal tail")
    @MainActor
    func replaceStackDropsModalTail() {
        let store = FlowStore<NamedRoute>()
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))
        #expect(store.modalStore.currentPresentation?.route == .sheet)

        store.send(.replaceStack([.settings]))

        #expect(store.path == [.push(.settings)])
        #expect(store.navigationStore.state.path == [.settings])
        #expect(store.modalStore.currentPresentation == nil)
    }

    @Test(".replaceStack emits a single onPathChanged event")
    @MainActor
    func replaceStackEmitsPathChanged() {
        let captured = Mutex<[[RouteStep<NamedRoute>]]>([])
        let store = FlowStore<NamedRoute>(
            configuration: FlowStoreConfiguration(
                onPathChanged: { _, new in captured.withLock { $0.append(new) } }
            )
        )

        store.send(.replaceStack([.home, .detail]))

        let paths = captured.withLock { $0 }
        #expect(paths == [[.push(.home), .push(.detail)]])
    }

    // MARK: - backOrPush

    @Test(".backOrPush pops to existing route without a rejection event")
    @MainActor
    func backOrPushPopsExisting() {
        let rejections = Mutex<[(FlowIntent<NamedRoute>, FlowRejectionReason)]>([])
        let store = FlowStore<NamedRoute>(
            configuration: FlowStoreConfiguration(
                onIntentRejected: { intent, reason in
                    rejections.withLock { $0.append((intent, reason)) }
                }
            )
        )
        store.send(.push(.home))
        store.send(.push(.detail))
        store.send(.push(.settings))

        store.send(.backOrPush(.detail))

        #expect(store.navigationStore.state.path == [.home, .detail])
        #expect(store.path == [.push(.home), .push(.detail)])
        #expect(rejections.withLock { $0.isEmpty })
    }

    @Test(".backOrPush pushes when route is absent")
    @MainActor
    func backOrPushPushesWhenAbsent() {
        let store = FlowStore<NamedRoute>()
        store.send(.push(.home))

        store.send(.backOrPush(.detail))

        #expect(store.path == [.push(.home), .push(.detail)])
    }

    @Test(".backOrPush rejects with .pushBlockedByModalTail when modal is active and route is new")
    @MainActor
    func backOrPushRejectsUnderModal() {
        let rejections = Mutex<[(FlowIntent<NamedRoute>, FlowRejectionReason)]>([])
        let store = FlowStore<NamedRoute>(
            configuration: FlowStoreConfiguration(
                onIntentRejected: { intent, reason in
                    rejections.withLock { $0.append((intent, reason)) }
                }
            )
        )
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))

        store.send(.backOrPush(.detail))

        let captured = rejections.withLock { $0 }
        #expect(captured.count == 1)
        if case (.backOrPush(.detail), .pushBlockedByModalTail) = (captured.first!.0, captured.first!.1) {
            // expected
        } else {
            Issue.record("Expected backOrPush rejection with pushBlockedByModalTail, got \(captured)")
        }
        #expect(store.modalStore.currentPresentation?.route == .sheet)
    }

    // MARK: - pushUniqueRoot

    @Test(".pushUniqueRoot is a silent no-op when stack root already matches")
    @MainActor
    func pushUniqueRootNoOpsWhenMatching() {
        let captured = Mutex<[[RouteStep<NamedRoute>]]>([])
        let store = FlowStore<NamedRoute>(
            configuration: FlowStoreConfiguration(
                onPathChanged: { _, new in captured.withLock { $0.append(new) } }
            )
        )
        store.send(.push(.home))
        captured.withLock { $0.removeAll() }

        store.send(.pushUniqueRoot(.home))

        #expect(store.path == [.push(.home)])
        #expect(captured.withLock { $0.isEmpty })
    }

    @Test(".pushUniqueRoot pushes when current root differs")
    @MainActor
    func pushUniqueRootPushesWhenDifferent() {
        let store = FlowStore<NamedRoute>()

        store.send(.pushUniqueRoot(.home))

        #expect(store.path == [.push(.home)])
    }

    @Test(".pushUniqueRoot rejects under an active modal tail")
    @MainActor
    func pushUniqueRootRejectsUnderModal() {
        let rejections = Mutex<[(FlowIntent<NamedRoute>, FlowRejectionReason)]>([])
        let store = FlowStore<NamedRoute>(
            configuration: FlowStoreConfiguration(
                onIntentRejected: { intent, reason in
                    rejections.withLock { $0.append((intent, reason)) }
                }
            )
        )
        store.send(.push(.home))
        store.send(.presentSheet(.sheet))

        store.send(.pushUniqueRoot(.detail))

        let captured = rejections.withLock { $0 }
        #expect(captured.count == 1)
        if case (.pushUniqueRoot(.detail), .pushBlockedByModalTail) = (captured.first!.0, captured.first!.1) {
            // expected
        } else {
            Issue.record("Expected pushUniqueRoot rejection, got \(captured)")
        }
    }

    // MARK: - End-to-end through events stream

    @Test(".replaceStack shows on FlowStore.events as .pathChanged")
    @MainActor
    func replaceStackSurfacesOnEventsStream() async {
        let store = FlowStore<NamedRoute>()
        var iterator = store.events.makeAsyncIterator()

        store.send(.replaceStack([.home, .detail]))

        var sawPathChanged = false
        for _ in 0..<6 {
            let event = await iterator.next()
            if case .pathChanged(let old, let new) = event,
               old.isEmpty,
               new == [.push(.home), .push(.detail)] {
                sawPathChanged = true
                break
            }
        }
        #expect(sawPathChanged)
    }
}
