// MARK: - NavigationCommandTests.swift
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

// MARK: - NavigationCommand Tests

@Suite("NavigationCommand Tests")
struct NavigationCommandTests {

    @Test("Execute push command")
    @MainActor
    func testExecutePush() {
        let store = NavigationStore<TestRoute>()

        let result = store.execute(.push(.home))

        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }

    @Test("Execute pop command")
    @MainActor
    func testExecutePop() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])

        let result = store.execute(.pop)

        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }

    @Test("Execute pop on empty returns emptyStack")
    @MainActor
    func testExecutePopEmpty() {
        let store = NavigationStore<TestRoute>()

        let result = store.execute(.pop)

        #expect(result == .emptyStack)
    }

    @Test("Execute popCount zero returns invalidPopCount")
    @MainActor
    func testExecutePopCountZero() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])

        let result = store.execute(.popCount(0))

        #expect(result == .invalidPopCount(0))
        #expect(store.state.path == [.home])
    }

    @Test("Execute popCount negative returns invalidPopCount")
    @MainActor
    func testExecutePopCountNegative() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])

        let result = store.execute(.popCount(-1))

        #expect(result == .invalidPopCount(-1))
        #expect(store.state.path == [.home])
    }

    @Test("Execute popCount beyond stack depth returns insufficientStackDepth")
    @MainActor
    func testExecutePopCountTooLarge() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])

        let result = store.execute(.popCount(2))

        #expect(result == .insufficientStackDepth(requested: 2, available: 1))
        #expect(store.state.path == [.home])
    }

    @Test("Execute sequence of commands")
    @MainActor
    func testExecuteSequence() {
        let store = NavigationStore<TestRoute>()

        let result = store.execute(.sequence([
            .push(.home),
            .push(.detail(id: "123")),
            .push(.settings)
        ]))

        if case .multiple(let results) = result {
            #expect(results.count == 3)
            #expect(results.allSatisfy { $0 == .success })
        } else {
            Issue.record("Expected multiple result")
        }

        #expect(store.state.path.count == 3)
    }

    @Test("Nested sequence is state-equivalent to flat left-to-right execution")
    @MainActor
    func testSequenceAssociativityForState() {
        let nestedStore = NavigationStore<TestRoute>()
        let flatStore = NavigationStore<TestRoute>()

        _ = nestedStore.execute(.sequence([
            .push(.home),
            .sequence([
                .push(.detail(id: "123")),
                .push(.settings)
            ])
        ]))

        _ = flatStore.execute(.sequence([
            .push(.home),
            .push(.detail(id: "123")),
            .push(.settings)
        ]))

        #expect(nestedStore.state == flatStore.state)
    }

    @Test("Sequence preserves successful prefixes before a later failure")
    @MainActor
    func testSequenceHasNoRollbackOnFailure() {
        let store = NavigationStore<TestRoute>()

        let result = store.execute(.sequence([
            .push(.home),
            .pop,
            .pop
        ]))

        #expect(result == .multiple([.success, .success, .emptyStack]))
        #expect(store.state.path.isEmpty)
    }

    @Test("Middleware runs per-step for sequence")
    @MainActor
    func testSequenceRunsMiddlewarePerStep() {
        let store = NavigationStore<TestRoute>()
        var willCount = 0
        var didCount = 0

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willCount += 1
                    return .proceed(command)
                },
                didExecute: { _, result, _ in
                    didCount += 1
                    return result
                }
            )
        )

        _ = store.execute(.sequence([.push(.home), .push(.settings)]))

        #expect(willCount == 2)
        #expect(didCount == 2)
        #expect(store.state.path == [.home, .settings])
    }

    @Test("Middleware can cancel command")
    @MainActor
    func testMiddlewareCanCancelCommand() {
        let store = NavigationStore<TestRoute>()
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    .cancel(.middleware(debugName: nil, command: command))
                }
            )
        )

        let result = store.execute(.push(.home))

        #expect(result == .cancelled(.middleware(debugName: nil, command: .push(.home))))
        #expect(store.state.path.isEmpty)
    }

    @Test("Cancelled commands only notify participating middleware in didExecute")
    @MainActor
    func testCancelledCommandsOnlyNotifyParticipatingMiddleware() {
        let store = NavigationStore<TestRoute>()
        var willOrder: [String] = []
        var didOrder: [String] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willOrder.append("first")
                    return .proceed(command)
                },
                didExecute: { _, result, _ in
                    didOrder.append("first")
                    return result
                }
            ),
            debugName: "first"
        )
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willOrder.append("second")
                    return .cancel(.middleware(debugName: nil, command: command))
                },
                didExecute: { _, result, _ in
                    didOrder.append("second")
                    return result
                }
            ),
            debugName: "second"
        )
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willOrder.append("third")
                    return .proceed(command)
                },
                didExecute: { _, result, _ in
                    didOrder.append("third")
                    return result
                }
            ),
            debugName: "third"
        )

        let result = store.execute(.push(.home))

        #expect(result == .cancelled(.middleware(debugName: "second", command: .push(.home))))
        #expect(willOrder == ["first", "second"])
        #expect(didOrder == ["first", "second"])
        #expect(store.state.path.isEmpty)
    }

    @Test("Middleware can transform results after execution in order")
    @MainActor
    func testMiddlewareCanTransformResultAfterExecution() {
        let store = NavigationStore<TestRoute>()
        var seenBySecond: NavigationResult<TestRoute>?

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in .proceed(command) },
                didExecute: { _, _, _ in
                    .cancelled(.custom("first"))
                }
            ),
            debugName: "first"
        )
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in .proceed(command) },
                didExecute: { _, result, _ in
                    seenBySecond = result
                    return .cancelled(.custom("second"))
                }
            ),
            debugName: "second"
        )

        let result = store.execute(.push(.home))

        #expect(seenBySecond == .cancelled(.custom("first")))
        #expect(result == .cancelled(.custom("second")))
        #expect(store.state.path == [.home])
    }

    @Test("NavigationResult multiple with empty results is failure")
    func testNavigationResultMultipleEmptyIsFailure() {
        let result = NavigationResult<TestRoute>.multiple([])
        #expect(result.isSuccess == false)
    }

    @Test("Command validation previews legality without mutation")
    func testCommandValidationPreview() throws {
        let stack: RouteStack<TestRoute> = try validatedStack([.home])

        #expect(NavigationCommand<TestRoute>.pop.validate(on: stack) == .success)
        #expect(NavigationCommand<TestRoute>.pop.canExecute(on: stack) == true)
        #expect(NavigationCommand<TestRoute>.popTo(.settings).validate(on: stack) == .routeNotFound(.settings))
        #expect(NavigationCommand<TestRoute>.popTo(.settings).canExecute(on: stack) == false)
        #expect(stack.path == [TestRoute.home])
    }

    @Test(
        "Random command streams match the reference navigation model",
        arguments: Array(0..<100)
    )
    @MainActor
    func randomCommandStreamsMatchReferenceModel(seed: Int) throws {
        let store = NavigationStore<TestRoute>()
        var referencePath: [TestRoute] = []
        var rng = SeededGenerator(seed: UInt64(seed + 1))

        for _ in 0..<40 {
            let command = randomNavigationCommand(
                rng: &rng,
                currentPath: referencePath,
                depth: 0
            )

            let expectedPreview = previewReferenceResult(command, path: referencePath)
            let actualPreview = command.validate(on: try validatedStack(referencePath))
            #expect(actualPreview == expectedPreview)

            let actual = store.execute(command)
            let expected = applyReference(command, to: &referencePath)

            #expect(actual == expected)
            #expect(store.state.path == referencePath)
        }
    }
}
