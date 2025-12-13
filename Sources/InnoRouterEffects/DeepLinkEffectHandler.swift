// MARK: - DeepLinkEffectHandler.swift
// InnoRouterEffects - DeepLink Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore
import InnoRouterDeepLink

// MARK: - DeepLinkEffectHandler

/// InnoFlow Effect에서 DeepLink를 처리하는 핸들러입니다.
///
/// ## Usage with InnoFlow
/// ```swift
/// @InnoFlow
/// struct AppFeature {
///     // Dependencies
///     let deepLinkHandler: DeepLinkEffectHandler<AppRoute>
///
///     // Effect
///     enum Effect: Sendable {
///         case handleDeepLink(URL)
///         case navigate(Navigation<AppRoute>)
///     }
///
///     // Reduce
///     func reduce(state: inout State, action: Action) -> Effect? {
///         switch action {
///         case .deepLinkReceived(let url):
///             return .handleDeepLink(url)
///         }
///     }
///
///     // Handle Effect
///     func handle(effect: Effect) async -> EffectOutput<Action> {
///         switch effect {
///         case .handleDeepLink(let url):
///             let result = await deepLinkHandler.handle(url)
///             switch result {
///             case .handled(let route):
///                 return .send(.navigatedToRoute(route))
///             case .authRequired(let route):
///                 return .send(.authRequiredForRoute(route))
///             case .unhandled:
///                 return .send(.deepLinkFailed)
///             }
///
///         case .navigate(let command):
///             await deepLinkHandler.navigationHandler.execute(command)
///             return .none
///         }
///     }
/// }
/// ```
@MainActor
public final class DeepLinkEffectHandler<R: Route>: Sendable {
    
    // MARK: - Result Type
    
    /// DeepLink 처리 결과
    public enum Result: Sendable {
        /// 성공적으로 처리되어 Route로 네비게이션함
        case handled(R)
        
        /// 인증이 필요하여 pending 상태
        case authRequired(PendingNav<R>)
        
        /// 처리되지 않음 (매칭 실패 또는 필터 거부)
        case unhandled
    }
    
    // MARK: - Properties
    
    private let navigator: AnyNavigator<R>
    private let pipeline: DeepLinkPipeline<R>
    
    /// Pending route (인증 필요 시 저장)
    public private(set) var pending: PendingNav<R>?
    
    /// 내부 NavigationEffectHandler에 접근
    public let navigationHandler: NavigationEffectHandler<R>
    
    // MARK: - Initialization
    
    public init(
        navigator: AnyNavigator<R>,
        matcher: DeepLinkMatcher<R>,
        allowedSchemes: Set<String>? = nil,
        allowedHosts: Set<String>? = nil,
        authGuard: (@Sendable (R) -> Bool)? = nil,
        isAuthenticated: (@Sendable () -> Bool)? = nil
    ) {
        self.navigator = navigator
        self.pipeline = DeepLinkPipeline(
            allowedSchemes: allowedSchemes,
            allowedHosts: allowedHosts,
            resolve: { url in matcher.match(url) },
            requiresAuthentication: authGuard,
            isAuthenticated: isAuthenticated
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
        case .rejected, .unhandled:
            return .unhandled

        case .pending(let pending):
            self.pending = pending
            return .authRequired(pending)

        case .plan(let plan):
            for command in plan.commands {
                _ = navigator.execute(command)
            }
            if let last = plan.commands.last,
               case .push(let route) = last {
                return .handled(route)
            }
            return .unhandled
        }
    }
    
    /// URL 문자열을 처리합니다.
    public func handle(_ urlString: String) async -> Result {
        guard let url = URL(string: urlString) else { return .unhandled }
        return await handle(url)
    }
    
    /// Pending route를 처리합니다 (인증 후 호출).
    @discardableResult
    public func handlePendingRoute() async -> R? {
        guard let pending else { return nil }
        self.pending = nil
        _ = navigator.execute(.push(pending.route))
        return pending.route
    }
    
    /// Pending route가 있는지 확인합니다.
    public var hasPendingRoute: Bool {
        pending != nil
    }
    
    /// Pending route를 취소합니다.
    public func clearPendingRoute() {
        pending = nil
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

extension DeepLinkEffectHandler {
    
    /// DeepLinkEffect에서 URL을 추출하여 처리합니다.
    public func handle<E: DeepLinkEffect>(_ effect: E) async -> Result {
        guard let url = effect.deepLinkURL else { return .unhandled }
        return await handle(url)
    }
}

// MARK: - Coordinator DeepLink Effect Handler

// NOTE: Coordinator integration intentionally removed from the adapter target.
