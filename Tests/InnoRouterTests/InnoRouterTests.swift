// MARK: - InnoRouterTests.swift
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

// MARK: - Test Route

enum TestRoute: Route {
    case home
    case detail(id: String)
    case settings
    case profile(userId: String, tab: Int)
}

enum TestModalRoute: Route {
    case profile
    case onboarding
}

private enum TestValidationError: Error, Equatable {
    case rejected
}

// MARK: - RouteStack Tests

@Suite("RouteStack Tests")
struct RouteStackTests {
    @Test("RouteStack init creates an empty stack")
    func testEmptyInit() {
        let stack = RouteStack<TestRoute>()
        #expect(stack.path.isEmpty)
    }

    @Test("RouteStack validating init accepts permissive snapshots")
    func testValidatedInitPermissive() throws {
        let stack = try RouteStack<TestRoute>(validating: [.home, .detail(id: "123")])
        #expect(stack.path == [.home, .detail(id: "123")])
    }

    @Test("RouteStack validating init surfaces validator failures")
    func testValidatedInitFailure() {
        let validator = RouteStackValidator<TestRoute> { _ in
            throw TestValidationError.rejected
        }

        do {
            _ = try RouteStack<TestRoute>(validating: [.home], using: validator)
            Issue.record("Expected RouteStack validation to fail")
        } catch let error as TestValidationError {
            #expect(error == .rejected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator nonEmpty rejects empty stacks")
    func testNonEmptyValidator() {
        do {
            _ = try RouteStack<TestRoute>(validating: [], using: .nonEmpty)
            Issue.record("Expected nonEmpty validator to reject empty path")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .emptyStackNotAllowed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator uniqueRoutes rejects duplicates")
    func testUniqueRoutesValidator() {
        do {
            _ = try RouteStack<TestRoute>(validating: [.home, .settings, .home], using: .uniqueRoutes)
            Issue.record("Expected uniqueRoutes validator to reject duplicates")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .duplicateRoute(.home))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator rooted validates the first route")
    func testRootedValidator() {
        let valid = try? RouteStack<TestRoute>(validating: [.home, .settings], using: .rooted(at: .home))
        #expect(valid?.path == [.home, .settings])

        do {
            _ = try RouteStack<TestRoute>(validating: [.settings], using: .rooted(at: .home))
            Issue.record("Expected rooted validator to reject wrong root")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .invalidRoot(expected: .home, actual: .settings))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RouteStackValidator combined applies validators in order")
    func testCombinedValidator() {
        let validator = RouteStackValidator<TestRoute>.nonEmpty
            .combined(with: .rooted(at: .home))
            .combined(with: .uniqueRoutes)

        let valid = try? RouteStack<TestRoute>(
            validating: [.home, .settings, .detail(id: "123")],
            using: validator
        )
        #expect(valid?.path == [.home, .settings, .detail(id: "123")])

        do {
            _ = try RouteStack<TestRoute>(
                validating: [.home, .settings, .home],
                using: validator
            )
            Issue.record("Expected combined validator to reject duplicates")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .duplicateRoute(.home))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - NavigationStore Tests

@Suite("NavigationStore Tests")
struct NavigationStoreTests {
    @Test("Configuration init preserves legacy onChange and onBatchExecuted behavior")
    @MainActor
    func testConfigurationInitParity() throws {
        var changeCount = 0
        var batchCount = 0
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { _ in
                    batchCount += 1
                }
            )
        )

        _ = store.execute(.push(.settings))
        _ = store.executeBatch([.push(.detail(id: "123")), .pop])

        #expect(store.state.path == [.home, .settings])
        #expect(changeCount == 1)
        #expect(batchCount == 1)
    }

    @Test("Configuration initialPath validates before store creation")
    @MainActor
    func testConfigurationInitialPathValidation() {
        do {
            _ = try NavigationStore<TestRoute>(
                initialPath: [.settings],
                configuration: NavigationStoreConfiguration(
                    routeStackValidator: .rooted(at: .home)
                )
            )
            Issue.record("Expected validator to reject initial path")
        } catch let error as RouteStackValidationError<TestRoute> {
            #expect(error == .invalidRoot(expected: .home, actual: .settings))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    
    @Test("Push adds route to path")
    @MainActor
    func testPush() {
        let store = NavigationStore<TestRoute>()
        
        _ = store.execute(.push(.home))
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .home)
        
        _ = store.execute(.push(.detail(id: "123")))
        #expect(store.state.path.count == 2)
        #expect(store.state.path.last == .detail(id: "123"))
    }
    
    @Test("Pop removes last route")
    @MainActor
    func testPop() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        let result = store.execute(.pop)
        #expect(result == .success)
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Pop on empty returns emptyStack")
    @MainActor
    func testPopEmpty() {
        let store = NavigationStore<TestRoute>()
        
        let result = store.execute(.pop)
        #expect(result == .emptyStack)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("PopToRoot clears all routes")
    @MainActor
    func testPopToRoot() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        _ = store.execute(.popToRoot)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("Replace replaces entire stack")
    @MainActor
    func testReplace() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        _ = store.execute(.replace([.settings]))
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .settings)
    }
    
    @Test("Pop to specific route")
    @MainActor
    func testPopTo() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        let result = store.execute(.popTo(.detail(id: "123")))
        #expect(result == .success)
        #expect(store.state.path.count == 2)
        #expect(store.state.path.last == .detail(id: "123"))
    }

    @Test("Pop to nearest matching route when duplicates exist")
    @MainActor
    func testPopToNearestMatch() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings, .detail(id: "123"), .profile(userId: "u1", tab: 0)]
        )

        let result = store.execute(.popTo(.detail(id: "123")))

        #expect(result == .success)
        #expect(store.state.path == [.home, .detail(id: "123"), .settings, .detail(id: "123")])
    }
    
    @Test("onChange callback is called")
    @MainActor
    func testOnChange() {
        var changeCount = 0
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                }
            )
        )
        
        _ = store.execute(.push(.home))
        _ = store.execute(.push(.detail(id: "123")))
        _ = store.execute(.pop)
        
        #expect(changeCount == 3)
    }
}

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

// MARK: - NavigationIntent Tests

@Suite("NavigationIntent Tests")
struct NavigationIntentTests {
    @Test("NavigationStore send goMany uses batch execution for multiple routes")
    @MainActor
    func testSendGoMany() {
        var changeCount = 0
        var observedBatch: NavigationBatchResult<TestRoute>?
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { batch in
                    observedBatch = batch
                }
            )
        )

        store.send(.goMany([.home, .detail(id: "123"), .settings]))

        #expect(store.state.path == [.home, .detail(id: "123"), .settings])
        #expect(changeCount == 1)
        #expect(observedBatch?.requestedCommands == [.push(.home), .push(.detail(id: "123")), .push(.settings)])
        #expect(observedBatch?.executedCommands == [.push(.home), .push(.detail(id: "123")), .push(.settings)])
        #expect(observedBatch?.results == [.success, .success, .success])
    }

    @Test("NavigationStore send backBy pops expected count")
    @MainActor
    func testSendBackBy() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backBy(2))

        #expect(store.state.path == [.home])
    }

    @Test("NavigationStore send backBy zero routes through popCount semantics")
    @MainActor
    func testSendBackByZeroUsesPopCount() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.backBy(0))

        #expect(seenCommands == [.popCount(0)])
        #expect(store.state.path == [.home])
    }

    @Test("NavigationStore send backBy zero on empty stack still routes through popCount semantics")
    @MainActor
    func testSendBackByZeroOnEmptyUsesPopCount() {
        let store = NavigationStore<TestRoute>()
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.backBy(0))

        #expect(seenCommands == [.popCount(0)])
        #expect(store.state.path.isEmpty)
    }

    @Test("NavigationStore send backTo pops to matching route")
    @MainActor
    func testSendBackTo() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backTo(.detail(id: "123")))

        #expect(store.state.path == [.home, .detail(id: "123")])
    }

    @Test("NavigationStore send backToRoot clears stack")
    @MainActor
    func testSendBackToRoot() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backToRoot)

        #expect(store.state.path.isEmpty)
    }

    @Test("NavigationStore send replaceStack overwrites path via replace command")
    @MainActor
    func testSendReplaceStack() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.replaceStack([.settings]))

        #expect(seenCommands == [.replace([.settings])])
        #expect(store.state.path == [.settings])
    }

    @Test("NavigationStore send backOrPush pops to existing route")
    @MainActor
    func testSendBackOrPushWhenRouteExists() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.backOrPush(.detail(id: "123")))

        #expect(seenCommands == [.popTo(.detail(id: "123"))])
        #expect(store.state.path == [.home, .detail(id: "123")])
    }

    @Test("NavigationStore send backOrPush pushes when route is absent")
    @MainActor
    func testSendBackOrPushWhenRouteMissing() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.backOrPush(.settings))

        #expect(seenCommands == [.push(.settings)])
        #expect(store.state.path == [.home, .settings])
    }

    @Test("NavigationStore send pushUniqueRoot pushes when absent")
    @MainActor
    func testSendPushUniqueRootWhenAbsent() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.pushUniqueRoot(.settings))

        #expect(seenCommands == [.push(.settings)])
        #expect(store.state.path == [.home, .settings])
    }

    @Test("NavigationStore send pushUniqueRoot is a no-op when present")
    @MainActor
    func testSendPushUniqueRootWhenPresent() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.send(.pushUniqueRoot(.detail(id: "123")))

        #expect(seenCommands.isEmpty)
        #expect(store.state.path == [.home, .detail(id: "123"), .settings])
    }
}

// MARK: - Typed Case Binding Tests

private let testRouteDetailCase = CasePath<TestRoute, String>(
    embed: { TestRoute.detail(id: $0) },
    extract: { route in
        if case .detail(let id) = route { return id }
        return nil
    }
)

private let testModalProfileCase = CasePath<TestModalRoute, Void>(
    embed: { _ in TestModalRoute.profile },
    extract: { route in
        if case .profile = route { return () }
        return nil
    }
)

private enum TestBoundModalRoute: Route {
    case profile(id: String)
    case onboarding
}

private let testBoundModalProfileCase = CasePath<TestBoundModalRoute, String>(
    embed: { TestBoundModalRoute.profile(id: $0) },
    extract: { route in
        if case .profile(let id) = route { return id }
        return nil
    }
)

