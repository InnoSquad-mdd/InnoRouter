// MARK: - NavigationPathReconcilerTests.swift
// Unit coverage for the NavigationPathReconciler that NavigationStore
// uses to translate SwiftUI's Binding-driven path updates into typed
// NavigationCommand work.
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import Testing

@testable import InnoRouterSwiftUI
import InnoRouterCore

private enum ReconcilerRoute: String, Route, Codable {
    case home
    case detail
    case profile
    case settings
    case about
}

@MainActor
private final class Recorder {
    var singles: [NavigationCommand<ReconcilerRoute>] = []
    var batches: [[NavigationCommand<ReconcilerRoute>]] = []
    var mismatchCalls: [(old: [ReconcilerRoute], new: [ReconcilerRoute])] = []

    func execute(_ command: NavigationCommand<ReconcilerRoute>) {
        singles.append(command)
    }

    func executeBatch(_ commands: [NavigationCommand<ReconcilerRoute>]) {
        batches.append(commands)
    }
}

@Suite("NavigationPathReconciler Tests", .tags(.unit))
struct NavigationPathReconcilerTests {
    // MARK: - Pop branch (new path is a prefix of old)

    @Test("Identical paths produce no work")
    @MainActor
    func noDivergenceIsNoOp() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail],
            to: [.home, .detail],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles.isEmpty)
        #expect(recorder.batches.isEmpty)
    }

    @Test("New path strictly shorter than old emits popCount")
    @MainActor
    func popPartialStack() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail, .profile],
            to: [.home],
            resolveMismatch: { _, _ in
                Issue.record("resolveMismatch must not be invoked for pure-prefix collapses")
                return .ignore
            },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles == [.popCount(2)])
        #expect(recorder.batches.isEmpty)
    }

    @Test("New path empty when old had content emits popToRoot")
    @MainActor
    func popToRoot() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail, .profile],
            to: [],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles == [.popToRoot])
        #expect(recorder.batches.isEmpty)
    }

    // MARK: - Append branch (old path is a prefix of new)

    @Test("Appending a single route emits push")
    @MainActor
    func appendOnePush() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home],
            to: [.home, .detail],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles == [.push(.detail)])
        #expect(recorder.batches.isEmpty)
    }

    @Test("Appending multiple routes emits a batch of pushes")
    @MainActor
    func appendManyBatchPushes() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home],
            to: [.home, .detail, .profile, .settings],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles.isEmpty)
        #expect(recorder.batches.count == 1)
        #expect(recorder.batches.first == [
            .push(.detail),
            .push(.profile),
            .push(.settings),
        ])
    }

    @Test("Appending from an empty path still batches pushes correctly")
    @MainActor
    func appendFromEmpty() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [],
            to: [.home, .detail],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles.isEmpty)
        #expect(recorder.batches.count == 1)
        #expect(recorder.batches.first == [.push(.home), .push(.detail)])
    }

    // MARK: - Mismatch branch (prefix differs)

    @Test("Totally different paths invoke resolveMismatch")
    @MainActor
    func totalDivergence() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail],
            to: [.profile, .settings],
            resolveMismatch: { old, new in
                recorder.mismatchCalls.append((old: old, new: new))
                return .single(.replace(new))
            },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.mismatchCalls.count == 1)
        #expect(recorder.mismatchCalls.first?.old == [.home, .detail])
        #expect(recorder.mismatchCalls.first?.new == [.profile, .settings])
        #expect(recorder.singles == [.replace([.profile, .settings])])
    }

    @Test("Prefix shared but tail swapped still invokes resolveMismatch")
    @MainActor
    func sharedPrefixThenDivergence() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail, .profile],
            to: [.home, .settings, .about],
            resolveMismatch: { old, new in
                recorder.mismatchCalls.append((old: old, new: new))
                return .batch([.popCount(2), .push(.settings), .push(.about)])
            },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.mismatchCalls.count == 1)
        #expect(recorder.batches.first == [
            .popCount(2),
            .push(.settings),
            .push(.about),
        ])
    }

    @Test("Resolution .ignore leaves the stack alone")
    @MainActor
    func resolutionIgnoreSkipsWork() {
        let recorder = Recorder()
        NavigationPathReconciler<ReconcilerRoute>().reconcile(
            from: [.home, .detail],
            to: [.profile, .settings],
            resolveMismatch: { _, _ in .ignore },
            execute: recorder.execute,
            executeBatch: recorder.executeBatch
        )

        #expect(recorder.singles.isEmpty)
        #expect(recorder.batches.isEmpty)
    }

    @Test("Mismatch policies in NavigationStoreConfiguration compile as-is")
    @MainActor
    func policyEnumCasesCompile() {
        // Coverage smoke: every policy case should be constructible
        // without extra parameters, so downstream switches stay
        // exhaustive even as the enum grows.
        let policies: [NavigationPathMismatchPolicy<ReconcilerRoute>] = [
            .replace,
            .assertAndReplace,
            .ignore,
            .custom { _, _ in .ignore },
        ]

        for policy in policies {
            switch policy {
            case .replace, .assertAndReplace, .ignore:
                break
            case .custom(let resolver):
                let resolution = resolver([.home], [.detail])
                if case .ignore = resolution {
                    break
                }
                Issue.record("Expected smoke-test resolver to return .ignore")
            }
        }
    }
}
