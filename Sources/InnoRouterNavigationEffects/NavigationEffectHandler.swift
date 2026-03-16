// MARK: - NavigationEffectHandler.swift
// InnoRouterNavigationEffects - Navigation Effect Handler
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation
@_exported import InnoRouterCore

/// InnoFlow feature가 app/coordinator boundary에서 navigation intent를 실행하도록 돕는 핸들러입니다.
@MainActor
public final class NavigationEffectHandler<R: Route> {
    private let executeCommand: @MainActor (NavigationCommand<R>) -> NavigationResult<R>
    private let executeBatchCommands: @MainActor ([NavigationCommand<R>], Bool) -> NavigationBatchResult<R>
    private let executeTransactionCommands: @MainActor ([NavigationCommand<R>]) -> NavigationTransactionResult<R>

    /// 마지막 실행 결과
    public private(set) var lastResult: NavigationResult<R>?

    /// 마지막 batch 실행 결과
    public private(set) var lastBatchResult: NavigationBatchResult<R>?

    public init<N: Navigator & NavigationBatchExecutor & NavigationTransactionExecutor>(
        navigator: N
    ) where N.RouteType == R {
        self.executeCommand = { command in
            navigator.execute(command)
        }
        self.executeBatchCommands = { commands, stopOnFailure in
            navigator.executeBatch(commands, stopOnFailure: stopOnFailure)
        }
        self.executeTransactionCommands = { commands in
            navigator.executeTransaction(commands)
        }
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        let result = executeCommand(command)
        lastResult = result
        lastBatchResult = nil
        return result
    }

    @discardableResult
    public func execute(_ commands: [NavigationCommand<R>]) -> NavigationBatchResult<R> {
        execute(commands, stopOnFailure: false)
    }

    @discardableResult
    public func execute(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool
    ) -> NavigationBatchResult<R> {
        let batchResult = executeBatchCommands(commands, stopOnFailure)
        lastBatchResult = batchResult
        lastResult = batchResult.results.last
        return batchResult
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        let transactionResult = executeTransactionCommands(commands)
        lastResult = transactionResult.results.last
        lastBatchResult = nil
        return transactionResult
    }

    public func push(_ route: R) {
        _ = execute(.push(route))
    }

    public func pop() {
        _ = execute(.pop)
    }

    public func popToRoot() {
        _ = execute(.popToRoot)
    }

    public func replace(with routes: [R]) {
        _ = execute(.replace(routes))
    }

    @discardableResult
    public func executeIf(
        _ shouldExecute: @escaping @Sendable () -> Bool,
        command: NavigationCommand<R>
    ) -> NavigationResult<R> {
        guard shouldExecute() else {
            let result: NavigationResult<R> = .cancelled(.conditionFailed)
            lastResult = result
            lastBatchResult = nil
            return result
        }
        return execute(command)
    }

    @discardableResult
    public func executeGuarded(
        _ command: NavigationCommand<R>,
        prepare: @escaping @MainActor @Sendable (NavigationCommand<R>) async -> NavigationInterception<R>
    ) async -> NavigationResult<R> {
        switch await prepare(command) {
        case .proceed(let updatedCommand):
            return execute(updatedCommand)
        case .cancel(let reason):
            let result: NavigationResult<R> = .cancelled(reason)
            lastResult = result
            lastBatchResult = nil
            return result
        }
    }
}

public protocol NavigationEffect {
    associatedtype RouteType: Route
    var navigationCommand: NavigationCommand<RouteType>? { get }
    static func navigation(_ command: NavigationCommand<RouteType>) -> Self
}

public extension NavigationEffectHandler {
    @discardableResult
    func handle<E: NavigationEffect>(_ effect: E) -> NavigationResult<R>? where E.RouteType == R {
        guard let command = effect.navigationCommand else { return nil }
        return execute(command)
    }
}
