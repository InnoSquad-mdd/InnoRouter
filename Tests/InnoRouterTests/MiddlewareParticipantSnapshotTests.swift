// MARK: - MiddlewareParticipantSnapshotTests.swift
// InnoRouterTests - in-flight middleware mutation snapshot integrity
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouterCore
@testable import InnoRouterSwiftUI

// MARK: - Local fixtures

private enum SnapshotRoute: Route {
    case a
    case b
}

@MainActor
private final class CallLog {
    var willExecute: [String] = []
    var didExecute: [String] = []
}

/// Middleware that records every `willExecute` / `didExecute` it receives
/// against a shared `CallLog` keyed by a label. The label is private to
/// the test fixture so we can assert the exact set of participants that
/// both saw `willExecute` and `didExecute`.
private struct RecordingNavigationMiddleware: NavigationMiddleware {
    typealias RouteType = SnapshotRoute
    let label: String
    let log: CallLog
    let onWillExecute: @MainActor () -> Void

    init(label: String, log: CallLog, onWillExecute: @MainActor @escaping () -> Void = {}) {
        self.label = label
        self.log = log
        self.onWillExecute = onWillExecute
    }

    @MainActor
    func willExecute(
        _ command: NavigationCommand<SnapshotRoute>,
        state: RouteStack<SnapshotRoute>
    ) -> NavigationInterception<SnapshotRoute> {
        log.willExecute.append(label)
        onWillExecute()
        return .proceed(command)
    }

    @MainActor
    func didExecute(
        _ command: NavigationCommand<SnapshotRoute>,
        result: NavigationResult<SnapshotRoute>,
        state: RouteStack<SnapshotRoute>
    ) -> NavigationResult<SnapshotRoute> {
        log.didExecute.append(label)
        return result
    }
}

private struct RecordingModalMiddleware: ModalMiddleware {
    typealias RouteType = SnapshotRoute
    let label: String
    let log: CallLog
    let onWillExecute: @MainActor () -> Void

    init(label: String, log: CallLog, onWillExecute: @MainActor @escaping () -> Void = {}) {
        self.label = label
        self.log = log
        self.onWillExecute = onWillExecute
    }

    @MainActor
    func willExecute(
        _ command: ModalCommand<SnapshotRoute>,
        currentPresentation: ModalPresentation<SnapshotRoute>?,
        queuedPresentations: [ModalPresentation<SnapshotRoute>]
    ) -> ModalInterception<SnapshotRoute> {
        log.willExecute.append(label)
        onWillExecute()
        return .proceed(command)
    }

    @MainActor
    func didExecute(
        _ command: ModalCommand<SnapshotRoute>,
        currentPresentation: ModalPresentation<SnapshotRoute>?,
        queuedPresentations: [ModalPresentation<SnapshotRoute>]
    ) {
        log.didExecute.append(label)
    }
}

@MainActor
private func makeNavigationRegistry() -> NavigationMiddlewareRegistry<SnapshotRoute> {
    let sink = NavigationStoreTelemetrySink<SnapshotRoute>(
        logger: nil,
        recorder: { _ in }
    )
    return NavigationMiddlewareRegistry<SnapshotRoute>(
        registrations: [],
        telemetrySink: sink
    )
}

@MainActor
private func makeModalRegistry() -> ModalMiddlewareRegistry<SnapshotRoute> {
    let sink = ModalStoreTelemetrySink<SnapshotRoute>(
        logger: nil,
        recorder: { _ in }
    )
    return ModalMiddlewareRegistry<SnapshotRoute>(
        registrations: [],
        telemetrySink: sink
    )
}

// MARK: - Suite

@Suite("Middleware participant snapshot integrity")
struct MiddlewareParticipantSnapshotTests {

    // The contract: every middleware that sees `willExecute` during a
    // single command's interception MUST also see `didExecute` for that
    // same command, and no middleware that did NOT see `willExecute`
    // may see `didExecute`. Concretely this means the registry has to
    // capture the set of participants at intercept time and feed that
    // exact set into didExecute, instead of slicing the live entries
    // array by a saved count after the fact.

