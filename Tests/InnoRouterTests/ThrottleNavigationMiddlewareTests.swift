// MARK: - ThrottleNavigationMiddlewareTests.swift
// InnoRouterTests - ThrottleNavigationMiddleware behaviour
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import Synchronization
import InnoRouter
import InnoRouterSwiftUI

private enum ThrottleRoute: Route {
    case home
    case detail
    case settings
}

/// Deterministic clock for testing. Advances only when the test
/// explicitly steps it forward. Uses `Mutex` so the `Clock`
/// protocol's non-isolated requirements can be satisfied while
/// callers (on the MainActor) drive `advance(by:)`.
private final class TestClock: Clock, Sendable {
    typealias Duration = Swift.Duration

    struct Instant: InstantProtocol, Sendable, Comparable {
        typealias Duration = Swift.Duration
        let elapsed: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant {
            Instant(elapsed: elapsed + duration)
        }

        func duration(to other: Instant) -> Swift.Duration {
            other.elapsed - elapsed
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.elapsed < rhs.elapsed
        }
    }

    private let state = Mutex<Instant>(Instant(elapsed: .zero))

    var now: Instant {
        state.withLock { $0 }
    }

    let minimumResolution: Swift.Duration = .nanoseconds(1)

    init() {}

    func advance(by duration: Swift.Duration) {
        state.withLock { $0 = $0.advanced(by: duration) }
    }

    func sleep(until deadline: Instant, tolerance: Swift.Duration?) async throws {
        // Synthetic clock — synchronous fulfillment only, real sleep
        // semantics aren't needed for the throttle tests.
    }
}

@Suite("ThrottleNavigationMiddleware Tests")
struct ThrottleNavigationMiddlewareTests {

    @Test("Same command within interval is cancelled")
    @MainActor
    func sameCommandWithinIntervalCancelled() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        _ = store.execute(.push(.home))
        clock.advance(by: .milliseconds(50))
        let result2 = store.execute(.push(.detail))

