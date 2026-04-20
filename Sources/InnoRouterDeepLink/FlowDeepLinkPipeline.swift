// MARK: - FlowDeepLinkPipeline.swift
// InnoRouterDeepLink - composite URL → FlowPlan<R> pipeline with auth policy
// Copyright © 2026 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore

/// Authentication-deferred composite deep link, queued for replay once
/// the gate permits it.
///
/// Mirrors ``PendingDeepLink`` but carries a ``FlowPlan`` instead of a
/// push-only ``NavigationPlan``. `primaryRoute` is the first
/// ``RouteStep``'s route and is used to re-evaluate the
/// authentication policy on replay — a policy that keyed off of
/// "require auth for `.detail`" still works correctly when the
/// pending URL resolved to a multi-step plan that starts with `.home`
/// before pushing `.detail`.
public struct FlowPendingDeepLink<R: Route>: Sendable, Equatable {
    public let url: URL
    public let primaryRoute: R
    public let plan: FlowPlan<R>

    public init(url: URL, primaryRoute: R, plan: FlowPlan<R>) {
        self.url = url
        self.primaryRoute = primaryRoute
        self.plan = plan
    }
}

/// Outcome of ``FlowDeepLinkPipeline/decide(for:)``.
///
/// Parallels ``DeepLinkDecision``. Kept as a separate enum so adding
/// `.flowPlan` is not a breaking change to consumers of the push-only
/// surface — both pipelines coexist and callers pick whichever output
/// type matches their store.
public enum FlowDeepLinkDecision<R: Route>: Sendable, Equatable {
    /// The URL was rejected by scheme or host validation.
    case rejected(reason: DeepLinkRejectionReason)
    /// The URL did not match any ``FlowDeepLinkMapping``.
    case unhandled(url: URL)
    /// Authentication gate deferred the URL; caller should queue it
    /// and replay once authenticated.
    case pending(FlowPendingDeepLink<R>)
    /// The URL matched and produced a plan.
    case flowPlan(FlowPlan<R>)
}

/// Deep-link pipeline that emits composite ``FlowPlan`` values, so a
/// single URL can describe a push prefix plus a modal terminal step
/// that `FlowStore.apply(_:)` replays atomically.
///
/// Composition mirrors ``DeepLinkPipeline``:
///
/// 1. Validate the URL's scheme / host.
/// 2. Walk the matcher for a `FlowPlan`.
/// 3. Run the authentication policy against the plan's first step.
/// 4. Return `.flowPlan(plan)` or `.pending(...)` as appropriate.
public struct FlowDeepLinkPipeline<R: Route>: Sendable {
    public var allowedSchemes: Set<String>?
    public var allowedHosts: Set<String>?
    public var matcher: FlowDeepLinkMatcher<R>
    public var authenticationPolicy: DeepLinkAuthenticationPolicy<R>

    public init(
        allowedSchemes: Set<String>? = nil,
        allowedHosts: Set<String>? = nil,
        matcher: FlowDeepLinkMatcher<R>,
        authenticationPolicy: DeepLinkAuthenticationPolicy<R> = .notRequired
    ) {
        self.allowedSchemes = allowedSchemes?.flowLowercasedSet
        self.allowedHosts = allowedHosts?.flowLowercasedSet
        self.matcher = matcher
        self.authenticationPolicy = authenticationPolicy
    }

    public func decide(for url: URL) -> FlowDeepLinkDecision<R> {
        if let allowedSchemes {
            guard let scheme = url.scheme?.lowercased() else {
                return .rejected(reason: .schemeNotAllowed(actualScheme: url.scheme))
            }
            guard allowedSchemes.contains(scheme) else {
                return .rejected(reason: .schemeNotAllowed(actualScheme: url.scheme))
            }
        }

        if let allowedHosts {
            guard let host = url.host?.lowercased() else {
                return .rejected(reason: .hostNotAllowed(actualHost: url.host))
            }
            guard allowedHosts.contains(host) else {
                return .rejected(reason: .hostNotAllowed(actualHost: url.host))
            }
        }

        guard let plan = matcher.match(url) else {
            return .unhandled(url: url)
        }

        // Empty plans produce neither a route nor a visible change —
        // pass through as `.flowPlan`. Authentication policy is only
        // consulted when a primary route is available.
        guard let primaryRoute = plan.steps.first?.route else {
            return .flowPlan(plan)
        }

        switch authenticationPolicy {
        case .notRequired:
            return .flowPlan(plan)

        case .required(let shouldRequireAuthentication, let isAuthenticated):
            if shouldRequireAuthentication(primaryRoute), !isAuthenticated() {
                return .pending(
                    FlowPendingDeepLink(url: url, primaryRoute: primaryRoute, plan: plan)
                )
            }
            return .flowPlan(plan)
        }
    }
}

private extension Set where Element == String {
    var flowLowercasedSet: Set<String> {
        Set(map { $0.lowercased() })
    }
}
