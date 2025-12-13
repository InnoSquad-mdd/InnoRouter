// MARK: - NavigationEffectHandler.swift
// InnoRouterEffects - Navigation Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
import InnoRouterCore

// MARK: - NavigationEffectHandler

/// InnoFlow Effect에서 Navigation을 처리하는 핸들러입니다.
///
/// ## Usage with InnoFlow
/// ```swift
/// @InnoFlow
/// struct ProductFeature {
///     // State
///     struct State {
///         var products: [Product] = []
///     }
///
///     // Dependencies
///     let navigationHandler: NavigationEffectHandler<ProductRoute>
///
///     // Effect
///     enum Effect: Sendable {
///         case navigate(Navigation<ProductRoute>)
///         case loadProducts
///     }
///
///     // Reduce
///     func reduce(state: inout State, action: Action) -> Effect? {
///         switch action {
///         case .productTapped(let id):
///             return .navigate(.push(.detail(id: id)))
///
///         case .backTapped:
///             return .navigate(.pop)
///
///         case .logoutCompleted:
///             return .navigate(.popToRoot)
///         }
///     }
///
///     // Handle Effect
///     func handle(effect: Effect) async -> EffectOutput<Action> {
///         switch effect {
///         case .navigate(let command):
///             await navigationHandler.execute(command)
///             return .none
///
///         case .loadProducts:
///             // ... load products
///             return .none
///         }
///     }
/// }
/// ```
@MainActor
public final class NavigationEffectHandler<R: Route>: Sendable {
    
    // MARK: - Properties
    
    private let navigator: AnyNavigator<R>
    
    /// 마지막 실행 결과
    public private(set) var lastResult: NavResult<R>?
    
    // MARK: - Initialization
    
    public init(navigator: AnyNavigator<R>) {
        self.navigator = navigator
    }
    
    // MARK: - Execute
    
    /// Navigation 명령을 실행합니다.
    ///
    /// - Parameter command: 실행할 Navigation 명령
    /// - Returns: 실행 결과
    @discardableResult
    public func execute(_ command: NavCommand<R>) async -> NavResult<R> {
        let result = navigator.execute(command)
        lastResult = result
        return result
    }
    
    /// 여러 Navigation 명령을 순차적으로 실행합니다.
    ///
    /// - Parameter commands: 실행할 Navigation 명령들
    /// - Returns: 모든 실행 결과
    @discardableResult
    public func execute(_ commands: [NavCommand<R>]) async -> [NavResult<R>] {
        var results: [NavResult<R>] = []
        for command in commands {
            let result = navigator.execute(command)
            results.append(result)
        }
        lastResult = results.last
        return results
    }
    
    // MARK: - Convenience Methods
    
    /// Route를 push합니다.
    public func push(_ route: R) async {
        await execute(.push(route))
    }
    
    /// 현재 화면을 pop합니다.
    public func pop() async {
        await execute(.pop)
    }
    
    /// Root로 이동합니다.
    public func popToRoot() async {
        await execute(.popToRoot)
    }
    
    /// 스택을 교체합니다.
    public func replace(with routes: [R]) async {
        await execute(.replace(routes))
    }
    
    /// 조건부 네비게이션을 실행합니다.
    public func executeIf(
        _ condition: @escaping @Sendable () -> Bool,
        then command: NavCommand<R>
    ) async -> NavResult<R> {
        await execute(.conditional(condition, command))
    }
}

// MARK: - NavigationEffect Protocol

/// Navigation을 Effect로 표현하기 위한 프로토콜입니다.
///
/// InnoFlow의 Effect enum이 이 프로토콜을 채택하면
/// Navigation 관련 유틸리티를 사용할 수 있습니다.
public protocol NavigationEffect {
    associatedtype RouteType: Route
    
    /// Effect에서 Navigation을 추출합니다.
    var navigationCommand: NavCommand<RouteType>? { get }
    
    /// Navigation을 Effect로 변환합니다.
    static func navigation(_ command: NavCommand<RouteType>) -> Self
}

// MARK: - Effect Handler Extension

public extension NavigationEffectHandler {
    
    /// NavigationEffect에서 Navigation을 추출하여 실행합니다.
    @discardableResult
    func handle<E: NavigationEffect>(_ effect: E) async -> NavResult<R>? where E.RouteType == R {
        guard let command = effect.navigationCommand else { return nil }
        return await execute(command)
    }
}