        #expect(store.state.path == [.home])
        if case .cancelled(.middleware(let debugName, _)) = result2 {
            #expect(debugName == "throttle")
        } else {
            Issue.record("Expected .cancelled(.middleware), got \(result2)")
        }
    }

    @Test("Same command beyond interval succeeds")
    @MainActor
    func sameCommandBeyondIntervalSucceeds() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        _ = store.execute(.push(.home))
        clock.advance(by: .milliseconds(400)) // beyond 300ms window
        _ = store.execute(.push(.detail))

        #expect(store.state.path == [.home, .detail])
    }

    @Test("Sequence interleaves didExecute so throttle blocks the second step")
    @MainActor
    func sequenceInterleavesThrottleWindow() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        let result = store.execute(.sequence([.push(.home), .push(.detail)]))

        guard case .multiple(let results) = result else {
            Issue.record("Expected .multiple, got \(result)")
            return
        }
        guard results.count == 2 else {
            Issue.record("Expected two sequence results, got \(results)")
            return
        }
        #expect(results[0] == .success)
        if case .cancelled(.middleware(let debugName, _)) = results[1] {
            #expect(debugName == "throttle")
        } else {
            Issue.record("Expected second sequence step to be throttled, got \(results[1])")
        }
        #expect(store.state.path == [.home])
    }

    @Test("Batch interleaves didExecute so throttle blocks the second step")
    @MainActor
    func batchInterleavesThrottleWindow() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        let batch = store.executeBatch([.push(.home), .push(.detail)], stopOnFailure: false)

        #expect(batch.executedCommands == [.push(.home)])
        guard batch.results.count == 2 else {
            Issue.record("Expected two batch results, got \(batch.results)")
            return
        }
        #expect(batch.results[0] == .success)
        if case .cancelled(.middleware(let debugName, _)) = batch.results[1] {
            #expect(debugName == "throttle")
        } else {
            Issue.record("Expected second batch step to be throttled, got \(batch.results[1])")
        }
        #expect(store.state.path == [.home])
    }

    @Test("Per-command keys throttle independently")
    @MainActor
    func perCommandKeys() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { command in
                if case .push(let route) = command {
                    return "push-\(route)"
                }
                return "other"
            }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        _ = store.execute(.push(.home))
        // Different command keys → no throttle interference.
        _ = store.execute(.push(.detail))
        _ = store.execute(.push(.settings))

        #expect(store.state.path == [.home, .detail, .settings])
    }

    @Test("Nil key opts the command out of throttling entirely")
    @MainActor
    func nilKeyBypasses() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { command in
                // Only throttle .pop; push is opt-out.
                if case .pop = command { return "pop" }
                return nil
            }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        // Rapid pushes — all go through because key returns nil.
        _ = store.execute(.push(.home))
        _ = store.execute(.push(.detail))
        _ = store.execute(.push(.settings))

        #expect(store.state.path == [.home, .detail, .settings])
    }

    @Test("Engine failure does not arm the throttle window")
    @MainActor
    func engineFailureDoesNotArmWindow() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle")]
            )
        )

        let failure = store.execute(.pop)
        clock.advance(by: .milliseconds(50))
        let success = store.execute(.push(.home))

        #expect(failure == .emptyStack)
        #expect(success.isSuccess)
        #expect(store.state.path == [.home])
    }

    @Test("Later middleware cancellation does not arm the throttle window")
    @MainActor
    func laterMiddlewareCancellationDoesNotArmWindow() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let gate = AnyNavigationMiddleware<ThrottleRoute>(
            willExecute: { command, _ in
                if case .push(.home) = command {
                    return .cancel(.middleware(debugName: nil, command: command))
                }
                return .proceed(command)
            }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle"),
                    .init(middleware: gate, debugName: "gate")
                ]
            )
        )

        let first = store.execute(.push(.home))
        clock.advance(by: .milliseconds(50))
        let second = store.execute(.push(.detail))

        if case .cancelled(.middleware(let debugName, _)) = first {
            #expect(debugName == "gate")
        } else {
            Issue.record("Expected first command to be cancelled by gate, got \(first)")
        }
        #expect(second.isSuccess)
        #expect(store.state.path == [.detail])
    }

    @Test("Throttle cancellation uses the registered debug name")
    @MainActor
    func registeredDebugNameSurfacesInCancellationReason() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [.init(middleware: AnyNavigationMiddleware(throttle), debugName: "nav-throttle")]
            )
        )

        _ = store.execute(.push(.home))
        clock.advance(by: .milliseconds(50))
        let result = store.execute(.push(.detail))

        if case .cancelled(.middleware(let debugName, _)) = result {
            #expect(debugName == "nav-throttle")
        } else {
            Issue.record("Expected .cancelled(.middleware), got \(result)")
        }
    }

    @Test("Transaction discard cleanup keeps throttle aligned to the committed fallback")
    @MainActor
    func transactionDiscardCleanupKeepsThrottleBalanced() {
        let clock = TestClock()
        let throttle = ThrottleNavigationMiddleware<ThrottleRoute, TestClock>(
            interval: .milliseconds(300),
            clock: clock,
            key: { _ in "all" }
        )
        let gate = AnyNavigationMiddleware<ThrottleRoute>(
            willExecute: { command, _ in
                if case .push(.detail) = command {
                    return .cancel(.middleware(debugName: nil, command: command))
                }
                return .proceed(command)
            }
        )
        let store = NavigationStore<ThrottleRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    .init(middleware: AnyNavigationMiddleware(throttle), debugName: "throttle"),
                    .init(middleware: gate, debugName: "gate")
                ]
            )
        )

        let transaction = store.executeTransaction([
            .whenCancelled(.push(.detail), fallback: .push(.home))
        ])
        #expect(transaction.isCommitted)
        #expect(store.state.path == [.home])

        clock.advance(by: .milliseconds(50))
        let first = store.execute(.push(.settings))
        if case .cancelled(.middleware(let debugName, _)) = first {
            #expect(debugName == "throttle")
        } else {
            Issue.record("Expected first post-transaction command to be throttled, got \(first)")
        }

        clock.advance(by: .milliseconds(400))
        let second = store.execute(.push(.settings))
        #expect(second.isSuccess)
        #expect(store.state.path == [.home, .settings])

        clock.advance(by: .milliseconds(50))
        let third = store.execute(.push(.home))
        if case .cancelled(.middleware(let debugName, _)) = third {
            #expect(debugName == "throttle")
        } else {
            Issue.record("Expected throttle window to track the committed fallback, got \(third)")
        }
        #expect(store.state.path == [.home, .settings])
    }
}
