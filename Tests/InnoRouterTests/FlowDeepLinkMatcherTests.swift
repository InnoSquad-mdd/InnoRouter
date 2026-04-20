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
}
