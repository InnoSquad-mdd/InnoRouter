// MARK: - NavigationStoreTelemetryTests.swift
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

// MARK: - NavigationStore Telemetry Tests

@Suite("NavigationStore Telemetry Tests")
struct NavigationStoreTelemetryTests {
    @Test("Non-prefix rewrite emits ignore telemetry without mutation")
    @MainActor
    func testIgnoreRewriteTelemetry() throws {
        let recorder = Mutex<[NavigationStoreTelemetryEvent<TestRoute>]>([])
        let store = NavigationStore<TestRoute>(
            initial: try validatedStack([.home, .detail(id: "123")]),
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .ignore,
                logger: Logger(subsystem: "InnoRouterTests", category: "NavigationStore")
            ),
            nonPrefixAssertionHandler: { _, _ in },
            telemetryRecorder: { event in
                recorder.withLock { $0.append(event) }
            }
        )

        store.pathBinding.wrappedValue = [.home, .settings]

        #expect(store.state.path == [.home, .detail(id: "123")])
        let events = recorder.withLock { $0 }
        #expect(events.count == 1)
        guard case .pathMismatch(let policy, let resolution, let oldPath, let newPath) = events[0] else {
            Issue.record("Expected non-prefix rewrite event")
            return
        }
        #expect(policy == .ignore)
        #expect(resolution == .ignore)
        #expect(oldPath == [.home, .detail(id: "123")])
        #expect(newPath == [.home, .settings])
    }

    @Test("Non-prefix rewrite emits custom batch telemetry")
    @MainActor
    func testCustomBatchRewriteTelemetry() throws {
        let recorder = Mutex<[NavigationStoreTelemetryEvent<TestRoute>]>([])
        let store = NavigationStore<TestRoute>(
            initial: try validatedStack([.home]),
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .custom { _, _ in
                    .batch([.push(.settings), .push(.detail(id: "123"))])
                },
                logger: Logger(subsystem: "InnoRouterTests", category: "NavigationStore")
            ),
            nonPrefixAssertionHandler: { _, _ in },
            telemetryRecorder: { event in
                recorder.withLock { $0.append(event) }
            }
        )

        store.pathBinding.wrappedValue = [.settings]

        #expect(store.state.path == [.home, .settings, .detail(id: "123")])
        let events = recorder.withLock { $0 }
        #expect(events.count == 1)
        guard case .pathMismatch(let policy, let resolution, _, _) = events[0] else {
            Issue.record("Expected non-prefix rewrite event")
            return
        }
        #expect(policy == .custom)
        #expect(resolution == .batch([.push(.settings), .push(.detail(id: "123"))]))
    }

    @Test("Middleware operations emit metadata telemetry in order")
    @MainActor
    func testMiddlewareMutationTelemetry() {
        let recorder = Mutex<[NavigationStoreTelemetryEvent<TestRoute>]>([])
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                logger: Logger(subsystem: "InnoRouterTests", category: "Middleware")
            ),
            nonPrefixAssertionHandler: { _, _ in },
            telemetryRecorder: { event in
                recorder.withLock { $0.append(event) }
            }
        )

        let first = store.addMiddleware(
            AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) }),
            debugName: "first"
        )
        let second = store.insertMiddleware(
            AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) }),
            at: 0,
            debugName: "second"
        )
        _ = store.replaceMiddleware(
            first,
            with: AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) }),
            debugName: "first-replaced"
        )
        #expect(store.moveMiddleware(second, to: 1) == true)
        _ = store.removeMiddleware(first)

        let events = recorder.withLock { $0 }
        #expect(events.count == 5)

        let actionNames = events.compactMap { event -> String? in
            guard case .middlewareMutation(let action, _, _) = event else { return nil }
            return action.rawValue
        }
        #expect(actionNames == ["added", "inserted", "replaced", "moved", "removed"])
    }
}
