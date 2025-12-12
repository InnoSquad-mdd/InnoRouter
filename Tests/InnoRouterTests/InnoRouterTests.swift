// MARK: - InnoRouterTests.swift
// InnoRouter Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import Testing
import Foundation
import Observation
import SwiftUI
import InnoRouter

// MARK: - Test Route

enum TestRoute: Route {
    case home
    case detail(id: String)
    case settings
    case profile(userId: String, tab: Int)
}

// MARK: - NavStore Tests

@Suite("NavStore Tests")
struct NavStoreTests {
    
    @Test("Push adds route to path")
    @MainActor
    func testPush() {
        let store = NavStore<TestRoute>()
        
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
        let store = NavStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        let result = store.execute(.pop)
        #expect(result == .success)
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Pop returns nil when empty")
    @MainActor
    func testPopEmpty() {
        let store = NavStore<TestRoute>()
        
        let result = store.execute(.pop)
        #expect(result == .stackEmpty)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("PopToRoot clears all routes")
    @MainActor
    func testPopToRoot() {
        let store = NavStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        _ = store.execute(.popToRoot)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("Replace replaces entire stack")
    @MainActor
    func testReplace() {
        let store = NavStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        _ = store.execute(.replace([.settings]))
        #expect(store.state.path.count == 1)
        #expect(store.state.path.last == .settings)
    }
    
    @Test("Pop to specific route")
    @MainActor
    func testPopTo() {
        let store = NavStore<TestRoute>(initialPath: [.home, .detail(id: "123"), .settings])
        
        let result = store.execute(.popTo(.detail(id: "123")))
        #expect(result == .success)
        #expect(store.state.path.count == 2)
        #expect(store.state.path.last == .detail(id: "123"))
    }
    
    @Test("onChange callback is called")
    @MainActor
    func testOnChange() {
        var changeCount = 0
        let store = NavStore<TestRoute>(onChange: { _, _ in
            changeCount += 1
        })
        
        _ = store.execute(.push(.home))
        _ = store.execute(.push(.detail(id: "123")))
        _ = store.execute(.pop)
        
        #expect(changeCount == 3)
    }
}

// MARK: - NavCommand Tests

@Suite("NavCommand Tests")
struct NavCommandTests {
    
    @Test("Execute push command")
    @MainActor
    func testExecutePush() {
        let store = NavStore<TestRoute>()
        
        let result = store.execute(.push(.home))
        
        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Execute pop command")
    @MainActor
    func testExecutePop() {
        let store = NavStore<TestRoute>(initialPath: [.home, .detail(id: "123")])
        
        let result = store.execute(.pop)
        
        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Execute pop on empty returns stackEmpty")
    @MainActor
    func testExecutePopEmpty() {
        let store = NavStore<TestRoute>()
        
        let result = store.execute(.pop)
        
        #expect(result == .stackEmpty)
    }
    
    @Test("Execute conditional when true")
    @MainActor
    func testExecuteConditionalTrue() {
        let store = NavStore<TestRoute>()
        
        let result = store.execute(.conditional({ true }, .push(.home)))
        
        #expect(result == .success)
        #expect(store.state.path.last == .home)
    }
    
    @Test("Execute conditional when false")
    @MainActor
    func testExecuteConditionalFalse() {
        let store = NavStore<TestRoute>()
        
        let result = store.execute(.conditional({ false }, .push(.home)))
        
        #expect(result == .conditionNotMet)
        #expect(store.state.path.isEmpty)
    }
    
    @Test("Execute sequence of commands")
    @MainActor
    func testExecuteSequence() {
        let store = NavStore<TestRoute>()
        
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
        let store = NavStore<TestRoute>()
        var willCount = 0
        var didCount = 0

        store.addMiddleware(
            AnyNavMiddleware(
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
        #expect(parsed.queryItems["category"] == "electronics")
    }
    
    @Test("DeepLinkPattern matches literal path")
    func testPatternLiteral() {
        let pattern = DeepLinkPattern("/home")
        
        let result = pattern.match("/home")
        #expect(result != nil)
        #expect(result?.params.isEmpty == true)
        
        let noMatch = pattern.match("/settings")
        #expect(noMatch == nil)
    }
    
    @Test("DeepLinkPattern matches parameter")
    func testPatternParameter() {
        let pattern = DeepLinkPattern("/products/:id")
        
        let result = pattern.match("/products/123")
        #expect(result != nil)
        #expect(result?.params["id"] == "123")
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
                guard let id = params["id"] else { return nil }
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
}

// MARK: - Coordinator Tests

@Suite("Coordinator Tests")
struct CoordinatorTests {
    
    @Observable
    @MainActor
    final class TestCoordinator: Coordinator {
        typealias RouteType = TestRoute
        typealias Destination = EmptyView
        
        let store = NavStore<TestRoute>()
        var handleCount = 0
        
        func handle(_ intent: NavIntent<TestRoute>) {
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
    
    @Test("Coordinator navigates via handle")
    @MainActor
    func testNavigate() {
        let coordinator = TestCoordinator()
        
        coordinator.navigate(to: .home)
        coordinator.navigate(to: .detail(id: "123"))
        
        #expect(coordinator.handleCount == 2)
        #expect(coordinator.store.state.path.count == 2)
    }
    
    @Test("Coordinator goBack pops")
    @MainActor
    func testGoBack() {
        let coordinator = TestCoordinator()
        _ = coordinator.store.execute(.push(.home))
        _ = coordinator.store.execute(.push(.detail(id: "123")))
        
        coordinator.goBack()
        
        #expect(coordinator.store.state.path.last == .home)
    }
    
    @Test("Coordinator goToRoot clears stack")
    @MainActor
    func testGoToRoot() {
        let coordinator = TestCoordinator()
        _ = coordinator.store.execute(.push(.home))
        _ = coordinator.store.execute(.push(.detail(id: "123")))
        
        coordinator.goToRoot()
        
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

        let store = NavStore<TestRoute>()

        var pendingDeepLink: PendingNav<TestRoute>?
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
            requiresAuthentication: { _ in true },
            isAuthenticated: { false }
        )
        let coordinator = DeepLinkCoordinator(deepLinkPipeline: pipeline)

        coordinator.handle(.deepLink(URL(string: "myapp://myapp.com/secure")!))

        #expect(coordinator.store.state.path.isEmpty)
        #expect(coordinator.pendingDeepLink?.route == .settings)
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
