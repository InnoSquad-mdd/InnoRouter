// MARK: - InnoRouterTests.swift
// InnoRouter Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import Foundation
import Observation
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

// MARK: - NavigationStore Tests

@Suite("NavigationStore Tests")
struct NavigationStoreTests {
    
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
    func testPop() {
        let store = NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        let result = store.execute(.pop)
        #expect(result == .success)
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Pop returns nil when empty")
    @MainActor
    func testPopEmpty() {
        let store = NavigationStore<TestRoute>()
        
        let result = store.execute(.pop)
        #expect(result == .stackEmpty)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("PopToRoot clears all routes")
    @MainActor
    func testPopToRoot() {
        let store = NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        _ = store.execute(.popToRoot)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("Replace replaces entire stack")
    @MainActor
    func testReplace() {
        let store = NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        _ = store.execute(.replace([.settings]))
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .settings)
    }
    
    @Test("Pop to specific route")
    @MainActor
    func testPopTo() {
        let store = NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        let result = store.execute(.popTo(.detail(id: "123")))
        #expect(result == .success)
        #expect(store.state.path.count == 2)
        #expect(store.state.path.last == .detail(id: "123"))
    }
    
    @Test("onChange callback is called")
    @MainActor
    func testOnChange() {
        var changeCount = 0
        let store = NavigationStore<TestRoute>(onChange: { _, _ in
            changeCount += 1
        })
        
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
    func testExecutePop() {
        let store = NavigationStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        let result = store.execute(.pop)
        
        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Execute pop on empty returns stackEmpty")
    @MainActor
    func testExecutePopEmpty() {
        let store = NavigationStore<TestRoute>()
        
        let result = store.execute(.pop)
        
        #expect(result == .stackEmpty)
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
                    return command
                },
                didExecute: { _, _, _ in
                    didCount += 1
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
                willExecute: { _, _ in nil }
            )
        )

        let result = store.execute(.push(.home))

        #expect(result == .cancelled)
        #expect(store.state.path.isEmpty)
    }

    @Test("NavigationResult multiple with empty results is failure")
    func testNavigationResultMultipleEmptyIsFailure() {
        let result = NavigationResult<TestRoute>.multiple([])
        #expect(result.isSuccess == false)
    }

    @Test("Command validation previews legality without mutation")
    func testCommandValidationPreview() {
        let stack = RouteStack<TestRoute>(path: [.home])

        #expect(NavigationCommand<TestRoute>.pop.validate(on: stack) == .success)
        #expect(NavigationCommand<TestRoute>.pop.canExecute(on: stack) == true)
        #expect(NavigationCommand<TestRoute>.popTo(.settings).validate(on: stack) == .routeNotFound(.settings))
        #expect(NavigationCommand<TestRoute>.popTo(.settings).canExecute(on: stack) == false)
        #expect(stack.path == [.home])
    }
}

// MARK: - NavigationIntent Tests

@Suite("NavigationIntent Tests")
struct NavigationIntentTests {
    @Test("NavigationStore send goMany pushes routes in order")
    @MainActor
    func testSendGoMany() {
        let store = NavigationStore<TestRoute>()

        store.send(.goMany([.home, .detail(id: "123"), .settings]))

        #expect(store.state.path == [.home, .detail(id: "123"), .settings])
    }

    @Test("NavigationStore send backBy pops expected count")
    @MainActor
    func testSendBackBy() {
        let store = NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backBy(2))

        #expect(store.state.path == [.home])
    }

    @Test("NavigationStore send backTo pops to matching route")
    @MainActor
    func testSendBackTo() {
        let store = NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backTo(.detail(id: "123")))

        #expect(store.state.path == [.home, .detail(id: "123")])
    }

    @Test("NavigationStore send backToRoot clears stack")
    @MainActor
    func testSendBackToRoot() {
        let store = NavigationStore<TestRoute>(
            initialPath: [.home, .detail(id: "123"), .settings]
        )

        store.send(.backToRoot)

        #expect(store.state.path.isEmpty)
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

        coordinator.handle(.deepLink(URL(string: "myapp://myapp.com/anything")!))

        #expect(coordinator.store.state.path.last == .settings)
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

        coordinator.handle(.deepLink(URL(string: "myapp://myapp.com/secure")!))

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

        coordinator.handle(.deepLink(URL(string: "myapp://myapp.com/secure")!))

        #expect(coordinator.pendingDeepLink?.plan.commands == planCommands)
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
    func testPlanExecutionResult() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher,
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )

        let result = await handler.handle(URL(string: "myapp://myapp.com/settings")!)

        guard case .executed(let plan, let results) = result else {
            Issue.record("Expected executed result")
            return
        }
        #expect(plan.commands == [.replace([.home, .settings])])
        #expect(results == [.success])
        #expect(store.state.path == [.home, .settings])
    }

    @Test("Resume pending deep link replays preserved plan")
    @MainActor
    func testResumePendingDeepLink() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let authState = Mutex(false)
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher,
            authenticationPolicy: .required(
                shouldRequireAuthentication: { _ in true },
                isAuthenticated: { authState.withLock { $0 } }
            ),
            plan: { _ in NavigationPlan(commands: [.replace([.home, .settings])]) }
        )

        let pendingResult = await handler.handle(URL(string: "myapp://myapp.com/settings")!)
        guard case .pending = pendingResult else {
            Issue.record("Expected pending result")
            return
        }
        #expect(handler.hasPendingDeepLink)

        authState.withLock { $0 = true }
        let resumeResult = await handler.resumePendingDeepLink()
        guard case .executed(let plan, _) = resumeResult else {
            Issue.record("Expected executed result after resume")
            return
        }
        #expect(plan.commands == [.replace([.home, .settings])])
        #expect(store.state.path == [.home, .settings])
        #expect(!handler.hasPendingDeepLink)
    }

    @Test("Rejected decision preserves rejection reason")
    @MainActor
    func testRejectedReasonIsPreserved() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/settings") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher,
            allowedSchemes: ["myapp"]
        )

        let result = await handler.handle(URL(string: "https://myapp.com/settings")!)
        guard case .rejected(let reason) = result else {
            Issue.record("Expected rejected result")
            return
        }
        #expect(reason == .schemeNotAllowed(actualScheme: "https"))
    }

    @Test("Unhandled decision preserves original URL")
    @MainActor
    func testUnhandledURLIsPreserved() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher
        )
        let url = URL(string: "myapp://myapp.com/unknown")!

        let result = await handler.handle(url)
        guard case .unhandled(let unhandledURL) = result else {
            Issue.record("Expected unhandled result")
            return
        }
        #expect(unhandledURL == url)
    }

    @Test("Invalid URL string returns invalidURL result")
    @MainActor
    func testInvalidURLStringReturnsTypedResult() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher
        )

        let result = await handler.handle("://invalid url")

        #expect(result == .invalidURL(input: "://invalid url"))
    }

    @Test("Missing effect URL returns missingDeepLinkURL result")
    @MainActor
    func testMissingEffectURLReturnsTypedResult() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher
        )

        let result = await handler.handle(MockDeepLinkEffect(deepLinkURL: nil))

        #expect(result == .missingDeepLinkURL)
    }

    @Test("No pending deep link returns noPendingDeepLink result")
    @MainActor
    func testNoPendingDeepLinkReturnsTypedResult() async {
        let store = NavigationStore<TestRoute>()
        let matcher = DeepLinkMatcher<TestRoute> {
            DeepLinkMapping("/known") { _ in .settings }
        }
        let handler = DeepLinkEffectHandler(
            navigator: AnyNavigator(store),
            matcher: matcher
        )

        let result = await handler.resumePendingDeepLink()

        #expect(result == .noPendingDeepLink)
    }
}

// MARK: - NavigationEffectHandler Tests

@Suite("NavigationEffectHandler Tests")
struct NavigationEffectHandlerTests {
    @Test("execute(_:stopOnFailure:) stops at first failure and preserves middleware order")
    @MainActor
    func testExecuteStopOnFailure() async {
        let store = NavigationStore<TestRoute>()
        var willExecuteCount = 0
        var didExecuteCount = 0
        store.addMiddleware(
            AnyNavigationMiddleware(
                willExecute: { command, _ in
                    willExecuteCount += 1
                    return command
                },
                didExecute: { _, _, _ in
                    didExecuteCount += 1
                }
            )
        )

        let handler = NavigationEffectHandler(navigator: AnyNavigator(store))
        let results = await handler.execute(
            [
                .push(.home),
                .popCount(5),
                .push(.settings)
            ],
            stopOnFailure: true
        )

        #expect(results.count == 2)
        #expect(results[0] == .success)
        #expect(results[1] == .stackEmpty)
        #expect(store.state.path == [.home])
        #expect(willExecuteCount == 2)
        #expect(didExecuteCount == 2)
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