@Suite("Typed Case Binding Tests")
struct TypedCaseBindingTests {
    @Test("NavigationStore binding(case:) extracts when case matches top")
    @MainActor
    func testNavigationBindingExtracts() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "42")]
        )

        let binding = store.binding(case: testRouteDetailCase)

        #expect(binding.wrappedValue == "42")
    }

    @Test("NavigationStore binding(case:) returns nil when case does not match")
    @MainActor
    func testNavigationBindingReturnsNilForMismatch() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .settings])

        let binding = store.binding(case: testRouteDetailCase)

        #expect(binding.wrappedValue == nil)
    }

    @Test("NavigationStore binding(case:) push routes through middleware")
    @MainActor
    func testNavigationBindingPushUsesCommandPipeline() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testRouteDetailCase).wrappedValue = "99"

        #expect(seenCommands == [.push(.detail(id: "99"))])
        #expect(store.state.path == [.home, .detail(id: "99")])
    }

    @Test("NavigationStore binding(case:) rewrites matching top instead of pushing duplicate")
    @MainActor
    func testNavigationBindingRewritesMatchingTop() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "42")]
        )
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testRouteDetailCase).wrappedValue = "99"

        #expect(seenCommands == [.replace([.home, .detail(id: "99")])])
        #expect(store.state.path == [.home, .detail(id: "99")])
    }

    @Test("NavigationStore binding(case:) same value is a no-op")
    @MainActor
    func testNavigationBindingSameValueIsNoOp() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "42")]
        )
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testRouteDetailCase).wrappedValue = "42"

        #expect(seenCommands.isEmpty)
        #expect(store.state.path == [.home, .detail(id: "42")])
    }

    @Test("NavigationStore binding(case:) nil pops only when case matches top")
    @MainActor
    func testNavigationBindingNilPopsWhenCaseMatches() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "42")]
        )
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testRouteDetailCase).wrappedValue = nil

        #expect(seenCommands == [.pop])
        #expect(store.state.path == [.home])
    }

    @Test("NavigationStore binding(case:) nil is a no-op when case differs")
    @MainActor
    func testNavigationBindingNilNoOpForMismatch() throws {
        let store = try NavigationStore<TestRoute>(initialPath: [.home, .settings])
        var seenCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testRouteDetailCase).wrappedValue = nil

        #expect(seenCommands.isEmpty)
        #expect(store.state.path == [.home, .settings])
    }

    @Test("ModalStore binding(case:) extracts when current presentation matches")
    @MainActor
    func testModalBindingExtracts() {
        let store = ModalStore<TestModalRoute>()
        store.present(.profile, style: .sheet)

        let binding = store.binding(case: testModalProfileCase)

        #expect(binding.wrappedValue != nil)
    }

    @Test("ModalStore binding(case:style:) returns nil when style does not match")
    @MainActor
    func testModalBindingReturnsNilForStyleMismatch() {
        let store = ModalStore<TestModalRoute>()
        store.present(.profile, style: .fullScreenCover)

        let binding = store.binding(case: testModalProfileCase, style: .sheet)

        #expect(binding.wrappedValue == nil)
    }

    @Test("ModalStore binding(case:) present routes through command pipeline")
    @MainActor
    func testModalBindingPresentEmitsCommand() {
        let store = ModalStore<TestModalRoute>()
        var seenCommands: [ModalCommand<TestModalRoute>] = []

        store.addMiddleware(
            AnyModalMiddleware(
                willExecute: { command, _, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testModalProfileCase, style: .sheet).wrappedValue = ()

        #expect(seenCommands.count == 1)
        #expect(store.currentPresentation?.route == .profile)
    }

    @Test("ModalStore binding(case:style:) updates matching presentation without queueing")
    @MainActor
    func testModalBindingMatchingUpdateUsesReplaceCurrent() {
        let store = ModalStore<TestBoundModalRoute>()
        store.present(.profile(id: "42"), style: .sheet)
        let originalID = store.currentPresentation?.id
        var seenCommands: [ModalCommand<TestBoundModalRoute>] = []

        store.addMiddleware(
            AnyModalMiddleware(
                willExecute: { command, _, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testBoundModalProfileCase, style: .sheet).wrappedValue = "99"

        let expectedPresentation = ModalPresentation(
            id: originalID!,
            route: TestBoundModalRoute.profile(id: "99"),
            style: .sheet
        )
        #expect(seenCommands == [.replaceCurrent(expectedPresentation)])
        #expect(store.currentPresentation == expectedPresentation)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("ModalStore binding(case:style:) same value is a no-op")
    @MainActor
    func testModalBindingSameValueIsNoOp() {
        let store = ModalStore<TestBoundModalRoute>()
        store.present(.profile(id: "42"), style: .sheet)
        let originalPresentation = store.currentPresentation
        var seenCommands: [ModalCommand<TestBoundModalRoute>] = []

        store.addMiddleware(
            AnyModalMiddleware(
                willExecute: { command, _, _ in
                    seenCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.binding(case: testBoundModalProfileCase, style: .sheet).wrappedValue = "42"

        #expect(seenCommands.isEmpty)
        #expect(store.currentPresentation == originalPresentation)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("ModalStore binding(case:) nil dismisses when case matches current")
    @MainActor
    func testModalBindingNilDismissesWhenMatching() {
        let store = ModalStore<TestModalRoute>()
        store.present(.profile, style: .sheet)

        store.binding(case: testModalProfileCase).wrappedValue = nil

        #expect(store.currentPresentation == nil)
    }

    @Test("ModalStore binding(case:style:) nil uses systemDismiss reason")
    @MainActor
    func testModalBindingNilUsesSystemDismissReason() {
        let dismissed = Mutex<[(ModalPresentation<TestModalRoute>, ModalDismissalReason)]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onDismissed: { presentation, reason in
                    dismissed.withLock { $0.append((presentation, reason)) }
                }
            )
        )
        store.present(.profile, style: .sheet)

        store.binding(case: testModalProfileCase, style: .sheet).wrappedValue = nil

        #expect(dismissed.withLock(\.count) == 1)
        #expect(dismissed.withLock(\.first)?.0.route == .profile)
        #expect(dismissed.withLock(\.first)?.1 == .systemDismiss)
    }

    @Test("ModalStore binding(case:style:) nil ignores mismatched style")
    @MainActor
    func testModalBindingNilIgnoresStyleMismatch() {
        let store = ModalStore<TestModalRoute>()
        store.present(.profile, style: .fullScreenCover)

        store.binding(case: testModalProfileCase, style: .sheet).wrappedValue = nil

        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .fullScreenCover)
    }
}

// MARK: - NavigationPathBinding Tests

@Suite("NavigationPathBinding Tests")
struct NavigationPathBindingTests {
    @Test("Path binding shrink uses popCount")
    @MainActor
    func testPathBindingShrinkUsesPopCount() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.home, .detail(id: "123")]

        #expect(executedCommands == [.popCount(1)])
        #expect(store.state.path == [.home, .detail(id: "123")])
    }

    @Test("Path binding root shrink uses popToRoot")
    @MainActor
    func testPathBindingRootShrinkUsesPopToRoot() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = []

        #expect(executedCommands == [.popToRoot])
        #expect(store.state.path.isEmpty)
    }

    @Test("Path binding expansion uses batch push execution")
    @MainActor
    func testPathBindingExpansionUsesBatchPushes() throws {
        var changeCount = 0
        var observedBatch: NavigationBatchResult<TestRoute>?
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { batch in
                    observedBatch = batch
                }
            )
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.home, .detail(id: "123"), .settings]

        #expect(executedCommands == [.push(.detail(id: "123")), .push(.settings)])
        #expect(store.state.path == [.home, .detail(id: "123"), .settings])
        #expect(changeCount == 1)
        #expect(observedBatch?.requestedCommands == [.push(.detail(id: "123")), .push(.settings)])
        #expect(observedBatch?.executedCommands == [.push(.detail(id: "123")), .push(.settings)])
        #expect(observedBatch?.results == [.success, .success])
    }

    @Test("Path binding non-prefix rewrite falls back to replace")
    @MainActor
    func testPathBindingNonPrefixRewriteUsesReplace() throws {
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123")]
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.home, .settings]

        #expect(executedCommands == [.replace([.home, .settings])])
        #expect(store.state.path == [.home, .settings])
    }

    @Test("Path binding non-prefix rewrite can ignore changes")
    @MainActor
    func testPathBindingNonPrefixRewriteIgnore() throws {
        var changeCount = 0
        var batchCount = 0
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123")],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .ignore,
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { _ in
                    batchCount += 1
                }
            )
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.home, .settings]

        #expect(executedCommands.isEmpty)
        #expect(changeCount == 0)
        #expect(batchCount == 0)
        #expect(store.state.path == [.home, .detail(id: "123")])
    }

    @Test("Path binding non-prefix rewrite custom single resolution runs execute")
    @MainActor
    func testPathBindingNonPrefixRewriteCustomSingle() throws {
        let store = NavigationStore<TestRoute>(
            initial: try validatedStack([.home, .detail(id: "123")]),
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .custom { _, _ in
                    .single(.popToRoot)
                }
            )
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.home, .settings]

        #expect(executedCommands == [.popToRoot])
        #expect(store.state.path.isEmpty)
    }

    @Test("Path binding non-prefix rewrite custom batch resolution runs executeBatch")
    @MainActor
    func testPathBindingNonPrefixRewriteCustomBatch() throws {
        var changeCount = 0
        var observedBatch: NavigationBatchResult<TestRoute>?
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .custom { _, _ in
                    .batch([.push(.settings), .push(.detail(id: "123"))])
                },
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { batch in
                    observedBatch = batch
                }
            )
        )
        var executedCommands: [NavigationCommand<TestRoute>] = []

        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    executedCommands.append(command)
                    return .proceed(command)
                }
            )
        )

        store.pathBinding.wrappedValue = [.settings]

        #expect(executedCommands == [.push(.settings), .push(.detail(id: "123"))])
        #expect(changeCount == 1)
        #expect(observedBatch?.requestedCommands == [.push(.settings), .push(.detail(id: "123"))])
        #expect(store.state.path == [.home, .settings, .detail(id: "123")])
    }

    @Test("Path binding non-prefix rewrite assert-and-replace reports and falls back")
    @MainActor
    func testPathBindingNonPrefixRewriteAssertAndReplace() throws {
        var assertionCount = 0
        let store = NavigationStore<TestRoute>(
            initial: try validatedStack([.home, .detail(id: "123")]),
            configuration: NavigationStoreConfiguration(
                pathMismatchPolicy: .assertAndReplace
            ),
            nonPrefixAssertionHandler: { _, _ in
                assertionCount += 1
            }
        )

        store.pathBinding.wrappedValue = [.home, .settings]

        #expect(assertionCount == 1)
        #expect(store.state.path == [.home, .settings])
    }
}

// MARK: - NavigationBatch Tests

@Suite("NavigationBatch Tests")
struct NavigationBatchTests {
    @Test("Execute batch records snapshots, middleware, and observer once")
    @MainActor
    func testExecuteBatchCapturesSnapshots() throws {
        var changeCount = 0
        var observedBatch: NavigationBatchResult<TestRoute>?
        let store = try NavigationStore<TestRoute>(
            initialPath: [.home],
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onBatchExecuted: { batch in
                    observedBatch = batch
                }
            )
        )
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

        let batch = store.executeBatch([.push(.detail(id: "123")), .push(.settings)])

