// MARK: - DeepLinkEffectHandler.swift
// InnoRouterEffects - DeepLink Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore
import InnoRouterDeepLink

// MARK: - DeepLinkEffectHandler

/// InnoFlow Effect에서 DeepLink를 처리하는 핸들러입니다.
@MainActor
public final class DeepLinkEffectHandler<R: Route> {

    // MARK: - Result Type

    /// DeepLink 처리 결과
    public enum Result: Sendable, Equatable {
        /// DeepLink를 NavigationPlan으로 실행했습니다.
        case executed(plan: NavigationPlan<R>, results: [NavigationResult<R>])

        /// 인증이 필요해 pending 상태로 보류했습니다.
        case pending(PendingDeepLink<R>)

        /// 스킴/호스트 등의 정책에 의해 거부되었습니다.
        case rejected(reason: DeepLinkRejectionReason)

        /// 매칭에 실패하거나 처리할 작업이 없습니다.
        case unhandled(url: URL)

        /// URL 문자열이 유효한 URL로 파싱되지 않았습니다.
        case invalidURL(input: String)

        /// Effect에 DeepLink URL이 없습니다.
        case missingDeepLinkURL

        /// 재개할 pending deep link가 없습니다.
        case noPendingDeepLink
    }

    // MARK: - Properties

    private let pipeline: DeepLinkPipeline<R>

    /// 인증 완료 후 재개할 pending deep link입니다.
    public private(set) var pendingDeepLink: PendingDeepLink<R>?

    /// 내부 NavigationEffectHandler에 접근
    public let navigationHandler: NavigationEffectHandler<R>

    // MARK: - Initialization

    public init<N: Navigator>(
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

    // MARK: - Handle

    /// DeepLink URL을 처리합니다.
    ///
    /// - Parameter url: 처리할 URL
    /// - Returns: 처리 결과
    public func handle(_ url: URL) async -> Result {
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
            let results = await navigationHandler.execute(plan.commands)
            return .executed(plan: plan, results: results)
        }
    }

    /// URL 문자열을 처리합니다.
    public func handle(_ urlString: String) async -> Result {
        guard let url = URL(string: urlString) else {
            return .invalidURL(input: urlString)
        }
        return await handle(url)
    }

    /// 인증 완료 후 pending deep link를 재개합니다.
    public func resumePendingDeepLink() async -> Result {
        guard let pendingDeepLink else {
            return .noPendingDeepLink
        }

        if !canResume(pendingDeepLink) {
            return .pending(pendingDeepLink)
        }

        self.pendingDeepLink = nil
        let results = await navigationHandler.execute(pendingDeepLink.plan.commands)
        return .executed(plan: pendingDeepLink.plan, results: results)
    }

    /// Pending deep link가 있는지 확인합니다.
    public var hasPendingDeepLink: Bool {
        pendingDeepLink != nil
    }

    /// Pending deep link를 취소합니다.
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

// MARK: - DeepLinkEffect Protocol

/// DeepLink를 Effect로 표현하기 위한 프로토콜입니다.
public protocol DeepLinkEffect {
    /// Effect에서 DeepLink URL을 추출합니다.
    var deepLinkURL: URL? { get }

    /// DeepLink URL을 Effect로 변환합니다.
    static func deepLink(_ url: URL) -> Self
}

// MARK: - Combined Effect Protocol

/// Navigation과 DeepLink를 모두 처리하는 Effect 프로토콜입니다.
public protocol RouterEffect: NavigationEffect, DeepLinkEffect {}

// MARK: - Effect Handler Extension

public extension DeepLinkEffectHandler {
    /// DeepLinkEffect에서 URL을 추출하여 처리합니다.
    func handle<E: DeepLinkEffect>(_ effect: E) async -> Result {
        guard let url = effect.deepLinkURL else {
            return .missingDeepLinkURL
        }
        return await handle(url)
    }
}
