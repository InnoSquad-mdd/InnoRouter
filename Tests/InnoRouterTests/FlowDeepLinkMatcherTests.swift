// MARK: - FlowDeepLinkMatcherTests.swift
// InnoRouterTests - URL → FlowPlan<R>? composite matching
// Copyright © 2026 Inno Squad. All rights reserved.

import Testing
import Foundation
import InnoRouter
import InnoRouterDeepLink

private enum MatcherRoute: Route {
    case home
    case detail(id: String)
    case comments(id: String)
    case privacyPolicy
    case compare(ids: [String])
}

/// Pattern matching keys off the URL's **path** (not the
/// scheme/host). Use hosts like `app` and paths like `/home/detail/42`.
@Suite("FlowDeepLinkMatcher Tests")
struct FlowDeepLinkMatcherTests {

    private func makeMatcher() -> FlowDeepLinkMatcher<MatcherRoute> {
        FlowDeepLinkMatcher<MatcherRoute> {
            FlowDeepLinkMapping("/home") { _ in
                FlowPlan(steps: [.push(.home)])
            }
            FlowDeepLinkMapping("/home/detail/:id") { params in
                guard let id = params.firstValue(forName: "id") else { return nil }
                return FlowPlan(steps: [.push(.home), .push(.detail(id: id))])
            }
            FlowDeepLinkMapping("/home/detail/:id/comments/:cid") { params in
                guard let id = params.firstValue(forName: "id"),
                      let cid = params.firstValue(forName: "cid") else { return nil }
                return FlowPlan(steps: [
                    .push(.home),
                    .push(.detail(id: id)),
                    .push(.comments(id: cid))
                ])
            }
            FlowDeepLinkMapping("/onboarding/privacy") { _ in
                FlowPlan(steps: [.sheet(.privacyPolicy)])
            }
        }
    }

    @Test("Single-path pattern matches and builds a single-step plan")
    func singleRoutePattern() {
        let matcher = makeMatcher()
        let plan = matcher.match("myapp://app/home")
        #expect(plan == FlowPlan(steps: [.push(.home)]))
    }

    @Test("Multi-segment pattern extracts :id and builds a two-push plan")
    func multiSegmentPattern() {
        let matcher = makeMatcher()
        let plan = matcher.match("myapp://app/home/detail/42")
        #expect(plan == FlowPlan(steps: [.push(.home), .push(.detail(id: "42"))]))
    }

    @Test("Deep multi-segment pattern preserves parameter extraction order")
    func deepMultiSegmentPattern() {
        let matcher = makeMatcher()
        let plan = matcher.match("myapp://app/home/detail/42/comments/7")
        #expect(plan == FlowPlan(steps: [
            .push(.home),
            .push(.detail(id: "42")),
            .push(.comments(id: "7"))
        ]))
    }

    @Test("Modal-terminal pattern produces a .sheet tail in FlowPlan")
    func modalTerminalPattern() {
        let matcher = makeMatcher()
        let plan = matcher.match("myapp://app/onboarding/privacy")
        #expect(plan == FlowPlan(steps: [.sheet(.privacyPolicy)]))
    }

    @Test("Unmatched URL returns nil")
    func noMatch() {
        let matcher = makeMatcher()
        #expect(matcher.match("myapp://app/nonexistent") == nil)
    }

    @Test("Malformed URL string returns nil")
    func malformedString() {
        let matcher = makeMatcher()
        #expect(matcher.match("not a url") == nil)
    }

    @Test("Handler returning nil allows fallthrough to the next mapping")
    func handlerFallthrough() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute> {
            // This mapping declines to build a plan.
            FlowDeepLinkMapping("/detail/:id") { _ in nil }
            // Later mapping with same pattern still matches because
            // the first one fell through.
            FlowDeepLinkMapping("/detail/:id") { params in
                guard let id = params.firstValue(forName: "id") else { return nil }
                return FlowPlan(steps: [.push(.detail(id: id))])
            }
        }
        #expect(matcher.match("myapp://app/detail/99") == FlowPlan(steps: [.push(.detail(id: "99"))]))
    }

    @Test("Init(mappings:) non-builder accepts a direct array")
    func arrayInit() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute>(mappings: [
            FlowDeepLinkMapping("/home") { _ in FlowPlan(steps: [.push(.home)]) }
        ])
        #expect(matcher.match("myapp://app/home") == FlowPlan(steps: [.push(.home)]))
    }

    @Test("Repeated path parameters use DeepLinkPattern append semantics")
    func repeatedPathParametersAppend() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute> {
            FlowDeepLinkMapping("/compare/:id/:id") { params in
                FlowPlan(steps: [.push(.compare(ids: params.values(forName: "id")))])
            }
        }

        #expect(
            matcher.match("myapp://app/compare/a/b?id=c&id=d")
            == FlowPlan(steps: [.push(.compare(ids: ["a", "b", "c", "d"]))])
        )
    }

    @Test("FlowDeepLinkMatcher surfaces duplicate pattern diagnostics")
    func duplicatePatternDiagnostics() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            FlowDeepLinkMapping("/home") { _ in FlowPlan(steps: [.push(.home)]) }
            FlowDeepLinkMapping("/home") { _ in FlowPlan(steps: [.push(.privacyPolicy)]) }
        }

        #expect(
            matcher.diagnostics == [
                .duplicatePattern(pattern: "/home", firstIndex: 0, duplicateIndex: 1)
            ]
        )
    }

    @Test("FlowDeepLinkMatcher surfaces wildcard shadowing diagnostics")
    func wildcardShadowingDiagnostics() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            FlowDeepLinkMapping("/api/*") { _ in FlowPlan(steps: [.push(.home)]) }
            FlowDeepLinkMapping("/api/users") { _ in FlowPlan(steps: [.push(.privacyPolicy)]) }
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

    @Test("FlowDeepLinkMatcher surfaces parameter shadowing diagnostics")
    func parameterShadowingDiagnostics() {
        let matcher = FlowDeepLinkMatcher<MatcherRoute>(
            configuration: .init(diagnosticsMode: .disabled)
        ) {
            FlowDeepLinkMapping("/products/:id") { _ in FlowPlan(steps: [.push(.detail(id: "generic"))]) }
            FlowDeepLinkMapping("/products/featured") { _ in FlowPlan(steps: [.push(.privacyPolicy)]) }
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
}