        #expect(batch.requestedCommands == [.push(.detail(id: "123")), .push(.settings)])
        #expect(batch.executedCommands == [.push(.detail(id: "123")), .push(.settings)])
        #expect(batch.results == [.success, .success])
        #expect(batch.stateBefore == (try validatedStack([.home])))
        #expect(batch.stateAfter == (try validatedStack([.home, .detail(id: "123"), .settings])))
        #expect(batch.hasStoppedOnFailure == false)
        #expect(batch.isSuccess == true)
        #expect(store.state == batch.stateAfter)
        #expect(changeCount == 1)
        #expect(observedBatch == batch)
        #expect(willCount == 2)
        #expect(didCount == 2)
    }

    @Test("Execute batch can stop on first failure")
    @MainActor
    func testExecuteBatchStopOnFailure() throws {
        var changeCount = 0
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                }
            )
        )

        let batch = store.executeBatch(
            [.push(.home), .popCount(5), .push(.settings)],
            stopOnFailure: true
        )

        #expect(batch.requestedCommands == [.push(.home), .popCount(5), .push(.settings)])
        #expect(batch.executedCommands == [.push(.home), .popCount(5)])
        #expect(batch.results == [.success, .insufficientStackDepth(requested: 5, available: 1)])
        #expect(batch.stateBefore == RouteStack<TestRoute>())
        #expect(batch.stateAfter == (try validatedStack([.home])))
        #expect(batch.hasStoppedOnFailure == true)
        #expect(batch.isSuccess == false)
        #expect(store.state.path == [.home])
        #expect(changeCount == 1)
    }

    @Test("Execute batch records middleware-rewritten commands")
    @MainActor
    func testExecuteBatchTracksActualExecutedCommands() {
        let store = NavigationStore<TestRoute>()
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    switch command {
                    case .push(.home):
                        return .proceed(.push(.settings))
                    default:
                        return .proceed(command)
                    }
                }
            ),
            debugName: "rewrite"
        )

        let batch = store.executeBatch([.push(.home), .push(.detail(id: "123"))])

        #expect(batch.requestedCommands == [.push(.home), .push(.detail(id: "123"))])
        #expect(batch.executedCommands == [.push(.settings), .push(.detail(id: "123"))])
        #expect(store.state.path == [.settings, .detail(id: "123")])
    }

    @Test("Sequence and batch keep different observation semantics")
    @MainActor
    func testSequenceAndBatchObservationDifference() {
        var sequenceChanges = 0
        var sequenceBatchCount = 0
        let sequenceStore = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    sequenceChanges += 1
                },
                onBatchExecuted: { _ in
                    sequenceBatchCount += 1
                }
            )
        )

        _ = sequenceStore.execute(.sequence([.push(.home), .push(.settings)]))

        var batchChanges = 0
        var batchObserverCount = 0
        let batchStore = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    batchChanges += 1
                },
                onBatchExecuted: { _ in
                    batchObserverCount += 1
                }
            )
        )

        _ = batchStore.executeBatch([.push(.home), .push(.settings)])

        #expect(sequenceStore.state == batchStore.state)
        #expect(sequenceChanges == 2)
        #expect(sequenceBatchCount == 0)
        #expect(batchChanges == 1)
        #expect(batchObserverCount == 1)
    }

    @Test("Middleware handles support insert move replace and remove")
    @MainActor
    func testMiddlewareHandleOperations() {
        let store = NavigationStore<TestRoute>()
        var invocationOrder: [String] = []

        let first = store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    invocationOrder.append("first")
                    return .proceed(command)
                }
            ),
            debugName: "first"
        )
        let second = store.insertMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    invocationOrder.append("second")
                    return .proceed(command)
                }
            ),
            at: 0,
            debugName: "second"
        )
        #expect(store.middlewareHandles == [second, first])
        #expect(store.middlewareMetadata.map(\.debugName) == ["second", "first"])

        let moved = store.moveMiddleware(first, to: 0)
        #expect(moved == true)
        #expect(store.middlewareHandles == [first, second])
        #expect(store.middlewareMetadata.map(\.debugName) == ["first", "second"])

        let replaced = store.replaceMiddleware(
            second,
            with: AnyNavigationMiddleware(
                willExecute: { command, _ in
                    invocationOrder.append("second-replaced")
                    return .proceed(command)
                }
            ),
            debugName: "second-replaced"
        )
        #expect(replaced == true)
        #expect(store.middlewareMetadata.map(\.debugName) == ["first", "second-replaced"])

        _ = store.execute(.push(.home))
        #expect(invocationOrder == ["first", "second-replaced"])

        let removed = store.removeMiddleware(first)
        #expect(removed != nil)
        #expect(store.middlewareHandles == [second])
        #expect(store.middlewareMetadata.map(\.debugName) == ["second-replaced"])

        invocationOrder.removeAll()
        _ = store.execute(.push(.settings))
        #expect(invocationOrder == ["second-replaced"])
    }

    @Test("Initializer middlewares receive stable handles in order")
    @MainActor
    func testInitializerMiddlewaresReceiveHandles() {
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                middlewares: [
                    NavigationMiddlewareRegistration(
                        middleware: AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) }),
                        debugName: "first"
                    ),
                    NavigationMiddlewareRegistration(
                        middleware: AnyNavigationMiddleware(willExecute: { command, _ in .proceed(command) }),
                        debugName: "second"
                    )
                ]
            )
        )

        #expect(store.middlewareHandles.count == 2)
        #expect(Set(store.middlewareHandles).count == 2)
        #expect(store.middlewareMetadata.map(\.debugName) == ["first", "second"])
    }
}

// MARK: - NavigationTransaction Tests

@Suite("NavigationTransaction Tests")
struct NavigationTransactionTests {
    @Test("Execute transaction commits once and notifies observers once")
    @MainActor
    func testExecuteTransactionCommit() throws {
        var changeCount = 0
        var transactionObserver: NavigationTransactionResult<TestRoute>?
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onTransactionExecuted: { transaction in
                    transactionObserver = transaction
                }
            )
        )
        var didExecuteOrder: [NavigationCommand<TestRoute>] = []
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in .proceed(command) },
                didExecute: { command, result, _ in
                    didExecuteOrder.append(command)
                    return result
                }
            ),
            debugName: "tracking"
        )

        let transaction = store.executeTransaction([.push(.home), .push(.settings)])

        #expect(transaction.isCommitted == true)
        #expect(transaction.failureIndex == nil)
        #expect(transaction.results == [.success, .success])
        #expect(transaction.stateBefore == RouteStack<TestRoute>())
        #expect(transaction.stateAfter == (try validatedStack([.home, .settings])))
        #expect(store.state == (try validatedStack([.home, .settings])))
        #expect(changeCount == 1)
        #expect(didExecuteOrder == [.push(.home), .push(.settings)])
        #expect(transactionObserver == transaction)
    }

    @Test("Execute transaction rolls back state on failure")
    @MainActor
    func testExecuteTransactionRollbackOnFailure() {
        var changeCount = 0
        var transactionObserver: NavigationTransactionResult<TestRoute>?
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                },
                onTransactionExecuted: { transaction in
                    transactionObserver = transaction
                }
            )
        )
        var didExecuteCount = 0
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in .proceed(command) },
                didExecute: { _, result, _ in
                    didExecuteCount += 1
                    return result
                }
            )
        )

        let transaction = store.executeTransaction([.push(.home), .popCount(5)])

        #expect(transaction.isCommitted == false)
        #expect(transaction.failureIndex == 1)
        #expect(transaction.results == [.success, .insufficientStackDepth(requested: 5, available: 1)])
        #expect(transaction.stateBefore == RouteStack<TestRoute>())
        #expect(transaction.stateAfter == RouteStack<TestRoute>())
        #expect(store.state == RouteStack<TestRoute>())
        #expect(changeCount == 0)
        #expect(didExecuteCount == 0)
        #expect(transactionObserver == transaction)
    }

    @Test("Execute transaction uses rewritten commands and folded results")
    @MainActor
    func testExecuteTransactionUsesActualCommandsAndFoldedResults() throws {
        let store = NavigationStore<TestRoute>()
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    switch command {
                    case .push(.home):
                        return .proceed(.push(.settings))
                    default:
                        return .proceed(command)
                    }
                },
                didExecute: { command, result, _ in
                    if command == .push(.settings) {
                        return .multiple([result])
                    }
                    return result
                }
            ),
            debugName: "rewrite"
        )

        let transaction = store.executeTransaction([.push(.home), .push(.detail(id: "123"))])

        #expect(transaction.executedCommands == [.push(.settings), .push(.detail(id: "123"))])
        #expect(transaction.results == [.multiple([.success]), .success])
        #expect(transaction.isCommitted == true)
        #expect(store.state == (try validatedStack([.settings, .detail(id: "123")])))
    }

    @Test("Sequence preserves partial success while transaction rolls back")
    @MainActor
    func testSequenceAndTransactionDifferOnFailure() {
        let sequenceStore = NavigationStore<TestRoute>()
        let transactionStore = NavigationStore<TestRoute>()

        let sequenceResult = sequenceStore.execute(.sequence([.push(.home), .popCount(5)]))
        let transactionResult = transactionStore.executeTransaction([.push(.home), .popCount(5)])

        #expect(sequenceResult == .multiple([.success, .insufficientStackDepth(requested: 5, available: 1)]))
        #expect(sequenceStore.state.path == [.home])
        #expect(transactionResult.results == [.success, .insufficientStackDepth(requested: 5, available: 1)])
        #expect(transactionResult.isCommitted == false)
        #expect(transactionStore.state.path.isEmpty)
    }
}

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

// MARK: - Property Test Helpers

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }

    mutating func nextBool() -> Bool {
        (next() & 1) == 0
    }
}

private func validatedStack<R: Route>(_ path: [R]) throws -> RouteStack<R> {
    try RouteStack(validating: path)
}

private let allTestRoutes: [TestRoute] = [
    .home,
    .settings,
    .detail(id: "123"),
    .detail(id: "456"),
    .profile(userId: "u1", tab: 0),
    .profile(userId: "u2", tab: 1)
]

private func randomRoute(rng: inout SeededGenerator) -> TestRoute {
    allTestRoutes[rng.nextInt(upperBound: allTestRoutes.count)]
}

private func randomRouteList(rng: inout SeededGenerator) -> [TestRoute] {
    let count = rng.nextInt(upperBound: 4)
    return (0..<count).map { _ in randomRoute(rng: &rng) }
}

private func randomNavigationCommand(
    rng: inout SeededGenerator,
    currentPath: [TestRoute],
    depth: Int
) -> NavigationCommand<TestRoute> {
    let allowSequence = depth < 2
    let upperBound = allowSequence ? 8 : 7

    switch rng.nextInt(upperBound: upperBound) {
    case 0:
        return .push(randomRoute(rng: &rng))
    case 1:
        return .pushAll(randomRouteList(rng: &rng))
    case 2:
        return .pop
    case 3:
        let requested = rng.nextInt(upperBound: 4)
        return .popCount(requested)
    case 4:
        return .popToRoot
    case 5:
        if !currentPath.isEmpty, rng.nextBool() {
            return .popTo(currentPath[rng.nextInt(upperBound: currentPath.count)])
        }
        return .popTo(randomRoute(rng: &rng))
    case 6:
        return .replace(randomRouteList(rng: &rng))
    default:
        let count = rng.nextInt(upperBound: 3) + 1
        let commands = (0..<count).map { _ in
            randomNavigationCommand(rng: &rng, currentPath: currentPath, depth: depth + 1)
        }
        return .sequence(commands)
    }
}

