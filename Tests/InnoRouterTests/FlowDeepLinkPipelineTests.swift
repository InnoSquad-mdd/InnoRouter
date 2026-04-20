// MARK: - FlowDeepLinkPipelineTests.swift
// InnoRouterTests - FlowDeepLinkPipeline decide(for:)
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterDeepLink

private enum PipelineRoute: Route {
    case home
    case detail(id: String)
    case privacyPolicy
    case requiresAuth
}

@Suite("FlowDeepLinkPipeline Tests")
struct FlowDeepLinkPipelineTests {

    private func makeMatcher() -> FlowDeepLinkMatcher<PipelineRoute> {
        FlowDeepLinkMatcher<PipelineRoute> {
            FlowDeepLinkMapping("/home") { _ in
                FlowPlan(steps: [.push(.home)])
            }
            FlowDeepLinkMapping("/home/detail/:id") { params in
                guard let id = params.firstValue(forName: "id") else { return nil }
                return FlowPlan(steps: [.push(.home), .push(.detail(id: id))])
            }
            FlowDeepLinkMapping("/onboarding/privacy") { _ in
                FlowPlan(steps: [.sheet(.privacyPolicy)])
            }
            FlowDeepLinkMapping("/secure") { _ in
                FlowPlan(steps: [.push(.requiresAuth)])
            }
        }
    }

    @Test(".rejected when scheme is not allowed")
    func schemeRejection() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher()
        )
        let decision = pipeline.decide(for: URL(string: "other://app/home")!)
        if case .rejected(.schemeNotAllowed(let actual)) = decision {
            #expect(actual == "other")
        } else {
            Issue.record("Expected .rejected(.schemeNotAllowed), got \(decision)")
        }
    }

    @Test(".rejected when host is not allowed")
    func hostRejection() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            allowedHosts: ["app"],
            matcher: makeMatcher()
        )
        let decision = pipeline.decide(for: URL(string: "myapp://other/home")!)
        if case .rejected(.hostNotAllowed) = decision {
            // expected
        } else {
            Issue.record("Expected .rejected(.hostNotAllowed), got \(decision)")
        }
    }

    @Test(".unhandled when no mapping matches")
    func unmatchedURL() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher()
        )
        let url = URL(string: "myapp://app/nowhere")!
        let decision = pipeline.decide(for: url)
        if case .unhandled(let unhandledURL) = decision {
            #expect(unhandledURL == url)
        } else {
            Issue.record("Expected .unhandled, got \(decision)")
        }
    }

    @Test("Happy path returns .flowPlan with the matched plan")
    func happyPath() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher()
        )
        let decision = pipeline.decide(for: URL(string: "myapp://app/home/detail/42")!)
        if case .flowPlan(let plan) = decision {
            #expect(plan == FlowPlan(steps: [.push(.home), .push(.detail(id: "42"))]))
        } else {
            Issue.record("Expected .flowPlan, got \(decision)")
        }
    }

    @Test("Modal-terminal URL produces a .flowPlan with a sheet tail")
    func modalTerminal() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher()
        )
        let decision = pipeline.decide(for: URL(string: "myapp://app/onboarding/privacy")!)
        if case .flowPlan(let plan) = decision {
            #expect(plan == FlowPlan(steps: [.sheet(.privacyPolicy)]))
        } else {
            Issue.record("Expected .flowPlan, got \(decision)")
        }
    }

    @Test("Authentication .defer returns .pending with primaryRoute and plan")
    func authDefers() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher(),
            authenticationPolicy: .required(
                shouldRequireAuthentication: { route in
                    if case .requiresAuth = route { return true }
                    return false
                },
                isAuthenticated: { false }
            )
        )
        let decision = pipeline.decide(for: URL(string: "myapp://app/secure")!)
        if case .pending(let pending) = decision {
            if case .requiresAuth = pending.primaryRoute {
                // expected
            } else {
                Issue.record("Expected primaryRoute == .requiresAuth, got \(pending.primaryRoute)")
            }
            #expect(pending.plan == FlowPlan(steps: [.push(.requiresAuth)]))
        } else {
            Issue.record("Expected .pending, got \(decision)")
        }
    }

    @Test("Authentication .required passes through when already authenticated")
    func authPasses() {
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher(),
            authenticationPolicy: .required(
                shouldRequireAuthentication: { route in
                    if case .requiresAuth = route { return true }
                    return false
                },
                isAuthenticated: { true }
            )
        )
        let decision = pipeline.decide(for: URL(string: "myapp://app/secure")!)
        if case .flowPlan(let plan) = decision {
            #expect(plan == FlowPlan(steps: [.push(.requiresAuth)]))
        } else {
            Issue.record("Expected .flowPlan, got \(decision)")
        }
    }

    @Test("Authentication policy is only consulted for the first step's route")
    func authKeysOffPrimaryRoute() {
        // This URL produces [push(.home), push(.detail)]. `requiresAuth`
        // applies to .detail only — but the primary route is .home, so
        // the pipeline should allow the plan through.
        let pipeline = FlowDeepLinkPipeline<PipelineRoute>(
            allowedSchemes: ["myapp"],
            matcher: makeMatcher(),
            authenticationPolicy: .required(
                shouldRequireAuthentication: { route in
                    if case .detail = route { return true }
                    return false
                },
                isAuthenticated: { false }
            )
        )
        let decision = pipeline.decide(for: URL(string: "myapp://app/home/detail/42")!)
        if case .flowPlan = decision {
            // expected — primary route is .home, which doesn't require auth.
        } else {
            Issue.record("Expected .flowPlan (primary route is .home), got \(decision)")
        }
    }
}