    @Test("Navigation: insert mid-flight does not corrupt didExecute participants")
    @MainActor
    func navigationInsertMidFlightKeepsParticipantsCorrect() {
        let registry = makeNavigationRegistry()
        let log = CallLog()

        _ = registry.add(AnyNavigationMiddleware(RecordingNavigationMiddleware(label: "A", log: log)))
        // B's willExecute inserts a new middleware at the head of the
        // entries array. After intercept finishes, the live array is
        // [X, A, B, C] but only A/B/C ran willExecute.
        _ = registry.add(AnyNavigationMiddleware(
            RecordingNavigationMiddleware(label: "B", log: log) { [registry] in
                _ = registry.insert(
                    AnyNavigationMiddleware(RecordingNavigationMiddleware(label: "X", log: log)),
                    at: 0
                )
            }
        ))
        _ = registry.add(AnyNavigationMiddleware(RecordingNavigationMiddleware(label: "C", log: log)))

        let outcome = registry.intercept(.push(.a), state: RouteStack<SnapshotRoute>())
        _ = registry.didExecute(
            .push(.a),
            result: .success,
            state: RouteStack<SnapshotRoute>(),
            participants: outcome.participants
        )

        #expect(log.willExecute == ["A", "B", "C"])
        // The participants-snapshot strategy: every middleware that ran
        // willExecute receives didExecute for the same command, even if
        // entries[] is mutated mid-flight. X (inserted at head) does not
        // appear because it never ran willExecute for this command.
        #expect(log.didExecute == ["A", "B", "C"])
    }

    @Test("Navigation: remove mid-flight does not orphan didExecute calls")
    @MainActor
    func navigationRemoveMidFlightKeepsParticipantsCorrect() {
        let registry = makeNavigationRegistry()
        let log = CallLog()

        let aHandle = registry.add(AnyNavigationMiddleware(
            RecordingNavigationMiddleware(label: "A", log: log)
        ))
        // B removes A from the registry mid-flight. Live array becomes
        // [B, C], but A still must receive didExecute because it ran
        // willExecute.
        _ = registry.add(AnyNavigationMiddleware(
            RecordingNavigationMiddleware(label: "B", log: log) { [registry] in
                _ = registry.remove(aHandle)
            }
        ))
        _ = registry.add(AnyNavigationMiddleware(RecordingNavigationMiddleware(label: "C", log: log)))

        let outcome = registry.intercept(.push(.a), state: RouteStack<SnapshotRoute>())
        _ = registry.didExecute(
            .push(.a),
            result: .success,
            state: RouteStack<SnapshotRoute>(),
            participants: outcome.participants
        )

        #expect(log.willExecute == ["A", "B", "C"])
        #expect(log.didExecute == ["A", "B", "C"])
    }

    @Test("Modal: insert mid-flight does not corrupt didExecute participants")
    @MainActor
    func modalInsertMidFlightKeepsParticipantsCorrect() {
        let registry = makeModalRegistry()
        let log = CallLog()

        _ = registry.add(AnyModalMiddleware(RecordingModalMiddleware(label: "A", log: log)))
        _ = registry.add(AnyModalMiddleware(
            RecordingModalMiddleware(label: "B", log: log) { [registry] in
                _ = registry.insert(
                    AnyModalMiddleware(RecordingModalMiddleware(label: "X", log: log)),
                    at: 0
                )
            }
        ))
        _ = registry.add(AnyModalMiddleware(RecordingModalMiddleware(label: "C", log: log)))

        let presentation = ModalPresentation<SnapshotRoute>(route: .a, style: .sheet)
        let outcome = registry.intercept(
            .present(presentation),
            currentPresentation: nil,
            queuedPresentations: []
        )
        registry.didExecute(
            .present(presentation),
            currentPresentation: nil,
            queuedPresentations: [],
            participants: outcome.participants
        )

        #expect(log.willExecute == ["A", "B", "C"])
        #expect(log.didExecute == ["A", "B", "C"])
    }

    @Test("Modal: remove mid-flight does not orphan didExecute calls")
    @MainActor
    func modalRemoveMidFlightKeepsParticipantsCorrect() {
        let registry = makeModalRegistry()
        let log = CallLog()

        let aHandle = registry.add(AnyModalMiddleware(
            RecordingModalMiddleware(label: "A", log: log)
        ))
        _ = registry.add(AnyModalMiddleware(
            RecordingModalMiddleware(label: "B", log: log) { [registry] in
                _ = registry.remove(aHandle)
            }
        ))
        _ = registry.add(AnyModalMiddleware(RecordingModalMiddleware(label: "C", log: log)))

        let presentation = ModalPresentation<SnapshotRoute>(route: .a, style: .sheet)
        let outcome = registry.intercept(
            .present(presentation),
            currentPresentation: nil,
            queuedPresentations: []
        )
        registry.didExecute(
            .present(presentation),
            currentPresentation: nil,
            queuedPresentations: [],
            participants: outcome.participants
        )

        #expect(log.willExecute == ["A", "B", "C"])
        #expect(log.didExecute == ["A", "B", "C"])
    }
}