private func previewReferenceResult(
    _ command: NavigationCommand<TestRoute>,
    path: [TestRoute]
) -> NavigationResult<TestRoute> {
    var copy = path
    return applyReference(command, to: &copy)
}

private func applyReference(
    _ command: NavigationCommand<TestRoute>,
    to path: inout [TestRoute]
) -> NavigationResult<TestRoute> {
    switch command {
    case .push(let route):
        path.append(route)
        return .success

    case .pushAll(let routes):
        path.append(contentsOf: routes)
        return .success

    case .pop:
        guard !path.isEmpty else { return .emptyStack }
        _ = path.removeLast()
        return .success

    case .popCount(let count):
        guard count > 0 else { return .invalidPopCount(count) }
        guard count <= path.count else {
            return .insufficientStackDepth(requested: count, available: path.count)
        }
        path.removeLast(count)
        return .success

    case .popToRoot:
        path.removeAll()
        return .success

    case .popTo(let route):
        guard let index = path.lastIndex(of: route) else { return .routeNotFound(route) }
        path = Array(path.prefix(through: index))
        return .success

    case .replace(let routes):
        path = routes
        return .success

    case .sequence(let commands):
        let results = commands.map { applyReference($0, to: &path) }
        return .multiple(results)

    case .whenCancelled(let primary, let fallback):
        let snapshot = path
        let primaryResult = applyReference(primary, to: &path)
        if primaryResult.isSuccess {
            return primaryResult
        }
        path = snapshot
        return applyReference(fallback, to: &path)
    }
}

// MARK: - DeepLink Tests

@Suite("DeepLink Tests")
struct DeepLinkTests {
    
    @Test("DeepLinkParser parses URL correctly")
    func testParser() {
        let parsed = DeepLinkParser.parse("myapp://example.com/products/123?category=electronics")!
        
        #expect(parsed.scheme == "myapp")
        #expect(parsed.host == "example.com")
        #expect(parsed.path == ["products", "123"])
        #expect(parsed.queryItems["category"] == ["electronics"])
        #expect(parsed.firstQueryItems["category"] == "electronics")
    }

    @Test("DeepLinkParser keeps duplicate query values without crashing")
    func testParserDuplicateQueries() {
        let parsed = DeepLinkParser.parse("myapp://example.com/products/123?tag=a&tag=b&tag=c")!
        #expect(parsed.queryItems["tag"] == ["a", "b", "c"])
        #expect(parsed.firstQueryItems["tag"] == "a")
    }

    @Test("DeepLinkParser keeps flag-style query items as empty strings")
    func testParserFlagQueryItem() {
        let parsed = DeepLinkParser.parse("myapp://example.com/products/123?debug&tag=a")!
        #expect(parsed.queryItems["debug"] == [""])
        #expect(parsed.firstQueryItems["debug"] == "")
        #expect(parsed.queryItems["tag"] == ["a"])
    }

    @Test("DeepLinkParameters preserves duplicate query value order")
    func testDeepLinkParametersValueOrder() {
        let parameters = DeepLinkParameters(valuesByName: ["tag": ["a", "b", "c"]])
        #expect(parameters.values(forName: "tag") == ["a", "b", "c"])
        #expect(parameters.firstValue(forName: "tag") == "a")
    }

    @Test("Path parameters take precedence when query uses same key")
    func testPatternMergeCollisionOrder() {
        let pattern = DeepLinkPattern("/products/:id")
        let parsed = DeepLinkParser.parse("myapp://example.com/products/123?id=override&id=final")!

        guard let result = pattern.match(parsed) else {
            Issue.record("Expected pattern match")
            return
        }

        #expect(result.parameters["id"] == ["123", "override", "final"])

        let parameters = DeepLinkParameters(valuesByName: result.parameters)
        #expect(parameters.firstValue(forName: "id") == "123")
    }
    
    @Test("DeepLinkPattern matches literal path")
    func testPatternLiteral() {
        let pattern = DeepLinkPattern("/home")
        
        let result = pattern.match("/home")
        #expect(result != nil)
        #expect(result?.parameters.isEmpty == true)
        
        let noMatch = pattern.match("/settings")
        #expect(noMatch == nil)
    }
    
    @Test("DeepLinkPattern matches parameter")
    func testPatternParameter() {
        let pattern = DeepLinkPattern("/products/:id")
        
        let result = pattern.match("/products/123")
        #expect(result != nil)
        #expect(result?.parameters["id"] == ["123"])
    }
    
    @Test("DeepLinkPattern matches wildcard")
    func testPatternWildcard() {
        let pattern = DeepLinkPattern("/api/*")
        
        let result = pattern.match("/api/v1/users/123")
        #expect(result != nil)
    }
    
    @Test("DeepLinkMatcher finds matching route")
    func testMatcher() {
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/home") { _ in .home }
            DeepLinkMapping("/detail/:id") { params in
                guard let id = params.firstValue(forName: "id") else { return nil }
                return .detail(id: id)
            }
            DeepLinkMapping("/settings") { _ in .settings }
        }
        
        let url1 = URL(string: "myapp://app/home")!
        #expect(matcher.match(url1) == .home)
        
        let url2 = URL(string: "myapp://app/detail/456")!
        #expect(matcher.match(url2) == .detail(id: "456"))
        
        let url3 = URL(string: "myapp://app/unknown")!
        #expect(matcher.match(url3) == nil)
    }

    @Test("DeepLinkMatcher surfaces duplicate pattern diagnostics")
    func testMatcherDuplicatePatternDiagnostics() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            DeepLinkMapping("/home") { _ in .home }
            DeepLinkMapping("/home") { _ in .settings }
        }

        #expect(
            matcher.diagnostics == [
                .duplicatePattern(pattern: "/home", firstIndex: 0, duplicateIndex: 1)
            ]
        )
    }

    @Test("DeepLinkMatcher surfaces wildcard shadowing diagnostics")
    func testMatcherWildcardShadowingDiagnostics() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            DeepLinkMapping("/api/*") { _ in .home }
            DeepLinkMapping("/api/users") { _ in .settings }
        }

        #expect(
            matcher.diagnostics == [
                .wildcardShadowing(
                    pattern: "/api/*",
                    index: 0,
                    shadowedPattern: "/api/users",
                    shadowedIndex: 1
                )
            ]
        )
    }

    @Test("DeepLinkMatcher surfaces parameter shadowing diagnostics")
    func testMatcherParameterShadowingDiagnostics() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            DeepLinkMapping("/products/:id") { _ in .detail(id: "generic") }
            DeepLinkMapping("/products/featured") { _ in .settings }
        }

        #expect(
            matcher.diagnostics == [
                .parameterShadowing(
                    pattern: "/products/:param",
                    index: 0,
                    shadowedPattern: "/products/featured",
                    shadowedIndex: 1
                )
            ]
        )
    }

    @Test("DeepLinkMatcher treats renamed parameters as equivalent structure")
    func testMatcherParameterNameOnlyShadowingDiagnostics() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            DeepLinkMapping("/users/:id") { _ in .detail(id: "id") }
            DeepLinkMapping("/users/:slug") { _ in .detail(id: "slug") }
        }

        #expect(
            matcher.diagnostics == [
                .duplicatePattern(pattern: "/users/:param", firstIndex: 0, duplicateIndex: 1)
            ]
        )
    }

    @Test("DeepLinkMatcher debug warnings remain non-fatal")
    func testMatcherDebugWarningsDoNotAssert() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(
                diagnosticsMode: .debugWarnings,
                logger: Logger(subsystem: "InnoRouterTests", category: "DeepLinkMatcher")
            )
        ) {
            DeepLinkMapping("/products/:id") { _ in .detail(id: "generic") }
            DeepLinkMapping("/products/featured") { _ in .settings }
        }

        #expect(matcher.diagnostics.count == 1)
    }

    @Test("DeepLinkMatcher diagnostics do not change declaration-order precedence")
    func testMatcherDiagnosticsDoNotAffectMatchingPrecedence() {
        let matcher = DeepLinkMatcher<TestRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            DeepLinkMapping("/products/:id") { _ in .detail(id: "generic") }
            DeepLinkMapping("/products/featured") { _ in .settings }
        }

        let matched = matcher.match(URL(string: "myapp://app/products/featured")!)

        #expect(matched == .detail(id: "generic"))
        #expect(matcher.diagnostics.count == 1)
    }

    @Test("DeepLinkPipeline rejected reason is schemeNotAllowed")
    func testPipelineRejectsSchemeWithReason() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            allowedSchemes: ["myapp"],
            resolve: { _ in .home }
        )
        let url = URL(string: "https://myapp.com/home")!

        let decision = pipeline.decide(for: url)
        guard case .rejected(let reason) = decision else {
            Issue.record("Expected rejected decision")
            return
        }
        #expect(reason == .schemeNotAllowed(actualScheme: "https"))
    }

    @Test("DeepLinkPipeline rejected reason is hostNotAllowed")
    func testPipelineRejectsHostWithReason() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            allowedHosts: ["myapp.com"],
            resolve: { _ in .home }
        )
        let url = URL(string: "myapp://other.com/home")!

        let decision = pipeline.decide(for: url)
        guard case .rejected(let reason) = decision else {
            Issue.record("Expected rejected decision")
            return
        }
        #expect(reason == .hostNotAllowed(actualHost: "other.com"))
    }

    @Test("DeepLinkPipeline keeps URL in unhandled decision")
    func testPipelineUnhandledKeepsURL() {
        let pipeline = DeepLinkPipeline<TestRoute>(resolve: { _ in nil })
        let url = URL(string: "myapp://myapp.com/missing")!

        let decision = pipeline.decide(for: url)
        guard case .unhandled(let unhandledURL) = decision else {
            Issue.record("Expected unhandled decision")
            return
        }
        #expect(unhandledURL == url)
    }

    @Test("DeepLinkPipeline notRequired policy returns plan")
    func testPipelineNotRequiredPolicyReturnsPlan() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { _ in .settings },
            authenticationPolicy: .notRequired
        )
        let url = URL(string: "myapp://myapp.com/settings")!

        let decision = pipeline.decide(for: url)
        guard case .plan(let plan) = decision else {
            Issue.record("Expected plan decision")
            return
        }
        #expect(plan.commands == [.push(.settings)])
    }
}

// MARK: - Coordinator Tests

@Suite("Coordinator Tests")
struct CoordinatorTests {
    
    @Observable
    @MainActor
    final class TestCoordinator: Coordinator {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView
        
        let store = NavigationStore<TestRoute>()
        var handleCount = 0
        
        func handle(_ intent: NavigationIntent<TestRoute>) {
            handleCount += 1
            switch intent {
            case .go(let route):
                _ = store.execute(.push(route))
            default:
                break
            }
        }
        
        @ViewBuilder
        func destination(for route: TestRoute) -> EmptyView {
            EmptyView()
        }
    }

    @Observable
    @MainActor
    final class DefaultBehaviorCoordinator: Coordinator {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView

        let store = NavigationStore<TestRoute>()

