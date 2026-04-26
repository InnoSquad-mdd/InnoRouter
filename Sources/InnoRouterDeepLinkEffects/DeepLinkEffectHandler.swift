// MARK: - DeepLinkEffectHandler.swift
// InnoRouterDeepLinkEffects - DeepLink Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
@_exported import InnoRouterCore
@_exported import InnoRouterDeepLink
@_exported import InnoRouterNavigationEffects

/// InnoFlow Effect에서 DeepLink를 처리하는 핸들러입니다.
@MainActor
public final class DeepLinkEffectHandler<R: Route> {
    public enum Result: Sendable, Equatable {
        case executed(plan: NavigationPlan<R>, batch: NavigationBatchResult<R>)
        case pending(PendingDeepLink<R>)
        case rejected(reason: DeepLinkRejectionReason)
        case unhandled(url: URL)
        case invalidURL(input: String)
        case missingDeepLinkURL
        case noPendingDeepLink
    }

    private let pipeline: DeepLinkPipeline<R>

    public private(set) var pendingDeepLink: PendingDeepLink<R>?
    public let navigationHandler: NavigationEffectHandler<R>

    public init<N: Navigator & NavigationBatchExecutor & NavigationTransactionExecutor>(
        navigator: N,
        matcher: DeepLinkMatcher<R>,
        allowedSchemes: Set<String>? = nil,
        allowedHosts: Set<String>? = nil,
        authenticationPolicy: DeepLinkAuthenticationPolicy<R> = .notRequired,
        plan: @escaping DeepLinkPipeline<R>.Planner = { route in
            NavigationPlan(commands: [.push(route)])
        }
    ) where N.RouteType == R {
        self.pipeline = DeepLinkPipeline(
            allowedSchemes: allowedSchemes,
            allowedHosts: allowedHosts,
            resolve: { url in matcher.match(url) },
            authenticationPolicy: authenticationPolicy,
            plan: plan
        )
        self.navigationHandler = NavigationEffectHandler(navigator: navigator)
    }

    public func handle(_ url: URL) -> Result {
        switch pipeline.decide(for: url) {
        case .rejected(let reason):
            return .rejected(reason: reason)
        case .unhandled(let unhandledURL):
            return .unhandled(url: unhandledURL)
        case .pending(let pendingDeepLink):
            self.pendingDeepLink = pendingDeepLink
            return .pending(pendingDeepLink)
        case .plan(let plan):
            self.pendingDeepLink = nil
            let batch = navigationHandler.execute(plan.commands)
            return .executed(plan: plan, batch: batch)
        }
    }

    public func handle(_ urlString: String) -> Result {
        guard let url = URL(string: urlString) else {
            return .invalidURL(input: urlString)
        }
        return handle(url)
    }

    public func resumePendingDeepLink() -> Result {
        guard let pendingDeepLink else {
            return .noPendingDeepLink
        }

        if !canResume(pendingDeepLink) {
            return .pending(pendingDeepLink)
        }

        self.pendingDeepLink = nil
        let batch = navigationHandler.execute(pendingDeepLink.plan.commands)
        return .executed(plan: pendingDeepLink.plan, batch: batch)
    }

    public func resumePendingDeepLinkIfAllowed(
        _ authorize: @escaping @MainActor @Sendable (PendingDeepLink<R>) async -> Bool
    ) async -> Result {
        guard let pendingDeepLink else {
            return .noPendingDeepLink
        }
        let capturedPendingDeepLink = pendingDeepLink
        let isAuthorized = await authorize(capturedPendingDeepLink)

        guard self.pendingDeepLink == capturedPendingDeepLink else {
            if let currentPendingDeepLink = self.pendingDeepLink {
                return .pending(currentPendingDeepLink)
            }
            return .noPendingDeepLink
        }

        guard isAuthorized else {
            return .pending(capturedPendingDeepLink)
        }

        // Re-validate the captured plan against the current stack. If the stack was
        // mutated while `authorize` was suspended (e.g. a concurrent `popToRoot`),
        // keep the pending deep link rather than replaying a stale plan.
        guard navigationHandler.canExecuteSequentially(capturedPendingDeepLink.plan.commands) else {
            return .pending(capturedPendingDeepLink)
        }

        return resumePendingDeepLink()
    }

    public var hasPendingDeepLink: Bool {
        pendingDeepLink != nil
    }

    public func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    private func canResume(_ pendingDeepLink: PendingDeepLink<R>) -> Bool {
        switch pipeline.authenticationPolicy {
        case .notRequired:
            return true
        case .required(let shouldRequireAuthentication, let isAuthenticated):
            if !shouldRequireAuthentication(pendingDeepLink.route) {
                return true
            }
            return isAuthenticated()
        }
    }
}

public protocol DeepLinkEffect {
    var deepLinkURL: URL? { get }
    static func deepLink(_ url: URL) -> Self
}

public protocol RouterEffect: NavigationEffect, DeepLinkEffect {}

public extension DeepLinkEffectHandler {
    func handle<E: DeepLinkEffect>(_ effect: E) -> Result {
        guard let url = effect.deepLinkURL else {
            return .missingDeepLinkURL
        }
        return handle(url)
    }
}