        @ViewBuilder
        func destination(for route: TestRoute) -> EmptyView {
            EmptyView()
        }
    }
    
    @Test("Coordinator routes via send intent")
    @MainActor
    func testNavigate() {
        let coordinator = TestCoordinator()
        
        coordinator.send(.go(.home))
        coordinator.send(.go(.detail(id: "123")))
        
        #expect(coordinator.handleCount == 2)
        #expect(coordinator.store.state.path.count == 2)
    }
    
    @Test("Coordinator send back pops")
    @MainActor
    func testGoBack() {
        let coordinator = DefaultBehaviorCoordinator()
        _ = coordinator.store.execute(.push(.home))
        _ = coordinator.store.execute(.push(.detail(id: "123")))
        
        coordinator.send(.back)
        
        #expect(coordinator.store.state.path.last == .home)
    }
    
    @Test("Coordinator send backToRoot clears stack")
    @MainActor
    func testGoToRoot() {
        let coordinator = DefaultBehaviorCoordinator()
        _ = coordinator.store.execute(.push(.home))
        _ = coordinator.store.execute(.push(.detail(id: "123")))
        
        coordinator.send(.backToRoot)
        
        #expect(coordinator.store.state.path.isEmpty)
    }

    @Test("Coordinator dispatcher sends intent to handle")
    @MainActor
    func testNavigationIntentDispatcher() {
        let coordinator = TestCoordinator()

        coordinator.navigationIntentDispatcher.send(.go(.home))

        #expect(coordinator.handleCount == 1)
        #expect(coordinator.store.state.path == [.home])
    }

    @Test("Default coordinator supports goMany/backBy/backTo/backToRoot")
    @MainActor
    func testDefaultCoordinatorIntentSet() {
        let coordinator = DefaultBehaviorCoordinator()

        coordinator.send(.goMany([.home, .detail(id: "123"), .settings]))
        #expect(coordinator.store.state.path == [.home, .detail(id: "123"), .settings])

        coordinator.send(.backBy(1))
        #expect(coordinator.store.state.path == [.home, .detail(id: "123")])

        coordinator.send(.backTo(.home))
        #expect(coordinator.store.state.path == [.home])

        coordinator.send(.backToRoot)
        #expect(coordinator.store.state.path.isEmpty)
    }

    @Test("CoordinatorSplitHost body can be constructed")
    @MainActor
    func testCoordinatorSplitHostConstruction() {
        let coordinator = DefaultBehaviorCoordinator()
        let host = CoordinatorSplitHost(coordinator: coordinator) {
            Text("Sidebar")
        } root: {
            Text("Root")
        }

        _ = host.body
        coordinator.send(.go(.settings))

        #expect(coordinator.store.state.path == [.settings])
    }
}

// MARK: - Coordinator DeepLink Tests

@Suite("Coordinator DeepLink Tests")
struct CoordinatorDeepLinkTests {
    @Observable
    @MainActor
    final class DeepLinkCoordinator: DeepLinkCoordinating {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView

        let store = NavigationStore<TestRoute>()

        var pendingDeepLink: PendingDeepLink<TestRoute>?
        let deepLinkPipeline: DeepLinkPipeline<TestRoute>

        init(deepLinkPipeline: DeepLinkPipeline<TestRoute>) {
            self.deepLinkPipeline = deepLinkPipeline
        }

        @ViewBuilder
        func destination(for route: TestRoute) -> EmptyView {
            EmptyView()
        }
    }

    @Test("DeepLink plan executes into store")
    @MainActor
    func testDeepLinkPlanExecutes() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { _ in .settings }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)

        let outcome = coordinator.handleDeepLink(URL(string: "myapp://myapp.com/anything")!)

        guard case .executed(let plan, _) = outcome else {
            Issue.record("expected .executed, got \(outcome)")
            return
        }
        #expect(plan.commands == [.push(.settings)])
        #expect(coordinator.store.state.path.last == .settings)
        #expect(coordinator.pendingDeepLink == nil)
    }

    @Test("handleDeepLink returns .rejected for disallowed scheme")
    @MainActor
    func testHandleDeepLinkReturnsRejectedForDisallowedScheme() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            allowedSchemes: ["myapp"],
            resolve: { _ in .settings }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)

        let outcome = coordinator.handleDeepLink(URL(string: "https://other.com/secure")!)

        guard case .rejected(let reason) = outcome else {
            Issue.record("expected .rejected, got \(outcome)")
            return
        }
        #expect(reason == .schemeNotAllowed(actualScheme: "https"))
        #expect(coordinator.store.state.path.isEmpty)
        #expect(coordinator.pendingDeepLink == nil)
    }

    @Test("handleDeepLink returns .unhandled for unresolved URL")
    @MainActor
    func testHandleDeepLinkReturnsUnhandledForUnresolvedURL() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { _ in nil }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)
        let url = URL(string: "myapp://myapp.com/nowhere")!

        let outcome = coordinator.handleDeepLink(url)

        guard case .unhandled(let unhandledURL) = outcome else {
            Issue.record("expected .unhandled, got \(outcome)")
            return
        }
        #expect(unhandledURL == url)
        #expect(coordinator.store.state.path.isEmpty)
        #expect(coordinator.pendingDeepLink == nil)
    }

    @Test("DeepLink pending is stored")
    @MainActor
    func testDeepLinkPendingStored() {
        let pipeline = DeepLinkPipeline<TestRoute>(
            allowedSchemes: ["myapp"],
            allowedHosts: ["myapp.com"],
            resolve: { _ in .settings },
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { false }
            )
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)

        coordinator.handleDeepLink(URL(string: "myapp://myapp.com/secure")!)

        #expect(coordinator.store.state.path.isEmpty)
        #expect(coordinator.pendingDeepLink?.route == .settings)
        #expect(coordinator.pendingDeepLink?.plan.commands == [.push(.settings)])
    }

    @Test("Pending deep link preserves planned commands")
    @MainActor
    func testPendingDeepLinkPreservesPlan() {
        let planCommands: [NavigationCommand<TestRoute>] = [
            .replace([.home, .settings]),
            .push(.detail(id: "123"))
        ]
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { _ in .settings },
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { false }
            ),
            plan: { _ in NavigationPlan(commands: planCommands) }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)

        coordinator.handleDeepLink(URL(string: "myapp://myapp.com/secure")!)

        #expect(coordinator.pendingDeepLink?.plan.commands == planCommands)
    }

    @Test("Async coordinator deep-link guard keeps pending until authorized")
    @MainActor
    func testResumePendingDeepLinkIfAllowed() async {
        let authState = Mutex(false)
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { _ in .settings },
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { authState.withLock { $0 } }
            ),
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)
        coordinator.handleDeepLink(URL(string: "myapp://myapp.com/secure")!)

        let denied = await coordinator.resumePendingDeepLinkIfAllowed { _ in false }
        if case .pending = denied {
            // expected
        } else {
            Issue.record("expected .pending after denied authorization, got \(denied)")
        }
        #expect(coordinator.pendingDeepLink != nil)
        #expect(coordinator.store.state.path.isEmpty)

        authState.withLock { $0 = true }
        let resumed = await coordinator.resumePendingDeepLinkIfAllowed { _ in true }
        if case .executed = resumed {
            // expected
        } else {
            Issue.record("expected .executed after authorization, got \(resumed)")
        }
        #expect(coordinator.pendingDeepLink == nil)
        #expect(coordinator.store.state.path == [.home, .settings])
    }

    @Test("Async coordinator deep-link guard does not resume stale pending deep links")
    @MainActor
    func testResumePendingDeepLinkIfAllowedUsesCurrentPendingIdentity() async {
        let pipeline = DeepLinkPipeline<TestRoute>(
            resolve: { url in
                url.path.contains("home") ? .home : .settings
            },
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { false }
            ),
            plan: { route in NavigationPlan(commands: [.push(route)]) }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)
        coordinator.handleDeepLink(URL(string: "myapp://myapp.com/settings")!)

        let resumed = await coordinator.resumePendingDeepLinkIfAllowed { _ in
            coordinator.handleDeepLink(URL(string: "myapp://myapp.com/home")!)
            return false
        }

        guard case .pending(let current) = resumed else {
            Issue.record("expected .pending after stale identity, got \(resumed)")
            return
        }
        #expect(current.route == .home)
        #expect(coordinator.pendingDeepLink?.route == .home)
        #expect(coordinator.store.state.path.isEmpty)
    }
}

// MARK: - DeepLinkEffectHandler Tests

@Suite("DeepLinkEffectHandler Tests")
struct DeepLinkEffectHandlerTests {
    struct MockDeepLinkEffect: DeepLinkEffect {
        var deepLinkURL: URL?

        static func deepLink(_ url: URL) -> MockDeepLinkEffect {
            MockDeepLinkEffect(deepLinkURL: url)
        }
    }

    @Test("Execute plan result is returned even when last command is not push")
    @MainActor
    func testPlanExecutionResult() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )

        let result = handler.handle(URL(string: "myapp://myapp.com/settings")!)

        guard case .executed(let plan, let batch) = result else {
            Issue.record("Expected executed result")
            return
        }
        #expect(plan.commands == [.replace([.home, .settings])])
        #expect(batch.results == [.success])
        #expect(batch.executedCommands == [.replace([.home, .settings])])
        #expect(store.state.path == [.home, .settings])
    }

    @Test("Resume pending deep link replays preserved plan")
    @MainActor
    func testResumePendingDeepLink() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let authState = Mutex(false)
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { authState.withLock { $0 } }
            ),
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )

        let pendingResult = handler.handle(URL(string: "myapp://myapp.com/settings")!)
        guard case .pending = pendingResult else {
            Issue.record("Expected pending result")
            return
        }
        #expect(handler.hasPendingDeepLink)

        authState.withLock { $0 = true }
        let resumeResult = handler.resumePendingDeepLink()
        guard case .executed(let plan, let batch) = resumeResult else {
            Issue.record("Expected executed result after resume")
            return
        }
        #expect(plan.commands == [.replace([.home, .settings])])
        #expect(batch.results == [.success])
        #expect(store.state.path == [.home, .settings])
        #expect(!handler.hasPendingDeepLink)
    }

    @Test("Async deep-link guard keeps pending until authorized")
    @MainActor
    func testResumePendingDeepLinkIfAllowed() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let authState = Mutex(false)
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { authState.withLock { $0 } }
            ),
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )

        let pending = handler.handle(URL(string: "myapp://myapp.com/settings")!)
        guard case .pending = pending else {
            Issue.record("Expected pending result")
            return
        }

        let denied = await handler.resumePendingDeepLinkIfAllowed { _ in false }
        #expect(denied == .pending(handler.pendingDeepLink!))
        #expect(handler.hasPendingDeepLink)
        #expect(store.state.path.isEmpty)

        authState.withLock { $0 = true }
        let resumed = await handler.resumePendingDeepLinkIfAllowed { _ in true }
        guard case .executed(_, let batch) = resumed else {
            Issue.record("Expected executed result after authorization")
            return
        }
        #expect(batch.results == [.success])
        #expect(store.state.path == [.home, .settings])
        #expect(!handler.hasPendingDeepLink)
    }

    @Test("Async deep-link guard does not resume a stale pending deep link")
    @MainActor
    func testResumePendingDeepLinkIfAllowedUsesCurrentPendingIdentity() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
            DeepLinkMapping("/home") { _ in .home }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { false }
            ),
            plan: { route in NavigationPlan(commands: [.push(route)]) }
        )

        let firstPending = handler.handle(URL(string: "myapp://myapp.com/settings")!)
        guard case .pending = firstPending else {
            Issue.record("Expected pending result")
            return
        }

        let resumed = await handler.resumePendingDeepLinkIfAllowed { _ in
            _ = handler.handle(URL(string: "myapp://myapp.com/home")!)
            return true
        }

        #expect(resumed == .pending(handler.pendingDeepLink!))
        #expect(handler.pendingDeepLink?.route == .home)
        #expect(store.state.path.isEmpty)
    }

    @Test("Async deep-link guard returns the current pending deep link after denied stale authorization")
    @MainActor
    func testResumePendingDeepLinkIfAllowedDeniedUsesCurrentPendingIdentity() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
            DeepLinkMapping("/home") { _ in .home }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { false }
            ),
            plan: { route in NavigationPlan(commands: [.push(route)]) }
        )

        let firstPending = handler.handle(URL(string: "myapp://myapp.com/settings")!)
        guard case .pending = firstPending else {
            Issue.record("Expected pending result")
            return
        }

        let denied = await handler.resumePendingDeepLinkIfAllowed { _ in
            _ = handler.handle(URL(string: "myapp://myapp.com/home")!)
            return false
        }

        #expect(denied == .pending(handler.pendingDeepLink!))
        #expect(handler.pendingDeepLink?.route == .home)
        #expect(store.state.path.isEmpty)
    }

    @Test("Rejected decision preserves rejection reason")
    @MainActor
    func testRejectedReasonIsPreserved() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher,
            allowedSchemes: ["myapp"]
        )

        let result = handler.handle(URL(string: "https://myapp.com/settings")!)
        guard case .rejected(let reason) = result else {
            Issue.record("Expected rejected result")
            return
        }
        #expect(reason == .schemeNotAllowed(actualScheme: "https"))
    }

    @Test("Unhandled decision preserves original URL")
    @MainActor
    func testUnhandledURLIsPreserved() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher
        )
        let url = URL(string: "myapp://myapp.com/unknown")!

        let result = handler.handle(url)
        guard case .unhandled(let unhandledURL) = result else {
            Issue.record("Expected unhandled result")
            return
        }
        #expect(unhandledURL == url)
    }

    @Test("Invalid URL string returns invalidURL result")
    @MainActor
    func testInvalidURLStringReturnsTypedResult() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher
        )

        let result = handler.handle("://invalid url")

        #expect(result == .invalidURL(input: "://invalid url"))
    }

    @Test("Missing effect URL returns missingDeepLinkURL result")
    @MainActor
    func testMissingEffectURLReturnsTypedResult() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher
        )

        let result = handler.handle(MockDeepLinkEffect(deepLinkURL: nil))

        #expect(result == .missingDeepLinkURL)
    }

    @Test("No pending deep link returns noPendingDeepLink result")
    @MainActor
    func testNoPendingDeepLinkReturnsTypedResult() {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyBatchNavigator(store),
            matcher: matcher
        )

        let result = handler.resumePendingDeepLink()

        #expect(result == .noPendingDeepLink)
    }
}

// MARK: - NavigationEffectHandler Tests

@Suite("NavigationEffectHandler Tests")
struct NavigationEffectHandlerTests {
    @Test("execute(_:stopOnFailure:) returns batch result and preserves middleware order")
    @MainActor
    func testExecuteStopOnFailure() throws {
        var changeCount = 0
        let store = NavigationStore<TestRoute>(
            configuration: NavigationStoreConfiguration(
                onChange: { _, _ in
                    changeCount += 1
                }
            )
        )
        var willExecuteCount = 0
        var didExecuteCount = 0
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willExecuteCount += 1
                    return .proceed(command)
                },
                didExecute: { _, result, _ in
                    didExecuteCount += 1
                    return result
                }
            )
        )

        let handler = NavigationEffectHandler(navigator: AnyBatchNavigator(store))
        let batch = handler.execute(
            [
                .push(.home),
                .popCount(5),
                .push(.settings)
            ],
            stopOnFailure: true
        )

        #expect(batch.requestedCommands == [.push(.home), .popCount(5), .push(.settings)])
        #expect(batch.executedCommands == [.push(.home), .popCount(5)])
        #expect(batch.results == [.success, .insufficientStackDepth(requested: 5, available: 1)])
        #expect(batch.hasStoppedOnFailure == true)
        #expect(batch.stateBefore == RouteStack<TestRoute>())
        #expect(batch.stateAfter == (try validatedStack([.home])))
        #expect(store.state.path == [.home])
        #expect(willExecuteCount == 2)
        #expect(didExecuteCount == 2)
        #expect(changeCount == 1)
        #expect(handler.lastBatchResult == batch)
        #expect(handler.lastResult == .insufficientStackDepth(requested: 5, available: 1))
    }

    @Test("AnyBatchNavigator convenience methods surface typed results")
    @MainActor
    func testAnyBatchNavigatorConvenienceMethodsReturnResults() {
        let navigator = AnyBatchNavigator(NavigationStore<TestRoute>())

        let popToRootResult = navigator.popToRoot()
        let replaceResult = navigator.replace(with: [.home])

        #expect(popToRootResult == .success)
        #expect(replaceResult == .success)
    }

    @Test("single execute clears stale batch result")
    @MainActor
    func testSingleExecuteClearsBatchResult() {
        let store = NavigationStore<TestRoute>()
        let handler = NavigationEffectHandler(navigator: AnyBatchNavigator(store))

        let batch = handler.execute([.push(.home), .push(.settings)])
        #expect(batch.results == [.success, .success])
        #expect(handler.lastBatchResult == batch)
        #expect(handler.lastResult == .success)

        let single = handler.execute(.pop)

        #expect(single == .success)
        #expect(handler.lastResult == .success)
        #expect(handler.lastBatchResult == nil)
        #expect(store.state.path == [.home])
    }

    @Test("executeTransaction returns atomic transaction result")
    @MainActor
    func testExecuteTransaction() throws {
        let store = NavigationStore<TestRoute>()
        let handler = NavigationEffectHandler(navigator: AnyBatchNavigator(store))

        let transaction = handler.executeTransaction([.push(.home), .push(.settings)])

        #expect(transaction.isCommitted == true)
        #expect(transaction.results == [.success, .success])
        #expect(transaction.stateAfter == (try validatedStack([.home, .settings])))
        #expect(store.state.path == [.home, .settings])
        #expect(handler.lastResult == .success)
        #expect(handler.lastBatchResult == nil)
    }

    @Test("executeGuarded cancels without mutating state")
    @MainActor
    func testExecuteGuardedCancel() async {
        let store = NavigationStore<TestRoute>()
        let handler = NavigationEffectHandler(navigator: AnyBatchNavigator(store))

        let result = await handler.executeGuarded(.push(.home)) { command in
            .cancel(.middleware(debugName: "guard", command: command))
        }

        #expect(result == .cancelled(.middleware(debugName: "guard", command: .push(.home))))
        #expect(handler.lastResult == result)
        #expect(handler.lastBatchResult == nil)
        #expect(store.state.path.isEmpty)
    }

    @Test("executeGuarded proceeds into synchronous execution")
    @MainActor
    func testExecuteGuardedProceed() async {
        let store = NavigationStore<TestRoute>()
        let handler = NavigationEffectHandler(navigator: AnyBatchNavigator(store))

        let result = await handler.executeGuarded(.push(.home)) { command in
            .proceed(command)
        }

        #expect(result == .success)
        #expect(handler.lastResult == .success)
        #expect(store.state.path == [.home])
    }
}

// MARK: - ModalStore Tests

@Suite("ModalStore Tests")
struct ModalStoreTests {
    @Test("Initial queued presentations normalize into active and queued state without callbacks")
    @MainActor
    func testInitNormalizesQueuedPresentationsWithoutCallbacks() {
        let presented = Mutex<[ModalPresentation<TestModalRoute>]>([])
        let queueChanges = Mutex<[([ModalPresentation<TestModalRoute>], [ModalPresentation<TestModalRoute>])]>([])
        let first = ModalPresentation<TestModalRoute>(route: .profile, style: .sheet)
        let second = ModalPresentation<TestModalRoute>(route: .onboarding, style: .fullScreenCover)
        let store = ModalStore<TestModalRoute>(
            currentPresentation: nil,
            queuedPresentations: [first, second],
            configuration: .init(
                onPresented: { presentation in
                    presented.withLock { $0.append(presentation) }
                },
                onQueueChanged: { oldQueue, newQueue in
                    queueChanges.withLock { $0.append((oldQueue, newQueue)) }
                }
            )
        )

        #expect(store.currentPresentation == first)
        #expect(store.queuedPresentations == [second])
        #expect(presented.withLock { $0.isEmpty })
        #expect(queueChanges.withLock { $0.isEmpty })
    }

    @Test("First present becomes the active modal")
    @MainActor
    func testPresentCreatesActiveModal() {
        let store = ModalStore<TestModalRoute>()

        store.present(.profile, style: .sheet)

        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .sheet)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("Additional presents queue while one is active")
    @MainActor
    func testPresentQueuesWhenActiveModalExists() {
        let store = ModalStore<TestModalRoute>()

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)

        #expect(store.currentPresentation?.route == .profile)
        #expect(store.queuedPresentations.map(\.route) == [.onboarding])
        #expect(store.queuedPresentations.map(\.style) == [.fullScreenCover])
    }

    @Test("Dismiss current promotes the next queued modal")
    @MainActor
    func testDismissPromotesQueuedPresentation() {
        let store = ModalStore<TestModalRoute>()

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)
        store.dismissCurrent()

        #expect(store.currentPresentation?.route == .onboarding)
        #expect(store.currentPresentation?.style == .fullScreenCover)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("First present emits onPresented once without queue callback")
    @MainActor
    func testPresentEmitsOnPresentedWithoutQueueCallback() {
        let presented = Mutex<[ModalPresentation<TestModalRoute>]>([])
        let queueChanges = Mutex<[([ModalPresentation<TestModalRoute>], [ModalPresentation<TestModalRoute>])]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onPresented: { presentation in
                    presented.withLock { $0.append(presentation) }
                },
                onQueueChanged: { oldQueue, newQueue in
                    queueChanges.withLock { $0.append((oldQueue, newQueue)) }
                }
            )
        )

        store.present(.profile, style: .sheet)

        #expect(presented.withLock(\.count) == 1)
        #expect(presented.withLock(\.first)?.route == .profile)
        #expect(queueChanges.withLock { $0.isEmpty })
    }

    @Test("Queued present emits queue callback but not presented")
    @MainActor
    func testQueuedPresentEmitsQueueCallbackOnly() {
        let presented = Mutex<[ModalPresentation<TestModalRoute>]>([])
        let queueChanges = Mutex<[([ModalPresentation<TestModalRoute>], [ModalPresentation<TestModalRoute>])]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onPresented: { presentation in
                    presented.withLock { $0.append(presentation) }
                },
                onQueueChanged: { oldQueue, newQueue in
                    queueChanges.withLock { $0.append((oldQueue, newQueue)) }
                }
            )
        )

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)

        #expect(presented.withLock(\.count) == 1)
        let change = queueChanges.withLock(\.first)
        #expect(change?.0.isEmpty == true)
        #expect(change?.1.map(\.route) == [.onboarding])
    }

    @Test("Dismiss current emits dismiss reason and promoted presentation")
    @MainActor
    func testDismissCurrentEmitsCallbacksInOrder() {
        let dismissed = Mutex<[(ModalPresentation<TestModalRoute>, ModalDismissalReason)]>([])
        let presented = Mutex<[ModalPresentation<TestModalRoute>]>([])
        let queueChanges = Mutex<[([ModalPresentation<TestModalRoute>], [ModalPresentation<TestModalRoute>])]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onPresented: { presentation in
                    presented.withLock { $0.append(presentation) }
                },
                onDismissed: { presentation, reason in
                    dismissed.withLock { $0.append((presentation, reason)) }
                },
                onQueueChanged: { oldQueue, newQueue in
                    queueChanges.withLock { $0.append((oldQueue, newQueue)) }
                }
            )
        )

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)
        store.dismissCurrent()

        #expect(dismissed.withLock(\.count) == 1)
        #expect(dismissed.withLock(\.first)?.0.route == .profile)
        #expect(dismissed.withLock(\.first)?.1 == .dismiss)
        #expect(queueChanges.withLock(\.count) == 2)
        #expect(queueChanges.withLock { $0.last?.0.map(\.route) } == [.onboarding])
        #expect(queueChanges.withLock { $0.last?.1.isEmpty } == true)
        #expect(presented.withLock(\.count) == 2)
        #expect(presented.withLock(\.last)?.route == .onboarding)
    }

    @Test("Dismiss all clears the active modal and queue")
    @MainActor
    func testDismissAllClearsState() {
        let store = ModalStore<TestModalRoute>()

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)
        store.dismissAll()

        #expect(store.currentPresentation == nil)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("Dismiss all emits active dismiss and queue clear once")
    @MainActor
    func testDismissAllEmitsDismissAndQueueCallbacks() {
        let dismissed = Mutex<[(ModalPresentation<TestModalRoute>, ModalDismissalReason)]>([])
        let queueChanges = Mutex<[([ModalPresentation<TestModalRoute>], [ModalPresentation<TestModalRoute>])]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onDismissed: { presentation, reason in
                    dismissed.withLock { $0.append((presentation, reason)) }
                },
                onQueueChanged: { oldQueue, newQueue in
                    queueChanges.withLock { $0.append((oldQueue, newQueue)) }
                }
            )
        )

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)
        store.dismissAll()

        #expect(dismissed.withLock(\.count) == 1)
        #expect(dismissed.withLock(\.first)?.0.route == .profile)
        #expect(dismissed.withLock(\.first)?.1 == .dismissAll)
        #expect(queueChanges.withLock(\.count) == 2)
        #expect(queueChanges.withLock { $0.last?.0.map(\.route) } == [.onboarding])
        #expect(queueChanges.withLock { $0.last?.1.isEmpty } == true)
    }

    @Test("Dismiss all clears state before callbacks so reentrant presents survive")
    @MainActor
    func testDismissAllClearsStateBeforeCallbacks() {
        let callbackOrder = Mutex<[String]>([])
        let observedStateDuringDismiss = Mutex<([TestModalRoute?], [[TestModalRoute]])>(([], []))
        var store: ModalStore<TestModalRoute>!
        store = ModalStore<TestModalRoute>(
            configuration: .init(
                onDismissed: { _, _ in
                    callbackOrder.withLock { $0.append("dismiss") }
                    observedStateDuringDismiss.withLock {
                        $0.0.append(store.currentPresentation?.route)
                        $0.1.append(store.queuedPresentations.map(\.route))
                    }
                    store.present(.profile, style: .sheet)
                },
                onQueueChanged: { _, _ in
                    callbackOrder.withLock { $0.append("queue") }
                }
            )
        )

        store.present(.onboarding, style: .fullScreenCover)
        store.present(.profile, style: .sheet)
        callbackOrder.withLock { $0.removeAll() }

        store.dismissAll()

        #expect(callbackOrder.withLock { $0 } == ["queue", "dismiss"])
        #expect(observedStateDuringDismiss.withLock { $0.0 } == [nil])
        #expect(observedStateDuringDismiss.withLock { $0.1 } == [[]])
        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .sheet)
        #expect(store.queuedPresentations.isEmpty)
    }

    @Test("Duplicate routes retain unique identities in the queue")
    @MainActor
    func testQueuedDuplicateRoutesKeepUniqueIDs() {
        let store = ModalStore<TestModalRoute>()

        store.present(.profile, style: .sheet)
        store.present(.profile, style: .sheet)
        store.present(.profile, style: .sheet)

        let ids = [store.currentPresentation?.id].compactMap { $0 } + store.queuedPresentations.map(\.id)
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3)
    }

    @Test("Style bindings expose only matching active modal and dismiss through setter")
    @MainActor
    func testBindingsFilterByStyleAndDismissThroughSetter() {
        let store = ModalStore<TestModalRoute>()

        store.send(.present(.profile, style: .sheet))
        store.send(.present(.onboarding, style: .fullScreenCover))

        #expect(store.binding(for: .sheet).wrappedValue?.route == .profile)
        #expect(store.binding(for: .fullScreenCover).wrappedValue == nil)

        store.binding(for: .sheet).wrappedValue = nil

        #expect(store.currentPresentation?.route == .onboarding)
        #expect(store.currentPresentation?.style == .fullScreenCover)
        #expect(store.binding(for: .sheet).wrappedValue == nil)
        #expect(store.binding(for: .fullScreenCover).wrappedValue?.route == .onboarding)
    }

    @Test("Binding setter dismiss uses systemDismiss reason")
    @MainActor
    func testBindingSetterUsesSystemDismissReason() {
        let dismissed = Mutex<[(ModalPresentation<TestModalRoute>, ModalDismissalReason)]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                onDismissed: { presentation, reason in
                    dismissed.withLock { $0.append((presentation, reason)) }
                }
            )
        )

        store.send(.present(.profile, style: .sheet))
        store.binding(for: .sheet).wrappedValue = nil

        #expect(dismissed.withLock(\.count) == 1)
        #expect(dismissed.withLock(\.first)?.0.route == .profile)
        #expect(dismissed.withLock(\.first)?.1 == .systemDismiss)
    }

    @Test("Telemetry recorder receives modal lifecycle events in order")
    @MainActor
    func testModalTelemetryRecorderLifecycle() {
        let recorder = Mutex<[ModalStoreTelemetryEvent<TestModalRoute>]>([])
        let store = ModalStore<TestModalRoute>(
            configuration: .init(
                logger: Logger(subsystem: "InnoRouterTests", category: "ModalStore")
            ),
            telemetryRecorder: { event in
                recorder.withLock { $0.append(event) }
            }
        )

        store.present(.profile, style: .sheet)
        store.present(.onboarding, style: .fullScreenCover)
        store.dismissCurrent()
        store.dismissAll()

        let events = recorder.withLock { $0 }.filter { event in
            if case .commandIntercepted = event { return false }
            if case .middlewareMutation = event { return false }
            return true
        }
        #expect(events.count == 7)

        switch events[0] {
        case .presented(let presentation):
            #expect(presentation.route == .profile)
            #expect(presentation.style == .sheet)
        default:
            Issue.record("Expected presented event first")
        }

        switch events[1] {
        case .queued(let presentation):
            #expect(presentation.route == .onboarding)
            #expect(presentation.style == .fullScreenCover)
        default:
            Issue.record("Expected queued event second")
        }

        switch events[2] {
        case .queueChanged(let oldQueue, let newQueue):
            #expect(oldQueue.isEmpty)
            #expect(newQueue.map(\.route) == [.onboarding])
        default:
            Issue.record("Expected queueChanged event third")
        }

        switch events[3] {
        case .dismissed(let presentation, let reason):
            #expect(presentation.route == .profile)
            #expect(reason == .dismiss)
        default:
            Issue.record("Expected dismissed event fourth")
        }

        switch events[4] {
        case .queueChanged(let oldQueue, let newQueue):
            #expect(oldQueue.map(\.route) == [.onboarding])
            #expect(newQueue.isEmpty)
        default:
            Issue.record("Expected queueChanged promotion event fifth")
        }

        switch events[5] {
        case .presented(let presentation):
            #expect(presentation.route == .onboarding)
            #expect(presentation.style == .fullScreenCover)
        default:
            Issue.record("Expected promoted presented event sixth")
        }

        switch events[6] {
        case .dismissed(let presentation, let reason):
            #expect(presentation.route == .onboarding)
            #expect(reason == .dismissAll)
        default:
            Issue.record("Expected dismissAll event seventh")
        }
    }

    @Test("Telemetry recorder captures replaceCurrent as an intercept without lifecycle events")
    @MainActor
    func testModalTelemetryRecorderReplaceCurrent() {
        let recorder = Mutex<[ModalStoreTelemetryEvent<TestBoundModalRoute>]>([])
        let store = ModalStore<TestBoundModalRoute>(
            configuration: .init(
                logger: Logger(subsystem: "InnoRouterTests", category: "ModalStore")
            ),
            telemetryRecorder: { event in
                recorder.withLock { $0.append(event) }
            }
        )

        store.present(.profile(id: "42"), style: .sheet)
        recorder.withLock { $0.removeAll() }

        store.replaceCurrent(.profile(id: "99"), style: .sheet)

        let events = recorder.withLock { $0 }
        #expect(events.count == 1)

        guard case .commandIntercepted(let command, let outcome, let cancellationReason) = events[0] else {
            Issue.record("Expected replaceCurrent to emit only a commandIntercepted event")
            return
        }

        #expect(outcome == .executed)
        #expect(cancellationReason == nil)
        guard case .replaceCurrent(let presentation) = command else {
            Issue.record("Expected replaceCurrent command, got \(command)")
            return
        }
        #expect(presentation.route == .profile(id: "99"))
        #expect(presentation.style == .sheet)
    }
}

// MARK: - NavigationEnvironmentStorage Tests

@Suite("NavigationEnvironmentStorage Tests")
struct NavigationEnvironmentStorageTests {
    @Test("Multiple host storages keep intent dispatch isolated")
    @MainActor
    func testNavigationEnvironmentStorageIsolationBetweenHosts() {
        let firstStore = NavigationStore<TestRoute>()
        let secondStore = NavigationStore<TestRoute>()
        let firstStorage = NavigationEnvironmentStorage()
        let secondStorage = NavigationEnvironmentStorage()

        firstStorage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            firstStore.send(intent)
        }
        secondStorage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            secondStore.send(intent)
        }

        guard let firstDispatcher = firstStorage[TestRoute.self] else {
            Issue.record("Expected first dispatcher")
            return
        }
        firstDispatcher.send(.go(.home))

        #expect(firstStore.state.path == [.home])
        #expect(secondStore.state.path.isEmpty)
    }

    @Test("NavigationHost-style dispatcher pushes route through send")
    @MainActor
    func testNavigationHostStyleDispatcher() {
        let store = NavigationStore<TestRoute>()
        let storage = NavigationEnvironmentStorage()
        storage[TestRoute.self] = AnyNavigationIntentDispatcher { intent in
            store.send(intent)
        }

        guard let dispatcher = storage[TestRoute.self] else {
            Issue.record("Expected dispatcher")
            return
        }
        dispatcher.send(.go(.detail(id: "123")))

        #expect(store.state.path == [.detail(id: "123")])
    }

    @Test("NavigationSplitHost body can be constructed")
    @MainActor
    func testNavigationSplitHostConstruction() {
        let store = NavigationStore<TestRoute>()
        let host = NavigationSplitHost(store: store) {
            Text("Sidebar")
        } destination: { _ in
            Text("Destination")
        } root: {
            Text("Root")
        }

        _ = host.body
        store.send(.go(.settings))

        #expect(store.state.path == [.settings])
    }
}

// MARK: - ModalEnvironmentStorage Tests

@Suite("ModalEnvironmentStorage Tests")
struct ModalEnvironmentStorageTests {
    @Test("ModalHost-style dispatcher presents and dismisses through send")
    @MainActor
    func testModalHostStyleDispatcher() {
        let store = ModalStore<TestModalRoute>()
        let storage = ModalEnvironmentStorage()
        storage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            store.send(intent)
        }

        guard let dispatcher = storage[TestModalRoute.self] else {
            Issue.record("Expected modal dispatcher")
            return
        }

        dispatcher.send(.present(.profile, style: .sheet))
        #expect(store.currentPresentation?.route == .profile)
        #expect(store.currentPresentation?.style == .sheet)

        dispatcher.send(.dismiss)
        #expect(store.currentPresentation == nil)
    }

    @Test("Multiple modal host storages keep intent dispatch isolated")
    @MainActor
    func testModalEnvironmentStorageIsolationBetweenHosts() {
        let firstStore = ModalStore<TestModalRoute>()
        let secondStore = ModalStore<TestModalRoute>()
        let firstStorage = ModalEnvironmentStorage()
        let secondStorage = ModalEnvironmentStorage()

        firstStorage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            firstStore.send(intent)
        }
        secondStorage[TestModalRoute.self] = AnyModalIntentDispatcher { intent in
            secondStore.send(intent)
        }

        guard let firstDispatcher = firstStorage[TestModalRoute.self] else {
            Issue.record("Expected first modal dispatcher")
            return
        }

        firstDispatcher.send(.present(.profile, style: .sheet))

        #expect(firstStore.currentPresentation?.route == .profile)
        #expect(secondStore.currentPresentation == nil)
    }

    @Test("ModalHost body can be constructed around NavigationHost")
    @MainActor
    func testModalHostConstructionWithNavigationHost() {
        let navigationStore = NavigationStore<TestRoute>()
        let modalStore = ModalStore<TestModalRoute>()
        let host = ModalHost(store: modalStore) { route in
            switch route {
            case .profile:
                Text("Profile")
            case .onboarding:
                Text("Onboarding")
            }
        } content: {
            NavigationHost(store: navigationStore) { _ in
                Text("Destination")
            } root: {
                Text("Root")
            }
        }

        _ = host.body
        navigationStore.send(.go(.settings))
        modalStore.send(.present(.profile, style: .sheet))

        #expect(navigationStore.state.path == [.settings])
        #expect(modalStore.currentPresentation?.route == .profile)
    }
}

// MARK: - FlowCoordinator Tests

@Suite("FlowCoordinator Tests")
struct FlowCoordinatorTests {
    
    enum TestStep: Int, FlowStep, CaseIterable {
        case step1 = 0
        case step2 = 1
        case step3 = 2
        
        var index: Int { rawValue }
    }
    
    @Observable
    @MainActor
    final class TestFlowCoordinator: FlowCoordinator {
        typealias Step = TestStep
        typealias Result = String
        
        var currentStep: TestStep = .step1
        var completedSteps: Set<TestStep> = []
        var onComplete: ((String) -> Void)?
        
        func canProceed(from step: TestStep) -> Bool {
            true
        }
        
        func complete(with result: String) {
            onComplete?(result)
        }
    }
    
    @Test("FlowCoordinator starts at first step")
    @MainActor
    func testInitialStep() {
        let coordinator = TestFlowCoordinator()
        
        #expect(coordinator.currentStep == .step1)
        #expect(coordinator.isAtStart)
        #expect(!coordinator.isAtEnd)
    }
    
    @Test("FlowCoordinator progresses through steps")
    @MainActor
    func testProgress() {
        let coordinator = TestFlowCoordinator()
        
        coordinator.next()
        #expect(coordinator.currentStep == .step2)
        #expect(coordinator.completedSteps.contains(.step1))
        
        coordinator.next()
        #expect(coordinator.currentStep == .step3)
        #expect(coordinator.isAtEnd)
    }
    
    @Test("FlowCoordinator can go back")
    @MainActor
    func testPrevious() {
        let coordinator = TestFlowCoordinator()
        coordinator.next()
        coordinator.next()
        
        coordinator.previous()
        #expect(coordinator.currentStep == .step2)
    }
    
    @Test("FlowCoordinator reset clears progress")
    @MainActor
    func testReset() {
        let coordinator = TestFlowCoordinator()
        coordinator.next()
        coordinator.next()
        
        coordinator.reset()
        
        #expect(coordinator.currentStep == .step1)
        #expect(coordinator.completedSteps.isEmpty)
    }
    
    @Test("FlowCoordinator progress calculation")
    @MainActor
    func testProgressCalculation() {
        let coordinator = TestFlowCoordinator()
        
        #expect(coordinator.progress == 1.0 / 3.0)
        
        coordinator.next()
        #expect(coordinator.progress == 2.0 / 3.0)
        
        coordinator.next()
        #expect(coordinator.progress == 1.0)
    }
}

// MARK: - TabCoordinator Tests

@Suite("TabCoordinator Tests")
struct TabCoordinatorTests {
    enum TestTab: String, InnoRouterSwiftUI.Tab, CaseIterable {
        case home
        case inbox
        case settings

        var icon: String {
            switch self {
            case .home: "house"
            case .inbox: "tray"
            case .settings: "gearshape"
            }
        }

        var title: String {
            rawValue.capitalized
        }
    }

    @Observable
    @MainActor
    final class TestTabCoordinator: InnoRouterSwiftUI.TabCoordinator {
        typealias TabType = TestTab
        typealias TabContent = Text

        var selectedTab: TestTab = .home
        var tabBadges: [TestTab: Int] = [:]

        func content(for tab: TestTab) -> Text {
            Text(tab.title)
        }
    }

    @Test("TabCoordinator switches selected tab")
    @MainActor
    func testSwitchTab() {
        let coordinator = TestTabCoordinator()

        coordinator.switchTab(to: TestTab.inbox)

        #expect(coordinator.selectedTab == TestTab.inbox)
    }

    @Test("TabCoordinator manages badges per tab")
    @MainActor
    func testTabBadges() {
        let coordinator = TestTabCoordinator()

        coordinator.setBadge(3, for: TestTab.inbox)
        coordinator.setBadge(1, for: TestTab.settings)

        #expect(coordinator.badge(for: TestTab.inbox) == 3)
        #expect(coordinator.badge(for: TestTab.settings) == 1)
    }

    @Test("TabCoordinator clears badge state")
    @MainActor
    func testClearAllBadges() {
        let coordinator = TestTabCoordinator()
        coordinator.setBadge(2, for: TestTab.inbox)
        coordinator.setBadge(1, for: TestTab.settings)

        coordinator.clearAllBadges()

        #expect(coordinator.tabBadges.isEmpty)
        #expect(coordinator.badge(for: TestTab.inbox) == nil)
        #expect(coordinator.badge(for: TestTab.settings) == nil)
    }
}

// MARK: - ChildCoordinator Tests

@Suite("ChildCoordinator Tests")
struct ChildCoordinatorTests {
    private static func builtExecutable(named name: String) -> URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildDirectory = root.appending(path: ".build")
        guard let enumerator = FileManager.default.enumerator(
            at: buildDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isExecutableKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == name else {
                continue
            }

            guard fileURL.pathExtension.isEmpty, !fileURL.path.contains(".dSYM/") else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isExecutableKey])
            if values?.isRegularFile == true, values?.isExecutable == true {
                return fileURL
            }
        }

        return nil
    }

    @MainActor
    final class ParentTestCoordinator: Coordinator {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView

        let store = NavigationStore<TestRoute>()

        @ViewBuilder
        func destination(for route: TestRoute) -> EmptyView {
            EmptyView()
        }
    }

    @MainActor
    final class OnboardingChild: ChildCoordinator {
        typealias Result = String

        var onFinish: (@MainActor @Sendable (String) -> Void)?
        var onCancel: (@MainActor @Sendable () -> Void)?
    }

    @Test("push(child:) resumes Task with the finish result")
    @MainActor
    func testFinishResumesTask() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onFinish?("welcome")

        let result = await task.value
        #expect(result == "welcome")
    }

    @Test("push(child:) resumes Task with nil on cancel")
    @MainActor
    func testCancelResumesTaskWithNil() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onCancel?()

        let result = await task.value
        #expect(result == nil)
    }

    @Test("push(child:) ignores cancel after finish")
    @MainActor
    func testCancelAfterFinishIsIgnored() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onFinish?("final")
        child.onCancel?()

        let result = await task.value
        #expect(result == "final")
    }

    @Test("push(child:) ignores finish after cancel")
    @MainActor
    func testFinishAfterCancelIsIgnored() async {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        let task = parent.push(child: child)
        child.onCancel?()
        child.onFinish?("late")

        let result = await task.value
        #expect(result == nil)
    }

    @Test("push(child:) installs finish and cancel callbacks on the child")
    @MainActor
    func testPushInstallsCallbacks() {
        let parent = ParentTestCoordinator()
        let child = OnboardingChild()

        #expect(child.onFinish == nil)
        #expect(child.onCancel == nil)

        _ = parent.push(child: child)

        #expect(child.onFinish != nil)
        #expect(child.onCancel != nil)
    }

    @Test("push(child:) fails fast when the same child instance is reused")
    func testPushRejectsSameChildInstanceReuse() throws {
        guard let executableURL = Self.builtExecutable(named: "ChildCoordinatorFailFastProbe") else {
            Issue.record("Expected ChildCoordinatorFailFastProbe executable to be built")
            return
        }

        let stdout = Pipe()
        let stderr = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stderrOutput = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        #expect(process.terminationStatus != 0)
        #expect(stderrOutput.contains("Cannot push the same ChildCoordinator instance more than once."))
    }
}
